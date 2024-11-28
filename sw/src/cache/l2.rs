use std::{cell::RefCell, iter::zip};

use crate::{block::Block, math::Vec3i};

use super::L3Cache;

/// An L2 cache with `P` ports and `S` entries
#[derive(Debug)]
pub struct L2Cache<const P: usize, const S: usize> {
    /// Reset the cache to a known state
    pub reset: bool,
    /// Voxel indices being queried by each port
    pub addr_in: [Vec3i; P],
    /// Whether [L2Cache::addr_in] should actually be queried
    pub read_enable_in: [bool; P],
    /// Voxel data being queried by each port
    pub voxel_out: [Block; P],
    /// Whether [L2Cache::voxel_out] corresponds to the address inputted
    pub valid_out: [bool; P],
    /// Reference to an L2 cache used for cache misses
    pub l3: RefCell<L3Cache>,

    /// Entries in the cache
    entries: [Option<Entry>; S],
    /// Index of the next entry that will be replaced upon a cache miss
    next_replacement: usize,
}

#[derive(Debug, Default, Clone, Copy)]
struct Entry {
    key: Vec3i,
    value: Block,
}

impl<const P: usize, const S: usize> Default for L2Cache<P, S> {
    fn default() -> Self {
        Self {
            reset: Default::default(),
            addr_in: [Default::default(); P],
            read_enable_in: [Default::default(); P],
            voxel_out: [Default::default(); P],
            valid_out: [Default::default(); P],
            l3: Default::default(),
            entries: [Default::default(); S],
            next_replacement: Default::default()
        }
    }
}

impl<const P: usize, const S: usize> L2Cache<P, S> {
    pub fn rising_clk_edge(&mut self) {
        // Reset
        if self.reset {
            self.voxel_out = [Block::Air; P];
            self.valid_out = [false; P];
            self.entries = [None; S];
            self.next_replacement = 0;
            return;
        }
        
        // Respond to each port's query...
        for ((&addr, ra), (voxel, valid)) in zip(zip(&self.addr_in, &self.read_enable_in), zip(&mut self.voxel_out, &mut self.valid_out)) {
            *valid = false;
            if !ra {
                continue;
            }

            // ...by checking every entry
            for entry in self.entries {
                match entry {
                    // Cache-hit!
                    Some(Entry { value, key }) if key == addr => {
                        *valid = true;
                        *voxel = value;
                    },
                    _ => {}
                }
            }
        }

        let mut l3 = self.l3.borrow_mut();

        // Replace cache entry with last query from L3, if valid
        if l3.valid_out {
            self.entries[self.next_replacement] = Some(Entry {
                key: l3.addr_in,
                value: l3.voxel_out,
            });
            self.next_replacement = (self.next_replacement + 1) % S;
        }

        // Cache-miss static priority arbitration:
        // Port 0 has priority, then port 1, port 2, etc...
        match zip(&self.addr_in, &self.valid_out).find(|(_, &valid)| !valid) {
            Some((&addr, _)) => {
                l3.addr_in = addr;
                l3.read_enable_in = true;
            },
            _ => {
                // If there's no cache-miss, don't bother querying the L3
                l3.read_enable_in = false;
            }
        }
    }
}