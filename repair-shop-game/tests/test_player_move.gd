extends "res://tests/test_case.gd"

func run() -> void:
	var id := Basis.IDENTITY

	var fwd := PlayerMove.move_direction(Vector2(0, 1), id)
	check_near(fwd.x, 0.0, 0.0001, "W.x")
	check_near(fwd.y, 0.0, 0.0001, "W.y")
	check_near(fwd.z, -1.0, 0.0001, "W faces -Z")

	var strafe := PlayerMove.move_direction(Vector2(1, 0), id)
	check_near(strafe.x, 1.0, 0.0001, "D.x")
	check_near(strafe.y, 0.0, 0.0001, "D.y")
	check_near(strafe.z, 0.0, 0.0001, "D.z")

	var back := PlayerMove.move_direction(Vector2(0, -1), id)
	check_near(back.z, 1.0, 0.0001, "S faces +Z")
	check_near(back.y, 0.0, 0.0001, "S.y")

	check_eq(PlayerMove.move_direction(Vector2.ZERO, id), Vector3.ZERO, "idle is ZERO")

	var diag := PlayerMove.move_direction(Vector2(1, 1), id)
	check_near(diag.x, 0.7071, 0.001, "diagonal normalized x")
	check_near(diag.y, 0.0, 0.0001, "diagonal has zero Y")
	check_near(diag.z, -0.7071, 0.001, "diagonal normalized z")

	# camera pitch 30 độ xuống: hướng đi vẫn phải nằm trên mặt phẳng XZ
	var pitched := Basis.IDENTITY.rotated(Vector3.RIGHT, deg_to_rad(30.0))
	var moved := PlayerMove.move_direction(Vector2(0, 1), pitched)
	check_near(moved.y, 0.0, 0.0001, "pitched basis keeps Y at 0")
	check_near(moved.length(), 1.0, 0.001, "pitched basis result is unit length")
	check(moved.x * moved.x + moved.z * moved.z > 0.9, "pitched basis still moves")

	var script := load("res://scripts/player.gd")
	check(script != null, "player.gd loads")
	if script != null:
		check_near(script.WALK_SPEED, 3.0, 0.001, "WALK_SPEED is 3.0")
