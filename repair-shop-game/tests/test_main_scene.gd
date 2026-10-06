extends "res://tests/test_case.gd"

func run() -> void:
	# Ruling R11: InputMap coverage cho các action mà player.gd đọc trong _physics_process
	check(InputMap.has_action("move_left"), "InputMap has move_left")
	check(InputMap.has_action("move_right"), "InputMap has move_right")
	check(InputMap.has_action("move_forward"), "InputMap has move_forward")
	check(InputMap.has_action("move_back"), "InputMap has move_back")

	var packed := load("res://scenes/main.tscn") as PackedScene
	check(packed != null, "main.tscn must load")
	if packed == null:
		return
	var root := packed.instantiate()
	check_eq(root.get_child_count(), 3, "Main has 3 direct children")
	check(root.has_node("Workshop"), "has Workshop")
	check(root.has_node("Player"), "has Player")
	check(root.has_node("CameraRig"), "has CameraRig")

	var player := root.get_node_or_null("Player")
	if player != null:
		var spawn := _world_origin(player)
		check_near(spawn.x, 0.0, 0.01, "player spawn X")
		check_near(spawn.z, 0.0, 0.01, "player spawn Z")
		check_near(spawn.y, 0.1, 0.01, "player spawn Y above floor")
		check(player.is_in_group("player"), "player in group 'player'")
		# spawn nằm trong phòng 8x8
		check(absf(spawn.x) < 4.0, "spawn inside room X")
		check(absf(spawn.z) < 4.0, "spawn inside room Z")

	var rig := root.get_node_or_null("CameraRig")
	if rig != null:
		var arm := rig.get_node_or_null("SpringArm3D")
		check(arm is SpringArm3D, "CameraRig has SpringArm3D")
		if arm is SpringArm3D:
			check_near((arm as SpringArm3D).spring_length, 5.0, 0.001, "spring arm length")
			check(arm.get_node_or_null("Camera3D") is Camera3D, "SpringArm3D has Camera3D")

		# Review Important #1: mất script = mất follow im lặng, suite vẫn xanh
		check(rig.get_script() == load("res://scripts/camera_follow.gd"), "CameraRig has camera_follow.gd")

		# Pure-logic follow (mẫu move_direction): clamp weight ≤ 1, Y không đổi — test headless không cần frame.
		# Bắt buộc qua get_script_method_list: has_method trên GDScript resource trả false cho method của script.
		var cam_script := load("res://scripts/camera_follow.gd") as GDScript
		var method_names := PackedStringArray()
		if cam_script != null:
			for m in cam_script.get_script_method_list():
				method_names.append(String(m.name))
		check("follow_step" in method_names, "camera_follow has follow_step")
		if "follow_step" in method_names:
			var out: Vector3 = cam_script.follow_step(Vector3(10, 0, 10), Vector3(0, 0.1, 0), 8.0, 1.0)
			check_near(out.x, 0.0, 0.01, "follow_step clamps to target X")
			check_near(out.z, 0.0, 0.01, "follow_step clamps to target Z")
			check_near(out.y, 0.0, 0.01, "follow_step never changes Y")
			var partial: Vector3 = cam_script.follow_step(Vector3(10, 0, 10), Vector3(0, 0.1, 0), 8.0, 0.05)
			check(partial.x > 0.0 and partial.x < 10.0, "follow_step partial step interpolates")

		# Ruling R15 (b): target mà camera_follow.gd sẽ resolve phải tồn tại —
		# cùng thứ tự với script: group "player" trước, fallback sibling "../Player".
		check(_resolve_camera_target(root, rig) != null, "camera follow target resolves")
		# Ruling R15: production script phải thật sự đọc group "player" (Ruling R1 sống).
		# Lookup theo tree không chạy được trong harness (Engine.get_main_loop() == null trong _init),
		# nên check tại nguồn script — đây là chỗ duy nhất guard được group wiring.
		check(_camera_script_reads_player_group(),
			"camera_follow.gd resolves target via group 'player'")

	root.free()

func _resolve_camera_target(main: Node, rig: Node) -> Node3D:
	var group_target := _first_in_group(main, "player")
	if group_target != null:
		return group_target
	return rig.get_node_or_null("../Player") as Node3D

func _first_in_group(node: Node, group: String) -> Node3D:
	if node.is_in_group(group):
		return node as Node3D
	for child in node.get_children():
		var found := _first_in_group(child, group)
		if found != null:
			return found
	return null

func _camera_script_reads_player_group() -> bool:
	var file := FileAccess.open("res://scripts/camera_follow.gd", FileAccess.READ)
	if file == null:
		return false
	return file.get_as_text().contains("get_first_node_in_group(\"player\")")

func _world_origin(node: Node3D) -> Vector3:
	var v := Vector3.ZERO
	var n: Node = node
	while n is Node3D:
		v = (n as Node3D).transform * v
		n = n.get_parent()
	return v
