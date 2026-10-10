extends CharacterBody3D
class_name ChibiNPCController

@export_group("Animation")
@export var animation_controller: AnimationController

@export_group("Behavior")
@export var wander_radius: float = 5.0
@export var wander_interval: float = 3.0
@export var interaction_radius: float = 2.0
@export var face_player: bool = true

@export_group("Visual")
@export var mesh_instance: MeshInstance3D

var _home_position: Vector3 = Vector3.ZERO
var _target_position: Vector3 = Vector3.ZERO
var _wander_timer: float = 0.0
var _current_state: String = "idle"
var _player: Node3D = null

func _ready() -> void:
	_home_position = global_position
	_target_position = _home_position
	
	if not animation_controller:
		animation_controller = get_node_or_null("AnimationController")
	
	if not mesh_instance:
		mesh_instance = get_node_or_null("Body")
	
	_player = get_tree().get_first_node_in_group("player")
	
	call_deferred("_setup_animations")

func _setup_animations() -> void:
	if animation_controller:
		animation_controller.play("idle")

func _physics_process(delta: float) -> void:
	if face_player and _player:
		look_at(_player.global_position, Vector3.UP)
		rotation_degrees.x = 0
		rotation_degrees.z = 0
	
	handle_wander(delta)
	handle_movement(delta)
	handle_animation(delta)

func handle_wander(delta: float) -> void:
	_wander_timer -= delta
	
	if _wander_timer <= 0.0:
		var angle = randf() * TAU
		var distance = randf() * wander_radius
		_target_position = _home_position + Vector3(cos(angle), 0, sin(angle)) * distance
		_wander_timer = wander_interval + randf() * 2.0

func handle_movement(delta: float) -> void:
	var to_target = _target_position - global_position
	to_target.y = 0
	
	if to_target.length() > 0.5:
		var direction = to_target.normalized()
		velocity.x = direction.x * 2.0
		velocity.z = direction.z * 2.0
	else:
		velocity.x = lerp(velocity.x, 0.0, 5.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 5.0 * delta)
	
	velocity.y -= 20.0 * delta
	move_and_slide()

func handle_animation(delta: float) -> void:
	if not animation_controller:
		return
	
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	var new_state = "walk" if horizontal_speed > 0.3 else "idle"
	
	if new_state != _current_state:
		_current_state = new_state
		animation_controller.set_state(new_state)

func interact() -> void:
	if animation_controller:
		animation_controller.set_state("wave", true)

func _on_player_entered_interaction_range() -> void:
	interact()