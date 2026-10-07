extends "res://tests/test_case.gd"

const REQUIRED := ["Floor", "WallN", "WallS", "WallE", "WallW", "Desk", "Chair"]
const SOLIDS := ["Floor", "WallN", "WallS", "WallE", "WallW"]

func run() -> void:
	var packed := load("res://scenes/workshop.tscn") as PackedScene
	check(packed != null, "workshop.tscn must load")
	if packed == null:
		return
	var root := packed.instantiate()
	check_eq(root.name, "Workshop", "root name")
	check_eq(root.get_child_count(), 8, "exactly 8 direct children")

	for n in REQUIRED:
		check(root.has_node(NodePath(n)), "has child " + n)

	for n in SOLIDS:
		var node: Node = root.get_node_or_null(NodePath(n))
		var solid: Node = node.find_child("StaticBody3D", true, false) if node != null else null
		check(solid is StaticBody3D, n + " has StaticBody3D")
		if solid is StaticBody3D:
			var cs: Node = solid.find_child("CollisionShape3D", true, false)
			check(cs is CollisionShape3D, n + " has CollisionShape3D")

	var floor_node: Node = root.get_node_or_null(NodePath("Floor"))
	if floor_node != null:
		var solid: Node = floor_node.find_child("StaticBody3D", true, false)
		var cs: Node = solid.find_child("CollisionShape3D") if solid != null else null
		var box: BoxShape3D = null
		if cs is CollisionShape3D:
			box = (cs as CollisionShape3D).shape as BoxShape3D
		check(box != null, "floor shape is BoxShape3D")
		if box != null:
			check_near(box.size.x, 8.0, 0.01, "floor width X")
			check_near(box.size.z, 8.0, 0.01, "floor depth Z")
			var top_y := _world_origin(cs as CollisionShape3D).y + box.size.y / 2.0
			check_near(top_y, 0.0, 0.01, "floor top at y=0")

	check(root.has_node("RepairPanel"), "has RepairPanel")
	check(root.get_node("RepairPanel").get_script() == load("res://scripts/ui/repair_panel.gd"), "RepairPanel script")

	root.free()

func _world_origin(node: Node3D) -> Vector3:
	var v := Vector3.ZERO
	var n: Node = node
	while n is Node3D:
		v = (n as Node3D).transform * v
		n = n.get_parent()
	return v
