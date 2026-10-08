extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 1:
		print("usage: -s res://tests/run_one.gd -- <test_path>")
		quit(1)
		return
	var script = load(args[0])
	if script == null or not (script is Script) or not (script as Script).can_instantiate():
		print("FAIL load: ", args[0])
		quit(1)
		return
	var case = script.new()
	case.run()
	print("FAILURES=", case.failures.size())
	for x in case.failures:
		print("FAIL: ", x)
	quit(0 if case.failures.is_empty() else 1)
