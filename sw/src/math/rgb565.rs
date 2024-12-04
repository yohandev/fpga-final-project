use std::ops;

use crate::fixed;

use super::Fixed;

#[derive(Debug, Default, Clone, Copy, PartialEq, Eq)]
pub struct Rgb565(u16);

#[allow(unused)]
impl Rgb565 {
    pub const fn new(r: u8, g: u8, b: u8) -> Self {
        let r = r as u16;
        let g = g as u16;
        let b = b as u16;

        Self(((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3))
    }

    /// Red channel, scaled back to 0..=255
    pub const fn r(&self) -> u8 {
        ((self.0 >> 11) as u8) << 3
    }

    /// Green channel, scaled back to 0..=255
    pub const fn g(&self) -> u8 {
        ((self.0 >> 5) as u8 & 0b111111) << 2
    }

    /// Blue channel, scaled back to 0..=255
    pub const fn b(&self) -> u8 {
        ((self.0 & 0b11111) as u8) << 3
    }
}

impl ops::Mul<Fixed> for Rgb565 {
    type Output = Self;

    fn mul(self, rhs: Fixed) -> Self::Output {
        Self::new(
            (Fixed::from(self.r() as i16) * rhs).floor() as _,
            (Fixed::from(self.g() as i16) * rhs).floor() as _,
            (Fixed::from(self.b() as i16) * rhs).floor() as _,
        )
    }
}

impl ops::Mul<Rgb565> for Fixed {
    type Output = Rgb565;

    fn mul(self, rhs: Rgb565) -> Self::Output {
        rhs * self
    }
}

impl ops::MulAssign<Fixed> for Rgb565 {
    fn mul_assign(&mut self, rhs: Fixed) {
        *self = *self * rhs;
    }
}