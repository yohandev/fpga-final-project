def from_rgb8(rgb):
    r, g, b = rgb

    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)

def into_rgb8(rgb565):
    r = (rgb565 >> 11) << 3
    g = ((rgb565 >> 5) & 0x3F) << 2
    b = (rgb565 & 0x1F) << 3

    return (r, g, b)