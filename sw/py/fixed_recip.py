import matplotlib.pyplot as plt
import numpy as np

D = 15

def fixed(f): return int(f * (1 << D))
def f32(fx): return float(fx / (1 << D))

def fixed_mul(a, b): return int((a * b) >> D)

def leading_zeros(n):
    for i in reversed(range(32)):
        if n & (1 << i):
            return 31 - i
    return 32

# LUT reconstructs some fractional number from the index
# [33] => (fixed) 0.515625 => (LUT has (fixed)1/0.515625)
# [47] => (fixed) 0.734375 => ...
# [63] => (fixed) 0.984375 => ...
# [0]  => special case, assumes (fixed) 1.0000 => LUT has (fixed) 1/1.0000
LUT = [fixed(1 / f32(i << (D - 6))) if i != 0 else fixed(1) for i in range(64)]

def fixed_recip_lte1(fx):
    # First iteration (LUT)
    idx = (fx >> (D - 6)) & 63 # index into LUT is 6 MSB of fractional part
    iter0 = LUT[idx]
    
    # Second iteration (Newton)
    iter1 = (iter0 << 1) - fixed_mul(fx, fixed_mul(iter0, iter0))

    # Third iteration (Newton)
    iter2 = (iter1 << 1) - fixed_mul(fx, fixed_mul(iter1, iter1))

    return iter2

def err(f):
    actual = 1 / f
    predicted = f32(fixed_recip_lte1(fixed(f)))
    
    return abs(actual - predicted) / actual

x = np.arange(0.001, 1, 0.00001)
y = [100 * err(i) for i in x]

fig, ax = plt.subplots()

ax.plot(x, y)
ax.set(xlabel="x", ylabel="% Error", title="1/x")
ax.grid()

plt.show()