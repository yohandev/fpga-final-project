use std::ops;

/// A 3-dimensional vector
#[derive(Debug, Default, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct Vec3i {
    pub x: i16,
    pub y: i16,
    pub z: i16,
}

impl Vec3i {
    pub fn new(x: i16, y: i16, z: i16) -> Self {
        Self { x, y, z }
    }

    pub fn magnitude_squared(self) -> i16 {
        (self.x * self.x) + (self.y * self.y) + (self.z * self.z)
    }
}

impl ops::Add for Vec3i {
    type Output = Self;

    fn add(self, rhs: Self) -> Self::Output {
        Self {
            x: self.x + rhs.x,
            y: self.y + rhs.y,
            z: self.z + rhs.z,
        }
    }
}

impl ops::Sub for Vec3i {
    type Output = Self;

    fn sub(self, rhs: Self) -> Self::Output {
        Self {
            x: self.x - rhs.x,
            y: self.y - rhs.y,
            z: self.z - rhs.z,
        }
    }
}

impl ops::Mul<i16> for Vec3i {
    type Output = Self;

    fn mul(self, rhs: i16) -> Self::Output {
        Self {
            x: self.x * rhs,
            y: self.y * rhs,
            z: self.z * rhs,
        }
    }
}

impl ops::Mul<Vec3i> for i16 {
    type Output = Vec3i;

    fn mul(self, rhs: Vec3i) -> Self::Output {
        rhs * self
    }
}

impl ops::AddAssign for Vec3i {
    fn add_assign(&mut self, rhs: Self) {
        *self = *self + rhs;
    }
}

impl ops::SubAssign for Vec3i {
    fn sub_assign(&mut self, rhs: Self) {
        *self = *self - rhs;
    }
}

impl ops::MulAssign<i16> for Vec3i {
    fn mul_assign(&mut self, rhs: i16) {
        *self = *self * rhs;
    }
}