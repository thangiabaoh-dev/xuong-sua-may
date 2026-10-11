extends "res://tests/test_case.gd"

const REQUIRED := [
	"Floor", "Board", "Podium", "TeacherDesk", "Ceiling",
	"DoorJambL", "DoorJambR", "DoorLintel",
	"WallBack", "WallLeft", "WallRight", "WallFrontL", "WallFrontR",
	"WindowL1", "WindowL2", "WindowR1", "WindowR2",
	"Fan1", "Fan2", "Light1", "Light2", "Light3", "Light4",
	"Sun", "WorldEnv",
]
const WALL_SHAPES := {
	"WallBack": Vector3(12, 3, 0.2),
	"WallLeft": Vector3(0.2, 3, 10),
	"WallRight": Vector3(0.2, 3, 10),
	"WallFrontL": Vector3(5, 3, 0.2),
	"WallFrontR": Vector3(5, 3, 0.2),
}

func run() -> void:
	var packed := load("res://scenes/classroom.tscn") as PackedScene
	check(packed != null, "classroom.tscn must load")
	if packed == null:
		return
	var root := packed.instantiate()
	check_eq(root.name, "Classroom", "root name")
	for n in REQUIRED:
		check(root.has_node(NodePath(n)), "has child " + n)
	_check_floor(root)
	_check_wall_collisions(root)
	_check_ceiling_and_fans(root)
	root.free()

func _check_floor(root: Node) -> void:
	var floor_node: Node = root.get_node_or_null(NodePath("Floor"))
	if floor_node == null:
		return
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

func _check_wall_collisions(root: Node) -> void:
	for w in WALL_SHAPES:
		var wall: Node = root.get_node_or_null(NodePath(w))
		var solid: Node = wall.find_child("StaticBody3D", true, false) if wall != null else null
		var cs: Node = solid.find_child("CollisionShape3D") if solid != null else null
		var box: BoxShape3D = null
		if cs is CollisionShape3D:
			box = (cs as CollisionShape3D).shape as BoxShape3D
		check(box != null, w + " has BoxShape3D collision")
		if box != null:
			var expected: Vector3 = WALL_SHAPES[w]
			check_near(box.size.x, expected.x, 0.01, w + " shape X")
			check_near(box.size.z, expected.z, 0.01, w + " shape Z")

func _check_ceiling_and_fans(root: Node) -> void:
	var ceil_node := root.get_node_or_null(NodePath("Ceiling")) as Node3D
	if ceil_node == null:
		return
	check(ceil_node.position.y >= 3.0, "ceiling at y>=3")
	for f in ["Fan1", "Fan2"]:
		var fan: Node3D = root.get_node_or_null(NodePath(f)) as Node3D
		if fan == null:
			continue
		var hub: Node = fan.find_child("MeshHub", false, false)
		if hub is Node3D:
			check((hub as Node3D).global_position.y < ceil_node.position.y, f + " hub hangs below ceiling")

func _world_origin(node: Node3D) -> Vector3:
	var v := Vector3.ZERO
	var n: Node = node
	while n is Node3D:
		v = (n as Node3D).transform * v
		n = n.get_parent()
	return v
