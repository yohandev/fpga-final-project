use std::{cell::RefCell, rc::Rc};

use crate::{block::Block, cache::{L2Cache, L3Cache}, fixed, math::{Fixed, Rgb565, Vec3}, vtu::VoxelTraversalUnit};

#[derive(Debug)]
pub struct Orchestrator {
    /// Reset the orchestrator to a known state
    pub reset: bool,
    /// Camera's current position
    pub camera_pos_in: Vec3,
    /// Camera's heading (forward vector)
    pub camera_heading_in: Vec3,
    /// Framebuffer being drawn (no double buffering for now)
    pub frame_buffer_out: Box<[Rgb565]>,
    /// Signal that goes high for one cycle after a frame is done rendering
    pub frame_done_out: bool,

    /// Camera position as being currently rendered
    camera_pos: Vec3,
    /// TODO: change this to many VTUs
    vtu: VoxelTraversalUnit,
    /// L2 cache shared by all the VTUs
    l2: Rc<RefCell<L2Cache<1, 16>>>,
    /// L3 cache shared by all the VTUs
    l3: Rc<RefCell<L3Cache>>,
    /// Index of the next pixel to be rendered
    next_pixel: usize,
    /// Location of the top-left pixel in world space
    pixel0_loc: Vec3,
    /// Horizontal delta from pixel to pixel, in world space
    pixel_delta_u: Vec3,
    /// Vertical delta from pixel to pixel, in world space
    pixel_delta_v: Vec3,
}

impl Default for Orchestrator {
    fn default() -> Self {
        Self {
            reset: Default::default(),
            frame_buffer_out: vec![Rgb565::default(); Self::NUM_PIXELS].into_boxed_slice(),
            camera_pos_in: Default::default(),
            camera_heading_in: Default::default(),
            frame_done_out: Default::default(),
            camera_pos: Default::default(),
            vtu: Default::default(),
            l2: Default::default(),
            l3: Default::default(),
            next_pixel: Default::default(),
            pixel0_loc: Default::default(),
            pixel_delta_u: Default::default(),
            pixel_delta_v: Default::default(),
        }
    }
}

impl Orchestrator {
    pub const FRAME_WIDTH: usize = 160;
    pub const FRAME_HEIGHT: usize = 128;
    pub const NUM_PIXELS: usize = Self::FRAME_WIDTH * Self::FRAME_HEIGHT;

    pub const VIEWPORT_HEIGHT: Fixed = fixed!(2.0);
    pub const VIEWPORT_WIDTH: Fixed = fixed!(2.0 * (Self::FRAME_WIDTH as f32) / (Self::FRAME_HEIGHT as f32));

    /// Unrealistic render that finishes instantly (and isn't parallelized)
    pub fn mock_render(&mut self) {
        // Calculate orthonormal basis of camera
        let w = self.camera_heading_in.normalized();
        let u = Vec3::UP.cross(w).normalized();
        let v = w.cross(u);
        
        // UV vectors that span the viewport in world coordinates
        let viewport_u = u * Self::VIEWPORT_WIDTH;
        let viewport_v = -v * Self::VIEWPORT_HEIGHT;

        // Delta vectors from pixel to pixel
        let pixel_delta_x = viewport_u * fixed!(1.0 / Self::FRAME_WIDTH as f32);
        let pixel_delta_y = viewport_v * fixed!(1.0 / Self::FRAME_HEIGHT as f32);

        // Upper left pixel
        let viewport_corner = self.camera_pos_in - (w * fixed!(1.0)) - ((viewport_u + viewport_v) * fixed!(0.5));
        let pixel_center = viewport_corner + ((pixel_delta_x + pixel_delta_y) * fixed!(0.5));

        self.vtu.ray_origin_in = self.camera_pos_in;
        for (i, px) in self.frame_buffer_out.iter_mut().enumerate() {
            let x: Fixed = ((i % Self::FRAME_WIDTH) as i32).into();
            let y: Fixed = ((i / Self::FRAME_WIDTH) as i32).into();
            
            let pixel = pixel_center + (pixel_delta_x * x) + (pixel_delta_y * y);
            
            let light = self.vtu.normal_out.dot(Vec3::new(fixed!(1.0), fixed!(-5.0), fixed!(2.0)).normalized());
            let light = fixed!(0.4) + fixed!(0.2) * light;
            let apply_light = |c| (Fixed::from(c) * light).floor() as u8;
            let apply_light_rgb = |r, g, b| Rgb565::new(apply_light(r), apply_light(g), apply_light(b));

            self.vtu.ray_direction_in = pixel - self.camera_pos_in;
            self.vtu.mock_cast();

            match self.vtu.voxel_out {
                Block::Air => *px = Rgb565::new(174, 200, 235),
                Block::Water => *px = apply_light_rgb(52, 67, 138),
                _ => *px = apply_light_rgb(98, 168, 98),
            }
        }
    }

    pub fn rising_clk_edge(&mut self) {
        // Propagate signals to owned submodules
        // Reset
        (*self.l2).borrow_mut().reset = self.reset;
        (*self.l3).borrow_mut().reset = self.reset;
        self.vtu.reset = self.reset;
        
        // Clock edge
        (*self.l2).borrow_mut().rising_clk_edge();
        (*self.l3).borrow_mut().rising_clk_edge();
        self.vtu.rising_clk_edge();

        // Reset
        if self.reset {
            self.frame_buffer_out.fill(Default::default());
            self.frame_done_out = false;
            self.camera_pos = Vec3::default();
            self.next_pixel = Self::NUM_PIXELS;
            self.pixel0_loc = Vec3::default();
            self.pixel_delta_u = Vec3::default();
            self.pixel_delta_v = Vec3::default();
            
            (*self.l2).borrow_mut().l3 = Rc::clone(&self.l3);
            self.vtu.l2 = Rc::clone(&self.l2);
            return;
        }

        self.frame_done_out = self.next_pixel == Self::NUM_PIXELS - 1;

        // Initialize camera vectors
        if self.next_pixel == Self::NUM_PIXELS {
            self.next_pixel = 0;
            self.camera_pos = self.camera_pos_in;
            
            // Calculate orthonormal basis of camera
            let w = self.camera_heading_in.normalized();
            let u = Vec3::UP.cross(w).normalized();
            let v = w.cross(u);
            
            // UV vectors that span the viewport in world coordinates
            let viewport_u = u * Self::VIEWPORT_WIDTH;
            let viewport_v = -v * Self::VIEWPORT_HEIGHT;

            // Delta vectors from pixel to pixel
            self.pixel_delta_u = viewport_u * fixed!(1.0 / Self::FRAME_WIDTH as f32);
            self.pixel_delta_v = viewport_v * fixed!(1.0 / Self::FRAME_HEIGHT as f32);

            // Upper left pixel
            let viewport_corner = self.camera_pos_in - (w * fixed!(1.0)) - ((viewport_u + viewport_v) * fixed!(0.5));
            self.pixel0_loc = viewport_corner + ((self.pixel_delta_u + self.pixel_delta_v) * fixed!(0.5));

            self.vtu.ray_direction_in = self.pixel0_loc - self.camera_pos_in;
            self.vtu.ray_origin_in = self.camera_pos_in;
            self.vtu.ray_init_in = true;

            // TODO: this will probably require more cycles
            return;
        }

        // Draw current pixel
        self.vtu.ray_init_in = false;

        // VTU is done rendering a pixel!
        if self.vtu.valid_out {
            let px = &mut self.frame_buffer_out[self.next_pixel];

            let sun = Vec3 {
                x: fixed!(1.0),
                y: fixed!(-5.0),
                z: fixed!(2.0)
            };
            let light = fixed!(0.4) + fixed!(0.2) * self.vtu.normal_out.dot(sun.normalized());

            *px = match self.vtu.voxel_out {
                Block::Air => Rgb565::new(174, 200, 235),
                Block::Water => Rgb565::new(52, 67, 138),
                Block::Grass => Rgb565::new(90, 133, 77),
                Block::Dirt => Rgb565::new(133, 96, 77),
                Block::OakLog => Rgb565::new(91, 58, 42),
                Block::OakLeaves => Rgb565::new(129, 165, 118),
                _ => Rgb565::new(82, 70, 84),
            };
            if self.vtu.voxel_out != Block::Air {
                *px *= light;
            }

            self.next_pixel += 1;

            let x = ((self.next_pixel % Self::FRAME_WIDTH) as i32).into();
            let y = ((self.next_pixel / Self::FRAME_WIDTH) as i32).into();
            let pixel_loc = self.pixel0_loc + (self.pixel_delta_u * x) + (self.pixel_delta_v * y);

            self.vtu.ray_direction_in = pixel_loc - self.camera_pos;
            self.vtu.ray_origin_in = self.camera_pos;
            self.vtu.ray_init_in = true;
        }
    }
}