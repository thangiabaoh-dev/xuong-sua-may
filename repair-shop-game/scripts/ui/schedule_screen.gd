extends CanvasLayer

const HUDScript = preload("res://scripts/ui/hud.gd")
const COL_HEADERS := ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]

var game_state
var _built := false
var _days: Array = []
var _holiday_list: ItemList

func _ready() -> void:
	if game_state == null:
		setup(get_node_or_null("/root/GameState"))

func setup(gs: Node) -> void:
	game_state = gs
	if not _built:
		_build_ui()
		_built = true
	refresh()

func refresh() -> void:
	if game_state == null or _days.is_empty():
		return
	var u: int = Time.get_unix_time_from_datetime_dict(game_state.date)
	var wd: int = ScheduleLogic.weekday(game_state.date)
	u -= (wd - 1) * 86400
	for i in range(7):
		var col_date: Dictionary = Time.get_datetime_dict_from_unix_time(u + i * 86400)
		var slots: Array = ScheduleLogic.slots_for_day(game_state.week, col_date)
		var col = _days[i]
		for c in col.get_children():
			if String(c.name) != "Header":
				c.free()
		for j in range(slots.size()):
			var s = slots[j]
			var row := Label.new()
			row.name = "Row%d" % j
			row.text = "%02d:%02d–%02d:%02d · %s" % [
				int(s.start_minute) / 60, int(s.start_minute) % 60,
				int(s.end_minute) / 60, int(s.end_minute) % 60,
				HUDScript.slot_label(String(s.kind)),
			]
			col.add_child(row)
	_holiday_list.clear()
	for h in game_state.week.holidays:
		_holiday_list.add_item(String(h))

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if key.echo or not key.pressed:
		return
	if key.keycode == KEY_TAB:
		visible = not visible
		if visible:
			refresh()

func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var days := HBoxContainer.new()
	days.name = "Days"
	days.position = Vector2(24, 48)
	root.add_child(days)
	for i in range(7):
		var col := VBoxContainer.new()
		col.name = "Day%d" % i
		col.custom_minimum_size = Vector2(150, 0)
		var hdr := Label.new()
		hdr.name = "Header"
		hdr.text = COL_HEADERS[i]
		col.add_child(hdr)
		days.add_child(col)
		_days.append(col)
	_holiday_list = ItemList.new()
	_holiday_list.name = "HolidayList"
	_holiday_list.position = Vector2(24, 420)
	_holiday_list.custom_minimum_size = Vector2(300, 120)
	root.add_child(_holiday_list)
