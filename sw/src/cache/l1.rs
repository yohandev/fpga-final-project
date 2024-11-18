use crate::{block::Block, math::Vec3i};

use super::L2Cache;

/// An L1 cache with `P` ports and `S` entries
pub struct L1Cache<const P: usize, const S: usize> {
    entries: [Option<Entry>; S],
    /// Index of the next entry that will be replaced upon a cache miss
    next_replacement: usize,
}

#[derive(Debug, Default, Clone, Copy)]
struct Entry {
    key: Vec3i,
    value: Block,
}

impl<const P: usize, const S: usize> L1Cache<P, S> {
    /// Get a block from the cache. Returns immediately if it's cache-hit, otherwise
    /// returns [Option::None] for that port. Should be called every cycle, and cache misses
    /// are expected to hold their value since they will resolve eventually.
    pub fn query(&mut self, l2: &mut L2Cache, idx: &[Vec3i; P]) -> [Option<Block>; P] {
        let mut out = [None; P];
        let mut miss = None;

        for (port, key) in out.iter_mut().zip(idx) {
            for entry in self.entries {
                let Some(entry) = entry else {
                    continue;
                };
                // Cache-hit!
                if *key == entry.key {
                    *port = Some(entry.value);
                }
            }
            // Cache-miss!
            if matches!(port, Some(_)) {
                continue;
            }

            // Static priority arbitration: port 0 has priority, then port 1, port 2, etc...
            if matches!(miss, None) {
                miss = Some(key);
            }
        }

        // Resolve cache misses
        if let Some(&key) = miss {
            if let Some(value) = l2.query(key) {
                self.entries[self.next_replacement] = Some(Entry { key, value });
                self.next_replacement = (self.next_replacement + 1) % S;
            }
        }

        out
    }
}