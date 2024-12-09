from cocotb.binary import BinaryValue, BinaryRepresentation
import fixed

# Width of a scalar in this type, in bits
B = fixed.B - fixed.D

def encode_str(v):
    """Encode with two's complement"""
    def encode_scalar(s):
        # Bit masking magically does two's complement for us instead of "-0b1101" or garbage like that
        return bin(s & (2**B - 1))[2:].zfill(B)

    return ''.join(encode_scalar(vi) for vi in v)

def encode(v):
    """Encode with two's complement"""
    return BinaryValue(encode_str(v))

def from_f32(v):
    return tuple(fixed.fixed(vi) for vi in v)

def add(a, b):
    return tuple((ai + bi) & (2**B - 1) for (ai, bi) in zip(a, b))

def sub(a, b):
    return tuple((ai - bi) & (2**B - 1) for (ai, bi) in zip(a, b))