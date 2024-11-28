use crate::{block::Block, fixed, math::{Fixed, Rgb565, Vec3}, vtu::VoxelTraversalUnit};

#[derive(Debug)]
pub struct Orchestrator {
    /// Framebuffer being drawn (no double buffering for now)
    pub frame_buffer: Box<[Rgb565]>,
    /// Camera's current position
    pub camera_pos: Vec3,
    /// Camera's heading (forward vector)
    pub camera_heading: Vec3,

    /// TODO: change this to many VTUs
    vtu: VoxelTraversalUnit,
}

impl Default for Orchestrator {
    fn default() -> Self {
        Self {
            frame_buffer: vec![Rgb565::default(); Self::NUM_PIXELS].into_boxed_slice(),
            camera_pos: Default::default(),
            camera_heading: Default::default(),
            vtu: Default::default(),
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
        let w = self.camera_heading.normalized();
        let u = Vec3::UP.cross(w).normalized();
        let v = w.cross(u);
        
        // UV vectors that span the viewport in world coordinates
        let viewport_u = u * Self::VIEWPORT_WIDTH;
        let viewport_v = -v * Self::VIEWPORT_HEIGHT;

        // Delta vectors from pixel to pixel
        let pixel_delta_x = viewport_u * fixed!(1.0 / Self::FRAME_WIDTH as f32);
        let pixel_delta_y = viewport_v * fixed!(1.0 / Self::FRAME_HEIGHT as f32);

        // Upper left pixel
        let viewport_corner = self.camera_pos - (w * fixed!(1.0)) - ((viewport_u + viewport_v) * fixed!(0.5));
        let pixel_center = viewport_corner + ((pixel_delta_x + pixel_delta_y) * fixed!(0.5));

        self.vtu.ray_origin_in = self.camera_pos;
        for (i, px) in self.frame_buffer.iter_mut().enumerate() {
            let x: Fixed = ((i % Self::FRAME_WIDTH) as i32).into();
            let y: Fixed = ((i / Self::FRAME_WIDTH) as i32).into();
            
            let pixel = pixel_center + (pixel_delta_x * x) + (pixel_delta_y * y);
            
            let light = self.vtu.normal_out.dot(Vec3::new(fixed!(1.0), fixed!(-5.0), fixed!(2.0)).normalized());
            let light = fixed!(0.4) + fixed!(0.2) * light;
            let apply_light = |c| (Fixed::from(c) * light).floor() as u8;
            let apply_light_rgb = |r, g, b| Rgb565::new(apply_light(r), apply_light(g), apply_light(b));

            self.vtu.ray_direction_in = pixel - self.camera_pos;
            self.vtu.mock_cast();

            match self.vtu.voxel_out {
                Block::Air => *px = Rgb565::new(174, 200, 235),
                Block::Water => *px = apply_light_rgb(52, 67, 138),
                _ => *px = apply_light_rgb(98, 168, 98),
            }
        }
    }
}