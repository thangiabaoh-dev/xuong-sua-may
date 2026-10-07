extends "res://tests/test_case.gd"
const REQUIRED := ["Road", "WalkL", "WalkR", "House1", "House2", "Lamp1", "Lamp2"]
func run() -> void:
	var packed := load("res://scenes/street.tscn") as PackedScene
	check(packed != null, "street.tscn must load")
	if packed == null:
		return
	var root := packed.instantiate()
	check_eq(root.name, "Street", "root name")
	for n in REQUIRED:
		check(root.has_node(NodePath(n)), "has child " + n)
	# + road shape (20x6) + top y=0 checks giong test_schoolyard.gd
	var road_node: Node = root.get_node_or_null(NodePath("Road"))
	if road_node != null:
		var solid: Node = road_node.find_child("StaticBody3D", true, false)
		var cs: Node = solid.find_child("CollisionShape3D") if solid != null else null
		var box: BoxShape3D = null
		if cs is CollisionShape3D:
			box = (cs as CollisionShape3D).shape as BoxShape3D
		check(box != null, "road shape is BoxShape3D")
		if box != null:
			check_near(box.size.x, 20.0, 0.01, "road width X")
			check_near(box.size.z, 6.0, 0.01, "road depth Z")
			var top_y := _world_origin(cs as CollisionShape3D).y + box.size.y / 2.0
			check_near(top_y, 0.0, 0.01, "road top at y=0")
	root.free()

func _world_origin(node: Node3D) -> Vector3:
	var v := Vector3.ZERO
	var n: Node = node
	while n is Node3D:
		v = (n as Node3D).transform * v
		n = n.get_parent()
	return v
