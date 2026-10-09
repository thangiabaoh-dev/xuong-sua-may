extends SceneTree
# Chụp preview PNG cho scene (chạy: godot --path repair-shop-game -s res://tools/shot.gd)

const SHOTS := [
	{
		"scene": "res://scenes/gate.tscn",
		"out": "res://tools/preview_gate.png",
		"cam": Vector3(7, 7, 20),
		"target": Vector3(0, 1.5, 5),
		"fov": 55.0,
	},
	{
		"scene": "res://scenes/gate.tscn",
		"out": "res://tools/preview_gate_front.png",
		"cam": Vector3(0, 3.5, 16),
		"target": Vector3(0, 2.6, 5),
		"fov": 50.0,
	},
	{
		"scene": "res://scenes/classroom.tscn",
		"out": "res://tools/preview_classroom.png",
		"cam": Vector3(7, 9, 9),
		"target": Vector3(0, 1, 0),
		"fov": 50.0,
	},
	{
		"scene": "res://scenes/classroom.tscn",
		"out": "res://tools/preview_classroom_front.png",
		"cam": Vector3(0, 3.2, 4.6),
		"target": Vector3(0, 1.1, -4.5),
		"fov": 60.0,
	},
]

var _idx := 0
var _frames := 0
var _phase := "start"

func _initialize() -> void:
	get_root().size = Vector2i(1600, 900)
	# delay tới frame đầu: node add trong _initialize chưa vào tree
	_phase = "pending"

func _start(i: int) -> void:
	if i >= SHOTS.size():
		quit(0)
		return
	_idx = i
	_frames = 0
	_phase = "render"
	var shot: Dictionary = SHOTS[i]
	var packed: PackedScene = load(shot["scene"])
	if packed == null:
		push_error("cannot load " + shot["scene"])
		quit(1)
		return
	root.add_child(packed.instantiate())

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.shadow_bias = 0.6
	sun.shadow_normal_bias = 6.0
	root.add_child(sun)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.53, 0.7, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.35
	env_node.environment = env
	root.add_child(env_node)

	var cam := Camera3D.new()
	cam.fov = shot["fov"]
	root.add_child(cam)
	cam.look_at_from_position(shot["cam"], shot["target"], Vector3.UP)
	cam.current = true
	var meshes := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			meshes += 1
		stack.append_array(n.get_children())
	print("debug: meshes=", meshes, " cam_pos=", cam.global_position,
			" fwd=", -cam.global_transform.basis.z, " current=", cam.is_current(),
			" vp=", root.size)

func _process(_delta: float) -> bool:
	if _phase == "pending":
		_start(0)
		return false
	if _phase == "cleanup":
		_phase = "start"
		_start(_idx + 1)
		return false
	_frames += 1
	if _frames < 10:
		return false
	var img: Image = get_root().get_texture().get_image()
	var shot: Dictionary = SHOTS[_idx]
	img.save_png(shot["out"])
	print("saved ", shot["out"], " ", img.get_width(), "x", img.get_height(),
			" center=", img.get_pixel(img.get_width() / 2, img.get_height() / 2))
	for c in root.get_children():
		c.free()
	_phase = "cleanup"
	return false
