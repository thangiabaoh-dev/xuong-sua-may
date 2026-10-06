extends Node3D

const FOLLOW_HEIGHT_OFFSET := 0.0

@export var target_path: NodePath = NodePath("../Player")
@export var follow_speed: float = 8.0

func _process(delta: float) -> void:
	var target := get_node_or_null(target_path) as Node3D
	if target == null:
		return
	global_position.x = lerpf(global_position.x, target.global_position.x, follow_speed * delta)
	global_position.z = lerpf(global_position.z, target.global_position.z, follow_speed * delta)
