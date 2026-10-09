#!/usr/bin/env python3
"""Verify 3 NPC variants: geometry bounds, orientation, MTL integrity, rendered colours."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import render_preview as R
from generate_npcs import build_variant

W, H = 640, 880
SCALE = min(W, H) / 2.15
VARIANTS = ["ban_hoc", "giao_vien", "hoai_niem"]


def load_obj_mats(path):
    used, defined = set(), set()
    cur = None
    for line in open(path):
        t = line.split()
        if not t:
            continue
        if t[0] == "usemtl":
            cur = t[1]
            used.add(cur)
        elif t[0] == "o" and cur:
            used.add(cur)
    mtl = os.path.join(os.path.dirname(path),
                       open(path).read().split("mtllib")[1].split()[0])
    for line in open(mtl):
        if line.startswith("newmtl"):
            defined.add(line.split()[1])
    return used, defined


def px_at(wx, wz, panel, cx, cz):
    sx = 1.0 if panel == "front" else -1.0
    return (int(round((wx - cx) * sx * SCALE + W / 2)),
            int(round(H / 2 - (wz - cz) * SCALE)))


def chroma(c):
    m = max(c)
    if m < 40:
        return None
    return tuple(v / m for v in c)


def match(got, exp):
    if max(exp) < 60:
        return all(abs(a - b) <= 30 for a, b in zip(got, exp))
    g, e = chroma(got), chroma(exp)
    if g is None:
        return False
    return all(abs(a - b) <= 0.07 for a, b in zip(g, e))


def variant_bounds(name):
    objs, mats = build_variant(name)
    vs = [v for o in objs for v in o["verts"]]
    nv = sum(len(o["verts"]) for o in objs)
    nf = sum(len(o["faces"]) for o in objs)
    return objs, mats, vs, nv, nf


def obj_part_ymean(path, part):
    """Mean y of vertices belonging to object <part> (face-only parts: iris/pupil)."""
    ys, cur = [], None
    for line in open(path):
        t = line.split()
        if not t:
            continue
        if t[0] == "o":
            cur = t[1]
        elif t[0] == "v" and cur == part:
            ys.append(float(t[2]))
    return sum(ys) / len(ys) if ys else None


def test_face_orientation_minus_y():
    for v in VARIANTS:
        f = os.path.join(HERE, f"{v}.obj")
        iris_y = obj_part_ymean(f, "iris")
        assert iris_y is not None, f"{v}: no iris object"
        assert iris_y < -0.3, f"{v}: iris at y={iris_y}, face not -Y"
        # hair must sit at +Y (back) so the model is not fully mirrored
        _, _, vs, _, _ = variant_bounds(v)
        ymax_hair = max(p[1] for p in vs if p[2] > 1.5 and abs(p[0]) < 0.05)
        assert ymax_hair > 0.2, f"{v}: hair not at +Y back, ymax={ymax_hair}"
    print("PASS test_face_orientation_minus_y")


def test_budget_and_height():
    for v in VARIANTS:
        _, _, vs, nv, nf = variant_bounds(v)
        assert nv < 10000 and nf < 10000, f"{v}: nv={nv} nf={nf}"
        zmax = max(p[2] for p in vs)
        assert 1.85 <= zmax <= 2.05, f"{v}: height {zmax}"
        assert abs(min(p[2] for p in vs)) <= 0.01, f"{v}: feet off ground"
        assert max(abs(p[0]) for p in vs) < 0.8 and max(abs(p[1]) for p in vs) < 0.8, v
    print("PASS test_budget_and_height")


def test_mtl_names_match():
    for v in VARIANTS:
        used, defined = load_obj_mats(os.path.join(HERE, f"{v}.obj"))
        missing = used - defined
        assert not missing, f"{v}: materials missing from MTL: {missing}"
    print("PASS test_mtl_names_match")


# variant -> (name, wx, wz, expected sRGB, panel)
COLOR_CHECKS = [
    ("ban_hoc", "shirt white",     0.000, 0.95, (244, 245, 247), "front"),
    ("ban_hoc", "pants blue",      0.150, 0.40, (58, 95, 168),   "front"),
    ("ban_hoc", "backpack green",  0.000, 0.90, (65, 150, 90),   "back"),
    ("giao_vien", "shirt cream",   0.000, 0.95, (235, 225, 200), "front"),
    ("giao_vien", "pants brown",   0.150, 0.40, (110, 85, 60),   "front"),
    ("giao_vien", "glasses black", 0.305, 1.445, (14, 14, 16),   "front"),
    ("giao_vien", "briefcase",    -0.480, 0.55, (90, 65, 40),    "back"),
    ("hoai_niem", "jacket arm",    0.330, 0.90, (150, 110, 80),  "front"),
    ("hoai_niem", "pants gray",    0.150, 0.40, (130, 130, 135), "front"),
    ("hoai_niem", "old laptop",    0.000, 0.82, (140, 140, 145), "front"),
    ("hoai_niem", "hair long",     0.000, 1.70, (80, 60, 45),    "back"),
]


def test_rendered_colours():
    failed = []
    for v in VARIANTS:
        verts, _, faces = R.load2(os.path.join(HERE, f"{v}.obj"))
        xs = [q[0] for q in verts]
        zs = [q[2] for q in verts]
        cx = (min(xs) + max(xs)) / 2
        cz = (min(zs) + max(zs)) / 2
        panels = {p: R.render(verts, faces, W, H, p) for p in ("front", "back")}
        for vv, nm, wx, wz, exp, panel in COLOR_CHECKS:
            if vv != v:
                continue
            x, y = px_at(wx, wz, panel, cx, cz)
            got = tuple(int(q * 255) for q in panels[panel][y * W + x])
            if not match(got, exp):
                failed.append(f"{v}/{nm} {panel}: got={got} exp={exp}")
    assert not failed, "\n".join(failed)
    print(f"PASS test_rendered_colours ({len(COLOR_CHECKS)} samples)")


def test_brow_present():
    for v in ("giao_vien", "hoai_niem"):
        found = False
        for line in open(os.path.join(HERE, f"{v}.obj")):
            if line.split() == ["o", "brow"]:
                found = True
                break
        assert found, f"{v}: no brow object (ban_hoc has it)"
    print("PASS test_brow_present")


def test_mirror_cap_parts():
    """shell_patch cap parts must mirror exactly across x=0 (endpoints are
    exact mirror pairs, e.g. b = pi - a, so grid samples pair i+j = n)."""
    want = {"cap_brim", "cap_brim_stripe", "cap_band", "cap_gap"}
    verts, cur = [], None
    parts = {}
    for line in open(os.path.join(HERE, "chibi.obj")):
        t = line.split()
        if not t:
            continue
        if t[0] == "o":
            cur = t[1]
        elif t[0] == "v" and cur in want:
            parts.setdefault(cur, []).append(
                (float(t[1]), float(t[2]), float(t[3])))
    missing = want - set(parts)
    assert not missing, f"cap parts missing: {missing}"
    bad = {}
    for name, vs in parts.items():
        keys = {(round(x, 4), round(y, 4), round(z, 4)) for x, y, z in vs}
        for x, y, z in vs:
            if (-round(x, 4), round(y, 4), round(z, 4)) not in keys:
                bad.setdefault(name, []).append((x, y, z))
    assert not bad, "asymmetric cap verts: " + ", ".join(
        f"{n}({len(p)} e.g. {p[0]})" for n, p in bad.items())
    print("PASS test_mirror_cap_parts")


def test_source_assets_in_sync():
    """chibi-model source copies must be byte-identical to what Godot imports."""
    import hashlib

    def md5(f):
        return hashlib.md5(open(f, "rb").read()).hexdigest()

    assets = os.path.join(HERE, "..", "repair-shop-game", "assets", "models")
    for v in VARIANTS:
        for ext in (".obj", ".mtl"):
            src = os.path.join(HERE, v + ext)
            dst = os.path.join(assets, v + ext)
            assert os.path.exists(dst), f"{v}{ext}: missing in assets/models"
            assert md5(src) == md5(dst), f"{v}{ext}: chibi-model and assets/models differ"
    print("PASS test_source_assets_in_sync")


def main():
    tests = [test_face_orientation_minus_y, test_budget_and_height,
             test_mtl_names_match, test_rendered_colours, test_brow_present,
             test_mirror_cap_parts, test_source_assets_in_sync]
    for t in tests:
        try:
            t()
        except AssertionError as e:
            print(f"FAIL {t.__name__}: {e}")
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
