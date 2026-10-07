#!/usr/bin/env python3
"""Verify NPC variants (Task1 stub -> full in Task4)."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_ban_hoc_bounds_and_colors():
    from generate_npcs import build_variant
    objs, mats = build_variant("ban_hoc")
    hmax = max(v[2] for o in objs for v in o["verts"])
    assert 1.85 <= hmax <= 2.05, f"height {hmax}"
    assert mats["shirt_white"] == (0.957, 0.961, 0.969), mats.get("shirt_white")
    assert mats["pants_blue"] == (0.227, 0.373, 0.659), mats.get("pants_blue")
    print("PASS test_ban_hoc_bounds_and_colors")

if __name__ == "__main__":
    test_ban_hoc_bounds_and_colors()
