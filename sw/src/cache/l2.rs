use crate::{block::Block, math::Vec3i};

pub struct L2Cache {
    /// Amount of times [L2Cache::query] must be called before returning anything.
    stall: usize,
    /// The block being currently accessed
    key: Vec3i,
}

impl L2Cache {
    /// Query the block at the given position. Keeps returning [Option::None] until
    /// it's stalled enough cycles (like it would it hardware). This is ignored if
    /// a block was previously queried and is still stalling.
    pub fn query(&mut self, idx: Vec3i) -> Option<Block> {
        if self.stall == 0 {
            if idx == self.key {
                return Some(todo!("index"));
            }
            // Start a new query
            self.key = idx;
            self.stall = todo!("how many cycles to stall??");
        } else {
            // Continue stalling
            self.stall -= 1;
        }

        None
    }
}