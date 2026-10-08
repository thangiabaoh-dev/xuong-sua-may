#!/usr/bin/env python3
"""Render front/back preview PNG for each NPC variant (reuses render_preview)."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import render_preview as R

W, H = 640, 880
VARIANTS = ["ban_hoc", "giao_vien", "hoai_niem"]


def render_variant(name: str) -> None:
    path = os.path.join(HERE, f"{name}.obj")
    verts, _, faces = R.load2(path)
    panels = [R.render(verts, faces, W, H, v) for v in ("front", "back")]
    full = []
    for y in range(H):
        full.extend(panels[0][y * W:(y + 1) * W])
        full.extend(panels[1][y * W:(y + 1) * W])
    out = os.path.join(HERE, f"preview_{name}.png")
    R.write_png(out, full, W * 2, H)
    print("wrote", out)


if __name__ == "__main__":
    names = sys.argv[1].split(",") if len(sys.argv) > 1 else VARIANTS
    for n in names:
        render_variant(n)
