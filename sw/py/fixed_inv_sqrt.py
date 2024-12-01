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

def lut(lz):
    if lz == 31:
        return fixed(1 / sqrt(f32(0b1)))
    elif 0 <= lz <= 30:
        return fixed(1 / sqrt(f32(0b11 << (30 - lz))))

def fixed_inv_sqrt(fx):
    # First iteration (LUT)
    iter0 = lut(leading_zeros(fx))
    
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


# Generate SystemVerilog LUT
for i in range(1, 31):
    print(f"32'sb?{'0' * i}1{'?' * (30-i)}: lut = 32'sh{hex(lut(i))[2:]};")
print(f"default: lut = 32'sh{hex(lut(31))[2:]};")

# Generate error plot
x = np.arange(0.001, 60000, 0.1)
y = [100 * err(i) for i in x]

fig, ax = plt.subplots()

ax.plot(x, y)
ax.set(xlabel="x", ylabel="% Error", title="1/sqrt(x)")
ax.grid()

print(f"Average error was {np.average(y)}")

plt.show()