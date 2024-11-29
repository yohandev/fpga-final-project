use std::{cell::RefCell, rc::Rc};

use crate::{block::Block, cache::{L2Cache, MockCache}, fixed, math::{Fixed, Vec3, Vec3i}};

#[derive(Debug, Default)]
pub struct VoxelTraversalUnit {
    /// Reset VTU to a known state
    pub reset: bool,
    /// World-space coordinate where the ray begins, e.g. camera's position
    pub ray_origin_in: Vec3,
    /// Heading of the ray. Doesn't need to be normalized.
    pub ray_direction_in: Vec3,
    /// Reinitialize the internal state of the VTU with the input parameters?
    pub ray_init_in: bool,
    /// The voxel that this VTU last intersected with
    pub voxel_out: Block,
    /// Surface normal of the voxel hit
    pub normal_out: Vec3,
    /// Whether or not [VoxelTraversalUnit::voxel_out] corresponds to the inputs
    pub valid_out: bool,
    /// Reference to an L2 cache used for cache misses
    /// TODO: store also an L1 cache
    pub l2: Rc<RefCell<L2Cache<1, 16>>>,

    /// Normalized ray direction being traversed
    ray_direction: Vec3,
    /// Current voxel along the ray being traversed
    ray_position: Vec3i,
    /// Change in voxel position
    ray_step: Vec3i,
    /// Movement along each axis per unit t
    ray_t_delta: Vec3,
    /// Movement along each axis per unit t
    ray_dist: Vec3,
    /// Nearest voxel boundary in units of t
    ray_t_max: Vec3,
    /// How many voxels has the ray traversed, so far?
    num_steps: usize,
    /// Along which axis was the last step taken?
    last_step: Axis,
}

#[derive(Debug, Default)]
enum Axis {
    #[default]
    None,
    X,
    Y,
    Z,
}

impl VoxelTraversalUnit {
    /// Unrealistic ray cast that finishes instantly, for testing
    pub fn mock_cast(&mut self) {
        let cache = MockCache::default();

        let ray_ori = self.ray_origin_in;
        let ray_dir = self.ray_direction_in.normalized();

        let mut ray_pos = self.ray_origin_in.floor();
        let step = Vec3i {
            x: if ray_dir.x > fixed!(0.0) { 1 } else { -1 },
            y: if ray_dir.y > fixed!(0.0) { 1 } else { -1 },
            z: if ray_dir.z > fixed!(0.0) { 1 } else { -1 },
        };

        // Movement along each axis per unit t
        // Ray direction is normalized, so every component is <= 1
        let t_delta = Vec3 {
            x: ray_dir.x.recip_lte1().abs(),
            y: ray_dir.y.recip_lte1().abs(),
            z: ray_dir.z.recip_lte1().abs(),
        };
        let dist = Vec3 {
            x: if step.x > 0 { fixed!(1.0) - ray_ori.x + ray_pos.x.into() } else { ray_ori.x - ray_pos.x.into() },
            y: if step.y > 0 { fixed!(1.0) - ray_ori.y + ray_pos.y.into() } else { ray_ori.y - ray_pos.y.into() },
            z: if step.z > 0 { fixed!(1.0) - ray_ori.z + ray_pos.z.into() } else { ray_ori.z - ray_pos.z.into() },
        };

        // Nearest voxel boundary in units of t
        let mut t_max = Vec3 {
            x: if ray_dir.x != fixed!(0.0) { t_delta.x * dist.x } else { Fixed::MAX },
            y: if ray_dir.y != fixed!(0.0) { t_delta.y * dist.y } else { Fixed::MAX },
            z: if ray_dir.z != fixed!(0.0) { t_delta.z * dist.z } else { Fixed::MAX },
        };

        let mut num_steps = 0;
        let mut last_step = Axis::None;

        loop {
            // Exit condition -> Out of render distance
            if num_steps > 220 {
                // "Nothing hit" is encoded as an air block
                self.voxel_out = Block::Air;
                self.valid_out = true;
                break;
            }
            // Exit condition -> Out of bounds
            let Some(block) = cache.query(ray_pos) else {
                // "Nothing hit" is encoded as an air block
                self.voxel_out = Block::Air;
                self.valid_out = true;
                break;
            };
            
            // Exit condition -> Found a block!
            if block != Block::Air {
                self.voxel_out = block;
                self.valid_out = true;
                self.normal_out = match last_step {
                    Axis::None => Default::default(),
                    Axis::X => Fixed::from(-step.x) * Vec3::RIGHT,
                    Axis::Y => Fixed::from(-step.y) * Vec3::UP,
                    Axis::Z => Fixed::from(-step.z) * Vec3::FORWARD,
                };
                break;
            }

            // Advance to the next voxel
            if t_max.x < t_max.y {
                if t_max.x < t_max.z {
                    ray_pos.x += step.x;
                    t_max.x += t_delta.x;
                    last_step = Axis::X;
                } else {
                    ray_pos.z += step.z;
                    t_max.z += t_delta.z;
                    last_step = Axis::Z;
                }
            } else {
                if t_max.y < t_max.z {
                    ray_pos.y += step.y;
                    t_max.y += t_delta.y;
                    last_step = Axis::Y;
                } else {
                    ray_pos.z += step.z;
                    t_max.z += t_delta.z;
                    last_step = Axis::Z;
                }
            }
            num_steps += 1;
        }
    }

    pub fn rising_clk_edge(&mut self) {
        let mut l2 = self.l2.borrow_mut();
        
        // Reset
        if self.reset {
            // Outputs
            self.voxel_out = Block::Air;
            self.valid_out = false;
            self.normal_out = Vec3::FORWARD;

            // Internal state
            self.ray_direction = Vec3::FORWARD;
            self.ray_position = Vec3i::default();
            self.ray_step = Vec3i::default();
            self.ray_t_delta = Vec3::default();
            self.ray_dist = Vec3::default();
            self.ray_t_max = Vec3::default();
            self.num_steps = 0;
            self.last_step = Axis::None;

            // Memory access
            l2.read_enable_in[0] = false;
            return;
        }

        // Change inputs -> reinitialize the traversal algorithm
        if self.ray_init_in {
            // TODO: this would probably take more than one cycle...
            self.ray_direction = self.ray_direction_in.normalized();
            self.ray_position = self.ray_origin_in.floor();

            // Shorthands, or this gets quite long
            let o = self.ray_origin_in;
            let d = self.ray_direction;
            let p = self.ray_position;

            self.ray_step = Vec3i {
                x: if d.x > fixed!(0.0) { 1 } else { -1 },
                y: if d.y > fixed!(0.0) { 1 } else { -1 },
                z: if d.z > fixed!(0.0) { 1 } else { -1 },
            };

            // Movement along each axis per unit t
            // Ray direction is normalized, so every component is <= 1
            self.ray_t_delta = Vec3 {
                x: d.x.recip_lte1().abs(),
                y: d.y.recip_lte1().abs(),
                z: d.z.recip_lte1().abs(),
            };
            self.ray_dist = Vec3 {
                x: if self.ray_step.x > 0 { fixed!(1.0) - o.x + p.x.into() } else { o.x - p.x.into() },
                y: if self.ray_step.y > 0 { fixed!(1.0) - o.y + p.y.into() } else { o.y - p.y.into() },
                z: if self.ray_step.z > 0 { fixed!(1.0) - o.z + p.z.into() } else { o.z - p.z.into() },
            };

            // Nearest voxel boundary in units of t
            self.ray_t_max = Vec3 {
                x: if d.x != fixed!(0.0) { self.ray_t_delta.x * self.ray_dist.x } else { Fixed::MAX },
                y: if d.y != fixed!(0.0) { self.ray_t_delta.y * self.ray_dist.y } else { Fixed::MAX },
                z: if d.z != fixed!(0.0) { self.ray_t_delta.z * self.ray_dist.z } else { Fixed::MAX },
            };

            // Other state stuff
            self.num_steps = 0;
            self.valid_out = false;

            l2.read_enable_in[0] = true;
            l2.addr_in[0] = self.ray_position;

            return;
        }

        // We're done
        if self.valid_out {
            return;
        }
        
        // Out of render distance
        if self.num_steps > 110 {
            self.voxel_out = Block::Air;
            self.valid_out = true;

            l2.read_enable_in[0] = false;
            return;
        }

        // TODO: VTU index
        
        // Stall until we can read the block
        if !l2.valid_out[0] {
            return;
        }

        // Hit a block!
        if l2.voxel_out[0] != Block::Air {
            self.voxel_out = l2.voxel_out[0];
            self.valid_out = true;
            self.normal_out = match self.last_step {
                Axis::None => Default::default(),
                Axis::X => Fixed::from(-self.ray_step.x) * Vec3::RIGHT,
                Axis::Y => Fixed::from(-self.ray_step.y) * Vec3::UP,
                Axis::Z => Fixed::from(-self.ray_step.z) * Vec3::FORWARD,
            };
            
            l2.read_enable_in[0] = false;
            return;
        }

        // Advance to the next voxel
        if self.ray_t_max.x < self.ray_t_max.y {
            if self.ray_t_max.x < self.ray_t_max.z {
                self.ray_position.x += self.ray_step.x;
                self.ray_t_max.x += self.ray_t_delta.x;
                self.last_step = Axis::X;
            } else {
                self.ray_position.z += self.ray_step.z;
                self.ray_t_max.z += self.ray_t_delta.z;
                self.last_step = Axis::Z;
            }
        } else {
            if self.ray_t_max.y < self.ray_t_max.z {
                self.ray_position.y += self.ray_step.y;
                self.ray_t_max.y += self.ray_t_delta.y;
                self.last_step = Axis::Y;
            } else {
                self.ray_position.z += self.ray_step.z;
                self.ray_t_max.z += self.ray_t_delta.z;
                self.last_step = Axis::Z;
            }
        }
        self.num_steps += 1;

        l2.read_enable_in[0] = true;
        l2.addr_in[0] = self.ray_position;
    }
}