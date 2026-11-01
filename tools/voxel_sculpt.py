"""Sculpting rounded voxel creatures with numpy, for shapes too big or too
organic to place box by box (dragons, spirits, genies...).

A Part collects shapes in "units" (any convenient scale: 1 unit = `scale`
voxels), painting each with a palette color; later shapes paint over earlier
ones. Shapes:
    ellipsoid(center, radii, color)
    capsule(a, b, radius_a, radius_b, color)       tapered, for limbs, necks, horns
    chain(points, radius_a, radius_b, color)       capsules through several points
    triangle(a, b, c, thickness, color)            thin plates (wing membranes)
    box(lo, hi, color)
Coordinates: y up, facing -z, like everything in tools/make_creatures.py.

part.voxels() gives {(x, y, z): color} in voxels. Big parts are hollowed out
(only their shell is kept) so the files stay small.
"""
import numpy as np


class Part:
    def __init__(self, scale, palette):
        self.scale = float(scale)
        self.names = list(palette)
        self.shapes = []  # (bbox_lo, bbox_hi, sdf function, color index)

    def _index(self, color):
        return self.names.index(color) + 1

    def _add(self, lo, hi, sdf, color):
        self.shapes.append((np.array(lo, float), np.array(hi, float), sdf, self._index(color)))

    def ellipsoid(self, c, r, color):
        c, r = np.array(c, float), np.array(r, float)

        def sdf(p):
            q = (p - c) / r
            return (np.sqrt((q * q).sum(-1)) - 1.0) * r.min()
        self._add(c - r, c + r, sdf, color)

    def capsule(self, a, b, ra, rb, color):
        a, b = np.array(a, float), np.array(b, float)
        ab = b - a
        denom = max(float(ab @ ab), 1e-9)

        def sdf(p):
            t = np.clip(((p - a) @ ab) / denom, 0.0, 1.0)
            closest = a + t[..., None] * ab
            return np.sqrt(((p - closest) ** 2).sum(-1)) - (ra + (rb - ra) * t)
        r = max(ra, rb)
        self._add(np.minimum(a, b) - r, np.maximum(a, b) + r, sdf, color)

    def chain(self, points, ra, rb, color):
        n = len(points) - 1
        for i in range(n):
            r0 = ra + (rb - ra) * i / n
            r1 = ra + (rb - ra) * (i + 1) / n
            self.capsule(points[i], points[i + 1], r0, r1, color)

    def triangle(self, a, b, c, thickness, color):
        a, b, c = (np.array(v, float) for v in (a, b, c))
        n = np.cross(b - a, c - a)
        n /= np.linalg.norm(n)
        v0, v1 = b - a, c - a
        d00, d01, d11 = v0 @ v0, v0 @ v1, v1 @ v1
        inv = 1.0 / (d00 * d11 - d01 * d01)
        half = thickness * 0.5

        def sdf(p):
            w = p - a
            dist = np.abs(w @ n)
            d20, d21 = w @ v0, w @ v1
            v = (d11 * d20 - d01 * d21) * inv
            u = (d00 * d21 - d01 * d20) * inv
            inside = (v >= -0.01) & (u >= -0.01) & (u + v <= 1.01)
            return np.where(inside, dist - half, 1.0)
        lo = np.minimum(np.minimum(a, b), c) - half
        hi = np.maximum(np.maximum(a, b), c) + half
        self._add(lo, hi, sdf, color)

    def box(self, lo, hi, color):
        lo, hi = np.array(lo, float), np.array(hi, float)
        c, r = (lo + hi) * 0.5, (hi - lo) * 0.5

        def sdf(p):
            q = np.abs(p - c) - r
            return np.max(q, axis=-1)
        self._add(lo, hi, sdf, color)

    def grid(self):
        """(color grid, voxel origin) covering every shape."""
        lo = np.floor(np.min([s[0] for s in self.shapes], axis=0) * self.scale).astype(int) - 1
        hi = np.ceil(np.max([s[1] for s in self.shapes], axis=0) * self.scale).astype(int) + 1
        g = np.zeros(hi - lo, np.uint8)
        for s_lo, s_hi, sdf, color in self.shapes:
            a = np.maximum(np.floor(s_lo * self.scale).astype(int) - 1, lo)
            b = np.minimum(np.ceil(s_hi * self.scale).astype(int) + 1, hi)
            if np.any(b <= a):
                continue
            axes = [(np.arange(a[k], b[k]) + 0.5) / self.scale for k in range(3)]
            p = np.stack(np.meshgrid(*axes, indexing="ij"), -1)
            # Thin shapes stay at least one voxel thick at low resolution.
            mask = sdf(p) <= 0.5 / self.scale * 0.75
            sub = g[a[0] - lo[0]:b[0] - lo[0], a[1] - lo[1]:b[1] - lo[1], a[2] - lo[2]:b[2] - lo[2]]
            sub[mask] = color
        return g, lo

    def voxels(self, shade=None, hollow_above=20000):
        """{(x, y, z): color name}. shade: {color: [variants]} speckles
        colors for texture. Parts with more voxels than hollow_above keep only
        their shell (two voxels thick)."""
        g, lo = self.grid()
        solid = g > 0
        if solid.sum() > hollow_above:
            inner = solid.copy()
            for _ in range(2):
                inner = _erode(inner)
            g = np.where(inner, 0, g)
        out = {}
        xs, ys, zs = np.nonzero(g)
        for x, y, z in zip(xs.tolist(), ys.tolist(), zs.tolist()):
            name = self.names[g[x, y, z] - 1]
            pos = (x + int(lo[0]), y + int(lo[1]), z + int(lo[2]))
            if shade and name in shade:
                variants = shade[name]
                name = variants[((pos[0] * 73856093) ^ (pos[1] * 19349663) ^ (pos[2] * 83492791)) % len(variants)]
            out[pos] = name
        return out


def _erode(m):
    e = m.copy()
    e[1:] &= m[:-1]
    e[:-1] &= m[1:]
    e[:, 1:] &= m[:, :-1]
    e[:, :-1] &= m[:, 1:]
    e[:, :, 1:] &= m[:, :, :-1]
    e[:, :, :-1] &= m[:, :, 1:]
    e[0] = e[-1] = False
    e[:, 0] = e[:, -1] = False
    e[:, :, 0] = e[:, :, -1] = False
    return e
