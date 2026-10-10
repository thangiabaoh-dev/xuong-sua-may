extends CharacterBody3D
class_name ChibiCharacterController

@export_group("Movement")
@export var walk_speed: float = 3.0
@export var run_speed: float = 6.0
@export var acceleration: float = 20.0
@export var air_acceleration: float = 10.0
@export var gravity: float = 20.0
@export var jump_velocity: float = 8.0
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1

@export_group("Animation")
@export var animation_controller: AnimationController

@export_group("Visual")
@export var mesh_instance: MeshInstance3D
@export var outline_mesh: MeshInstance3D

@export_group("Camera")
@export var camera_pivot: Node3D
@export var camera_distance: float = 4.0
@export var camera_height: float = 2.0
@export var camera_smooth_speed: float = 10.0

var _input_dir: Vector2 = Vector2.ZERO
var _target_velocity: Vector3 = Vector3.ZERO
var _is_running: bool = false
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = false
var _current_state: String = "idle"

func _ready() -> void:
	_was_on_floor = is_on_floor()
	
	if not animation_controller:
		animation_controller = get_node_or_null("AnimationController")
	
	if not mesh_instance:
		mesh_instance = get_node_or_null("Body")
	
	setup_outline()

func setup_outline() -> void:
	if not outline_mesh and mesh_instance:
		outline_mesh = mesh_instance.duplicate() as MeshInstance3D
		outline_mesh.name = "Outline"
		outline_mesh.material_override = ShaderMaterial.new()
		outline_mesh.material_override.shader = load("res://assets/shaders/chibi_outline.gdshader")
		mesh_instance.add_child(outline_mesh)
		outline_mesh.set_owner(get_tree().edited_scene_root)

func _physics_process(delta: float) -> void:
	handle_input(delta)
	handle_movement(delta)
	handle_animation(delta)
	handle_camera(delta)
	_was_on_floor = is_on_floor()

func handle_input(delta: float) -> void:
	_input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_is_running = Input.is_action_pressed("run")
	
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer -= delta
	
	_jump_buffer_timer -= delta

func handle_movement(delta: float) -> void:
	var camera = get_viewport().get_camera_3d()
	var cam_basis: Basis = camera.global_transform.basis if camera else Basis.IDENTITY
	
	var input_dir_3d = Vector3(_input_dir.x, 0.0, -_input_dir.y)
	input_dir_3d = (cam_basis * input_dir_3d).normalized()
	input_dir_3d.y = 0.0
	
	var target_speed = run_speed if _is_running else walk_speed
	_target_velocity = input_dir_3d * target_speed
	
	var current_velocity = velocity
	current_velocity.x = _target_velocity.x
	current_velocity.z = _target_velocity.z
	
	var accel = acceleration if is_on_floor() else air_acceleration
	velocity.x = lerp(velocity.x, current_velocity.x, accel * delta)
	velocity.z = lerp(velocity.z, current_velocity.z, accel * delta)
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
	
	move_and_slide()

func handle_animation(delta: float) -> void:
	if not animation_controller:
		return
	
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	var new_state = "idle"
	
	if not is_on_floor():
		if velocity.y > 0.1:
			new_state = "jump"
		else:
			new_state = "fall"
	elif horizontal_speed > 0.5:
		new_state = "run" if _is_running else "walk"
	else:
		new_state = "idle"
	
	if new_state != _current_state:
		_current_state = new_state
		animation_controller.set_state(new_state)
	
	if horizontal_speed > 0.01 and is_on_floor():
		var anim_speed = horizontal_speed / (run_speed if _is_running else walk_speed)
		animation_controller.play(_animation_map.get(new_state, new_state), -1.0, max(0.5, anim_speed * 1.5))

func handle_camera(delta: float) -> void:
	if not camera_pivot:
		return
	
	var target_pos = global_position + Vector3(0, camera_height, 0)
	camera_pivot.global_position = camera_pivot.global_position.lerp(target_pos, camera_smooth_speed * delta)

func _on_interact_pressed() -> void:
	if animation_controller and is_on_floor():
		animation_controller.set_state("interact", true)
		await animation_controller.animation_finished
		if _current_state == "interact":
			animation_controller.set_state("idle")

func _on_wave_pressed() -> void:
	if animation_controller:
		animation_controller.set_state("wave", true)

var _animation_map: Dictionary = {
	"idle": "idle",
	"walk": "walk",
	"run": "run",
	"jump": "jump",
	"fall": "fall",
	"interact": "interact",
	"wave": "wave",
}