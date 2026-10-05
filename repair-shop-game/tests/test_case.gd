extends RefCounted

var failures: PackedStringArray = PackedStringArray()

func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)

func check_eq(actual, expected, msg: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [msg, expected, actual])

func check_near(actual: float, expected: float, tol: float, msg: String) -> void:
	if absf(actual - expected) > tol:
		failures.append("%s: expected %s ± %s, got %s" % [msg, expected, tol, actual])
