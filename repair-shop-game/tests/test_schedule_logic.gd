extends "res://tests/test_case.gd"

func run() -> void:
	var week = load("res://data/week_schedule.tres")
	check(week != null, "week_schedule.tres loads")
	if week == null:
		return
	check_eq(week.days.size(), 7, "7 days")
	check(week.holidays.size() >= 3, "3+ holidays")

	# weekday
	check_eq(ScheduleLogic.weekday({"year": 2026, "month": 10, "day": 5}), 1, "2026-10-05 Mon=1")
	check_eq(ScheduleLogic.weekday({"year": 2026, "month": 10, "day": 11}), 7, "2026-10-11 Sun=7")
	check_eq(ScheduleLogic.weekday({"year": 2026, "month": 4, "day": 30}), 4, "2026-04-30 Thu=4")

	var mon := {"year": 2026, "month": 10, "day": 5}
	# boundary
	var s419 = ScheduleLogic.current_slot(week, mon, 419)
	check(s419 == null, "06:59 null")
	var s420 = ScheduleLogic.current_slot(week, mon, 420)
	check(s420 != null and String(s420.kind) == "SCHOOL", "07:00 SCHOOL")
	var s689 = ScheduleLogic.current_slot(week, mon, 689)
	check(s689 != null and String(s689.kind) == "SCHOOL", "11:29 SCHOOL")
	var s690 = ScheduleLogic.current_slot(week, mon, 690)
	check(s690 != null and String(s690.kind) == "CHOICE", "11:30 CHOICE")
	var s824 = ScheduleLogic.current_slot(week, mon, 824)
	check(s824 != null and String(s824.kind) == "CHOICE", "13:44 CHOICE")
	var s825 = ScheduleLogic.current_slot(week, mon, 825)
	check(s825 != null and String(s825.kind) == "SCHOOL", "13:45 SCHOOL")
	var s1019 = ScheduleLogic.current_slot(week, mon, 1019)
	check(s1019 != null and String(s1019.kind) == "SCHOOL", "16:59 SCHOOL")
	var s1020 = ScheduleLogic.current_slot(week, mon, 1020)
	check(s1020 != null and String(s1020.kind) == "REPAIR", "17:00 REPAIR")
	var s1140 = ScheduleLogic.current_slot(week, mon, 1140)
	check(s1140 != null and String(s1140.kind) == "PROJECT", "19:00 PROJECT")
	var s1319 = ScheduleLogic.current_slot(week, mon, 1319)
	check(s1319 != null and String(s1319.kind) == "PROJECT", "21:59 PROJECT")
	var s1320 = ScheduleLogic.current_slot(week, mon, 1320)
	check(s1320 == null, "22:00 null")

	# T3: 17:00 FREE_HOME (khong REPAIR), 19:00 PROJECT
	var tue := {"year": 2026, "month": 10, "day": 6}
	var t3a = ScheduleLogic.current_slot(week, tue, 1020)
	check(t3a != null and String(t3a.kind) == "FREE_HOME", "T3 17:00 FREE_HOME")
	var t3b = ScheduleLogic.current_slot(week, tue, 1140)
	check(t3b != null and String(t3b.kind) == "PROJECT", "T3 19:00 PROJECT")

	# CN (2026-10-11)
	var sun := {"year": 2026, "month": 10, "day": 11}
	var c0 = ScheduleLogic.current_slot(week, sun, 420)
	check(c0 != null and String(c0.kind) == "FREE_HOME", "CN 07:00 FREE_HOME")
	var c1 = ScheduleLogic.current_slot(week, sun, 540)
	check(c1 != null and String(c1.kind) == "REPAIR", "CN 09:00 REPAIR")
	var c2 = ScheduleLogic.current_slot(week, sun, 720)
	check(c2 != null and String(c2.kind) == "BREAK", "CN 12:00 BREAK")
	var c3 = ScheduleLogic.current_slot(week, sun, 810)
	check(c3 != null and String(c3.kind) == "REPAIR", "CN 13:30 REPAIR")
	var c4 = ScheduleLogic.current_slot(week, sun, 1140)
	check(c4 != null and String(c4.kind) == "PROJECT", "CN 19:00 PROJECT")

	# holiday — 30-04-2026 (T5, MM-DD)
	var hol := {"year": 2026, "month": 4, "day": 30}
	check(ScheduleLogic.is_holiday(week, hol), "04-30 is holiday")
	var hs = ScheduleLogic.slots_for_day(week, hol)
	check_eq(hs.size(), 1, "holiday -> 1 slot")
	check(String(hs[0].kind) == "HOLIDAY", "holiday kind HOLIDAY")
	var hm = ScheduleLogic.current_slot(week, hol, 480)
	check(hm != null and String(hm.kind) == "HOLIDAY", "holiday overrides morning SCHOOL")
	# Tet 2026-02-17 (YYYY-MM-DD)
	var tet := {"year": 2026, "month": 2, "day": 17}
	check(ScheduleLogic.is_holiday(week, tet), "Tet YYYY-MM-DD matches")
	var may1 := {"year": 2026, "month": 5, "day": 1}
	check(not ScheduleLogic.is_holiday(week, may1), "01-05 not holiday")
