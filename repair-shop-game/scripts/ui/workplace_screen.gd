extends CanvasLayer

const UPGRADES_PATH := "res://data/workspace_upgrades.tres"
const TIER_NAMES := ["Bàn học", "Phòng", "Tiệm"]
const REASON_TEXT := {
	"no_money": "Chưa đủ tiền",
	"low_uy_tin": "Uy tín còn thấp",
	"condition": "Điều kiện chưa đạt",
	"max_tier": "Đã là tiệm rồi",
}

var game_state
var _built := false
var _upgrade_defs: Array = []
var _core  # UnlockCore — scene-local
var _rules: Array = []
var _rule_ids: Dictionary = {}
var _warned_missing_rule := false
var _tier_nodes: Array = []
var _lbl_tier: Label
var _lbl_next: Label
var _btn_upgrade: Button
var _toast_label: Label
var _lbl_warning: Label

func _ready() -> void:
	if game_state == null:
		setup(get_node_or_null("/root/GameState"))

func setup(gs: Node) -> void:
	game_state = gs
	_upgrade_defs.clear()
	var res = load(UPGRADES_PATH)
	if res != null:
		_upgrade_defs.assign(res.defs)
	var rules_res = load("res://data/unlock_rules.tres")
	if rules_res != null:
		_rules = rules_res.rules
	else:
		_rules = []
	_rule_ids.clear()
	for r in _rules:
		_rule_ids[String(r.id)] = true
	if not _built:
		_build_ui()
		_built = true
	_core = null
	if rules_res != null:
		_core = load("res://scripts/progression/unlock_core.gd").new()
		_core.setup(_rules)
		_core.unlock_changed.connect(_on_unlock_changed)
		_core.refresh(game_state)
	refresh()

func refresh() -> void:
	if _core != null:
		_core.refresh(game_state)
	var tier := 0
	if game_state != null:
		tier = clampi(int(game_state.workspace_tier), 0, 2)
	for i in range(3):
		(_tier_nodes[i] as Control).visible = (i == tier)
	_lbl_tier.text = "CHỖ LÀM: " + TIER_NAMES[tier]
	if _upgrade_defs.is_empty():
		_lbl_next.text = "Thiếu dữ liệu progression"
		_btn_upgrade.disabled = true
	else:
		var def = null
		for d in _upgrade_defs:
			if int(d.to_tier) == tier + 1:
				def = d
				break
		if def == null:
			_lbl_next.text = "Đã lên cấp cao nhất"
			_btn_upgrade.disabled = true
		else:
			_lbl_next.text = "→ %s · %sđ · uy tín %d" % [
				TIER_NAMES[clampi(int(def.to_tier), 0, 2)], _vn(int(def.cost)), int(def.uy_tin_req),
			]
			_btn_upgrade.disabled = false
	_refresh_tracker()
	_update_warning()

func _refresh_tracker() -> void:
	if _lbl_warning == null or _core == null or game_state == null:
		return
	var values := {}
	for prop in UnlockCore.INPUT_NAMES:
		var v = game_state.get(prop)
		values[prop] = 0 if v == null else int(v)
	for r in _rules:
		if not bool(r.enabled):
			continue
		var row = get_node_or_null("Root/Tracker/Milestones/" + String(r.id))
		if row == null:
			continue
		var unlocked: bool = _core.is_unlocked(r.id)
		(row.get_node("MMark") as Label).text = "✓" if unlocked else ""
		var pct_txt := ""
		if unlocked:
			pct_txt = "100%"
		else:
			var pp := progress_percent(String(r.condition), values)
			if pp >= 0.0:
				pct_txt = "%d%%" % int(round(pp * 100.0))
		(row.get_node("MPct") as Label).text = pct_txt
	var customers: Array = CustomerCatalog.load_all()
	for c in customers:
		var crow = get_node_or_null("Root/Tracker/Customers/" + String(c.key))
		if crow == null:
			continue
		var ur := String(c.unlock_rule)
		var bright: bool = ur == "" or _core.is_unlocked(c.unlock_rule)
		if bright:
			_set_alpha(crow as Control, 1.0)
			(crow.get_node("CNote") as Label).text = ""
		else:
			if not _rule_ids.has(ur) and not _warned_missing_rule:
				_warned_missing_rule = true
				push_warning("unlock_rule khong ton tai trong rules: %s" % ur)
			_set_alpha(crow as Control, 0.4)
			(crow.get_node("CNote") as Label).text = "Chưa mở"

func _update_warning() -> void:
	if _lbl_warning == null:
		return
	if _core == null:
		_lbl_warning.text = "Thiếu dữ liệu progression"
		_lbl_warning.visible = true
		return
	var errs: Array = _core.parse_errors()
	var show_now := not errs.is_empty()
	if show_now:
		_lbl_warning.text = String(errs[0])
		if not _lbl_warning.visible:
			push_warning(String(errs[0]))
	_lbl_warning.visible = show_now

func _on_unlock_changed(_id: StringName) -> void:
	_refresh_tracker()

static func progress_percent(condition: String, values: Dictionary) -> float:
	var re := RegEx.create_from_string("^\\s*(\\w+) >= (\\d+)\\s*$")
	var best := -1.0
	for part in condition.split(" and "):
		var m := re.search(String(part))
		if m == null:
			return -1.0
		var key := m.get_string(1)
		if not values.has(key):
			return -1.0
		var threshold := float(int(m.get_string(2)))
		if threshold <= 0.0:
			return -1.0
		var ratio := clampf(float(values[key]) / threshold, 0.0, 1.0)
		if best < 0.0 or ratio < best:
			best = ratio
	return best

func _on_upgrade_pressed() -> void:
	var reason := WorkspaceUpgrades.try_upgrade(game_state, _upgrade_defs)
	if reason == "":
		_toast("Đã mở chỗ làm mới!")
		refresh()
		if _core != null:
			_core.refresh(game_state)
			_refresh_tracker()
	else:
		_toast(REASON_TEXT.get(reason, reason))

func close() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if key.echo or not key.pressed:
		return
	if key.keycode == KEY_ESCAPE:
		close()

func _toast(msg: String) -> void:
	_toast_label.text = msg
	_toast_label.visible = true
	if is_inside_tree():
		var timer := get_tree().create_timer(1.5)
		timer.timeout.connect(func() -> void: _toast_label.visible = false)

func _set_alpha(c: Control, a: float) -> void:
	var m := c.modulate
	m.a = a
	c.modulate = m

static func _vn(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	var cnt := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			out = "." + out
	return out

func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var backdrop := Control.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var tier_colors := [Color(0.16, 0.15, 0.18), Color(0.14, 0.16, 0.20), Color(0.12, 0.14, 0.16)]
	for i in range(3):
		var tier := Control.new()
		tier.name = "Tier%d" % i
		tier.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop.add_child(tier)
		var bg := ColorRect.new()
		bg.name = "Bg"
		bg.color = tier_colors[i]
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		tier.add_child(bg)
		_add_rect(tier, "Desk", Vector2(200, 300), Vector2(400, 20), Color(0.45, 0.32, 0.2))
		_add_rect(tier, "Lamp", Vector2(350, 150), Vector2(12, 120), Color(0.9, 0.85, 0.6))
		if i >= 1:
			_add_rect(tier, "Shelf", Vector2(60, 160), Vector2(120, 14), Color(0.5, 0.38, 0.25))
			_add_rect(tier, "Socket", Vector2(640, 320), Vector2(16, 16), Color(0.8, 0.8, 0.8))
		if i >= 2:
			_add_rect(tier, "Sign", Vector2(250, 60), Vector2(300, 64), Color(0.2, 0.45, 0.75))
			_add_rect(tier, "Counter", Vector2(140, 360), Vector2(520, 28), Color(0.35, 0.26, 0.18))
		_tier_nodes.append(tier)

	var panel := Control.new()
	panel.name = "UpgradePanel"
	panel.position = Vector2(40, 430)
	root.add_child(panel)
	_lbl_tier = Label.new()
	_lbl_tier.name = "TierLabel"
	_lbl_tier.position = Vector2(0, 0)
	panel.add_child(_lbl_tier)
	_lbl_next = Label.new()
	_lbl_next.name = "NextLabel"
	_lbl_next.position = Vector2(0, 32)
	panel.add_child(_lbl_next)
	_btn_upgrade = Button.new()
	_btn_upgrade.name = "UpgradeBtn"
	_btn_upgrade.text = "NÂNG CẤP"
	_btn_upgrade.position = Vector2(0, 64)
	_btn_upgrade.size = Vector2(220, 44)
	_btn_upgrade.pressed.connect(_on_upgrade_pressed)
	panel.add_child(_btn_upgrade)

	var tracker := Control.new()
	tracker.name = "Tracker"
	tracker.position = Vector2(700, 80)
	root.add_child(tracker)
	var milestones := VBoxContainer.new()
	milestones.name = "Milestones"
	milestones.position = Vector2(0, 0)
	tracker.add_child(milestones)
	for r in _rules:
		if not bool(r.enabled):
			continue
		var row := HBoxContainer.new()
		row.name = String(r.id)
		var m_name := Label.new()
		m_name.name = "MName"
		m_name.text = String(r.label)
		row.add_child(m_name)
		var m_pct := Label.new()
		m_pct.name = "MPct"
		m_pct.custom_minimum_size = Vector2(56, 0)
		row.add_child(m_pct)
		var m_mark := Label.new()
		m_mark.name = "MMark"
		row.add_child(m_mark)
		milestones.add_child(row)
	var customers_box := VBoxContainer.new()
	customers_box.name = "Customers"
	customers_box.position = Vector2(0, 240)
	tracker.add_child(customers_box)
	var customers: Array = CustomerCatalog.load_all()
	for c in customers:
		var crow := HBoxContainer.new()
		crow.name = String(c.key)
		var c_name := Label.new()
		c_name.name = "CName"
		c_name.text = String(c.display_name)
		crow.add_child(c_name)
		var c_note := Label.new()
		c_note.name = "CNote"
		crow.add_child(c_note)
		customers_box.add_child(crow)
	_lbl_warning = Label.new()
	_lbl_warning.name = "Warning"
	_lbl_warning.visible = false
	_lbl_warning.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
	_lbl_warning.position = Vector2(0, 470)
	tracker.add_child(_lbl_warning)

	_toast_label = Label.new()
	_toast_label.name = "Toast"
	_toast_label.visible = false
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.offset_left = -260.0
	_toast_label.offset_right = 260.0
	_toast_label.offset_top = 60.0
	_toast_label.offset_bottom = 100.0
	root.add_child(_toast_label)

	var close_btn := Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "✕"
	close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_btn.offset_left = -72.0
	close_btn.offset_right = -16.0
	close_btn.offset_top = 16.0
	close_btn.offset_bottom = 60.0
	close_btn.pressed.connect(close)
	root.add_child(close_btn)

func _add_rect(parent: Control, rect_name: String, pos: Vector2, size: Vector2, color: Color) -> void:
	var r := ColorRect.new()
	r.name = rect_name
	r.position = pos
	r.size = size
	r.color = color
	parent.add_child(r)
