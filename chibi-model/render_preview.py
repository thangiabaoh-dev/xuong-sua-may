#!/usr/bin/env python3
"""Tiny orthographic software renderer -> PNG (stdlib only)."""
import math
import struct
import zlib
import sys

OBJ = "chibi.obj"


def load_mtl(path):
    mtl, last = {}, None
    for line in open(path):
        t = line.split()
        if not t:
            continue
        if t[0] == "newmtl":
            last = t[1]
            mtl[last] = (0.8, 0.8, 0.8)
        elif t[0] == "Kd" and last:
            mtl[last] = (float(t[1]), float(t[2]), float(t[3]))
    return mtl


def load2(path):
    verts, faces = [], []
    mtl = {}
    cur = (0.8, 0.8, 0.8)
    import os
    for line in open(path):
        t = line.split()
        if not t:
            continue
        if t[0] == "v":
            verts.append((float(t[1]), float(t[2]), float(t[3])))
        elif t[0] == "mtllib":
            mtl = load_mtl(os.path.join(os.path.dirname(path) or ".", t[1]))
        elif t[0] == "usemtl":
            cur = mtl.get(t[1], cur)
        elif t[0] == "f":
            idx = [(int(q.split("/")[0]) - 1, int(q.split("//")[-1]) - 1) for q in t[1:]]
            faces.append((idx, cur))
    return verts, [], faces


def render(verts, faces, W, H, view, bg=(0.80, 0.83, 0.87)):
    # view direction d: from camera into the scene
    if view == "front":
        d = (0.0, 1.0, 0.0)      # camera sits at -Y
        sx_sign = 1.0
        light = (-0.45, -0.85, 0.55)
    else:
        d = (0.0, -1.0, 0.0)     # camera sits at +Y
        sx_sign = -1.0
        light = (-0.45, 0.85, 0.55)
    ll = math.sqrt(sum(c * c for c in light))
    light = tuple(c / ll for c in light)

    xs = [v[0] for v in verts]
    zs = [v[2] for v in verts]
    scale = min(W, H) / 2.15
    cx = (min(xs) + max(xs)) / 2
    cz = (min(zs) + max(zs)) / 2

    def proj(v):
        return (
            (v[0] - cx) * sx_sign * scale + W / 2,
            H / 2 - (v[2] - cz) * scale,
            -(v[0] * d[0] + v[1] * d[1] + v[2] * d[2]),  # larger = nearer
        )

    buf = [[bg[0], bg[1], bg[2]] for _ in range(W * H)]
    zbuf = [-1e18] * (W * H)
    amb = 0.40

    for idx, col in faces:
        a, b, c = (verts[idx[0][0]], verts[idx[1][0]], verts[idx[2][0]])
        u = [b[i] - a[i] for i in range(3)]
        v = [c[i] - a[i] for i in range(3)]
        fn = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
        fl = math.sqrt(sum(x * x for x in fn))
        if fl < 1e-12:
            continue
        fn = [x / fl for x in fn]
        if fn[0] * d[0] + fn[1] * d[1] + fn[2] * d[2] > 0:
            continue  # back-face: culled
        ndl = max(0.0, fn[0] * light[0] + fn[1] * light[1] + fn[2] * light[2])
        shade = amb + (1 - amb) * ndl
        rc = min(1.0, col[0] * shade)
        gc = min(1.0, col[1] * shade)
        bc = min(1.0, col[2] * shade)

        P = [proj(verts[i]) for i, _ in idx]
        for tri in range(len(P) - 2):
            (x0, y0, z0), (x1, y1, z1), (x2, y2, z2) = P[0], P[tri + 1], P[tri + 2]
            minx = max(0, int(min(x0, x1, x2)))
            maxx = min(W - 1, int(max(x0, x1, x2)) + 1)
            miny = max(0, int(min(y0, y1, y2)))
            maxy = min(H - 1, int(max(y0, y1, y2)) + 1)
            if maxx < minx or maxy < miny:
                continue
            den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
            if abs(den) < 1e-12:
                continue
            for py in range(miny, maxy + 1):
                for px in range(minx, maxx + 1):
                    l0 = ((y1 - y2) * (px - x2) + (x2 - x1) * (py - y2)) / den
                    l1 = ((y2 - y0) * (px - x2) + (x0 - x2) * (py - y2)) / den
                    l2 = 1.0 - l0 - l1
                    if l0 < -1e-6 or l1 < -1e-6 or l2 < -1e-6:
                        continue
                    z = l0 * z0 + l1 * z1 + l2 * z2
                    i = py * W + px
                    if z > zbuf[i]:
                        zbuf[i] = z
                        cell = buf[i]
                        cell[0], cell[1], cell[2] = rc, gc, bc
    return buf


def write_png(path, buf, W, H):
    raw = bytearray()
    for y in range(H):
        raw.append(0)
        for r, g, b in buf[y * W:(y + 1) * W]:
            raw += bytes((int(r * 255), int(g * 255), int(b * 255)))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(
            ">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 6))
    png += chunk(b"IEND", b"")
    open(path, "wb").write(png)


if __name__ == "__main__":
    W, H = 640, 880
    verts, norms, faces = load2(OBJ)
    panels = [render(verts, faces, W, H, v) for v in ("front", "back")]
    full = []
    for y in range(H):
        full.extend(panels[0][y * W:(y + 1) * W])
        full.extend(panels[1][y * W:(y + 1) * W])
    out = sys.argv[1] if len(sys.argv) > 1 else "preview.png"
    write_png(out, full, W * 2, H)
    print("wrote", out)
