extends Node

const LOCATIONS := {
	"workshop": "res://scenes/workshop.tscn",
	"schoolyard": "res://scenes/schoolyard.tscn",
	"gate": "res://scenes/gate.tscn",
	"classroom": "res://scenes/classroom.tscn",
	"library": "res://scenes/library.tscn",
	"cafe": "res://scenes/cafe.tscn",
	"street": "res://scenes/street.tscn",
}
const SPAWN := Vector3(0, 0.1, 0)
const KEY_ORDER := ["workshop", "schoolyard", "gate", "classroom", "library", "cafe", "street"]

static func location_for_key(keycode: int) -> String:
	var i := keycode - 49
	if i >= 0 and i < KEY_ORDER.size():
		return KEY_ORDER[i]
	return ""

static func change_map(parent: Node3D, player: CharacterBody3D, loc: String, gs: Node) -> void:
	if not LOCATIONS.has(loc):
		return
	var packed = load(LOCATIONS[loc])
	if packed == null:
		return
	for k in LOCATIONS:
		var old := parent.get_node_or_null(NodePath(str(k).capitalize()))
		if old != null:
			parent.remove_child(old)
			old.free()
	var scene = packed.instantiate()
	scene.name = loc.capitalize()
	parent.add_child(scene)
	gs.set("current_location", loc)
	player.position = SPAWN
	player.velocity = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if key.echo:
		return
	if not key.pressed:
		return
	var loc := location_for_key(key.keycode)
	if loc == "":
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var player := tree.get_first_node_in_group("player") as CharacterBody3D
	if player == null:
		return
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return
	change_map(tree.current_scene as Node3D, player, loc, gs)
