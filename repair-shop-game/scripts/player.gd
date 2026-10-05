class_name PlayerMove
extends CharacterBody3D

const WALK_SPEED: float = 3.0
const GRAVITY: float = 20.0

static func move_direction(input: Vector2, cam_basis: Basis) -> Vector3:
	if input == Vector2.ZERO:
		return Vector3.ZERO
	var world := cam_basis * Vector3(input.x, 0.0, -input.y)
	world.y = 0.0
	if world.length_squared() == 0.0:
		return Vector3.ZERO
	return world.normalized()

func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera := get_viewport().get_camera_3d()
	var cam_basis: Basis = camera.global_transform.basis if camera != null else Basis.IDENTITY
	var direction := move_direction(input, cam_basis)
	velocity.x = direction.x * WALK_SPEED
	velocity.z = direction.z * WALK_SPEED
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
