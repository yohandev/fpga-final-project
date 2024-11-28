use std::{fmt, ops};

/// Fixed point number
#[derive(Debug, Default, Clone, Copy, PartialEq, PartialOrd)]
pub struct Fixed(f32);

/// Converts a floating point to a fixed
#[macro_export]
macro_rules! fixed {
    ($x:expr) => {
        // Identity is used for type checking
        crate::math::Fixed::from_raw(std::convert::identity::<f32>($x) as _)
    };
}

macro_rules! f32 {
    ($x:expr) => {
        ($x.0)
    };
}

impl Fixed {
    /// Number of fractional bits
    pub const D: usize = 15;

    pub const MAX: Self = Self(f32::MAX);
    pub const MIN: Self = Self(f32::MIN);

    pub const fn from_raw(x: f32) -> Self {
        Self(x)
    }

    pub fn floor(self) -> i32 {
        self.0.floor() as _
    }

    pub fn abs(self) -> Self {
        Self(self.0.abs())
    }

    /// Inverse square root, as would be implemented in hardware
    pub fn inv_sqrt(self) -> Self {
        Self(1.0 / self.0.sqrt())
    }

    /// Reciprocal for 0 < value <= 1, as would be implemented in hardware
    pub fn recip_lte1(self) -> Self {
        Self(1.0 / self.0)
    }
}

impl ops::Add for Fixed {
    type Output = Self;

    fn add(self, rhs: Self) -> Self::Output {
        Self(self.0 + rhs.0)
    }
}

impl ops::Sub for Fixed {
    type Output = Self;

    fn sub(self, rhs: Self) -> Self::Output {
        Self(self.0 - rhs.0)
    }
}

impl ops::Mul for Fixed {
    type Output = Self;

    fn mul(self, rhs: Self) -> Self::Output {
        Self(self.0 * rhs.0)
    }
}

impl ops::Neg for Fixed {
    type Output = Self;

    fn neg(self) -> Self::Output {
        Self(-self.0)
    }
}

impl ops::AddAssign for Fixed {
    fn add_assign(&mut self, rhs: Self) {
        *self = *self + rhs;
    }
}

impl ops::SubAssign for Fixed {
    fn sub_assign(&mut self, rhs: Self) {
        *self = *self - rhs;
    }
}

impl ops::MulAssign for Fixed {
    fn mul_assign(&mut self, rhs: Self) {
        *self = *self * rhs;
    }
}

impl From<i32> for Fixed {
    fn from(value: i32) -> Self {
        Self(value as _)
    }
}

impl fmt::Display for Fixed {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", f32!(self))
    }
}