extends CanvasLayer

const SLOT_LABELS := {
	"SCHOOL": "Đi học",
	"CHOICE": "Tự chọn",
	"REPAIR": "Ca sửa máy",
	"FREE_HOME": "Ở nhà",
	"PROJECT": "Làm project",
	"BREAK": "Nghỉ",
	"HOLIDAY": "Ngày lễ",
}
const WEEKDAY_LABELS := {1: "T2", 2: "T3", 3: "T4", 4: "T5", 5: "T6", 6: "T7", 7: "CN"}

var game_state
var _built := false
var _time_label: Label

static func slot_label(kind: String) -> String:
	if kind.is_empty():
		return "Ngoài lịch"
	return String(SLOT_LABELS.get(kind, kind))

func _ready() -> void:
	if game_state == null:
		var gs = get_node_or_null("/root/GameState")
		var clock = null
		if get_parent() != null:
			clock = get_parent().get_node_or_null("ClockTimer")
		setup(gs, clock)

func setup(gs: Node, clock: Node = null) -> void:
	game_state = gs
	if not _built:
		_build_ui()
		_built = true
	if clock != null and not clock.minute_changed.is_connected(refresh_from_clock):
		clock.minute_changed.connect(refresh_from_clock)
	refresh()

func refresh_from_clock(_old: int, _new: int) -> void:
	refresh()

func refresh() -> void:
	if game_state == null or _time_label == null:
		return
	var s = game_state.slot()
	var kind := ""
	if s != null:
		kind = String(s.kind)
	var wd: int = ScheduleLogic.weekday(game_state.date)
	_time_label.text = "%02d:%02d · %s · %s" % [
		int(game_state.minute) / 60,
		int(game_state.minute) % 60,
		String(WEEKDAY_LABELS.get(wd, "?")),
		slot_label(kind),
	]

func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_time_label = Label.new()
	_time_label.name = "TimeLabel"
	_time_label.position = Vector2(16, 8)
	_time_label.add_theme_font_size_override("font_size", 22)
	root.add_child(_time_label)
