use crate::{block::Block, math::Vec3i};

use super::MockCache;

#[derive(Debug, Default)]
pub struct L3Cache {
    /// Reset cache to a known state
    pub reset: bool,
    /// Voxel index being queried
    pub addr_in: Vec3i,
    /// Whether [L3Cache::addr_in] should actually be queried
    pub read_enable_in: bool,
    /// Voxel data being queried
    pub voxel_out: Block,
    /// Whether [L3Cache::voxel_out] corresponds to the address inputted
    pub valid_out: bool,

    /// Shhhh...
    ddr_ram: MockCache,
}

impl L3Cache {
    pub fn rising_clk_edge(&mut self) {
        if self.reset {
            self.voxel_out = Block::Air;
            self.valid_out = false;
            return;
        }

        if !self.read_enable_in {
            self.valid_out = false;
            return;
        }

        // TODO: simulate DDR3 taking forever
        self.voxel_out = self.ddr_ram.query(self.addr_in).unwrap_or_default();
        self.valid_out = true;
    }
}