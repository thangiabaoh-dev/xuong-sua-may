extends SceneTree

const TEST_SCRIPTS: PackedStringArray = [
	"res://tests/test_chibi_import.gd",
	"res://tests/test_player_scene.gd",
]

func _init() -> void:
	var total := 0
	for path in TEST_SCRIPTS:
		var script := load(path)
		if script == null:
			print("FAIL ", path, " (cannot load)")
			total += 1
			continue
		var case = script.new()
		case.run()
		if case.failures.is_empty():
			print("PASS ", path)
		else:
			for f in case.failures:
				print("FAIL ", path, ": ", f)
			total += case.failures.size()
	print("TOTAL_FAILURES=", total)
	quit(0 if total == 0 else 1)
