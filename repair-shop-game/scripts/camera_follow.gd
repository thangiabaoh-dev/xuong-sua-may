extends Node3D

const FOLLOW_HEIGHT_OFFSET := 0.0

@export var target_path: NodePath = NodePath("../Player")
@export var follow_speed: float = 8.0

# Hàm thuần — test headless không cần frame (mẫu move_direction của player.gd).
# Weight clamp ≤ 1: tránh overshoot/oscillation khi frame chậm (delta lớn).
static func follow_step(from: Vector3, to: Vector3, speed: float, delta: float) -> Vector3:
	var weight := minf(speed * delta, 1.0)
	return Vector3(lerpf(from.x, to.x, weight), from.y, lerpf(from.z, to.z, weight))

# Ưu tiên nhóm "player" (Ruling R1) — chống mất target khi đổi hierarchy; fallback target_path.
func _resolve_target() -> Node3D:
	var tree := get_tree()
	if tree != null:
		var by_group := tree.get_first_node_in_group("player")
		if by_group is Node3D:
			return by_group
	return get_node_or_null(target_path) as Node3D

func _process(delta: float) -> void:
	var target := _resolve_target()
	if target == null:
		return
	global_position = follow_step(global_position, target.global_position, follow_speed, delta)
