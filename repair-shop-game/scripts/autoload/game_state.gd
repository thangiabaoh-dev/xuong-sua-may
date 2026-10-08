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

func slot() -> Resource:
	return ScheduleLogic.current_slot(week, date, minute)

func advance_to(m: int) -> void:
	minute = m
	if minute >= 1320:
		end_day()

func end_day() -> void:
	mode = GameStateMode.SUMMARIZE
	var u: int = Time.get_unix_time_from_datetime_dict(date)
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(u + 86400)
	date = {"year": int(d["year"]), "month": int(d["month"]), "day": int(d["day"])}
	minute = 420
	mode = GameStateMode.SCHEDULE

func can_enter(loc: String) -> bool:
	return ScheduleLogic.can_enter(week, date, minute, loc)
