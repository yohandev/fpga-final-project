#[derive(Debug, Default, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum Block {
    #[default]
    Air,
    Grass,
}