//! This file is a bunch of boilerplate that lets us draw "something" on the
//! screen. Don't worry too much about it.

mod math;

use nannou::{image::{DynamicImage, ImageBuffer}, prelude::*};

const WIDTH: usize = 256;
const HEIGHT: usize = 128;

fn main() {
    nannou::app(model)
        .update(update)
        .run();
}

#[derive(Debug, Default)]
struct Model {
    // TODO: put the FPGA stuff here instead
    rgb: [u8; 3],
    i: u8,
    j: u8,
}

fn model(app: &App) -> Model {
    app
        .new_window()
        .size((WIDTH * 3) as _, (HEIGHT * 3) as _)
        .resizable(false)
        .view(view)
        .build()
        .unwrap();

    Default::default()
}

fn update(_: &App, model: &mut Model, _: Update) {
    // TODO: step "FPGA" loop here
    // Some random RGB logic for now
    let j = model.j as usize;
    let k = (j + 1) % 3;

    model.rgb[j] = model.rgb[j].wrapping_sub(1);
    model.rgb[k] = model.rgb[k].wrapping_add(1);
    
    if model.i == 255 {
        model.i = 0;
        model.j = (model.j + 1) % 3;
    } else {
        model.i += 1;
    }
}

fn view(app: &App, model: &Model, frame: Frame) {
    // Generate the frame (TODO: get this from "FPGA" logic)
    let mut frame_out = [0u16; WIDTH * HEIGHT];

    let r = ((model.rgb[0] >> 3) as u16) << 11;
    let g = ((model.rgb[1] >> 2) as u16) << 5;
    let b = (model.rgb[2] >> 3) as u16;
    
    frame_out.fill(r | g | b);

    // Convert to something WGPU can use (rgb565 -> rgb8)
    let frame_wgpu = frame_out
        .iter()
        .flat_map(|rgb| [rgb >> 11, (rgb >> 5) & 0x3F, rgb & 0x1F])
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