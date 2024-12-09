from cocotb.binary import BinaryValue, BinaryRepresentation
from math import sqrt


D = 8
B = 20
MAX = (1 << (B-1)) - 1
MIN = -(1 << (B-1))


def fixed(f): return int(f * (1 << D))
def f32(fx): return float(fx / (1 << D))

def encode_str(f):
    """Encode with two's complement"""
    # Bit masking magically does two's complement for us instead of "-0b1101" or garbage like that
    return bin(f & (2**B - 1))[2:].zfill(B)

def encode(f):
    """Encode with two's complement"""
    return BinaryValue(encode_str(f))

def mul(a, b): return ((a * b) >> D) & (2**B - 1)
def add(a, b) : return (a + b) & (2**B - 1)
def sub(a, b) : return (a - b) & (2**B - 1)

def leading_zeros(n):
    for i in reversed(range(B)):
        if n & (1 << i):
            return (B-1) - i
    return B

def inv_sqrt(fx):
    def lut(lz):
        if lz == B-1:
            return fixed(1 / sqrt(f32(0b1)))
        elif 0 <= lz <= B-2:
            return fixed(1 / sqrt(f32(0b11 << ((B-2) - lz))))
    
    # First iteration (LUT)
    iter0 = lut(leading_zeros(fx) - 1)
    
    # Second iteration (Newton)
    iter1 = mul(iter0, sub(fixed(1.5), mul(fx >> 1, mul(iter0, iter0))))

    return iter1

def recip_lte1(fx):
    def lut_dbl(i):
        return fixed((1 / f32(i << (D - 6))) * 2) if i != 0 else fixed(1)
    def lut_sqr(i):
        if i == 1:
            # I modified this one manually b/c it overflowed
            return 0x7FFFF
        return fixed((1 / f32(i << (D - 6))) ** 2) if i != 0 else fixed(1)
    
    # First iteration (LUT)
    idx = (abs(fx) >> (D - 6)) & 63 # index into LUT is 6 MSB of fractional part

    iter0_dbl = (lut_dbl(idx) * (1 if fx > 0 else -1)) & (2**B - 1)
    iter0_sqr = lut_sqr(idx)
    
    # Second iteration (Newton)
    iter1 = sub(iter0_dbl, mul(fx, iter0_sqr))

    return iter1