class_name MinigameController
extends RefCounted

enum Kind { VAN_OC, HAN_MACH, CAM_CAP, LAU_BUI }

const ZONE_HALF := 0.06
const ZONE_SPEED := 0.8
const TOTAL_CELLS := 100
const PASS_CELLS := 80

var kind: int = -1
var difficulty: int = 1
var passed := false
var failed := false

# van_oc
var beats_needed := 0
var progress := 0
var needle_pos := 0.0
var zone_lo := 0.0
var zone_hi := 0.0

# han_mach
var hold_need := 0.0
var held := 0.0

# cam_cap
var port_count := 0
var correct_port := 0
var correct_orientation := 0

# lau_bui
var wiped := 0
var marked: Dictionary = {}

var _rng: RandomNumberGenerator


static func create(minigame_key: String, p_difficulty: int, p_rng: RandomNumberGenerator) -> MinigameController:
	var c := MinigameController.new()
	c.difficulty = p_difficulty
	c._rng = p_rng
	match minigame_key:
		"van_oc":
			c.kind = Kind.VAN_OC
			c.beats_needed = p_difficulty * 2
		"han_mach":
			c.kind = Kind.HAN_MACH
			c.hold_need = float(p_difficulty)
		"cam_cap":
			c.kind = Kind.CAM_CAP
			c.port_count = 3 if p_difficulty <= 2 else 4
		"lau_bui":
			c.kind = Kind.LAU_BUI
		_:
			push_error("MinigameController: unknown minigame '%s'" % minigame_key)
			return null
	c.reset()
	return c

func reset() -> void:
	passed = false
	failed = false
	match kind:
		Kind.VAN_OC:
			progress = 0
			needle_pos = 0.0
			_roll_zone()
		Kind.HAN_MACH:
			held = 0.0
		Kind.CAM_CAP:
			correct_port = _rng.randi_range(0, port_count - 1)
			correct_orientation = _rng.randi_range(0, 1)
		Kind.LAU_BUI:
			wiped = 0
			marked.clear()

func _roll_zone() -> void:
	var center := _rng.randf_range(0.1, 0.9)
	zone_lo = maxf(0.0, center - ZONE_HALF)
	zone_hi = minf(1.0, center + ZONE_HALF)

# --- van_oc ---
func tick(delta: float) -> void:
	if kind != Kind.VAN_OC or passed or failed:
		return
	needle_pos = fmod(needle_pos + ZONE_SPEED * delta, 1.0)

func press() -> bool:
	if kind != Kind.VAN_OC or passed or failed:
		return false
	if needle_pos >= zone_lo and needle_pos <= zone_hi:
		progress += 1
		if progress >= beats_needed:
			passed = true
		else:
			_roll_zone()
		return true
	failed = true
	return false

# --- han_mach ---
func hold(delta: float) -> void:
	if kind != Kind.HAN_MACH or passed or failed:
		return
	held += delta
	if held >= hold_need:
		passed = true

func release() -> void:
	if kind != Kind.HAN_MACH or passed:
		return
	held = 0.0

# --- cam_cap ---
func select(p_port: int, p_orientation: int) -> bool:
	if kind != Kind.CAM_CAP or passed or failed:
		return false
	if p_port < 0 or p_port >= port_count or p_orientation < 0 or p_orientation > 1:
		return false
	if p_port == correct_port and p_orientation == correct_orientation:
		passed = true
		return true
	failed = true
	return false

# --- lau_bui ---
func wipe(cell: int) -> bool:
	if kind != Kind.LAU_BUI or passed or failed:
		return false
	if cell < 0 or cell >= TOTAL_CELLS or marked.has(cell):
		return false
	marked[cell] = true
	wiped += 1
	if wiped >= PASS_CELLS:
		passed = true
	return true

func wipe_random() -> void:
	if kind != Kind.LAU_BUI or passed or failed:
		return
	if marked.size() >= TOTAL_CELLS:
		return
	var start := _rng.randi_range(0, TOTAL_CELLS - 1)
	for i in TOTAL_CELLS:
		var cell := (start + i) % TOTAL_CELLS
		if not marked.has(cell):
			wipe(cell)
			return
