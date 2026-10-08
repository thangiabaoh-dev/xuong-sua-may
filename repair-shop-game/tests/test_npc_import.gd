extends "res://tests/test_case.gd"

const VARIANTS: Dictionary = {
	"ban_hoc": {"shirt_white": Color(0.957, 0.961, 0.969),
			"pants_blue": Color(0.227, 0.373, 0.659),
			"backpack_green": Color(0.255, 0.588, 0.353)},
	"giao_vien": {"shirt_cream": Color(0.922, 0.882, 0.784),
			"pants_brown": Color(0.431, 0.333, 0.235),
			"glasses_black": Color(0.055, 0.055, 0.062),
			"briefcase_brown": Color(0.353, 0.255, 0.157)},
	"hoai_niem": {"jacket_brown": Color(0.588, 0.431, 0.314),
			"pants_gray": Color(0.510, 0.510, 0.529),
			"laptop_gray": Color(0.549, 0.549, 0.569),
			"hair_long": Color(0.314, 0.235, 0.176)},
}

func run() -> void:
	for name in VARIANTS:
		_check_variant(name)

func _check_variant(name: String) -> void:
	var mesh := load("res://assets/models/%s.obj" % name) as ArrayMesh
	check(mesh != null, name + ".obj must load")
	if mesh == null:
		return
	check(mesh.get_surface_count() > 10, name + ": surfaces > 10")

	var colors := {}
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		if m is StandardMaterial3D:
			colors[m.resource_name] = (m as StandardMaterial3D).albedo_color
	for mat_name in VARIANTS[name]:
		check(colors.has(mat_name), "%s: material %s present" % [name, mat_name])
		if colors.has(mat_name):
			var c: Color = colors[mat_name]
			var e: Color = VARIANTS[name][mat_name]
			check_near(c.r, e.r, 0.02, name + "/" + mat_name + ".r")
			check_near(c.g, e.g, 0.02, name + "/" + mat_name + ".g")
			check_near(c.b, e.b, 0.02, name + "/" + mat_name + ".b")

	# Z-up source: feet at z=0, height in spec range
	var aabb := mesh.get_aabb()
	check_near(aabb.position.z, 0.0, 0.02, name + ": feet at z=0 (Z-up)")
	check(aabb.size.z >= 1.85 and aabb.size.z <= 2.05,
		"%s: Z height %s in [1.85,2.05]" % [name, aabb.size.z])

	# Drop-in like player.tscn: rotation_degrees (-90, 180, 0)
	var basis := Basis.from_euler(Vector3(deg_to_rad(-90), deg_to_rad(180), 0))
	var g := AABB(basis * aabb.get_endpoint(0), Vector3.ZERO)
	for i in range(1, 8):
		g = g.expand(basis * aabb.get_endpoint(i))
	check_near(g.position.y, 0.0, 0.02, name + ": feet on floor after rotation")
	check(g.size.y >= 1.85 and g.size.y <= 2.05,
		"%s: Godot height %s in [1.85,2.05]" % [name, g.size.y])
	check(g.position.z < -0.3,
		"%s: face toward -Z, min.z=%s" % [name, g.position.z])
