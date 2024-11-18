#[derive(Debug, Default, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
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

impl From<quill::BlockKind> for Block {
    fn from(value: quill::BlockKind) -> Self {
        match value {
            quill::BlockKind::Air => Self::Air,
            quill::BlockKind::Stone => Self::Stone,
            quill::BlockKind::GrassBlock => Self::Grass,
            quill::BlockKind::Dirt => Self::Dirt,
            quill::BlockKind::Cobblestone => Self::Cobblestone,
            quill::BlockKind::OakPlanks => Self::OakPlanks,
            quill::BlockKind::SprucePlanks => Self::SprucePlanks,
            quill::BlockKind::BirchPlanks => Self::BirchPlanks,
            quill::BlockKind::Water => Self::Water,
            quill::BlockKind::Sand => Self::Sand,
            quill::BlockKind::Gravel => Self::Gravel,
            quill::BlockKind::OakLog => Self::OakLog,
            quill::BlockKind::SpruceLog => Self::SpruceLog,
            quill::BlockKind::BirchLog => Self::BirchLog,
            quill::BlockKind::OakLeaves => Self::OakLeaves,
            quill::BlockKind::SpruceLeaves => Self::SpruceLeaves,
            quill::BlockKind::BirchLeaves => Self::BirchLeaves,
            quill::BlockKind::Glass => Self::Glass,
            _ => Self::Air,
        }
    }
}