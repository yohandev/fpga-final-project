//! Software implementation of what would otherwise run on an FPGA.
//! 
//! This isn't the centerpiece of this project, so organization is rather loose. But, some
//! patterns I'm using:
//!     - Avoid methods, those don't exist in hardware. Instead, make public fields and call `rising_clk_edge`
//!     - Modules that _own_ other modules are responsible for calling `rising_clk_edge`
//!         - Otherwise, if shared (e.g. through a [std::cell::RefCell]), **don't** call it
//!     - Every module should implement [Default], and have a `reset` signal to set the appropriate values
//!     - Registers/submodules that aren't input/outputs should be private fields

use crate::{math::Vec3, orchestrator::Orchestrator};

#[derive(Debug, Default)]
pub struct TopLevel {
    /// Signal to reset the module
    pub reset: bool,
    /// Module that manages the VTUs
    pub orchestrator: Orchestrator,
}

impl TopLevel {
    pub fn rising_clk_edge(&mut self) {
        self.orchestrator.camera_heading = Vec3::FORWARD;
        self.orchestrator.mock_render();
    }
}