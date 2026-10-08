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


def test_giao_vien_glasses_and_case():
    from generate_npcs import build_variant
    objs, mats = build_variant("giao_vien")
    assert mats["glasses_black"] == (0.055, 0.055, 0.062), mats.get("glasses_black")
    assert any(o["name"] == "glasses" for o in objs), "missing glasses"
    assert any(o["name"] == "briefcase" for o in objs), "missing briefcase"
    print("PASS test_giao_vien_glasses_and_case")

def test_hoai_niem_laptop():
    from generate_npcs import build_variant
    objs, mats = build_variant("hoai_niem")
    assert any(o["name"] == "old_laptop" for o in objs), "missing old_laptop"
    assert mats["jacket_brown"] == (0.588, 0.431, 0.314), mats.get("jacket_brown")
    print("PASS test_hoai_niem_laptop")

if __name__ == "__main__":
    test_ban_hoc_bounds_and_colors()
    test_giao_vien_glasses_and_case()
    test_hoai_niem_laptop()
