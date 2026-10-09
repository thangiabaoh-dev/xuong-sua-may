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



# ------------------------------------------------------------------ NPC materials
MATERIALS_NPCS_BASE = {
    "skin": (0.965, 0.843, 0.737),
    "eye_white": (1.000, 1.000, 1.000),
    "iris": (0.784, 0.608, 0.235),
    "pupil": (0.180, 0.130, 0.070),
    "mouth": (0.520, 0.240, 0.200),
    "brow": (0.520, 0.480, 0.450),
    "hair_black": (0.102, 0.114, 0.149),
    "shirt_white": (0.957, 0.961, 0.969),
    "pants_blue": (0.227, 0.373, 0.659),
    "backpack_green": (0.255, 0.588, 0.353),
    "shoe_white": (1.000, 1.000, 1.000),
    "shoe_blue": (0.227, 0.373, 0.659),
    "shoe_navy": (0.137, 0.173, 0.302),
    "stripe": (0.145, 0.145, 0.155),
    "glove_skin": (0.965, 0.843, 0.737),
    "shirt_cream": (0.922, 0.882, 0.784),
    "pants_brown": (0.431, 0.333, 0.235),
    "hair_neat": (0.118, 0.118, 0.137),
    "glasses_black": (0.055, 0.055, 0.062),
    "briefcase_brown": (0.353, 0.255, 0.157),
    "jacket_brown": (0.588, 0.431, 0.314),
    "pants_gray": (0.510, 0.510, 0.529),
    "hair_long": (0.314, 0.235, 0.176),
    "laptop_gray": (0.549, 0.549, 0.569),
}

HEAD_POS = (0.0, 0.0, 1.50)
HEAD_A, HEAD_B, HEAD_C = 0.46, 0.43, 0.44
M = 0.6

def hs(k):
    return (HEAD_A * k, HEAD_B * k, HEAD_C * k)

def _add(objs, name, mat, shape, smooth=True):
    v, f = shape
    objs.append({"name": name, "mat": mat, "verts": v, "faces": f, "smooth": smooth})

def build_base_head(objs):
    _add(objs, "head", "skin", super_shape(HEAD_POS, HEAD_A, HEAD_B, HEAD_C, M, M, 28, 18))
    _add(objs, "neck", "skin", tcyl((0, 0, 1.00), (0, 0, 1.18), 0.12, 0.115, 12))
    for sx in (-1, 1):
        _add(objs, "ear", "skin", super_shape((sx * 0.45, 0.03, 1.42), 0.03, 0.06, 0.075, 1, 1, 10, 8))
        _add(objs, "eye_white", "eye_white", super_shape((sx * 0.17, -0.396, 1.44), 0.115, 0.052, 0.11, 1, 1, 14, 10))
        _add(objs, "iris", "iris", super_shape((sx * 0.17, -0.420, 1.435), 0.072, 0.040, 0.080, 1, 1, 12, 8))
        _add(objs, "pupil", "pupil", super_shape((sx * 0.17, -0.440, 1.432), 0.034, 0.030, 0.044, 1, 1, 10, 8))
        _add(objs, "brow", "brow", box((sx * 0.17, -0.418, 1.575), 0.055, 0.016, 0.012), smooth=False)
    _add(objs, "mouth", "mouth", super_shape((0, -0.410, 1.215), 0.052, 0.032, 0.030, 1, 1, 12, 8))
    # short black hair shell (ban_hoc)
    HAIR_A, HAIR_B, HAIR_C = hs(1.065)
    _add(objs, "hair_shell", "hair_black",
        shell_cap(HEAD_POS, HAIR_A, HAIR_B, HAIR_C, M, M,
            phi_min_quad(1.590, 1.235, 1.095, HAIR_C, M, 1.50), n_lam=28, n_phi=7))
    # side tufts short
    for sx in (-1, 1):
        _add(objs, "hair_side", "hair_black", cone((sx*0.40, -0.05, 1.45), (sx*0.50, -0.10, 1.34), 0.09, 10, 0.6))

def build_ban_hoc():
    objs = []
    mats = dict(MATERIALS_NPCS_BASE)
    build_base_head(objs)
    # torso shirt
    _add(objs, "torso", "shirt_white", super_shape((0, 0, 0.83), 0.31, 0.26, 0.31, 0.5, 0.5, 24, 16))
    _add(objs, "pocket", "shirt_white", super_shape((0, -0.250, 0.665), 0.20, 0.05, 0.105, 0.5, 0.5, 16, 10))
    for sx in (-1, 1):
        sh = (sx * 0.23, 0.0, 1.06)
        wr = (sx * 0.41, -0.03, 0.60)
        _add(objs, "sleeve", "shirt_white", tcyl(sh, wr, 0.125, 0.09, 12))
        _add(objs, "glove", "glove_skin", super_shape((sx * 0.425, -0.035, 0.545), 0.088, 0.078, 0.098, 0.8, 0.8, 14, 10))
    _add(objs, "hips", "pants_blue", super_shape((0, 0, 0.615), 0.27, 0.23, 0.06, 0.5, 0.5, 20, 10))
    for sx in (-1, 1):
        hip = (sx * 0.13, 0.0, 0.62)
        ank = (sx * 0.145, 0.0, 0.155)
        _add(objs, "pant_leg", "pants_blue", tcyl(hip, ank, 0.135, 0.098, 12))
        x = sx * 0.145
        _add(objs, "shoe_sole", "shoe_navy", super_shape((x, -0.025, 0.035), 0.108, 0.148, 0.035, 0.45, 0.45, 16, 10))
        _add(objs, "shoe_midsole", "shoe_blue", super_shape((x, -0.025, 0.072), 0.104, 0.144, 0.030, 0.45, 0.45, 16, 10))
        _add(objs, "shoe_upper", "shoe_white", super_shape((x, -0.015, 0.135), 0.100, 0.140, 0.065, 0.5, 0.5, 16, 10))
    # backpack behind (+Y is back, front is -Y)
    _add(objs, "backpack", "backpack_green", box((0, 0.38, 0.90), 0.26, 0.14, 0.30), smooth=False)
    _add(objs, "backpack_front_pocket", "backpack_green", box((0, 0.52, 0.82), 0.18, 0.04, 0.18), smooth=False)
    for sx in (-1, 1):
        _add(objs, "backpack_strap", "backpack_green", box((sx*0.16, -0.27, 0.90), 0.05, 0.03, 0.28), smooth=False)
    return objs, mats

def build_giao_vien():
    objs = []
    import copy
    mats = dict(MATERIALS_NPCS_BASE)
    # head reuse but neat hair
    _add(objs, "head", "skin", super_shape(HEAD_POS, HEAD_A, HEAD_B, HEAD_C, M, M, 28, 18))
    _add(objs, "neck", "skin", tcyl((0, 0, 1.00), (0, 0, 1.18), 0.12, 0.115, 12))
    for sx in (-1, 1):
        _add(objs, "ear", "skin", super_shape((sx * 0.45, 0.03, 1.42), 0.03, 0.06, 0.075, 1, 1, 10, 8))
        _add(objs, "eye_white", "eye_white", super_shape((sx * 0.17, -0.396, 1.44), 0.115, 0.052, 0.11, 1, 1, 14, 10))
        _add(objs, "iris", "iris", super_shape((sx * 0.17, -0.420, 1.435), 0.072, 0.040, 0.080, 1, 1, 12, 8))
        _add(objs, "pupil", "pupil", super_shape((sx * 0.17, -0.440, 1.432), 0.034, 0.030, 0.044, 1, 1, 10, 8))
    # neat combed hair (shorter shell)
    HA, HB, HC = hs(1.05)
    _add(objs, "hair_neat", "hair_neat",
        shell_cap(HEAD_POS, HA, HB, HC, M, M,
            phi_min_quad(1.620, 1.300, 1.150, HC, M, 1.50), n_lam=28, n_phi=6))
    # glasses: two rectangular rims + bridge (eyes visible through lens gaps)
    for sx in (-1, 1):
        cx, cz = sx * 0.17, 1.445
        _add(objs, "glasses", "glasses_black", box((cx, -0.432, cz + 0.115), 0.135, 0.020, 0.018), smooth=False)
        _add(objs, "glasses", "glasses_black", box((cx, -0.432, cz - 0.115), 0.135, 0.020, 0.018), smooth=False)
        _add(objs, "glasses", "glasses_black", box((cx - 0.135, -0.432, cz), 0.018, 0.020, 0.115), smooth=False)
        _add(objs, "glasses", "glasses_black", box((cx + 0.135, -0.432, cz), 0.018, 0.020, 0.115), smooth=False)
    _add(objs, "glasses", "glasses_black", box((0, -0.432, 1.445), 0.055, 0.018, 0.018), smooth=False)

    _add(objs, "mouth", "mouth", super_shape((0, -0.410, 1.215), 0.052, 0.032, 0.030, 1, 1, 12, 8))
    # torso cream shirt + brown pants
    _add(objs, "torso", "shirt_cream", super_shape((0, 0, 0.83), 0.31, 0.26, 0.31, 0.5, 0.5, 24, 16))
    for sx in (-1, 1):
        sh = (sx * 0.23, 0.0, 1.06)
        wr = (sx * 0.41, -0.03, 0.60)
        _add(objs, "sleeve", "shirt_cream", tcyl(sh, wr, 0.125, 0.09, 12))
        _add(objs, "glove", "glove_skin", super_shape((sx * 0.425, -0.035, 0.545), 0.088, 0.078, 0.098, 0.8, 0.8, 14, 10))
    _add(objs, "hips", "pants_brown", super_shape((0, 0, 0.615), 0.27, 0.23, 0.06, 0.5, 0.5, 20, 10))
    for sx in (-1, 1):
        hip = (sx * 0.13, 0.0, 0.62)
        ank = (sx * 0.145, 0.0, 0.155)
        _add(objs, "pant_leg", "pants_brown", tcyl(hip, ank, 0.135, 0.098, 12))
        x = sx * 0.145
        _add(objs, "shoe_sole", "shoe_navy", super_shape((x, -0.025, 0.035), 0.108, 0.148, 0.035, 0.45, 0.45, 16, 10))
        _add(objs, "shoe_midsole", "shoe_blue", super_shape((x, -0.025, 0.072), 0.104, 0.144, 0.030, 0.45, 0.45, 16, 10))
        _add(objs, "shoe_upper", "shoe_white", super_shape((x, -0.015, 0.135), 0.100, 0.140, 0.065, 0.5, 0.5, 16, 10))
    # briefcase right side (-X is the character's right: faces -Y, right = fwd x up)
    _add(objs, "briefcase", "briefcase_brown", box((-0.48, 0.10, 0.55), 0.12, 0.10, 0.20), smooth=False)
    _add(objs, "briefcase_handle", "briefcase_brown", box((-0.48, -0.02, 0.78), 0.03, 0.03, 0.06), smooth=False)
    return objs, mats

def build_hoai_niem():
    objs = []
    mats = dict(MATERIALS_NPCS_BASE)
    _add(objs, "head", "skin", super_shape(HEAD_POS, HEAD_A, HEAD_B, HEAD_C, M, M, 28, 18))
    _add(objs, "neck", "skin", tcyl((0, 0, 1.00), (0, 0, 1.18), 0.12, 0.115, 12))
    for sx in (-1, 1):
        _add(objs, "ear", "skin", super_shape((sx * 0.45, 0.03, 1.42), 0.03, 0.06, 0.075, 1, 1, 10, 8))
        _add(objs, "eye_white", "eye_white", super_shape((sx * 0.17, -0.396, 1.44), 0.115, 0.052, 0.11, 1, 1, 14, 10))
        _add(objs, "iris", "iris", super_shape((sx * 0.17, -0.420, 1.435), 0.072, 0.040, 0.080, 1, 1, 12, 8))
        _add(objs, "pupil", "pupil", super_shape((sx * 0.17, -0.440, 1.432), 0.034, 0.030, 0.044, 1, 1, 10, 8))
    _add(objs, "mouth", "mouth", super_shape((0, -0.410, 1.215), 0.052, 0.032, 0.030, 1, 1, 12, 8))
    # long hair shell + ponytail back
    HA, HB, HC = hs(1.08)
    _add(objs, "hair_long_shell", "hair_long",
        shell_cap(HEAD_POS, HA, HB, HC, M, M,
            phi_min_quad(1.560, 1.180, 1.020, HC, M, 1.50), n_lam=28, n_phi=7))
    _add(objs, "ponytail", "hair_long", cone((0, 0.35, 1.30), (0, 0.48, 0.95), 0.10, 12, 0.7))
    # jacket torso
    _add(objs, "torso", "jacket_brown", super_shape((0, 0, 0.83), 0.32, 0.27, 0.31, 0.5, 0.5, 24, 16))
    _add(objs, "collar", "jacket_brown", super_shape((0, 0.10, 1.10), 0.20, 0.12, 0.08, 0.6, 0.6, 16, 10))
    # arms forward holding laptop
    for sx in (-1, 1):
        sh = (sx * 0.24, 0.0, 1.02)
        el = (sx * 0.30, -0.20, 0.80)
        ha = (sx * 0.18, -0.32, 0.82)
        _add(objs, "sleeve_upper", "jacket_brown", tcyl(sh, el, 0.125, 0.10, 12))
        _add(objs, "sleeve_fore", "jacket_brown", tcyl(el, ha, 0.10, 0.085, 12))
        _add(objs, "glove", "glove_skin", super_shape((ha[0], ha[1], ha[2]-0.03), 0.08, 0.07, 0.09, 0.8, 0.8, 12, 10))
    # old thick laptop in front (-Y)
    _add(objs, "old_laptop", "laptop_gray", box((0, -0.33, 0.82), 0.28, 0.06, 0.20), smooth=False)
    _add(objs, "old_laptop_screen", "laptop_gray", box((0, -0.30, 0.98), 0.28, 0.04, 0.14), smooth=False)
    _add(objs, "hips", "pants_gray", super_shape((0, 0, 0.615), 0.27, 0.23, 0.06, 0.5, 0.5, 20, 10))
    for sx in (-1, 1):
        hip = (sx * 0.13, 0.0, 0.62)
        ank = (sx * 0.145, 0.0, 0.155)
        _add(objs, "pant_leg", "pants_gray", tcyl(hip, ank, 0.135, 0.098, 12))
        x = sx * 0.145
        _add(objs, "shoe_sole", "shoe_navy", super_shape((x, -0.025, 0.035), 0.108, 0.148, 0.035, 0.45, 0.45, 16, 10))
        _add(objs, "shoe_midsole", "shoe_blue", super_shape((x, -0.025, 0.072), 0.104, 0.144, 0.030, 0.45, 0.45, 16, 10))
        _add(objs, "shoe_upper", "shoe_white", super_shape((x, -0.015, 0.135), 0.100, 0.140, 0.065, 0.5, 0.5, 16, 10))
    return objs, mats

def build_variant(name: str):
    if name == "ban_hoc":
        return build_ban_hoc()
    if name == "giao_vien":
        return build_giao_vien()
    if name == "hoai_niem":
        return build_hoai_niem()
    raise ValueError(f"unknown variant {name}")

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



def write_mtl_for(path, mats):
    lines = ["# npc materials", ""]
    for name, (r, g, b) in mats.items():
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

def write_obj_for(path, mtl_name, objs):
    out = ["# npc character", f"mtllib {mtl_name}", ""]
    v_off = n_off = 0
    for ob in objs:
        verts, faces = ob["verts"], ob["faces"]
        vn, fni = obj_normals(verts, faces, ob["smooth"])
        out.append(f"o {ob['name']}")
        out.append(f"usemtl {ob['mat']}")
        for x, y, z in verts:
            out.append(f"v {x:.5f} {y:.5f} {z:.5f}")
        for nx, ny, nz in vn:
            out.append(f"vn {nx:.4f} {ny:.4f} {nz:.4f}")
        for f, ni in zip(faces, fni):
            out.append("f " + " ".join(f"{v_off + a + 1}//{n_off + b}" for a, b in zip(f, ni)))
        out.append("")
        v_off += len(verts)
        n_off += len(vn)
    with open(path, "w") as fh:
        fh.write("\n".join(out) + "\n")

def stats_for(objs):
    nv = sum(len(o["verts"]) for o in objs)
    nf = sum(len(o["faces"]) for o in objs)
    return len(objs), nv, nf

if __name__ == "__main__":
    import os, sys
    HERE = os.path.dirname(os.path.abspath(__file__))
    args = sys.argv[1:]
    variants = ["ban_hoc"]
    if "--all" in args:
        variants = ["ban_hoc", "giao_vien", "hoai_niem"]
    elif "--variant" in args:
        i = args.index("--variant")
        variants = [args[i+1]] if i+1 < len(args) else variants
    for v in variants:
        objs, mats = build_variant(v)
        write_mtl_for(os.path.join(HERE, f"{v}.mtl"), mats)
        write_obj_for(os.path.join(HERE, f"{v}.obj"), f"{v}.mtl", objs)
        no, nv, nf = stats_for(objs)
        print(f"{v}: objects={no} vertices={nv} faces={nf}")
        print("wrote", os.path.join(HERE, f"{v}.obj"))
