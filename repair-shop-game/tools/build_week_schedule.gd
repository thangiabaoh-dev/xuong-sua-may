extends SceneTree

const SCHOOL := ["schoolyard", "classroom", "gate"]
const CHOICE := ["library", "cafe", "street", "gate"]
const REPAIR_WD := ["workshop", "street", "gate"]
const REPAIR_CN := ["workshop", "street"]
const HOME := ["workshop"]

func _act(id: String, label: String, loc: String, minutes: int, hook: String = "") -> ActivityDef:
	var a := ActivityDef.new()
	a.id = id
	a.label = label
	a.required_location = loc
	a.minutes = minutes
	a.hook = hook
	return a

func _acts_for(kind: String, s: int, e: int) -> Array:
	match kind:
		"SCHOOL":
			return [_act("di_hoc", "Đi học", "classroom", e - s, "knowledge_rate:0.008")]
		"CHOICE":
			return [_act("doc_thu_vien", "Đọc thư viện", "library", 135, "knowledge_rate:0.030"),
				_act("project_ca_phe", "Project ở cà phê", "cafe", 135, "complete_project:p_cafe,uy_tin:8")]
		"REPAIR":
			return [_act("mo_panel", "Mở panel sửa", "workshop", 0),
				_act("nghi_tai_nha", "Nghỉ tại nhà", "workshop", 120),
				_act("doc_sach_nha", "Đọc sách ở nhà", "workshop", 120, "knowledge_rate:0.020")]
		"FREE_HOME":
			return [_act("lam_project_som", "Làm project sớm", "workshop", 120, "complete_project:p_som,uy_tin:6"),
				_act("doc_sach_nha", "Đọc sách ở nhà", "workshop", 120, "knowledge_rate:0.020"),
				_act("don_kho", "Dọn dẹp", "workshop", 120),
				_act("nghi_ngoi", "Nghỉ ngơi", "workshop", 120)]
		"PROJECT":
			return [_act("lam_project", "Làm project", "workshop", 180, "complete_project:p_noibo,uy_tin:10")]
		"BREAK":
			return [_act("nghi_giac", "Ngủ trưa", "workshop", 90)]
		"HOLIDAY":
			return [_act("su_kien_doi_thuong", "Sự kiện đổi thưởng", "workshop", 900, "knowledge_rate:0.010")]
	return []

func _slot(s: int, e: int, kind: String, locs: Array, repair := false) -> TimeSlot:
	var t := TimeSlot.new()
	t.start_minute = s
	t.end_minute = e
	t.kind = kind
	t.locations.assign(locs)
	t.repair = repair
	t.activities.assign(_acts_for(kind, s, e))
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
	for d in week.days:
		for s in d.slots:
			for a in s.activities:
				if String(a.hook) == "":
					continue
				for pair in String(a.hook).split(","):
					var idx := pair.find(":")
					if idx <= 0:
						push_error("build_week_schedule: hook sai format: %s" % a.hook)
						quit(1)
						return
					var key := pair.substr(0, idx).strip_edges()
					var value := pair.substr(idx + 1).strip_edges()
					var ok := false
					match key:
						"knowledge_rate":
							ok = value.is_valid_float() and value.to_float() >= 0.0
						"complete_project":
							ok = RegEx.create_from_string("^[a-z0-9_]+$").search(value) != null
						"uy_tin":
							ok = value.is_valid_int() and int(value) >= 0
					if not ok:
						push_error("build_week_schedule: hook khong hop le: %s" % a.hook)
						quit(1)
						return
	var err := ResourceSaver.save(week, "res://data/week_schedule.tres")
	print("WROTE res://data/week_schedule.tres err=", err)
	quit(0 if err == OK else 1)
