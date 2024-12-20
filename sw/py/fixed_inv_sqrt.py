import matplotlib.pyplot as plt
import numpy as np

from math import sqrt

D = 8
B = 20

def fixed(f): return int(f * (1 << D))
def f32(fx): return float(fx / (1 << D))

def fixed_mul(a, b): return int((a * b) >> D)

def leading_zeros(n):
    for i in reversed(range(B)):
        if n & (1 << i):
            return (B-1) - i
    return B

def lut(lz):
    if lz == (B-1):
        return fixed(1 / sqrt(f32(0b1)))
    elif 0 <= lz <= (B-2):
        return fixed(1 / sqrt(f32(0b11 << ((B-2) - lz))))

def fixed_inv_sqrt(fx):
    # First iteration (LUT)
    iter0 = lut(leading_zeros(fx))
    
    # Second iteration (Newton)
    iter1 = fixed_mul(iter0, fixed(1.5) - fixed_mul(fx >> 1, fixed_mul(iter0, iter0)))

    # Third iteration (Newton)
    # iter2 = fixed_mul(iter1, fixed(1.5) - fixed_mul(fx >> 1, fixed_mul(iter1, iter1)))

    # iter3 = fixed_mul(iter2, fixed(1.5) - fixed_mul(fx >> 1, fixed_mul(iter2, iter2)))

    return iter1

def err(f):
    actual = 1 / sqrt(f)
    predicted = f32(fixed_inv_sqrt(fixed(f)))
    
    return abs(actual - predicted) / actual


# Generate SystemVerilog LUT
for i in range(B-1):
    print(f"{B}'sb?{'0' * i}1{'?' * ((B-2)-i)}: lut = {B}'sh{hex(lut(i))[2:]};")
print(f"default: lut = {B}'sh{hex(lut(B-1))[2:]};")

# Generate error plot
x = np.arange(0.01, 200, 0.01)
y = [100 * err(i) for i in x]

fig, ax = plt.subplots()

ax.plot(x, y)
ax.set(xlabel="x", ylabel="% Error", title="1/sqrt(x)")
ax.grid()

print(f"Average error was {np.average(y)}")

plt.show()