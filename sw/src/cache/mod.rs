mod l2;
mod l3;
mod mock;

pub use l2::L2Cache;
pub use l3::L3Cache;
pub use mock::MockCache;

static mut L2_ACCESSES: usize = 0;
static mut L2_HITS: usize = 0;

pub fn l2_benchmark_reset() {
    unsafe {
        L2_ACCESSES = 0;
        L2_HITS = 0;
    }
}

pub fn l2_cache_hit_ratio() -> f32 {
    unsafe {
        (L2_HITS as f32) / (L2_ACCESSES as f32)
    }
}

pub fn l2_cache_total_accesses() -> usize {
    unsafe {
        L2_ACCESSES
    }
}

pub(self) fn l2_cache_add_access() {
    unsafe {
        L2_ACCESSES += 1;
    }
}

pub(self) fn l2_cache_add_hit() {
    unsafe {
        L2_HITS += 1;
    }
}