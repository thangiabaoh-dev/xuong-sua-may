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
var _summarize: CanvasLayer
var _activity_box: VBoxContainer
var _lbl_budget: Label
var _lbl_toast: Label
var _workplace

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
	if game_state != null and not game_state.schedule_changed.is_connected(refresh):
		game_state.schedule_changed.connect(refresh)
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
	_refresh_activity_box()
	_refresh_summarize()

func _refresh_activity_box() -> void:
	var in_schedule: bool = int(game_state.mode) == int(game_state.GameStateMode.SCHEDULE)
	if not in_schedule:
		_activity_box.visible = false
		_lbl_budget.visible = false
		_lbl_budget.text = ""
		return
	_activity_box.visible = true
	_lbl_budget.visible = true
	for c in _activity_box.get_children():
		_activity_box.remove_child(c)
		c.queue_free()
	for act in ScheduleCore.available(game_state):
		var btn := Button.new()
		btn.name = "Btn_%s" % String(act.id)
		btn.text = String(act.label)
		var reason := ScheduleCore.reason_for(game_state, act)
		if reason != "":
			btn.disabled = true
			btn.tooltip_text = reason
		btn.pressed.connect(_on_activity.bind(String(act.id)))
		_activity_box.add_child(btn)
	if game_state.week != null and ScheduleLogic.is_repair_slot(game_state.week, game_state.date, int(game_state.minute)):
		var budget: int = ScheduleCore.shift_budget(game_state)
		_lbl_budget.text = "Ca còn %d/%d′" % [maxi(budget - int(game_state.shift_used), 0), budget]
	else:
		_lbl_budget.text = ""

func _on_activity(id: String) -> void:
	var r: Dictionary = ScheduleCore.try_activity(game_state, id)
	if id == "mo_panel" and bool(r.get("ok", false)) and get_tree() != null:
		var panel := get_tree().get_first_node_in_group("repair_panel")
		if panel != null and panel.has_method("_on_open"):
			panel._on_open()
	if bool(r.get("ok", false)):
		var gains: Dictionary = r.get("gains", {})
		var k: int = int(gains.get("knowledge", 0))
		if k > 0:
			_toast("+%d tri thức" % k)
	refresh()

func _toast(msg: String) -> void:
	_lbl_toast.text = msg
	_lbl_toast.visible = true
	if is_inside_tree():
		var timer := get_tree().create_timer(1.5)
		timer.timeout.connect(_hide_toast)

func _hide_toast() -> void:
	_lbl_toast.visible = false

func _refresh_summarize() -> void:
	var show: bool = int(game_state.mode) == int(game_state.GameStateMode.SUMMARIZE)
	if show:
		if _summarize == null:
			var packed := load("res://scenes/ui/summarize.tscn") as PackedScene
			if packed == null:
				return
			_summarize = packed.instantiate()
			add_child(_summarize)
			_summarize.setup(game_state)
		else:
			_summarize.visible = true
			_summarize.refresh()
	elif _summarize != null:
		_summarize.visible = false

func _toggle_workplace() -> void:
	if game_state == null:
		return
	if _workplace != null and not is_instance_valid(_workplace):
		_workplace = null
	if _workplace == null:
		if get_parent() == null:
			return
		var packed = load("res://scenes/ui/workplace_screen.tscn")
		if packed == null:
			return
		_workplace = packed.instantiate()
		_workplace.setup(game_state)
		get_parent().add_child(_workplace)
		_workplace.visible = true
	else:
		_workplace.visible = not _workplace.visible
		if _workplace.visible:
			_workplace.refresh()

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
	var wp_btn := Button.new()
	wp_btn.name = "WorkplaceBtn"
	wp_btn.text = "CHỖ LÀM"
	wp_btn.position = Vector2(16, 56)
	wp_btn.size = Vector2(170, 40)
	wp_btn.pressed.connect(_toggle_workplace)
	root.add_child(wp_btn)
	_lbl_budget = Label.new()
	_lbl_budget.name = "LblBudget"
	_lbl_budget.position = Vector2(330, 12)
	_lbl_budget.add_theme_font_size_override("font_size", 22)
	root.add_child(_lbl_budget)
	_activity_box = VBoxContainer.new()
	_activity_box.name = "ActivityBox"
	_activity_box.position = Vector2(16, 560)
	root.add_child(_activity_box)
	_lbl_toast = Label.new()
	_lbl_toast.name = "Toast"
	_lbl_toast.visible = false
	_lbl_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_lbl_toast.offset_left = -260.0
	_lbl_toast.offset_right = 260.0
	_lbl_toast.offset_top = 60.0
	_lbl_toast.offset_bottom = 100.0
	root.add_child(_lbl_toast)
