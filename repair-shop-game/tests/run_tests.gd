extends SceneTree

const TEST_SCRIPTS: PackedStringArray = [
	"res://tests/test_chibi_import.gd",
	"res://tests/test_npc_import.gd",
	"res://tests/test_player_scene.gd",
	"res://tests/test_player_move.gd",
	"res://tests/test_workshop.gd",
	"res://tests/test_gate.gd",
	"res://tests/test_classroom.gd",
	"res://tests/test_library.gd",
	"res://tests/test_cafe.gd",
	"res://tests/test_street.gd",
	"res://tests/test_schoolyard.gd",
	"res://tests/test_scene_manager.gd",
	"res://tests/test_main_scene.gd",
	"res://tests/test_machine_catalog.gd",
	"res://tests/test_machine_generator.gd",
	"res://tests/test_game_state.gd",
	"res://tests/test_fault_catalog.gd",
	"res://tests/test_order_factory.gd",
	"res://tests/test_repair_session.gd",
	"res://tests/test_repair_panel.gd",
	"res://tests/test_part_catalog.gd",
	"res://tests/test_customer_catalog.gd",
	"res://tests/test_minigame_controller.gd",
	"res://tests/test_schedule_logic.gd",
	"res://tests/test_game_state_time.gd",
	"res://tests/test_map_gating.gd",
	"res://tests/test_clock_timer.gd",
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
