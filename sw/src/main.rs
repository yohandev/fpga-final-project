//! This file is a bunch of boilerplate that lets us draw "something" on the
//! screen. Don't worry too much about it. See `top_level.rs`

mod vtu;
mod math;
mod block;
mod cache;
mod top_level;
mod orchestrator;

use math::Vec3;
use nannou::{image::{DynamicImage, ImageBuffer}, prelude::*, winit::dpi::PhysicalPosition};
use orchestrator::Orchestrator;
use top_level::TopLevel;

const WIDTH: usize = Orchestrator::FRAME_WIDTH;
const HEIGHT: usize = Orchestrator::FRAME_HEIGHT;

fn main() {
    nannou::app(model)
        .update(update)
        .run();
}

#[derive(Debug, Default)]
struct Model {
    top_level: TopLevel,
    input: (f32, f32, f32),
    heading: (f32, f32),
    velocity: Vec3,
}

fn model(app: &App) -> Model {
    app
        .new_window()
        .size((WIDTH * 3) as _, (HEIGHT * 3) as _)
        .resizable(false)
        .view(view)
        .key_pressed(key_pressed)
        .key_released(key_released)
        .mouse_wheel(mouse_wheel)
        .build()
        .unwrap();

    let mut top_level = TopLevel::default();

    top_level.reset = true;
    top_level.rising_clk_edge();
    top_level.reset = false;

    Model {
        top_level,
        ..Default::default()
    }
}

fn update(_: &App, model: &mut Model, update: Update) {    
    // First person camera    
    let speed = fixed!(8.0);
    let dir = Vec3 {
        x: fixed!(model.input.0 * model.heading.0.cos() + model.input.2 * model.heading.0.sin()),
        y: fixed!(model.input.1),
        z: fixed!(model.input.0 * -model.heading.0.sin() + model.input.2 * model.heading.0.cos()),
    };
    let dt = fixed!(update.since_last.as_secs_f32());

    model.velocity = fixed!(0.3) * model.velocity + fixed!(0.7) * dir;
    model.top_level.orchestrator.camera_pos_in += speed * model.velocity * dt;
    
    // Step "FPGA" loop
    let mut i = 0;
    let start = std::time::Instant::now();
    
    while !model.top_level.orchestrator.frame_done_out {
        model.top_level.rising_clk_edge();
        i += 1;
    }
    while model.top_level.orchestrator.frame_done_out {
        model.top_level.rising_clk_edge();
    }

    let duration = std::time::Instant::now() - start;

    println!("Took {i} cycles, simulation ran for {}ms", duration.as_millis());
}

fn key_pressed(_: &App, model: &mut Model, key: Key) {
    match key {
        Key::I => model.input.2 = -1.0,
        Key::K => model.input.2 = 1.0,
        Key::L => model.input.0 = 1.0,
        Key::J => model.input.0 = -1.0,
        Key::Space => model.input.1 = 1.0,
        Key::M => model.input.1 = -1.0,
        _ => {}
    }
}

fn key_released(_: &App, model: &mut Model, key: Key) {
    match key {
        Key::I | Key::K => model.input.2 = 0.0,
        Key::L | Key::J => model.input.0 = 0.0,
        Key::Space | Key::M => model.input.1 = 0.0,
        _ => {}
    }
}

fn mouse_wheel(_: &App, model: &mut Model, scroll: MouseScrollDelta, _: TouchPhase) {
    let MouseScrollDelta::PixelDelta(PhysicalPosition { x, y }) = scroll else {
        return;
    };
    
    model.heading.0 += (x as f32) * 0.005;
    // model.heading.1 += (y as f32) * 0.005;

    let x = model.heading.0.cos() * model.heading.1.cos();
    let y = model.heading.1.sin();
    let z = model.heading.0.sin() * model.heading.1.cos();
    let m = (x*x + y*y + z*z).sqrt();

    model.top_level.orchestrator.camera_heading_in = Vec3 {
        x: fixed!(x / m),
        y: fixed!(y / m),
        z: fixed!(z / m),
    };
}

fn view(app: &App, model: &Model, frame: Frame) {
    // Get the frame from the FPGA
    let frame_out = &model.top_level.orchestrator.frame_buffer_out;

    // Convert to something WGPU can use (rgb565 -> rgb8)
    let frame_wgpu = frame_out
        .iter()
        .flat_map(|rgb| [rgb.r(), rgb.g(), rgb.b()])
        .map(|n| n as u8)
        .collect::<Vec<_>>();
    let frame_wgpu = ImageBuffer::from_vec(WIDTH as _, HEIGHT as _, frame_wgpu).unwrap();
    let frame_wgpu = DynamicImage::ImageRgb8(frame_wgpu);
    let texture = wgpu::Texture::from_image(app, &frame_wgpu);

    // Draw onto the screen
    let draw = app.draw();
    
    frame.clear(BLACK);
    draw.texture(&texture).w((WIDTH * 3) as _).h((HEIGHT * 3) as _);

    draw.to_frame(app, &frame).unwrap();
}