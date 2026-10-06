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

	root.free()

func _world_origin(node: Node3D) -> Vector3:
	var v := Vector3.ZERO
	var n: Node = node
	while n is Node3D:
		v = (n as Node3D).transform * v
		n = n.get_parent()
	return v
