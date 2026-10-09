extends Node

var money: int = 50000
var knowledge: int = 0
var uy_tin: int = 0
var ky_luat: int = 100

const NIGHT_BAN_THRESHOLD := 50
var current_location: String = "workshop"
var inventory: Dictionary = {}

func night_banned() -> bool:
	return int(ky_luat) < NIGHT_BAN_THRESHOLD

enum GameStateMode { SCHEDULE, REPAIR, MINIGAME, SUMMARIZE }

var mode: int = GameStateMode.SCHEDULE
var date: Dictionary = {"year": 2026, "month": 10, "day": 5}
var minute: int = 420
var week: WeekSchedule = preload("res://data/week_schedule.tres")

signal schedule_changed()

var shift_used: int = 0
var today_activities: Array = []

func slot() -> Resource:
	if week == null:
		return null
	return ScheduleLogic.current_slot(week, date, minute)

func advance_to(m: int) -> void:
	minute = clampi(m, 0, 1320)
	if minute >= 1320:
		end_day()
	else:
		schedule_changed.emit()

func end_day() -> void:
	mode = GameStateMode.SUMMARIZE
	schedule_changed.emit()

func begin_new_day() -> void:
	var miss: int = 450 - school_minutes_done()
	if miss > 0:
		ky_luat -= 10 * int(ceil(float(miss) / 450.0))
	var u: int = Time.get_unix_time_from_datetime_dict(date)
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(u + 86400)
	date = {"year": int(d["year"]), "month": int(d["month"]), "day": int(d["day"])}
	minute = 420
	shift_used = 0
	today_activities.clear()
	mode = GameStateMode.SCHEDULE
	schedule_changed.emit()

func school_minutes_done() -> int:
	var total: int = 0
	for a in today_activities:
		if String(a["id"]) == "di_hoc":
			total += int(a["minutes"])
	return total

func can_enter(loc: String) -> bool:
	if week == null:
		return false
	return ScheduleLogic.can_enter(week, date, minute, loc)

var workspace_tier: int = 0
var completed_projects: Array[StringName] = []
