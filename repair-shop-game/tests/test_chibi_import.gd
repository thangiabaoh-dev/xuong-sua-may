extends "res://tests/test_case.gd"

func run() -> void:
	var mesh := load("res://assets/models/chibi.obj") as ArrayMesh
	check(mesh != null, "chibi.obj must load")
	if mesh == null:
		return
	check_eq(mesh.get_surface_count(), 103, "surface count")

	var colors := {}
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		if m is StandardMaterial3D:
			colors[m.resource_name] = (m as StandardMaterial3D).albedo_color

	check_eq(colors.size(), 23, "unique material count")
	check_near(colors["skin"].r, 0.965, 0.01, "skin.r")
	check_near(colors["skin"].g, 0.843, 0.01, "skin.g")
	check_near(colors["skin"].b, 0.737, 0.01, "skin.b")
	check_near(colors["hair"].r, 0.788, 0.01, "hair.r")
	check_near(colors["cap"].r, 0.102, 0.01, "cap.r")
	check_near(colors["red"].r, 0.878, 0.01, "red.r")

	var aabb := mesh.get_aabb()
	check_near(aabb.size.x, 1.12, 0.01, "aabb.x")
	check_near(aabb.size.y, 1.012, 0.01, "aabb.y")
	check_near(aabb.size.z, 2.012, 0.01, "aabb.z (Z-up height)")
	check_near(aabb.position.y, -0.512, 0.01, "aabb.position.y")
