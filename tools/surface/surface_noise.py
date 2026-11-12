"""Noise and raster helpers for the Surface baker (numpy + Pillow only).

Every map is a float32 array indexed [z, x] over the whole Surface, one
pixel per meter. Noise is value noise: a seeded random grid upscaled with
bicubic filtering, summed over octaves (fbm). Ridged noise folds it.
"""
import numpy as np
from PIL import Image


def value_noise(rng, cells, n):
    """Smooth noise in about [-1, 1] with `cells` features across `n` pixels."""
    cells = max(1, int(cells))
    grid = (rng.random((cells + 3, cells + 3)) * 2.0 - 1.0).astype(np.float32)
    size = int(round(n * (cells + 3) / cells))
    big = np.asarray(Image.fromarray(grid, mode="F").resize((size, size), Image.BICUBIC))
    off = int(round(n * 1.5 / cells))
    return np.ascontiguousarray(big[off:off + n, off:off + n])


def fbm(rng, cells, n, octaves=5, gain=0.5, lacunarity=2.0):
    total = np.zeros((n, n), np.float32)
    amp = 1.0
    norm = 0.0
    c = float(cells)
    for _ in range(octaves):
        if c > n / 2:
            break
        total += value_noise(rng, c, n) * amp
        norm += amp
        amp *= gain
        c *= lacunarity
    return total / norm * 1.6  # value noise is soft: stretch back toward [-1, 1]


def ridged(rng, cells, n, octaves=5):
    """Sharp crests in [0, 1] (mountain ridges, jagged rock)."""
    total = np.zeros((n, n), np.float32)
    amp = 1.0
    norm = 0.0
    c = float(cells)
    weight = np.ones((n, n), np.float32)
    for _ in range(octaves):
        if c > n / 2:
            break
        r = 1.0 - np.abs(value_noise(rng, c, n) * 1.6)
        r = np.clip(r, 0.0, 1.0) ** 2
        r *= weight
        weight = np.clip(r * 1.6, 0.0, 1.0)
        total += r * amp
        norm += amp
        amp *= 0.5
        c *= 2.0
    return total / norm


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def sample(a, px, pz):
    """Bilinear sample of `a` at float pixel coordinates (arrays)."""
    n_z, n_x = a.shape
    px = np.clip(px, 0, n_x - 1.001)
    pz = np.clip(pz, 0, n_z - 1.001)
    x0 = px.astype(np.int32)
    z0 = pz.astype(np.int32)
    fx = (px - x0).astype(np.float32)
    fz = (pz - z0).astype(np.float32)
    top = a[z0, x0] * (1 - fx) + a[z0, x0 + 1] * fx
    bottom = a[z0 + 1, x0] * (1 - fx) + a[z0 + 1, x0 + 1] * fx
    return top * (1 - fz) + bottom * fz


def terrace(h, step, sharp):
    """Flat shelves with short steep risers: the stone-walled hill steps."""
    k = h / step
    f = k - np.floor(k)
    return (np.floor(k) + smoothstep(1.0 - sharp, 1.0, f)) * step


def block_mean(a, k):
    n = a.shape[0] // k
    return a[:n * k, :n * k].reshape(n, k, n, k).mean(axis=(1, 3))


def block_max(a, k):
    n = a.shape[0] // k
    return a[:n * k, :n * k].reshape(n, k, n, k).max(axis=(1, 3))


def upscale(a, n, resample=Image.BILINEAR):
    return np.asarray(Image.fromarray(a.astype(np.float32), mode="F").resize((n, n), resample))


def box_blur(a, r):
    """Separable box blur with radius r pixels (edges clamped)."""
    if r <= 0:
        return a
    out = a.astype(np.float32)
    for axis in (0, 1):
        pad = np.pad(out, [(r + 1, r) if i == axis else (0, 0) for i in range(2)], mode="edge")
        c = np.cumsum(pad, axis=axis, dtype=np.float64)
        if axis == 0:
            out = ((c[2 * r + 1:] - c[:-2 * r - 1]) / (2 * r + 1)).astype(np.float32)
        else:
            out = ((c[:, 2 * r + 1:] - c[:, :-2 * r - 1]) / (2 * r + 1)).astype(np.float32)
    return out


def distance_to(mask, max_steps):
    """Approximate distance (pixels) from every cell to the nearest True cell,
    capped at max_steps (chamfer-like dilation, 8 neighbours)."""
    inf = np.float32(max_steps + 1)
    d = np.where(mask, np.float32(0), inf).astype(np.float32)
    diag = np.float32(1.4142)
    for _ in range(max_steps):
        p = np.pad(d, 1, mode="edge")
        best = np.minimum.reduce([
            p[1:-1, 1:-1], p[:-2, 1:-1] + 1, p[2:, 1:-1] + 1, p[1:-1, :-2] + 1, p[1:-1, 2:] + 1,
            p[:-2, :-2] + diag, p[:-2, 2:] + diag, p[2:, :-2] + diag, p[2:, 2:] + diag])
        if np.array_equal(best, d):
            break
        d = best
    return d


def chaikin(points, passes=2):
    pts = list(points)
    for _ in range(passes):
        if len(pts) < 3:
            return pts
        out = [pts[0]]
        for a, b in zip(pts[:-1], pts[1:]):
            out.append((a[0] * 0.75 + b[0] * 0.25, a[1] * 0.75 + b[1] * 0.25))
            out.append((a[0] * 0.25 + b[0] * 0.75, a[1] * 0.25 + b[1] * 0.75))
        out.append(pts[-1])
        pts = out
    return pts


def resample(points, spacing):
    pts = [tuple(p) for p in points]
    if len(pts) < 2:
        return pts
    out = [pts[0]]
    carry = 0.0
    for a, b in zip(pts[:-1], pts[1:]):
        length = ((b[0] - a[0]) ** 2 + (b[1] - a[1]) ** 2) ** 0.5
        t = spacing - carry
        while t < length:
            f = t / length
            out.append((a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f))
            t += spacing
        carry = length - (t - spacing)
    if ((out[-1][0] - pts[-1][0]) ** 2 + (out[-1][1] - pts[-1][1]) ** 2) > 0.25:
        out.append(pts[-1])
    return out
