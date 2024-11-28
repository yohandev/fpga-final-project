use std::{fmt, ops};

use crate::{fixed, math::{Fixed, Vec3i}};

/// A 3-dimensional vector
#[derive(Debug, Default, Clone, Copy, PartialEq, PartialOrd)]
pub struct Vec3 {
    pub x: Fixed,
    pub y: Fixed,
    pub z: Fixed,
}

impl Vec3 {
    pub const UP: Self = Self::new(fixed!(0.0), fixed!(1.0), fixed!(0.0));
    pub const RIGHT: Self = Self::new(fixed!(1.0), fixed!(0.0), fixed!(0.0));
    pub const FORWARD: Self = Self::new(fixed!(0.0), fixed!(0.0), fixed!(1.0));

    pub const fn new(x: Fixed, y: Fixed, z: Fixed) -> Self {
        Self { x, y, z }
    }

    pub fn magnitude_squared(self) -> Fixed {
        (self.x * self.x) + (self.y * self.y) + (self.z * self.z)
    }

    pub fn normalized(self) -> Self {
        self * self.magnitude_squared().inv_sqrt()
    }

    pub fn floor(self) -> Vec3i {
        Vec3i {
            x: self.x.floor(),
            y: self.y.floor(),
            z: self.z.floor(),
        }
    }

    pub fn cross(self, rhs: Self) -> Self {
        Self {
            x: self.y * rhs.z - self.z * rhs.y,
            y: self.z * rhs.x - self.x * rhs.z,
            z: self.x * rhs.y - self.y * rhs.x,
        }
    }

    pub fn dot(self, rhs: Self) -> Fixed {
        (self.x * rhs.x) + (self.y * rhs.y) + (self.z * rhs.z)
    }
}

impl ops::Add for Vec3 {
    type Output = Self;

    fn add(self, rhs: Self) -> Self::Output {
        Self {
            x: self.x + rhs.x,
            y: self.y + rhs.y,
            z: self.z + rhs.z,
        }
    }
}

impl ops::Sub for Vec3 {
    type Output = Self;

    fn sub(self, rhs: Self) -> Self::Output {
        Self {
            x: self.x - rhs.x,
            y: self.y - rhs.y,
            z: self.z - rhs.z,
        }
    }
}

impl ops::Mul<Fixed> for Vec3 {
    type Output = Self;

    fn mul(self, rhs: Fixed) -> Self::Output {
        Self {
            x: self.x * rhs,
            y: self.y * rhs,
            z: self.z * rhs,
        }
    }
}

impl ops::Mul<Vec3> for Fixed {
    type Output = Vec3;

    fn mul(self, rhs: Vec3) -> Self::Output {
        rhs * self
    }
}

impl ops::Neg for Vec3 {
    type Output = Self;

    fn neg(self) -> Self::Output {
        Self {
            x: -self.x,
            y: -self.y,
            z: -self.z,
        }
    }
}

impl ops::AddAssign for Vec3 {
    fn add_assign(&mut self, rhs: Self) {
        *self = *self + rhs;
    }
}

impl ops::SubAssign for Vec3 {
    fn sub_assign(&mut self, rhs: Self) {
        *self = *self - rhs;
    }
}

impl ops::MulAssign<Fixed> for Vec3 {
    fn mul_assign(&mut self, rhs: Fixed) {
        *self = *self * rhs;
    }
}

impl fmt::Display for Vec3 {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "({}, {}, {})", self.x, self.y, self.z)
    }
}