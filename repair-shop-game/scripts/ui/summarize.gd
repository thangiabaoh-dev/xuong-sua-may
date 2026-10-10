extends CanvasLayer

var game_state
var _built := false

func setup(gs: Node) -> void:
	game_state = gs
	if not _built:
		_build_ui()
		_built = true
	refresh()

func refresh() -> void:
	if game_state == null or not has_node("Root/LblSummary"):
		return
	var lines: PackedStringArray = []
	for a in game_state.today_activities:
		lines.append("%s — %d′" % [String(a["label"]), int(a["minutes"])])
	lines.append("Tiền: %dđ" % int(game_state.money))
	var miss: int = 450 - int(game_state.school_minutes_done())
	if miss > 0:
		lines.append("Phạt học đường: −%d kỷ luật" % (10 * int(ceil(float(miss) / 450.0))))
	(get_node("Root/LblSummary") as Label).text = "\n".join(lines)

func _on_sleep() -> void:
	if game_state == null:
		return
	game_state.begin_new_day()
	refresh()

func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var lbl := Label.new()
	lbl.name = "LblSummary"
	lbl.position = Vector2(80, 100)
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.custom_minimum_size = Vector2(640, 0)
	root.add_child(lbl)
	var btn := Button.new()
	btn.name = "BtnSleep"
	btn.text = "Ngủ → ngày kế"
	btn.position = Vector2(80, 520)
	root.add_child(btn)
	btn.pressed.connect(_on_sleep)
