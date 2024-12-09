from cocotb.binary import BinaryValue, BinaryRepresentation
from math import sqrt


D = 8
B = 20
MAX = (1 << (B-1)) - 1
MIN = -(1 << (B-1))
MASK = (2**B) - 1


def fixed(f): return int(f * (1 << D)) & MASK
def f32(fx): return float(A(fx) / (1 << D))

def encode_str(f):
    """Encode with two's complement"""
    # Bit masking magically does two's complement for us instead of "-0b1101" or garbage like that
    return bin(f & MASK)[2:].zfill(B)

def encode(f):
    """Encode with two's complement"""
    return BinaryValue(encode_str(f))

def decode(f):
    if isinstance(f, BinaryValue):
        f = f.binstr
    
    assert len(f) == B

    return int(f, base=2)

def A(val):
    """2s complement => Python integer"""
    val &= MASK
    if (val & (1 << (B - 1))) != 0:
        val = val - (1 << B)
    return val

def mul(a, b): return ((A(a) * A(b)) >> D) & MASK
def add(a, b): return (A(a) + A(b)) & MASK
def sub(a, b): return (A(a) - A(b)) & MASK

def leading_zeros(n):
    n &= MASK
    for i in reversed(range(B - 1)):
        if n & (1 << i):
            return B - 2 - i
    return B - 1

def inv_sqrt(fx):
    def lut(lz):
        if lz == B-1:
            return fixed(1 / sqrt(f32(0b1)))
        elif 0 <= lz <= B-2:
            return fixed(1 / sqrt((0b11 << ((B-2) - lz)) / (1 << D)))
    
    # First iteration (LUT)
    iter0 = lut(leading_zeros(fx))
    
    # Second iteration (Newton)
    iter1 = mul(iter0, sub(fixed(1.5), mul(A(fx) >> 1, mul(iter0, iter0))))

    return iter1

def recip_lte1(fx):
    fx &= MASK
    def lut_dbl(i):
        return fixed((1 / f32(i << (D - 6))) * 2) if i != 0 else fixed(1)
    def lut_sqr(i):
        if i == 1:
            # I modified this one manually b/c it overflowed
            return 0x7FFFF
        return fixed((1 / f32(i << (D - 6))) ** 2) if i != 0 else fixed(1)
    
    # First iteration (LUT)
    idx = (abs(fx) >> (D - 6)) & 63 # index into LUT is 6 MSB of fractional part

    # iter0_dbl = mul(lut_dbl(idx), fixed(1 if A(fx) > 0 else -1))
    iter0_dbl = lut_dbl(idx) if A(fx) > 0 else (-lut_dbl(idx))
    iter0_sqr = lut_sqr(idx)
    
    # Second iteration (Newton)
    iter1 = sub(iter0_dbl, mul(fx, iter0_sqr))

    return iter1

def abs(fx):
    # In hardware I just check the top bit
    if (fx & MASK) & (1 << (B-1)):
        return (-fx) & MASK
    return fx