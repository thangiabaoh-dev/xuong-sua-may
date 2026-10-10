@tool
extends Node
class_name AnimationSetup

@export var animation_player: AnimationPlayer
@export var create_procedural: bool = true

func _ready() -> void:
	if Engine.is_editor_hint() and create_procedural:
		setup_animations()

func setup_animations() -> void:
	if not animation_player:
		animation_player = get_node_or_null("AnimationPlayer")

	if not animation_player:
		print("No AnimationPlayer found")
		return

	var controller = AnimationController.new()

	var idle_anim = controller.create_procedural_idle(3.0, 0.02)
	idle_anim.name = "idle"
	animation_player.add_animation("idle", idle_anim)

	var walk_anim = controller.create_procedural_walk(1.0, 1.0)
	walk_anim.name = "walk"
	animation_player.add_animation("walk", walk_anim)

	var run_anim = controller.create_procedural_run(0.6, 1.5)
	run_anim.name = "run"
	animation_player.add_animation("run", run_anim)

	var jump_anim = create_jump_animation()
	animation_player.add_animation("jump", jump_anim)

	var fall_anim = create_fall_animation()
	animation_player.add_animation("fall", fall_anim)

	var interact_anim = create_interact_animation()
	animation_player.add_animation("interact", interact_anim)

	var wave_anim = create_wave_animation()
	animation_player.add_animation("wave", wave_anim)

	var sit_anim = create_sit_animation()
	animation_player.add_animation("sit_down", sit_anim)

	var stand_anim = create_stand_animation()
	animation_player.add_animation("stand_up", stand_anim)

	animation_player.play("idle")
	print("Procedural animations created!")

func create_jump_animation() -> Animation:
	var anim = Animation.new()
	anim.length = 0.8
	anim.loop_mode = Animation.LOOP_NONE

	var track_pos = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track_pos, ".")
	var track_rot = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(track_rot, ".")

	anim.position_track_insert_key(track_pos, 0.0, Vector3.ZERO)
	anim.rotation_track_insert_key(track_rot, 0.0, Quaternion())
	anim.position_track_insert_key(track_pos, 0.2, Vector3(0, 0.15, 0))
	anim.rotation_track_insert_key(track_rot, 0.2, Quaternion())
	anim.position_track_insert_key(track_pos, 0.5, Vector3(0, 0.25, 0))
	anim.rotation_track_insert_key(track_rot, 0.5, Quaternion())
	anim.position_track_insert_key(track_pos, 0.8, Vector3.ZERO)
	anim.rotation_track_insert_key(track_rot, 0.8, Quaternion())

	return anim

func create_fall_animation() -> Animation:
	var anim = Animation.new()
	anim.length = 0.5
	anim.loop_mode = Animation.LOOP_LINEAR

	var track_pos = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track_pos, ".")
	var track_rot = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(track_rot, ".")

	anim.position_track_insert_key(track_pos, 0.0, Vector3(0, 0.1, 0))
	anim.rotation_track_insert_key(track_rot, 0.0, Basis().rotated(Vector3(1, 0, 0), -0.2).get_rotation_quaternion())
	anim.position_track_insert_key(track_pos, 0.5, Vector3.ZERO)
	anim.rotation_track_insert_key(track_rot, 0.5, Basis().rotated(Vector3(1, 0, 0), 0.1).get_rotation_quaternion())

	return anim

func create_interact_animation() -> Animation:
	var anim = Animation.new()
	anim.length = 1.2
	anim.loop_mode = Animation.LOOP_NONE

	var track_pos = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track_pos, ".")
	var track_rot = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(track_rot, ".")

	anim.position_track_insert_key(track_pos, 0.0, Vector3.ZERO)
	anim.rotation_track_insert_key(track_rot, 0.0, Quaternion())
	anim.position_track_insert_key(track_pos, 0.3, Vector3(0, 0, -0.1))
	anim.rotation_track_insert_key(track_rot, 0.3, Basis().rotated(Vector3(1, 0, 0), 0.3).get_rotation_quaternion())
	anim.position_track_insert_key(track_pos, 0.6, Vector3(0, 0, -0.2))
	anim.rotation_track_insert_key(track_rot, 0.6, Basis().rotated(Vector3(1, 0, 0), 0.5).get_rotation_quaternion())
	anim.position_track_insert_key(track_pos, 0.9, Vector3(0, 0, -0.1))
	anim.rotation_track_insert_key(track_rot, 0.9, Basis().rotated(Vector3(1, 0, 0), 0.3).get_rotation_quaternion())
	anim.position_track_insert_key(track_pos, 1.2, Vector3.ZERO)
	anim.rotation_track_insert_key(track_rot, 1.2, Quaternion())

	return anim

func create_wave_animation() -> Animation:
	var anim = Animation.new()
	anim.length = 1.5
	anim.loop_mode = Animation.LOOP_NONE

	var track_pos = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track_pos, ".")
	var track_rot = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(track_rot, ".")

	for i in range(7):
		var t = i * 1.5 / 6
		var angle = sin(t * 4.0 * PI) * 0.8
		anim.position_track_insert_key(track_pos, t, Vector3(sin(angle) * 0.05, 0, 0))
		anim.rotation_track_insert_key(track_rot, t, Basis().rotated(Vector3(0, 1, 0), angle * 0.3).get_rotation_quaternion())

	return anim

func create_sit_animation() -> Animation:
	var anim = Animation.new()
	anim.length = 1.0
	anim.loop_mode = Animation.LOOP_NONE

	var track_pos = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track_pos, ".")
	var track_rot = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(track_rot, ".")

	anim.position_track_insert_key(track_pos, 0.0, Vector3.ZERO)
	anim.rotation_track_insert_key(track_rot, 0.0, Quaternion())
	anim.position_track_insert_key(track_pos, 0.5, Vector3(0, -0.5, 0.2))
	anim.rotation_track_insert_key(track_rot, 0.5, Basis().rotated(Vector3(1, 0, 0), 0.4).get_rotation_quaternion())
	anim.position_track_insert_key(track_pos, 1.0, Vector3(0, -0.7, 0.3))
	anim.rotation_track_insert_key(track_rot, 1.0, Basis().rotated(Vector3(1, 0, 0), 0.6).get_rotation_quaternion())

	return anim

func create_stand_animation() -> Animation:
	var anim = Animation.new()
	anim.length = 0.8
	anim.loop_mode = Animation.LOOP_NONE

	var track_pos = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track_pos, ".")
	var track_rot = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(track_rot, ".")

	anim.position_track_insert_key(track_pos, 0.0, Vector3(0, -0.7, 0.3))
	anim.rotation_track_insert_key(track_rot, 0.0, Basis().rotated(Vector3(1, 0, 0), 0.6).get_rotation_quaternion())
	anim.position_track_insert_key(track_pos, 0.4, Vector3(0, -0.3, 0.15))
	anim.rotation_track_insert_key(track_rot, 0.4, Basis().rotated(Vector3(1, 0, 0), 0.3).get_rotation_quaternion())
	anim.position_track_insert_key(track_pos, 0.8, Vector3.ZERO)
	anim.rotation_track_insert_key(track_rot, 0.8, Quaternion())

	return anim
