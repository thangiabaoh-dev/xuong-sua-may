#!/usr/bin/env python3
"""Generate a chibi character (front/back matching reference) as OBJ + MTL.

Coordinate system: Z up, character faces -Y (Blender front view).
"""
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------- math utils


def sgnpow(v, m):
    if v == 0.0:
        return 0.0
    return math.copysign(abs(v) ** m, v)


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def mul(a, s):
    return (a[0] * s, a[1] * s, a[2] * s)


def cross(a, b):
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def length(a):
    return math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2])


def unit(a):
    l = length(a)
    if l < 1e-12:
        return (0.0, 0.0, 1.0)
    return (a[0] / l, a[1] / l, a[2] / l)


def lerp3(p0, p1, t):
    return (
        p0[0] + (p1[0] - p0[0]) * t,
        p0[1] + (p1[1] - p0[1]) * t,
        p0[2] + (p1[2] - p0[2]) * t,
    )


def spoint(cx, cy, cz, A, B, C, m1, m2, phi, lam):
    c = sgnpow(math.cos(phi), m1)
    return (
        cx + A * c * sgnpow(math.cos(lam), m2),
        cy + B * c * sgnpow(math.sin(lam), m2),
        cz + C * sgnpow(math.sin(phi), m1),
    )


def phi_for_z(z, C, m1, cz):
    """phi such that the superellipsoid reaches height z (C already scaled)."""
    t = (z - cz) / C
    t = max(-1.0, min(1.0, t))
    a = min(1.0, abs(t) ** (1.0 / m1))
    return math.asin(a) if t >= 0 else -math.asin(a)


# --------------------------------------------------------------- primitives


def super_shape(c, A, B, C, m1, m2, nu=32, nv=16):
    """Closed superellipsoid (m=1 -> ellipsoid, m<1 -> rounded box)."""
    cx, cy, cz = c
    verts = [(cx, cy, cz + C)]
    faces = []
    starts = []
    for j in range(1, nv):
        phi = math.pi / 2 - math.pi * j / nv
        starts.append(len(verts))
        for i in range(nu):
            lam = 2 * math.pi * i / nu
            verts.append(spoint(cx, cy, cz, A, B, C, m1, m2, phi, lam))
    bot = len(verts)
    verts.append((cx, cy, cz - C))

    r0 = starts[0]
    for i in range(nu):
        faces.append((0, r0 + i, r0 + (i + 1) % nu))
    for r in range(len(starts) - 1):
        hi, lo = starts[r], starts[r + 1]
        for i in range(nu):
            i2 = (i + 1) % nu
            faces.append((hi + i, lo + i, lo + i2, hi + i2))
    rl = starts[-1]
    for i in range(nu):
        faces.append((rl + (i + 1) % nu, rl + i, bot))
    return verts, faces


def box(c, hx, hy, hz):
    cx, cy, cz = c
    v = [
        (cx - hx, cy - hy, cz - hz),
        (cx + hx, cy - hy, cz - hz),
        (cx + hx, cy + hy, cz - hz),
        (cx - hx, cy + hy, cz - hz),
        (cx - hx, cy - hy, cz + hz),
        (cx + hx, cy - hy, cz + hz),
        (cx + hx, cy + hy, cz + hz),
        (cx - hx, cy + hy, cz + hz),
    ]
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (3, 0, 4, 7), (1, 2, 6, 5)]
    return v, f


def _frame(dn):
    a = (0.0, 0.0, 1.0) if abs(dn[2]) < 0.9 else (1.0, 0.0, 0.0)
    u = unit(cross(a, dn))
    v = cross(dn, u)
    return u, v


def tcyl(p0, p1, r0, r1, segs=16, cap0=True, cap1=True, flat=1.0):
    """Tapered cylinder/cone-ish tube from p0 to p1 (flat squashes the v axis)."""
    dn = unit(sub(p1, p0))
    u, v = _frame(dn)
    verts = []
    for i in range(segs):
        th = 2 * math.pi * i / segs
        c, s = math.cos(th), math.sin(th)
        verts.append(add(p0, add(mul(u, r0 * c), mul(v, r0 * s * flat))))
    for i in range(segs):
        th = 2 * math.pi * i / segs
        c, s = math.cos(th), math.sin(th)
        verts.append(add(p1, add(mul(u, r1 * c), mul(v, r1 * s * flat))))
    faces = []
    for i in range(segs):
        i2 = (i + 1) % segs
        faces.append((i, i2, segs + i2, segs + i))
    if cap0:
        ci = len(verts)
        verts.append(tuple(p0))
        for i in range(segs):
            faces.append((ci, (i + 1) % segs, i))
    if cap1:
        ci = len(verts)
        verts.append(tuple(p1))
        for i in range(segs):
            faces.append((ci, segs + i, segs + (i + 1) % segs))
    return verts, faces


def cone(p0, p1, r0, segs=14, flat=1.0, cap=True):
    """Spike: base circle at p0 tapering to point p1."""
    dn = unit(sub(p1, p0))
    u, v = _frame(dn)
    verts = []
    for i in range(segs):
        th = 2 * math.pi * i / segs
        c, s = math.cos(th), math.sin(th)
        verts.append(add(p0, add(mul(u, r0 * c), mul(v, r0 * s * flat))))
    tip = len(verts)
    verts.append(tuple(p1))
    faces = []
    for i in range(segs):
        faces.append((i, (i + 1) % segs, tip))
    if cap:
        ci = len(verts)
        verts.append(tuple(p0))
        for i in range(segs):
            faces.append((ci, (i + 1) % segs, i))
    return verts, faces


def shell_cap(c, A, B, C, m1, m2, phi_min_fn, n_lam=40, n_phi=8, lam0=-math.pi):
    """Open dome: phi from phi_min_fn(lam) up to the top pole."""
    cx, cy, cz = c
    verts, faces = [], []
    starts = []
    for j in range(n_phi):
        t = j / n_phi
        starts.append(len(verts))
        for i in range(n_lam):
            lam = lam0 + 2 * math.pi * i / n_lam
            pmin = phi_min_fn(lam)
            phi = pmin + t * (math.pi / 2 - pmin - 1e-4)
            verts.append(spoint(cx, cy, cz, A, B, C, m1, m2, phi, lam))
    pole = len(verts)
    verts.append((cx, cy, cz + C))
    for r in range(n_phi - 1):
        hi, lo = starts[r + 1], starts[r]
        for i in range(n_lam):
            i2 = (i + 1) % n_lam
            faces.append((hi + i, lo + i, lo + i2, hi + i2))
    rt = starts[-1]
    for i in range(n_lam):
        faces.append((pole, rt + i, rt + (i + 1) % n_lam))
    return verts, faces


def shell_patch(c, A, B, C, m1, m2, lam0, lam1, phi0, phi1, n_lam, n_phi, thick=0.02):
    """Closed rectangular patch on a superellipsoid shell (has thickness)."""
    cx, cy, cz = c

    def grid(sc):
        g = []
        for j in range(n_phi + 1):
            phi = phi0 + (phi1 - phi0) * j / n_phi
            row = []
            for i in range(n_lam + 1):
                lam = lam0 + (lam1 - lam0) * i / n_lam
                row.append(spoint(cx, cy, cz, A * sc, B * sc, C * sc, m1, m2, phi, lam))
            g.append(row)
        return g

    outer = grid(1.0)
    inner = grid(max(0.2, 1.0 - thick / max(A, 1e-6)))
    verts, faces = [], []
    oi, ii = [], []
    for g, idx in ((outer, oi), (inner, ii)):
        for row in g:
            idx.append(len(verts))
            verts.extend(row)

    def O(j, i):
        return oi[j] + i

    def I(j, i):
        return ii[j] + i

    for j in range(n_phi):
        for i in range(n_lam):
            faces.append((O(j + 1, i), O(j, i), O(j, i + 1), O(j + 1, i + 1)))
            faces.append((I(j, i), I(j + 1, i), I(j + 1, i + 1), I(j, i + 1)))
    for i in range(n_lam):
        faces.append((O(0, i), I(0, i), I(0, i + 1), O(0, i + 1)))
        faces.append((O(n_phi, i), O(n_phi, i + 1), I(n_phi, i + 1), I(n_phi, i)))
    for j in range(n_phi):
        faces.append((O(j, 0), O(j + 1, 0), I(j + 1, 0), I(j, 0)))
        faces.append((O(j, n_lam), I(j, n_lam), I(j + 1, n_lam), O(j + 1, n_lam)))
    return verts, faces


def phi_min_quad(z_front, z_side, z_back, C, m1, cz):
    pf = phi_for_z(z_front, C, m1, cz)
    ps = phi_for_z(z_side, C, m1, cz)
    pb = phi_for_z(z_back, C, m1, cz)
    b = (pf - pb) / 2.0
    cc = (pf - ps) - b
    a = ps

    def f(lam):
        fs = -math.sin(lam)
        return a + b * fs + cc * fs * fs

    return f


# ------------------------------------------------------------------ assembly
OBJECTS = []


def addobj(name, mat, shape, smooth=True):
    v, f = shape
    OBJECTS.append({"name": name, "mat": mat, "verts": v, "faces": f, "smooth": smooth})


HEAD_POS = (0.0, 0.0, 1.50)
HEAD_A, HEAD_B, HEAD_C = 0.46, 0.43, 0.44
M = 0.6


def hs(k):
    """Head-shaped shell scaled by k -> (A,B,C)."""
    return (HEAD_A * k, HEAD_B * k, HEAD_C * k)


# --- head / face -----------------------------------------------------------
addobj("head", "skin", super_shape(HEAD_POS, HEAD_A, HEAD_B, HEAD_C, M, M, 36, 22))
addobj("neck", "skin", tcyl((0, 0, 1.00), (0, 0, 1.18), 0.12, 0.115, 16))
for sx in (-1, 1):
    addobj("ear", "skin", super_shape((sx * 0.45, 0.03, 1.42), 0.03, 0.06, 0.075, 1, 1, 14, 10))

for sx in (-1, 1):
    addobj("eye_white", "eye_white", super_shape((sx * 0.17, -0.396, 1.44), 0.115, 0.052, 0.11, 1, 1, 20, 12))
    addobj("iris", "iris", super_shape((sx * 0.17, -0.420, 1.435), 0.072, 0.040, 0.080, 1, 1, 18, 10))
    addobj("pupil", "pupil", super_shape((sx * 0.17, -0.440, 0 + 1.432), 0.034, 0.030, 0.044, 1, 1, 14, 8))
    addobj("eye_glint", "eye_white", super_shape((sx * 0.145, -0.452, 1.478), 0.025, 0.022, 0.027, 1, 1, 12, 8))
    addobj("brow", "brow", box((sx * 0.17, -0.418, 1.575), 0.055, 0.016, 0.012), smooth=False)

addobj("mouth", "mouth", super_shape((0, -0.410, 1.215), 0.052, 0.032, 0.030, 1, 1, 16, 10))
addobj("teeth", "eye_white", super_shape((0, -0.428, 1.228), 0.038, 0.020, 0.013, 1, 1, 14, 8))

# --- hair ------------------------------------------------------------------
HAIR_A, HAIR_B, HAIR_C = hs(1.065)
addobj(
    "hair_shell",
    "hair",
    shell_cap(
        HEAD_POS, HAIR_A, HAIR_B, HAIR_C, M, M,
        phi_min_quad(1.590, 1.235, 1.095, HAIR_C, M, 1.50),
        n_lam=44, n_phi=9,
    ),
)

BANGS = [
    ((-0.055, -0.34, 1.70), (-0.03, -0.45, 1.47), 0.075, 0.45),
    ((0.055, -0.34, 1.70), (0.035, -0.45, 1.48), 0.075, 0.45),
    ((-0.185, -0.33, 1.68), (-0.16, -0.44, 1.545), 0.085, 0.50),
    ((0.185, -0.33, 1.68), (0.17, -0.44, 1.545), 0.085, 0.50),
    ((-0.30, -0.28, 1.65), (-0.33, -0.40, 1.555), 0.085, 0.50),
    ((0.30, -0.28, 1.65), (0.34, -0.40, 1.555), 0.085, 0.50),
    ((-0.38, -0.16, 1.60), (-0.45, -0.28, 1.57), 0.08, 0.50),
    ((0.38, -0.16, 1.60), (0.46, -0.28, 1.57), 0.08, 0.50),
]
for p0, p1, r, fl in BANGS:
    addobj("hair_bang", "hair", cone(p0, p1, r, 12, fl))

SIDES = [
    ((-0.40, -0.05, 1.45), (-0.53, -0.12, 1.32), 0.10, 0.6),
    ((0.40, -0.05, 1.45), (0.53, -0.12, 1.32), 0.10, 0.6),
    ((-0.42, 0.10, 1.38), (-0.55, 0.14, 1.26), 0.095, 0.6),
    ((0.42, 0.10, 1.38), (0.55, 0.14, 1.26), 0.095, 0.6),
    ((-0.34, -0.24, 1.34), (-0.43, -0.34, 1.22), 0.085, 0.6),
    ((0.34, -0.24, 1.34), (0.43, -0.34, 1.22), 0.085, 0.6),
    ((-0.36, 0.26, 1.30), (-0.44, 0.36, 1.18), 0.085, 0.6),
    ((0.36, 0.26, 1.30), (0.44, 0.36, 1.18), 0.085, 0.6),
    ((-0.16, 0.40, 1.25), (-0.20, 0.50, 1.12), 0.09, 0.6),
    ((0.16, 0.40, 1.25), (0.20, 0.50, 1.12), 0.09, 0.6),
    ((-0.44, -0.02, 1.30), (-0.56, -0.06, 1.18), 0.095, 0.55),
    ((0.44, -0.02, 1.30), (0.56, -0.06, 1.18), 0.095, 0.55),
    ((-0.43, 0.17, 1.24), (-0.54, 0.24, 1.13), 0.090, 0.55),
    ((0.43, 0.17, 1.24), (0.54, 0.24, 1.13), 0.090, 0.55),
    ((-0.30, -0.30, 1.26), (-0.38, -0.40, 1.15), 0.080, 0.55),
    ((0.30, -0.30, 1.26), (0.38, -0.40, 1.15), 0.080, 0.55),
    ((-0.28, 0.34, 1.20), (-0.34, 0.44, 1.08), 0.085, 0.6),
    ((0.28, 0.34, 1.20), (0.34, 0.44, 1.08), 0.085, 0.6),
]
for p0, p1, r, fl in SIDES:
    addobj("hair_spike", "hair", cone(p0, p1, r, 12, fl))

# nape tuft (back view)
addobj("hair_tuft", "hair", cone((0, 0.34, 1.16), (0, 0.42, 0.94), 0.105, 14, 0.75))
addobj("hair_tuft", "hair", cone((-0.13, 0.31, 1.14), (-0.17, 0.40, 1.00), 0.075, 12, 0.75))
addobj("hair_tuft", "hair", cone((0.13, 0.31, 1.14), (0.17, 0.40, 1.00), 0.075, 12, 0.75))

# --- cap (worn backwards) --------------------------------------------------
CAP_A, CAP_B, CAP_C = hs(1.095)
addobj(
    "cap_dome",
    "cap",
    shell_cap(
        HEAD_POS, CAP_A, CAP_B, CAP_C, M, M,
        phi_min_quad(1.700, 1.665, 1.330, CAP_C, M, 1.50),
        n_lam=44, n_phi=7,
    ),
)
addobj("cap_button", "cap", tcyl((0, 0, 1.975), (0, 0, 2.012), 0.024, 0.020, 12))

# closure band across the forehead
BAND_A, BAND_B, BAND_C = hs(1.105)
band_p0 = phi_for_z(1.575, BAND_C, M, 1.50)
band_p1 = phi_for_z(1.700, BAND_C, M, 1.50)
addobj(
    "cap_band",
    "band",
    # lam range is an exact mirror pair (b = -pi - a mod 2pi) so grid
    # samples pair up i+j = n_lam across x=0
    shell_patch(HEAD_POS, BAND_A, BAND_B, BAND_C, M, M,
                -(math.pi - 0.24), -0.24, band_p0, band_p1, 30, 5, thick=0.022),
)

# light closure gap panel in the middle of the band
GAP_A, GAP_B, GAP_C = hs(1.128)
addobj(
    "cap_gap",
    "capgap",
    shell_patch(HEAD_POS, GAP_A, GAP_B, GAP_C, M, M,
                -(math.pi - 1.30), -1.30,
                phi_for_z(1.592, GAP_C, M, 1.50),
                phi_for_z(1.688, GAP_C, M, 1.50), 12, 5, thick=0.016),
)
addobj("cap_clip", "clip", box((0, -0.492, 1.578), 0.045, 0.020, 0.018), smooth=False)

# two red marks on the left of the band
RED_A, RED_B, RED_C = hs(1.146)
rp0 = phi_for_z(1.600, RED_C, M, 1.50)
rp1 = phi_for_z(1.664, RED_C, M, 1.50)
for lam0 in (-2.80, -2.645):
    addobj("cap_mark", "red",
        shell_patch(HEAD_POS, RED_A, RED_B, RED_C, M, M,
                    lam0, lam0 + 0.062, rp0, rp1, 3, 4, thick=0.014))

# brim/visor at the back (cap is worn backwards)
BRIM_A, BRIM_B, BRIM_C = hs(1.10)
bt_lo = phi_for_z(1.170, BRIM_C, M, 1.50)
bt_hi = phi_for_z(1.360, BRIM_C, M, 1.50)
addobj("cap_brim", "cap",
    shell_patch(HEAD_POS, BRIM_A, BRIM_B, BRIM_C, M, M,
                0.16, math.pi - 0.16, bt_lo, bt_hi, 30, 7, thick=0.035))

BRS_A, BRS_B, BRS_C = hs(1.125)
addobj("cap_brim_stripe", "red",
    shell_patch(HEAD_POS, BRS_A, BRS_B, BRS_C, M, M,
                0.22, math.pi - 0.22,
                phi_for_z(1.178, BRS_C, M, 1.50),
                phi_for_z(1.212, BRS_C, M, 1.50), 28, 3, thick=0.014))

# --- torso / hoodie --------------------------------------------------------
addobj("torso", "hoodie", super_shape((0, 0, 0.83), 0.31, 0.26, 0.31, 0.5, 0.5, 32, 20))
addobj("hood", "hoodie", super_shape((0, 0.17, 1.13), 0.27, 0.19, 0.10, 0.6, 0.6, 26, 14))
addobj("hood_drape", "hoodie", super_shape((0, 0.27, 1.05), 0.20, 0.12, 0.13, 0.6, 0.6, 22, 12))
addobj("hood_print", "cap", super_shape((0, 0.375, 1.07), 0.13, 0.04, 0.07, 0.6, 0.6, 18, 10))
addobj("pocket", "hoodie", super_shape((0, -0.250, 0.665), 0.20, 0.05, 0.105, 0.5, 0.5, 22, 14))

for sx in (-1, 1):
    addobj("drawstring", "hoodie", tcyl((sx * 0.085, -0.230, 1.075), (sx * 0.095, -0.288, 0.905), 0.013, 0.013, 8))
    addobj("aglet", "gray", tcyl((sx * 0.095, -0.288, 0.905), (sx * 0.098, -0.296, 0.855), 0.021, 0.019, 8))

# --- arms ------------------------------------------------------------------
for sx in (-1, 1):
    sh = (sx * 0.23, 0.0, 1.06)
    wr = (sx * 0.41, -0.03, 0.60)
    addobj("sleeve", "hoodie", tcyl(sh, wr, 0.125, 0.09, 16))
    for t0 in (0.70, 0.775, 0.85):
        t1 = t0 + 0.045
        r = lambda t: 0.125 + (0.09 - 0.125) * t
        addobj("sleeve_stripe", "stripe",
            tcyl(lerp3(sh, wr, t0), lerp3(sh, wr, t1), r(t0) + 0.012, r(t1) + 0.012, 16, cap0=False, cap1=False))
    addobj("glove", "glove", super_shape((sx * 0.425, -0.035, 0.545), 0.088, 0.078, 0.098, 0.8, 0.8, 20, 14))
    addobj("glove_thumb", "glove", super_shape((sx * 0.368, -0.088, 0.552), 0.034, 0.030, 0.050, 1, 1, 12, 8))
    addobj("sleeve_tag", "red", box((sx * 0.352, 0.115, 0.855), 0.030, 0.018, 0.048), smooth=False)

# --- lower body ------------------------------------------------------------
addobj("hips", "pants", super_shape((0, 0, 0.615), 0.27, 0.23, 0.06, 0.5, 0.5, 26, 14))
addobj("waistband", "waist", super_shape((0, 0, 0.658), 0.275, 0.235, 0.024, 0.5, 0.5, 26, 10))

for sx in (-1, 1):
    hip = (sx * 0.13, 0.0, 0.62)
    ank = (sx * 0.145, 0.0, 0.155)
    addobj("pant_leg", "pants", tcyl(hip, ank, 0.135, 0.098, 16))
    addobj("pant_cuff", "pants", tcyl((sx * 0.145, 0, 0.155), (sx * 0.145, 0, 0.205), 0.100, 0.114, 16))

    # hanging straps on the +X thigh, tags on the -X thigh
    if sx > 0:
        addobj("strap", "stripe", box((0.258, -0.03, 0.465), 0.016, 0.055, 0.10), smooth=False)
        addobj("strap", "stripe", box((0.262, 0.035, 0.425), 0.014, 0.040, 0.085), smooth=False)
        addobj("strap", "stripe", box((0.255, -0.055, 0.360), 0.013, 0.030, 0.070), smooth=False)
    else:
        addobj("tag", "pink", box((-0.256, -0.055, 0.450), 0.014, 0.030, 0.050), smooth=False)
        addobj("tag", "stripe", box((-0.252, -0.015, 0.400), 0.012, 0.035, 0.045), smooth=False)
        addobj("tag", "pink", box((-0.254, 0.030, 0.355), 0.012, 0.028, 0.040), smooth=False)

    # shoes
    x = sx * 0.145
    addobj("shoe_sole", "shoe_navy", super_shape((x, -0.025, 0.035), 0.108, 0.148, 0.035, 0.45, 0.45, 22, 12))
    addobj("shoe_midsole", "shoe_blue", super_shape((x, -0.025, 0.072), 0.104, 0.144, 0.030, 0.45, 0.45, 22, 12))
    addobj("shoe_upper", "shoe_white", super_shape((x, -0.015, 0.135), 0.100, 0.140, 0.065, 0.5, 0.5, 22, 14))
    addobj("shoe_collar", "shoe_blue", super_shape((x, 0.035, 0.185), 0.065, 0.075, 0.032, 0.6, 0.6, 18, 10))
    addobj("shoe_heel", "shoe_blue", box((x, 0.122, 0.140), 0.055, 0.028, 0.045), smooth=False)
    addobj("shoe_dot", "yellow", box((sx * 0.248, -0.045, 0.105), 0.018, 0.045, 0.030), smooth=False)

addobj("belt_tag", "stripe", box((-0.20, -0.243, 0.668), 0.030, 0.016, 0.038), smooth=False)

# ---------------------------------------------------------------- materials
MATERIALS = {
    "skin": (0.965, 0.843, 0.737),
    "hair": (0.788, 0.769, 0.745),
    "brow": (0.520, 0.480, 0.450),
    "cap": (0.102, 0.114, 0.149),
    "band": (0.055, 0.055, 0.062),
    "red": (0.878, 0.192, 0.192),
    "capgap": (0.700, 0.660, 0.640),
    "clip": (0.300, 0.300, 0.330),
    "hoodie": (0.957, 0.961, 0.969),
    "stripe": (0.145, 0.145, 0.155),
    "glove": (0.812, 0.910, 0.969),
    "pants": (0.980, 0.980, 0.980),
    "waist": (0.900, 0.900, 0.920),
    "shoe_white": (1.000, 1.000, 1.000),
    "shoe_blue": (0.227, 0.373, 0.659),
    "shoe_navy": (0.137, 0.173, 0.302),
    "yellow": (0.940, 0.780, 0.230),
    "eye_white": (1.000, 1.000, 1.000),
    "iris": (0.784, 0.608, 0.235),
    "pupil": (0.180, 0.130, 0.070),
    "mouth": (0.520, 0.240, 0.200),
    "pink": (0.910, 0.380, 0.480),
    "gray": (0.560, 0.560, 0.600),
}


# ------------------------------------------------------------------ writers
def face_normal(v, f):
    p0, p1, p2 = v[f[0]], v[f[1]], v[f[2]]
    n = cross(sub(p1, p0), sub(p2, p0))
    l = length(n)
    if l < 1e-12:
        return (0.0, 0.0, 0.0)
    return (n[0] / l, n[1] / l, n[2] / l)


def obj_normals(verts, faces, smooth):
    if smooth:
        acc = {}
        for f in faces:
            n = face_normal(verts, f)
            if n == (0.0, 0.0, 0.0):
                continue
            for i in f:
                key = (round(verts[i][0], 5), round(verts[i][1], 5), round(verts[i][2], 5))
                cur = acc.get(key)
                if cur is None:
                    acc[key] = list(n)
                else:
                    cur[0] += n[0]
                    cur[1] += n[1]
                    cur[2] += n[2]
        vn = []
        for v in verts:
            n = acc.get((round(v[0], 5), round(v[1], 5), round(v[2], 5)))
            if n is None:
                vn.append((0.0, 0.0, 1.0))
            else:
                l = math.sqrt(n[0] ** 2 + n[1] ** 2 + n[2] ** 2)
                vn.append((n[0] / l, n[1] / l, n[2] / l) if l > 1e-12 else (0.0, 0.0, 1.0))
        return vn, [tuple(k + 1 for k in f) for f in faces]

    vn, fni = [], []
    for f in faces:
        vn.append(face_normal(verts, f))
        fni.append(tuple([len(vn)] * len(f)))
    return vn, fni


def write_mtl(path):
    lines = ["# chibi character materials", ""]
    for name, (r, g, b) in MATERIALS.items():
        lines += [
            f"newmtl {name}",
            f"Kd {r:.4f} {g:.4f} {b:.4f}",
            f"Ka {r*0.25:.4f} {g*0.25:.4f} {b*0.25:.4f}",
            "Ks 0.1000 0.1000 0.1000",
            "Ns 24.0000",
            "illum 2",
            "",
        ]
    with open(path, "w") as fh:
        fh.write("\n".join(lines))


def write_obj(path, mtl_name):
    out = [
        "# chibi character",
        f"mtllib {mtl_name}",
        "",
    ]
    v_off = n_off = 0
    for ob in OBJECTS:
        verts, faces = ob["verts"], ob["faces"]
        vn, fni = obj_normals(verts, faces, ob["smooth"])
        out.append(f"o {ob['name']}")
        out.append(f"usemtl {ob['mat']}")
        for x, y, z in verts:
            out.append(f"v {x:.5f} {y:.5f} {z:.5f}")
        for nx, ny, nz in vn:
            out.append(f"vn {nx:.4f} {ny:.4f} {nz:.4f}")
        for f, ni in zip(faces, fni):
            out.append(
                "f "
                + " ".join(f"{v_off + a + 1}//{n_off + b}" for a, b in zip(f, ni))
            )
        out.append("")
        v_off += len(verts)
        n_off += len(vn)
    with open(path, "w") as fh:
        fh.write("\n".join(out) + "\n")


def stats():
    nv = sum(len(o["verts"]) for o in OBJECTS)
    nf = sum(len(o["faces"]) for o in OBJECTS)
    return len(OBJECTS), nv, nf


if __name__ == "__main__":
    write_mtl(os.path.join(HERE, "chibi.mtl"))
    write_obj(os.path.join(HERE, "chibi.obj"), "chibi.mtl")
    no, nv, nf = stats()
    print(f"objects={no} vertices={nv} faces={nf}")
    print("wrote", os.path.join(HERE, "chibi.obj"))
    print("wrote", os.path.join(HERE, "chibi.mtl"))
