mod block;

use std::{fs::File, os::unix::fs::FileExt};

use block::Block;
use quill::{BlockKind, BlockPosition, Game, Plugin, Position};
use serialport::{SerialPort, SerialPortType, UsbPortInfo};

#[quill::plugin]
pub struct FpgaPlugin {
    serial: Option<Box<dyn SerialPort>>,

    /// Latest chunk data sent to the FPGA
    chunk_data: Box<[Block]>,
    /// Center of the [FpgaPlugin::chunk_data] in world cordiantes
    chunk_center: Option<BlockPosition>,
    /// Handle for chunk.bin
    chunk_file: File,
}

impl Plugin for FpgaPlugin {
    fn enable(_game: &mut quill::Game, setup: &mut quill::Setup<Self>) -> Self {
        setup.add_system(Self::connect_serial);
        setup.add_system(Self::send_blocks);
        setup.add_system(Self::save_chunk_local);

        Self {
            serial: None,
            chunk_data: vec![Block::Air; Self::CHUNK_SIZE.pow(3)].into_boxed_slice(),
            chunk_center: Default::default(),
            chunk_file: File::create("chunk.bin").unwrap(),
        }
    }

    fn disable(self, _game: &mut quill::Game) {}
}

impl FpgaPlugin {
    const SERIAL_BAUD: u32 = 115200;
    const CHUNK_SIZE: usize = 128;

    /// Attempts to connect the FPGA each frame
    fn connect_serial(&mut self, _: &mut Game) {
        // No easy way to detect disconnects, so we do a random I/O operation and if
        // that fails just assume the port was closed.
        if let Some(port) = &self.serial {
            if let Err(serialport::Error { kind, .. }) = port.data_bits() {
                // Explicitely close the port
                drop(self.serial.take());

                println!("Closed serial port because of {kind:?}!");
            } else {
                // Port is open and active, don't try to open a new one!
                return;
            }
        }

        // Find all the ports that might be our FPGA
        let mut ports = serialport::available_ports()
            .expect("No ports found!")
            .into_iter()
            .filter(|port| {
                match &port.port_type {
                    SerialPortType::UsbPort(UsbPortInfo { manufacturer, .. }) => {
                        manufacturer
                            .as_ref()
                            .is_some_and(|m| m == "Xilinx")
                    },
                    _ => false,
                }
            })
            .map(|port| port.port_name)
            .collect::<Vec<_>>();

        // On unix, prefer /dev/cu.* over /dev/tty.*
        if ports.len() > 1 {
            ports = ports
                .into_iter()
                .filter(|port| !port.starts_with("/dev/tty"))
                .collect();
        }
        
        // Otherwise, just pick the first one
        let Some(port) = ports.first() else {
            // No ports found!
            return;
        };

        // Open the serial port
        if let Ok(serial) = serialport::new(port, Self::SERIAL_BAUD).open() {
            self.serial = Some(serial);

            println!("Connected to {port}!");
        }
    }

    /// Sends blocks to the FPGA
    /// TODO: (Win Win) change this. see [FpgaPlugin::save_chunk_local] for inspiration
    fn send_blocks(&mut self, game: &mut Game) {
        let Some(port) = &mut self.serial else {
            return;
        };

        for (_, pos) in game.query::<&Position>() {
            if let Ok(block) = game.block(pos.block()) {
                port.write(&block.id().to_be_bytes()).unwrap();
            }
        }
    }

    /// Saves the entire 128*128*128 chunk near the player each time they move. This creates/modifies
    /// a local file "chunk.bin", which can be used for debugging and to compare against the software
    /// implementation.
    fn save_chunk_local(&mut self, game: &mut Game) {
        const HALF_CHUNK_SIZE: i32 = (FpgaPlugin::CHUNK_SIZE as i32) / 2;
        
        // Take the position of the first player
        let Some((_, pos)) = game.query::<&Position>().next() else {
            return;
        };
        let pos = pos.block();

        // No movement, do nothing
        if self.chunk_center == Some(pos) {
            return;
        }
        self.chunk_center = Some(pos);

        // This is pretty inefficient, as we have to query the entire chunk
        for (i, block) in self.chunk_data.iter_mut().enumerate() {
            // 1D -> 3D index
            let x = i % Self::CHUNK_SIZE;
            let y = (i / Self::CHUNK_SIZE) % Self::CHUNK_SIZE;
            let z = i / (Self::CHUNK_SIZE * Self::CHUNK_SIZE);

            // Recenter around pos
            let p = BlockPosition {
                x: (x as i32) - HALF_CHUNK_SIZE + pos.x,
                y: (y as i32) - HALF_CHUNK_SIZE + pos.y,
                z: (z as i32) - HALF_CHUNK_SIZE + pos.z,
            };

            if let Ok(state) = game.block(p) {
                // Convert into our block type
                *block = BlockKind::from_id(state.id() as _).unwrap_or(BlockKind::Air).into();
            }
        }

        // Save file
        let data = unsafe { std::mem::transmute(&*self.chunk_data) };

        if let Err(e) = self.chunk_file.write_all_at(data, 0) {
            eprintln!("Error writing chunk.bin! {e}");
        };
    }
}