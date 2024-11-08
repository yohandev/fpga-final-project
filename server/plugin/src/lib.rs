
use quill::{BlockPosition, Game, Plugin, Position};

#[quill::plugin]
pub struct BlockPlace;

impl Plugin for BlockPlace {
    fn enable(_game: &mut quill::Game, setup: &mut quill::Setup<Self>) -> Self {
        setup.add_system(system);
        Self
    }

    fn disable(self, _game: &mut quill::Game) {}
}

fn system(_plugin: &mut BlockPlace, game: &mut Game) {
    // WARN: just like how sending absolutely everything (block-data-wise) is too slow,
    // simply iterating over all those blocks is *also* too slow. we should only be querying the
    // blocks we need to send over serial
    for (_, pos) in game.query::<&Position>() {
        let pos = pos.block();
        let mut tally = 0;
        for z in -64..64 {
            for y in -64..64 {
                for x in -64..64 {
                    let Ok(_block) = game.block(pos + BlockPosition::new(x, y, z)) else {
                        continue;
                    };
                    tally += 1;
                }
            }
        }
        println!("Just iterated the {tally} blocks around {pos:?}!");
    }

    let ports = serialport::available_ports().expect("No ports found!");
    for p in ports {
        println!("{}", p.port_name);
    }
}