extends "res://tests/test_case.gd"

func run() -> void:
	var week = load("res://data/week_schedule.tres")
	check(week != null, "week loads")
	if week == null:
		return
	var mon = week.days[0]  # T2
	check_eq(mon.slots.size(), 5, "T2 5 slots")
	var school0 = mon.slots[0]
	check_eq(school0.activities.size(), 1, "SCHOOL 1 activity")
	check_eq(String(school0.activities[0].id), "di_hoc", "di_hoc id")
	check_eq(String(school0.activities[0].required_location), "classroom", "di_hoc @classroom")
	check_eq(int(school0.activities[0].minutes), 270, "sang 270")
	check_eq(int(mon.slots[2].activities[0].minutes), 195, "chieu 195")
	check_eq(int(mon.slots[1].activities.size()), 2, "CHOICE 2 activities")
	check_eq(String(mon.slots[3].activities[0].id), "mo_panel", "REPAIR mo_panel first")
	check_eq(int(mon.slots[3].activities[0].minutes), 0, "mo_panel 0 min")
	check_eq(int(mon.slots[4].activities[0].minutes), 180, "PROJECT 180")
	var t3 = week.days[1]
	check_eq(String(t3.slots[3].kind), "FREE_HOME", "T3 no REPAIR")
	check_eq(t3.slots[3].activities.size(), 4, "FREE_HOME 4 choices")
	var cn = week.days[6]
	check_eq(cn.slots.size(), 5, "CN 5 slots")
	check_eq(String(cn.slots[2].kind), "BREAK", "CN slot2 BREAK")
	check_eq(cn.slots[2].activities[0].id, "nghi_giac", "CN BREAK activity (720-810)")
	check_eq(int(cn.slots[2].activities[0].minutes), 90, "CN BREAK 90")
	check_eq(week.days[0].slots[0].activities[0].hook, "", "hook empty cycle1")
