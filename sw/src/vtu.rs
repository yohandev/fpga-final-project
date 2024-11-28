use crate::{block::Block, cache::MockCache, fixed, math::{Fixed, Vec3, Vec3i}};

#[derive(Debug, Default)]
pub struct VoxelTraversalUnit {
    /// World-space coordinate where the ray begins, e.g. camera's position
    pub ray_origin_in: Vec3,
    /// Heading of the ray. Doesn't need to be normalized.
    pub ray_direction_in: Vec3,
    /// The voxel that this VTU last intersected with
    pub voxel_out: Block,
    /// Surface normal of the voxel hit
    pub normal_out: Vec3,
    /// Whether or not [VoxelTraversalUnit::voxel_out] corresponds to the inputs
    pub valid_out: bool,
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

        enum Axis { None, X, Y, Z }

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
        todo!()
    }
}