extends SceneTree

const SCHOOL := ["schoolyard", "classroom", "gate"]
const CHOICE := ["library", "cafe", "street", "gate"]
const REPAIR_WD := ["workshop", "street", "gate"]
const REPAIR_CN := ["workshop", "street"]
const HOME := ["workshop"]

func _slot(s: int, e: int, kind: String, locs: Array, repair := false) -> TimeSlot:
	var t := TimeSlot.new()
	t.start_minute = s
	t.end_minute = e
	t.kind = kind
	t.locations.assign(locs)
	t.repair = repair
	return t

func _day(rows: Array) -> DaySchedule:
	var d := DaySchedule.new()
	for r in rows:
		var repair := false
		if r.size() > 4:
			repair = r[4]
		d.slots.append(_slot(r[0], r[1], r[2], r[3], repair))
	return d

func _weekday_rows() -> Array:
	return [
		[420, 690, "SCHOOL", SCHOOL],
		[690, 825, "CHOICE", CHOICE],
		[825, 1020, "SCHOOL", SCHOOL],
		[1020, 1140, "REPAIR", REPAIR_WD, true],
		[1140, 1320, "PROJECT", HOME],
	]

func _init() -> void:
	var week := WeekSchedule.new()
	# T2
	week.days.append(_day(_weekday_rows()))
	# T3: 17:00-19:00 FREE_HOME (khong ca sua)
	var t3 := _weekday_rows()
	t3[3] = [1020, 1140, "FREE_HOME", HOME]
	week.days.append(_day(t3))
	# T4, T5, T6, T7
	for i in range(4):
		week.days.append(_day(_weekday_rows()))
	# CN
	week.days.append(_day([
		[420, 540, "FREE_HOME", HOME],
		[540, 720, "REPAIR", REPAIR_CN, true],
		[720, 810, "BREAK", HOME],
		[810, 1140, "REPAIR", REPAIR_CN, true],
		[1140, 1320, "PROJECT", HOME],
	]))
	week.holidays = PackedStringArray(["04-30", "09-02", "2026-02-17"])
	var err := ResourceSaver.save(week, "res://data/week_schedule.tres")
	print("WROTE res://data/week_schedule.tres err=", err)
	quit(0 if err == OK else 1)
