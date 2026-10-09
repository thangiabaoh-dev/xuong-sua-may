class_name ClockTimer
extends Node

const GS = preload("res://scripts/autoload/game_state.gd")
const SECONDS_PER_GAME_MINUTE := 1.0

signal minute_changed(old_minute: int, new_minute: int)

var game_state
var _acc := 0.0

func _ready() -> void:
	if game_state == null:
		game_state = get_node_or_null("/root/GameState")

func setup(gs: Node) -> void:
	game_state = gs

func tick(delta: float) -> void:
	if game_state == null or game_state.mode != GS.GameStateMode.REPAIR:
		return
	_acc += delta
	while game_state.mode == GS.GameStateMode.REPAIR and _acc >= SECONDS_PER_GAME_MINUTE:
		_acc -= SECONDS_PER_GAME_MINUTE
		var old_m: int = game_state.minute
		game_state.advance_to(old_m + 1)
		minute_changed.emit(old_m, game_state.minute)

func _process(delta: float) -> void:
	tick(delta)

func _unhandled_input(event: InputEvent) -> void:
	if game_state == null:
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if key.echo or not key.pressed:
		return
	if key.keycode == KEY_F5:
		if game_state.mode == GS.GameStateMode.REPAIR:
			game_state.mode = GS.GameStateMode.SCHEDULE
		else:
			game_state.mode = GS.GameStateMode.REPAIR
	elif key.keycode == KEY_F6:
		var old6: int = game_state.minute
		game_state.advance_to(game_state.minute + 30)
		minute_changed.emit(old6, game_state.minute)
	elif key.keycode == KEY_F7:
		var old7: int = game_state.minute
		game_state.end_day()
		minute_changed.emit(old7, game_state.minute)
