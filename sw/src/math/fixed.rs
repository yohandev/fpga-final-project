use std::{fmt, ops};

use aint::Aint;

/// Fixed point number
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct Fixed(Repr);

/// Inner representation of [Fixed]
pub type Repr = Aint<i32, {Fixed::B as _}>;

/// Converts a floating point to a fixed
#[macro_export]
macro_rules! fixed {
    ($x:expr) => {
        {
            let x: f32 = $x;
            let f = (x * ((1 << crate::math::Fixed::D) as f32));
            let i = crate::math::fixed::Repr::new_wrapping(f as i32);

            crate::math::Fixed::from_raw(i)
        }
    };
}

macro_rules! f32 {
    ($x:expr) => {
        // Identity is used for type checking
        (std::convert::identity::<Fixed>($x).0.repr() as f32) / ((1 << Fixed::D) as f32)
    };
}

impl Default for Fixed {
    fn default() -> Self {
        Self(Repr::new_wrapping(0))
    }
}

impl Fixed {
    /// Total number of bits
    pub const B: usize = 20;

    /// Number of fractional bits
    pub const D: usize = 8;

    pub const MAX: Self = Self(Repr::MAX);
    pub const MIN: Self = Self(Repr::MIN);

    pub const fn from_raw(x: Repr) -> Self {
        Self(x)
    }

    pub fn floor(self) -> i16 {
        (self.0 >> Fixed::D).repr() as _
    }

    pub fn abs(self) -> Self {
        Self(self.0.abs())
    }

    /// Inverse square root, as would be implemented in hardware
    pub fn inv_sqrt(self) -> Self {
        // return fixed!(1.0 / f32!(self).sqrt());
        
        // https://www.shironekolabs.com/posts/efficient-approximate-square-roots-and-division-in-verilog/
        fn lut(i: u32) -> Fixed {
            if i == (Fixed::B as u32) - 1 {
                fixed!(1.0 / f32!(Fixed(Repr::new_wrapping(0b1))).sqrt())
            } else {
                fixed!(1.0 / f32!(Fixed(Repr::new_wrapping(0b11) << ((Fixed::B as u32) - 2 - i))).sqrt())
            }
        }

        // First iteration (LUT):
        let iter0 = lut(self.0.leading_zeros());

        // Second and third iterations (Newton's method)
        // x(n+1) = x(n) * (1.5 - (0.5 * val * x(n)^2))
        let iter1 = iter0 * (fixed!(1.5) - (Fixed(self.0 >> 1) * (iter0 * iter0)));
        // let iter2 = iter1 * (fixed!(1.5) - (Fixed(self.0 >> 1) * (iter1 * iter1)));

        iter1
    }

    /// Reciprocal for 0 < value <= 1, as would be implemented in hardware
    pub fn recip_lte1(self) -> Self {
        // return fixed!(1.0 / f32!(self));

        // Emulate a size 64 LUT
        fn lut(i: Repr) -> Fixed {
            if i.repr() == 0 {
                fixed!(1.0)
            } else {
                fixed!(1.0 / f32!(Fixed(i << (Fixed::D - 6))))
            }
        }

        // First iteration (LUT)
        let iter0 = Self(lut((self.0.abs() >> (Fixed::D - 6)) & Repr::new_wrapping(63)).0 * self.0.signum());

        // Second iteration (Newton's method)
        // x(n+1) = 2*x(n) - val * x(n)^2
        // ORDER MATTERS for multiplication to avoid overflows
        let iter1 = Fixed(iter0.0 << 1) - (iter0 * (self * iter0));

        iter1
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
        let a: Aint<i64, {Self::B as u32 * 2}> = self.0.repr().into();
        let b: Aint<i64, {Self::B as u32 * 2}> = rhs.0.repr().into();

        Self(Repr::new(((a * b) >> Self::D).repr() as _).unwrap())
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

impl From<i16> for Fixed {
    fn from(value: i16) -> Self {
        Self(Repr::new((value as i32) << Self::D).unwrap())
    }
}

impl From<Fixed> for f32 {
    fn from(value: Fixed) -> Self {
        f32!(value)
    }
}

impl fmt::Display for Fixed {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", f32!(*self))
    }
}