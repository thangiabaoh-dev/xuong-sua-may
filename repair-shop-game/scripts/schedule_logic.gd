class_name ScheduleLogic
extends RefCounted

static func weekday(date: Dictionary) -> int:
	var u: int = Time.get_unix_time_from_datetime_dict(date)
	var w: int = int(Time.get_datetime_dict_from_unix_time(u)["weekday"])
	return 7 if w == 0 else w

static func is_holiday(week, date: Dictionary) -> bool:
	var mmdd := "%02d-%02d" % [int(date["month"]), int(date["day"])]
	var ymd := "%04d-%02d-%02d" % [int(date["year"]), int(date["month"]), int(date["day"])]
	for h in week.holidays:
		if h == mmdd or h == ymd:
			return true
	return false

static func slots_for_day(week, date: Dictionary) -> Array:
	if is_holiday(week, date):
		var hol := TimeSlot.new()
		hol.start_minute = 420
		hol.end_minute = 1320
		hol.kind = "HOLIDAY"
		hol.locations.assign(["workshop"])
		hol.repair = false
		return [hol]
	return week.days[weekday(date) - 1].slots

static func current_slot(week, date: Dictionary, minute: int):
	for s in slots_for_day(week, date):
		if minute >= s.start_minute and minute < s.end_minute:
			return s
	return null
