from cocotb.binary import BinaryValue
import fixed


def encode_str(v):
    """Encode with two's complement"""
    return ''.join(fixed.encode_str(vi) for vi in v)

def encode(v):
    """Encode with two's complement"""
    return BinaryValue(encode_str(v))

def add(a, b):
    return tuple(fixed.add(ai, bi) for (ai, bi) in zip(a, b))

def sub(a, b):
    return tuple(fixed.sub(ai, bi) for (ai, bi) in zip(a, b))

def mul(v, s):
    return tuple(fixed.mul(vi, s) for vi in v)

def dot(a, b):
    x = fixed.mul(a[0], b[0])
    y = fixed.mul(a[1], b[1])
    z = fixed.mul(a[2], b[2])

    return fixed.add(x, fixed.add(y, z))

def normalize(v):
    m = fixed.inv_sqrt(dot(v, v))

    return tuple(fixed.mul(vi, m) for vi in v)