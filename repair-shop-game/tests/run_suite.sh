#!/bin/bash
# Gate gộp cho test suite: TOTAL_FAILURES=0, exit 0, VÀ không có SCRIPT ERROR.
# Lý do: run_tests.gd không bắt runtime error trong run() — test crash nhưng
# failures rỗng vẫn được báo PASS. Gate này chặn kiểu fail im lặng đó.
set -uo pipefail
cd "$(dirname "$0")/../.."

godot --headless --path repair-shop-game --import >/dev/null 2>&1
out=$(godot --headless --path repair-shop-game -s res://tests/run_tests.gd 2>&1)
rc=$?
echo "$out"

if echo "$out" | grep -q "SCRIPT ERROR"; then
	echo "GATE FAIL: SCRIPT ERROR detected (harness would report these as PASS)" >&2
	exit 1
fi
if [ "$rc" -ne 0 ] || ! echo "$out" | grep -q "TOTAL_FAILURES=0"; then
	echo "GATE FAIL: suite failures or nonzero exit (rc=$rc)" >&2
	exit 1
fi
echo "GATE PASS"
