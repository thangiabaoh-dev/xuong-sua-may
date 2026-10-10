extends Node

class_name AnimationController

signal animation_finished(anim_name: String)
signal animation_started(anim_name: String)

@export_group("Animation Player")
@export var animation_player: AnimationPlayer

@export_group("State Machine")
@export var current_state: String = "idle"
@export var previous_state: String = ""

var _state_machine: Dictionary = {
	"idle": ["walk", "run", "interact", "wave", "sit"],
	"walk": ["idle", "run", "interact"],
	"run": ["idle", "walk", "interact"],
	"interact": ["idle", "walk", "run"],
	"wave": ["idle"],
	"sit": ["idle"],
}

var _animation_map: Dictionary = {
	"idle": "idle",
	"walk": "walk",
	"run": "run",
	"interact": "interact",
	"wave": "wave",
	"sit": "sit_down",
	"stand_up": "stand_up",
}

var _blend_times: Dictionary = {
	"idle": 0.15,
	"walk": 0.1,
	"run": 0.1,
	"interact": 0.05,
	"wave": 0.1,
	"sit": 0.2,
	"stand_up": 0.2,
}

var _loop_animations: Array[String] = ["idle", "walk", "run"]
var _speed_multipliers: Dictionary = {
	"walk": 1.0,
	"run": 1.8,
}

func _ready() -> void:
	if not animation_player:
		animation_player = get_node_or_null("AnimationPlayer")
		if not animation_player:
			animation_player = get_parent().get_node_or_null("AnimationPlayer")
	
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)
		play("idle")

func _on_animation_finished(anim_name: String) -> void:
	if anim_name in _loop_animations:
		play(anim_name)
	else:
		if current_state == "sit":
			pass
		elif current_state == "interact" or current_state == "wave":
			set_state("idle")
	animation_finished.emit(anim_name)

func can_transition(to_state: String) -> bool:
	var allowed = _state_machine.get(current_state, [])
	return to_state in allowed

func set_state(new_state: String, force: bool = false) -> bool:
	if new_state == current_state and not force:
		return true
	
	if not force and not can_transition(new_state):
		push_warning("Invalid state transition: ", current_state, " -> ", new_state)
		return false
	
	previous_state = current_state
	current_state = new_state
	play(_animation_map.get(new_state, new_state))
	return true

func play(anim_name: String, blend: float = -1.0, speed: float = 1.0) -> void:
	if not animation_player:
		return
	
	if not animation_player.has_animation(anim_name):
		push_warning("Animation not found: ", anim_name)
		return
	
	var blend_time = blend if blend >= 0 else _blend_times.get(anim_name, 0.1)
	var playback_speed = speed * _speed_multipliers.get(anim_name, 1.0)
	
	animation_player.play(anim_name, blend_time, playback_speed)
	animation_started.emit(anim_name)

func stop() -> void:
	if animation_player:
		animation_player.stop()

func get_current_animation() -> String:
	if animation_player:
		return animation_player.get_current_animation()
	return ""

func is_playing() -> bool:
	if animation_player:
		return animation_player.is_playing()
	return false

func get_animation_length(anim_name: String) -> float:
	if animation_player and animation_player.has_animation(anim_name):
		return animation_player.get_animation(anim_name).length
	return 0.0

func seek(anim_name: String, time: float, blend: float = 0.1) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		animation_player.play(anim_name, blend)
		animation_player.seek(time, true)

func add_animation(anim_name: String, animation: Animation) -> void:
	if animation_player:
		animation_player.add_animation(anim_name, animation)

func create_procedural_walk(cycle_time: float = 1.0, stride: float = 1.0) -> Animation:
	var anim = Animation.new()
	var length = cycle_time
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR
	
	var pos_track = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(pos_track, ".")
	var rot_track = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(rot_track, ".")
	
	var key_count = 8
	for i in range(key_count):
		var t = i * length / key_count
		var phase = 2.0 * PI * t / length
		
		var pos = Vector3(
			sin(phase) * 0.02,
			abs(sin(phase)) * 0.05,
			0
		)
		var rot = Basis()
		
		anim.position_track_insert_key(pos_track, t, pos)
		anim.rotation_track_insert_key(rot_track, t, rot.get_rotation_quaternion())
	
	return anim

func create_procedural_idle(cycle_time: float = 3.0, breathe_amount: float = 0.02) -> Animation:
	var anim = Animation.new()
	var length = cycle_time
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR
	
	var pos_track = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(pos_track, ".")
	var rot_track = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(rot_track, ".")
	
	var key_count = 12
	for i in range(key_count):
		var t = i * length / key_count
		var phase = 2.0 * PI * t / length
		
		var pos = Vector3(
			sin(phase * 0.5) * 0.005,
			breathe_amount * sin(phase) + 0.01,
			sin(phase * 0.3) * 0.003
		)
		var rot = Basis().rotated(Vector3(0, 1, 0), sin(phase * 0.2) * 0.02)
		
		anim.position_track_insert_key(pos_track, t, pos)
		anim.rotation_track_insert_key(rot_track, t, rot.get_rotation_quaternion())
	
	return anim

func create_procedural_run(cycle_time: float = 0.6, stride: float = 1.5) -> Animation:
	var anim = Animation.new()
	var length = cycle_time
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR
	
	var pos_track = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(pos_track, ".")
	var rot_track = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(rot_track, ".")
	
	var key_count = 8
	for i in range(key_count):
		var t = i * length / key_count
		var phase = 2.0 * PI * t / length
		
		var pos = Vector3(
			sin(phase) * 0.04,
			abs(sin(phase)) * 0.1,
			0
		)
		var rot = Basis().rotated(Vector3(1, 0, 0), sin(phase) * 0.1)
		
		anim.position_track_insert_key(pos_track, t, pos)
		anim.rotation_track_insert_key(rot_track, t, rot.get_rotation_quaternion())
	
	return anim