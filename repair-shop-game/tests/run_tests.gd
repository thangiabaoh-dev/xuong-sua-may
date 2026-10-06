extends SceneTree

const TEST_SCRIPTS: PackedStringArray = [
	"res://tests/test_chibi_import.gd",
	"res://tests/test_player_scene.gd",
	"res://tests/test_player_move.gd",
	"res://tests/test_workshop.gd",
]

func _init() -> void:
	var total := 0
	for path in TEST_SCRIPTS:
		total += _run_test(path)
	print("TOTAL_FAILURES=", total)
	quit(0 if total == 0 else 1)

func _run_test(path: String) -> int:
	var script = load(path)
	if script == null:
		print("FAIL ", path, ": cannot load")
		return 1
	if not (script is Script):
		print("FAIL ", path, ": not a GDScript resource")
		return 1
	if not (script as Script).can_instantiate():
		print("FAIL ", path, ": failed to compile (parse error)")
		return 1
	var case = script.new()
	if case == null:
		print("FAIL ", path, ": could not instantiate test case")
		return 1
	case.run()
	if case.failures.is_empty():
		print("PASS ", path)
		return 0
	for f in case.failures:
		print("FAIL ", path, ": ", f)
	return case.failures.size()
