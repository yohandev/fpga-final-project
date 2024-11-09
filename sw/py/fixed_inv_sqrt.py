import matplotlib.pyplot as plt
import numpy as np

from math import sqrt


D = 15


def fixed(f): return int(f * (1 << D))
def f32(fx): return float(fx / (1 << D))

def fixed_mul(a, b): return int((a * b) >> D)

def leading_zeros(n):
    for i in reversed(range(32)):
        if n & (1 << i):
            return 31 - i
    return 32

def fixed_inv_sqrt(fx):
    # First iteration (LUT)
    iter0 = 0
    for i in range(31):
        if leading_zeros(fx) == i:
            iter0 = fixed(1 / sqrt(f32(0b11 << (30 - i))))
            break
    if leading_zeros(fx) == 31:
        iter0 = fixed(1 / sqrt(f32(0b1)))
    
    # Second iteration (Newton)
    iter1 = fixed_mul(iter0, fixed(1.5) - fixed_mul(fx >> 1, fixed_mul(iter0, iter0)))

    # Third iteration (Newton)
    iter2 = fixed_mul(iter1, fixed(1.5) - fixed_mul(fx >> 1, fixed_mul(iter1, iter1)))

    iter3 = fixed_mul(iter2, fixed(1.5) - fixed_mul(fx >> 1, fixed_mul(iter2, iter2)))

    return iter2

def err(f):
    actual = 1 / sqrt(f)
    predicted = f32(fixed_inv_sqrt(fixed(f)))
    
    return abs(actual - predicted) / actual

x = np.arange(1, 100000, 0.1)
y = [100 * err(i) for i in x]

fig, ax = plt.subplots()

ax.plot(x, y)
ax.set(xlabel="x", ylabel="% Error", title="1/sqrt(x)")
ax.grid()

plt.show()