extends "res://tests/test_case.gd"

func run() -> void:
	var packed := load("res://scenes/player.tscn") as PackedScene
	check(packed != null, "player.tscn must load")
	if packed == null:
		return
	var p = packed.instantiate()
	check(p is CharacterBody3D, "root is CharacterBody3D")
	check_eq(p.name, "Player", "root name")

	var shape_node := p.get_node_or_null("CollisionShape3D")
	check(shape_node != null, "has CollisionShape3D")
	if shape_node is CollisionShape3D:
		var cap := (shape_node as CollisionShape3D).shape as CapsuleShape3D
		check(cap != null, "collision shape is CapsuleShape3D")
		if cap != null:
			check_near(cap.radius, 0.35, 0.001, "capsule radius")
			check_near(cap.height, 2.0, 0.001, "capsule height")
		check_near(shape_node.position.y, 1.0, 0.001, "capsule y")

	var body := p.get_node_or_null("Body")
	check(body is MeshInstance3D, "has MeshInstance3D Body")
	if body is MeshInstance3D:
		var m := (body as MeshInstance3D).mesh as ArrayMesh
		check(m != null, "Body has mesh")
		if m != null:
			var corners := _transformed_corners(body as MeshInstance3D, m.get_aabb())
			var ext := _extent(corners)
			check_near(ext.y, 2.012, 0.02, "upright height along Y")
			check_near(ext.x, 1.12, 0.02, "width along X")
			check_near(_min_component(corners, 1), 0.0, 0.02, "feet on y=0")

	p.free()

func _transformed_corners(node: Node3D, aabb: AABB) -> Array:
	var out: Array = []
	for i in 8:
		var c := Vector3(
			aabb.position.x + (aabb.size.x if (i & 1) == 1 else 0.0),
			aabb.position.y + (aabb.size.y if (i & 2) == 2 else 0.0),
			aabb.position.z + (aabb.size.z if (i & 4) == 4 else 0.0))
		out.append(node.transform * c)
	return out

func _extent(corners: Array) -> Vector3:
	var mn := Vector3(INF, INF, INF)
	var mx := Vector3(-INF, -INF, -INF)
	for c in corners:
		mn = Vector3(minf(mn.x, c.x), minf(mn.y, c.y), minf(mn.z, c.z))
		mx = Vector3(maxf(mx.x, c.x), maxf(mx.y, c.y), maxf(mx.z, c.z))
	return mx - mn

func _min_component(corners: Array, axis: int) -> float:
	var v := INF
	for c in corners:
		v = minf(v, [c.x, c.y, c.z][axis])
	return v
