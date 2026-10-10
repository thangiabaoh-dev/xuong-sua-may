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
var _core  # UnlockCore — Task 4 mới khởi tạo
var _tier_nodes: Array = []
var _lbl_tier: Label
var _lbl_next: Label
var _btn_upgrade: Button
var _toast_label: Label

func _ready() -> void:
	if game_state == null:
		setup(get_node_or_null("/root/GameState"))

func setup(gs: Node) -> void:
	game_state = gs
	_upgrade_defs.clear()
	var res = load(UPGRADES_PATH)
	if res != null:
		_upgrade_defs.assign(res.defs)
	if not _built:
		_build_ui()
		_built = true
	refresh()

func refresh() -> void:
	var tier := 0
	if game_state != null:
		tier = clampi(int(game_state.workspace_tier), 0, 2)
	for i in range(3):
		(_tier_nodes[i] as Control).visible = (i == tier)
	_lbl_tier.text = "CHỖ LÀM: " + TIER_NAMES[tier]
	if _upgrade_defs.is_empty():
		_lbl_next.text = "Thiếu dữ liệu progression"
		_btn_upgrade.disabled = true
		return
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

func _on_upgrade_pressed() -> void:
	var reason := WorkspaceUpgrades.try_upgrade(game_state, _upgrade_defs)
	if reason == "":
		_toast("Đã mở chỗ làm mới!")
		refresh()
	else:
		_toast(REASON_TEXT.get(reason, reason))

func _toast(msg: String) -> void:
	_toast_label.text = msg
	_toast_label.visible = true
	if is_inside_tree():
		var timer := get_tree().create_timer(1.5)
		timer.timeout.connect(func() -> void: _toast_label.visible = false)

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

func _add_rect(parent: Control, rect_name: String, pos: Vector2, size: Vector2, color: Color) -> void:
	var r := ColorRect.new()
	r.name = rect_name
	r.position = pos
	r.size = size
	r.color = color
	parent.add_child(r)
