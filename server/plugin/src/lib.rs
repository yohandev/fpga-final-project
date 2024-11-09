
use quill::{Game, Plugin, Position};
use serialport::{SerialPort, SerialPortType, UsbPortInfo};

#[quill::plugin]
pub struct FpgaPlugin {
    serial: Option<Box<dyn SerialPort>>,
}

impl Plugin for FpgaPlugin {
    fn enable(_game: &mut quill::Game, setup: &mut quill::Setup<Self>) -> Self {
        setup.add_system(Self::connect_serial);
        setup.add_system(Self::send_blocks);
        
        Self {
            serial: None
        }
    }

    fn disable(self, _game: &mut quill::Game) {}
}

impl FpgaPlugin {
    const SERIAL_BAUD: u32 = 115200;

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
}