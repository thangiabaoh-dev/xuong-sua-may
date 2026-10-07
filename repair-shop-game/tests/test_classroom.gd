extends "res://tests/test_case.gd"
const REQUIRED := ["Floor", "Board", "Podium", "Desk1", "Desk2", "Desk3", "Desk4"]
func run() -> void:
	var packed := load("res://scenes/classroom.tscn") as PackedScene
	check(packed != null, "classroom.tscn must load")
	if packed == null:
		return
	var root := packed.instantiate()
	check_eq(root.name, "Classroom", "root name")
	for n in REQUIRED:
		check(root.has_node(NodePath(n)), "has child " + n)
	# + floor shape (12x10) + top y=0 checks giong test_schoolyard.gd
	var floor_node: Node = root.get_node_or_null(NodePath("Floor"))
	if floor_node != null:
		var solid: Node = floor_node.find_child("StaticBody3D", true, false)
		var cs: Node = solid.find_child("CollisionShape3D") if solid != null else null
		var box: BoxShape3D = null
		if cs is CollisionShape3D:
			box = (cs as CollisionShape3D).shape as BoxShape3D
		check(box != null, "floor shape is BoxShape3D")
		if box != null:
			check_near(box.size.x, 12.0, 0.01, "floor width X")
			check_near(box.size.z, 10.0, 0.01, "floor depth Z")
			var top_y := _world_origin(cs as CollisionShape3D).y + box.size.y / 2.0
			check_near(top_y, 0.0, 0.01, "floor top at y=0")
	root.free()

func _world_origin(node: Node3D) -> Vector3:
	var v := Vector3.ZERO
	var n: Node = node
	while n is Node3D:
		v = (n as Node3D).transform * v
		n = n.get_parent()
	return v
