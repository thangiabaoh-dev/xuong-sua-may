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
	for k in LOCATIONS:
		if k == loc:
			continue
		var old := parent.get_node_or_null(NodePath(str(k).capitalize()))
		if old != null:
			parent.remove_child(old)
			old.free()
	var scene = load(LOCATIONS[loc]).instantiate()
	scene.name = loc.capitalize()
	parent.add_child(scene)
	gs.set("current_location", loc)
	player.position = SPAWN
	player.velocity = Vector3.ZERO
