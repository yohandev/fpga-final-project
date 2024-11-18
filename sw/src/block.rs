#[derive(Debug, Default, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
#[allow(unused)]
pub enum Block {
    #[default]
    Air,
    Stone,
    Grass,
    Dirt,
    Cobblestone,
    OakPlanks,
    SprucePlanks,
    BirchPlanks,
    Water,
    Sand,
    Gravel,
    OakLog,
    SpruceLog,
    BirchLog,
    OakLeaves,
    SpruceLeaves,
    BirchLeaves,
    Glass,
}