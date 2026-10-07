class_name RepairSession
extends RefCounted

enum State { OFFER, SYMPTOM, CHECKS, CONCLUSION, PARTS, DISASSEMBLE, TEST, RESULT }
enum Result { NONE, REJECTED, LOST_TIME, LOST_MONEY, DONE }

const CHECK_KEYS: Array[String] = ["do_nguon", "nghe_quat", "kiem_tra_ram", "nhin_bo"]
const CHECK_MINUTES := 5
const WRONG_MINUTES := 15
const WRONG_MONEY := 20000
const BUY_MINUTES := 10
const TEST_MINUTES := 5
const DISASSEMBLE_MINUTES := 5

var order: RepairOrder
var game_state
var rng: RandomNumberGenerator
var state: int = State.OFFER
var result: int = Result.NONE
var elapsed: int = 0
var suspects: Array[String] = []
var checks_done: Array[String] = []
var wrong_count: int = 0
var earned: int = 0
var spent: int = 0

func _init(order_: RepairOrder, state_, rng_: RandomNumberGenerator) -> void:
	order = order_
	game_state = state_
	rng = rng_

func _check_timeout() -> bool:
	if elapsed > order.deadline_min:
		result = Result.LOST_TIME
		state = State.RESULT
		return true
	return false

func _add_minutes(n: int) -> bool:
	elapsed += n
	return _check_timeout()

func accept() -> void:
	if state != State.OFFER:
		return
	suspects.assign(order.machine.def.faults)
	state = State.SYMPTOM

func reject() -> void:
	if state != State.OFFER:
		return
	result = Result.REJECTED
	state = State.RESULT

func advance_symptom() -> void:
	if state != State.SYMPTOM:
		return
	state = State.CHECKS

func can_conclude() -> bool:
	return state == State.CHECKS and checks_done.size() >= 2 and suspects.size() >= 1

func begin_conclusion() -> void:
	if not can_conclude():
		return
	state = State.CONCLUSION

func conclude(fault_key: String) -> bool:
	if state != State.CONCLUSION:
		return false
	if not suspects.has(fault_key):
		return false
	if fault_key == String(order.fault_key):
		state = State.PARTS
		return true
	# sai: phat + loai nghi pham
	var before: int = int(game_state.money)
	elapsed += WRONG_MINUTES
	game_state.money = maxi(0, before - WRONG_MONEY)
	spent += mini(WRONG_MONEY, before)
	wrong_count += 1
	suspects.erase(fault_key)
	if wrong_count >= 2:
		game_state.uy_tin = maxi(0, int(game_state.uy_tin) - 5)
	if _check_timeout():
		return false
	state = State.CHECKS
	return false

func do_check(check_key: String) -> String:
	if state != State.CHECKS:
		return ""
	if not CHECK_KEYS.has(check_key):
		return ""
	if checks_done.has(check_key):
		return ""
	var fault := FaultCatalog.get_fault(String(order.fault_key))
	if fault == null:
		return ""
	var cell = fault.check_outcomes.get(check_key, null)
	if cell == null:
		return ""
	checks_done.append(check_key)
	var clue := String(cell.get("clue", ""))
	var ex = cell.get("excludes", [])
	for e in ex:
		suspects.erase(String(e))
	_add_minutes(CHECK_MINUTES)
	return clue

func buy_part() -> bool:
	if state != State.PARTS:
		return false
	var fault := FaultCatalog.get_fault(String(order.fault_key))
	if fault == null:
		return false
	var part := PartCatalog.get_part(fault.part_id)
	if part == null:
		return false
	var price: int = int(part.price)
	if int(game_state.money) < price:
		return false
	game_state.money = int(game_state.money) - price
	spent += price
	if _add_minutes(BUY_MINUTES):
		return true
	state = State.DISASSEMBLE
	return true

func stock_available() -> bool:
	if state != State.PARTS:
		return false
	var fault := FaultCatalog.get_fault(String(order.fault_key))
	if fault == null:
		return false
	return int(game_state.inventory.get(fault.part_id, 0)) > 0

func take_part_from_stock() -> bool:
	if not stock_available():
		return false
	var fault := FaultCatalog.get_fault(String(order.fault_key))
	if fault == null:
		return false
	game_state.inventory[fault.part_id] = int(game_state.inventory[fault.part_id]) - 1
	state = State.DISASSEMBLE
	return true

func give_up() -> void:
	if state != State.PARTS:
		return
	result = Result.LOST_MONEY
	state = State.RESULT

func disassemble() -> void:
	if state != State.DISASSEMBLE:
		return
	var cost: int = DISASSEMBLE_MINUTES * int(order.machine.def.difficulty)
	if _add_minutes(cost):
		return
	state = State.TEST

func run_test() -> void:
	if state != State.TEST:
		return
	if _add_minutes(TEST_MINUTES):
		return
	var reward: int = int(order.money_reward)
	var tip := 0
	if elapsed * 2 <= order.deadline_min:
		tip = int(reward * 0.25)
	earned = reward + tip
	game_state.money = int(game_state.money) + earned
	result = Result.DONE
	state = State.RESULT
