mod block;

// for Windows
use std::fs::File;
use std::io::Write;
#[cfg(target_family="unix")]
use std::os::unix::fs::FileExt;

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
        // setup.add_system(Self::send_blocks);
        setup.add_system(Self::save_chunk_local);
        // setup.add_system(Self::player_input);

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
    const CHUNK_SIZE: usize = 64;

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
    fn send_blocks(&mut self, _game: &mut Game) {
        // Make sure the serial port is available
        let Some(port) = &mut self.serial else {
            eprintln!("No serial port connected to send data!");
            return;
        };
    
        // Ensure chunk data is available
        if self.chunk_data.is_empty() {
            eprintln!("No chunk data available to send!");
            return;
        }
    
        // Serialize the chunk data into a byte slice
        let data: &[u8] = unsafe { std::mem::transmute(&*self.chunk_data) };

        // Put the byte into a packet containing the valid start and stop signal
        for byte in data {
            let packet = [0, *byte, 1];
            if let Err(e) = port.write_all(&packet) {
                eprintln!("Failed to send data byte to FPGA: {e}");
                return;
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

        #[cfg(target_family="unix")]
        if let Err(e) = self.chunk_file.write_all_at(data, 0) {
            eprintln!("Error writing chunk.bin! {e}");
        };
        #[cfg(not(target_family="unix"))]
        if let Err(e) = self.chunk_file.write_all(data) {
            eprintln!("Error writing chunk.bin! {e}");
        };
    }

    // Picks up the player's input signal from FPGA, and telling the server how to update
    // May need to look over if this works
    fn player_input(&mut self, game: &mut Game) {
        // Make sure the serial port is available
        let Some(port) = &mut self.serial else {
            eprintln!("No serial port connected to receive input!");
            return;
        };

        // Buffer to store the received single-byte signal from FPGA
        let mut signal = [0u8; 1];
        println!("{:?}", port.read_exact(&mut signal));
        match port.read_exact(&mut signal) {
            Ok(_) => {
                // Decode the signal into a movement command
                match signal[0] {
                    0x01 => {
                        self.update_player_state(game, 0, 0, 1); // Move forward
                    }
                    0x02 => {
                        self.update_player_state(game, 0, 0, -1); // Move backward
                    }
                    0x03 => {
                        self.update_player_state(game, -1, 0, 0); // Move left
                    }
                    0x04 => {
                        self.update_player_state(game, 1, 0, 0); // Move right
                    }
                    _ => {
                        eprintln!("Unknown signal received from FPGA!");
                    }
                }
            }
            Err(e) => {
                eprintln!("Failed to receive input from FPGA: {e}");
        }
    }
    }

    fn update_player_state(&mut self, game: &mut Game, dx: i32, dy: i32, dz: i32) {
        // Find the player
        if let Some((entity, pos)) = game.query::<&mut Position>().next() {
            // Update the player's position
            let new_pos = BlockPosition {
                x: pos.block().x + dx,
                y: pos.block().y + dy,
                z: pos.block().z + dz,
            };
    
            // Trigger the save and send operations
            // self.save_chunk_local(game);
            // self.send_blocks(game);
    
            println!("Player moved to new position: {:?}", new_pos);
        } else {
            eprintln!("Player not found.");
        }
    }
}