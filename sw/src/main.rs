//! This file is a bunch of boilerplate that lets us draw "something" on the
//! screen. Don't worry too much about it. See `top_level.rs`

mod vtu;
mod math;
mod block;
mod cache;
mod top_level;
mod orchestrator;

use math::Vec3;
use nannou::{image::{DynamicImage, ImageBuffer}, prelude::*};
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
}

fn model(app: &App) -> Model {
    app
        .new_window()
        .size((WIDTH * 3) as _, (HEIGHT * 3) as _)
        .resizable(false)
        .view(view)
        .key_pressed(key_pressed)
        .build()
        .unwrap();

    let mut top_level = TopLevel::default();

    top_level.reset = true;
    top_level.rising_clk_edge();
    top_level.reset = false;

    Model {
        top_level,
    }
}

fn update(_: &App, model: &mut Model, _: Update) {    
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
        Key::I => model.top_level.orchestrator.camera_pos_in += Vec3::FORWARD,
        Key::K => model.top_level.orchestrator.camera_pos_in -= Vec3::FORWARD,
        Key::L => model.top_level.orchestrator.camera_pos_in += Vec3::RIGHT,
        Key::J => model.top_level.orchestrator.camera_pos_in -= Vec3::RIGHT,
        Key::Space => model.top_level.orchestrator.camera_pos_in += Vec3::UP,
        Key::M => model.top_level.orchestrator.camera_pos_in -= Vec3::UP,
        _ => {}
    }
    println!("{}", model.top_level.orchestrator.camera_pos_in)
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