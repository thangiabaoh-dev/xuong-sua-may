extends "res://tests/test_case.gd"

func run() -> void:
	var packed = load("res://scenes/ui/schedule_screen.tscn") as PackedScene
	check(packed != null, "schedule_screen.tscn loads")
	if packed == null:
		return
	var scr = packed.instantiate()
	check(scr is CanvasLayer, "root CanvasLayer")
	check(not scr.visible, "starts hidden")
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = gs_script.new()
	scr.setup(gs)
	for i in range(7):
		check(scr.has_node("Root/Days/Day%d" % i), "day column %d" % i)
	var hdr0 = scr.get_node("Root/Days/Day0/Header") as Label
	check_eq(String(hdr0.text), "T2", "col0 header T2")
	var hdr6 = scr.get_node("Root/Days/Day6/Header") as Label
	check_eq(String(hdr6.text), "CN", "col6 header CN")
	var day0 = scr.get_node("Root/Days/Day0")
	check(day0.get_child_count() >= 6, "T2 column: header + 5 rows")
	var row0 = scr.get_node("Root/Days/Day0/Row0") as Label
	check(String(row0.text).contains("07:00"), "row0 shows 07:00")
	var day6 = scr.get_node("Root/Days/Day6")
	check(day6.get_child_count() >= 6, "CN column: header + 5 rows")
	check(scr.has_node("Root/HolidayList"), "holiday list exists")
	var hlist = scr.get_node("Root/HolidayList") as ItemList
	check(hlist.item_count >= 3, "3 holidays listed")

	# Tab toggle qua truc tiep _unhandled_input (khong can tree)
	var ev = InputEventKey.new()
	ev.keycode = KEY_TAB
	ev.pressed = true
	scr._unhandled_input(ev)
	check(scr.visible, "Tab press -> visible")
	ev.pressed = false
	scr._unhandled_input(ev)
	check(scr.visible, "release ignored")
	ev.pressed = true
	scr._unhandled_input(ev)
	check(not scr.visible, "Tab press again -> hidden")

	# source pin
	var f = FileAccess.open("res://scripts/ui/schedule_screen.gd", FileAccess.READ)
	check(f != null and f.get_as_text().contains("KEY_TAB"), "Tab pinned")
	check(f != null and f.get_as_text().contains("slots_for_day"), "renders via slots_for_day")
	scr.free()
