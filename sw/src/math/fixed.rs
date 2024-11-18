use std::ops;

/// Fixed point number
#[derive(Debug, Default, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct Fixed(i32);

/// Converts a floating point to a fixed
#[macro_export]
macro_rules! fixed {
    ($x:expr) => {
        // Identity is used for type checking
        Fixed((std::convert::identity::<f32>($x) * (1 << Fixed::D) as f32) as _)
    };
}

macro_rules! f32 {
    ($x:expr) => {
        ($x.0 as f32) / (1 << Fixed::D) as f32
    };
}

impl Fixed {
    /// Number of fractional bits
    pub const D: usize = 15;

    pub fn floor(self) -> i32 {
        self.0 >> Fixed::D
    }

    /// Inverse square root, as would be implemented in hardware
    pub fn inv_sqrt(self) -> Self {
        // https://www.shironekolabs.com/posts/efficient-approximate-square-roots-and-division-in-verilog/
        fn lut(i: u32) -> Fixed {
            match i {
                31 => fixed!(1.0 / f32!(Fixed(0b1)).sqrt()),
                0..=30 => fixed!(1.0 / f32!(Fixed(0b11 << (30 - i))).sqrt()),
                _ => fixed!(0.0)
            }
        }

        // First iteration (LUT):
        let iter0 = lut(self.0.leading_zeros());

        // Second and third iterations (Newton's method)
        // x(n+1) = x(n) * (1.5 - (0.5 * val * x(n)^2))
        let iter1 = iter0 * (fixed!(1.5) - (Fixed(self.0 >> 1) * (iter0 * iter0)));
        let iter2 = iter1 * (fixed!(1.5) - (Fixed(self.0 >> 1) * (iter1 * iter1)));

        iter2
    }

    /// Reciprocal for 0 < value <= 1, as would be implemented in hardware
    pub fn recip_lte1(self) -> Self {
        // Emulate a size 64 LUT
        fn lut(i: i32) -> Fixed {
            match i {
                0 => fixed!(1.0),
                1..64 => fixed!(1.0 / f32!(Fixed(i << (Fixed::D - 6)))),
                _ => panic!("Out of bounds of LUT!")
            }
        }

        // First iteration (LUT)
        let iter0 = lut((self.0 >> (Fixed::D - 6)) & 63);

        // Second and third iterations (Newton's method)
        // x(n+1) = 2*x(n) - val * x(n)^2
        // iter1 = (iter0 << 1) - fixed_mul(fx, fixed_mul(iter0, iter0))
        let iter1 = Fixed(iter0.0 << 1) - (self * (iter0 * iter0));
        let iter2 = Fixed(iter1.0 << 1) - (self * (iter1 * iter1));

        iter2
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
        let a = self.0 as i64;
        let b = rhs.0 as i64;

        Self(((a * b) >> Self::D) as _)
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