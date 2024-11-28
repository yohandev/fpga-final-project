use crate::{block::Block, math::Vec3i};

/// Unrealistic cache with instant access, for testing
#[derive(Debug)]
pub struct MockCache {
    chunk: &'static [Block]
}

static CHUNK: &[u8] = include_bytes!("chunk.bin");

impl Default for MockCache {
    fn default() -> Self {
        assert!(size_of::<u8>() == size_of::<Block>());
        Self {
            // SAFETY:
            // Underlying representation [Block] is just `u8`
            chunk: unsafe { std::slice::from_raw_parts(CHUNK.as_ptr() as _, CHUNK.len()) }
        }
    }
}

impl MockCache {
    /// Size of the cache in one dimension
    pub const SIZE: usize = 128;

    pub fn query(&self, idx: Vec3i) -> Option<Block> {
        const HALF_CHUNK_SIZE: i32 = (MockCache::SIZE as i32) / 2;
        
        // Re-center position in chunk
        let x: usize = (idx.x + HALF_CHUNK_SIZE).try_into().ok()?;
        let y: usize = (idx.y + HALF_CHUNK_SIZE).try_into().ok()?;
        let z: usize = (idx.z + HALF_CHUNK_SIZE).try_into().ok()?;

        // Out of bounds
        if x >= Self::SIZE || y >= Self::SIZE || z >= Self::SIZE {
            return None;
        }

        Some(self.chunk[Self::SIZE * (Self::SIZE * z + y) + x])
    }
}