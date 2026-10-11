class_name ScheduleCore
extends RefCounted

const GS = preload("res://scripts/autoload/game_state.gd")

static func available(gs: Node) -> Array[ActivityDef]:
	var out: Array[ActivityDef] = []
	var slot: Resource = gs.slot()
	if slot == null:
		return out
	if String(slot.kind) == "HOLIDAY":
		var h := ActivityDef.new()
		h.id = "su_kien_doi_thuong"
		h.label = "Sự kiện đổi thưởng"
		h.required_location = ""
		h.minutes = 900
		h.hook = "knowledge_rate:0.010"
		out.append(h)
		return out
	out.assign(slot.activities)
	return out

static func reason_for(gs: Node, act: ActivityDef) -> String:
	if int(gs.mode) != GS.GameStateMode.SCHEDULE:
		return "Ngoài lịch"
	if act.required_location != "" and String(gs.current_location) != act.required_location:
		return "Cần ở: %s" % act.required_location
	return ""

static func shift_budget(gs: Node) -> int:
	if gs.week == null:
		return 0
	var total: int = 0
	var slots: Array = ScheduleLogic.slots_for_day(gs.week, gs.date)
	for s in slots:
		if bool(s.repair):
			total += int(s.end_minute) - int(s.start_minute)
	return total

static func shift_tick(gs: Node, n: int) -> bool:
	if not ScheduleLogic.is_repair_slot(gs.week, gs.date, int(gs.minute)):
		return true
	gs.shift_used = int(gs.shift_used) + n
	return int(gs.shift_used) < shift_budget(gs)

static func try_activity(gs: Node, id: String) -> Dictionary:
	var acts := available(gs)
	var act: ActivityDef = null
	for a in acts:
		if String(a.id) == id:
			act = a
			break
	if act == null:
		push_error("try_activity: id không tồn tại: %s" % id)
		return {"ok": false, "reason": "Ngoài khung giờ"}
	var reason := reason_for(gs, act)
	if reason != "":
		return {"ok": false, "reason": reason}
	var slot: Resource = gs.slot()
	var before: int = int(gs.minute)
	var new_m: int = mini(before + int(act.minutes), int(slot.end_minute))
	new_m = maxi(new_m, before)
	var consumed: int = new_m - before
	var gains := HookRunner.apply(gs, act.hook, consumed)
	if id != "mo_panel":
		var entry := {"id": String(act.id), "label": String(act.label), "minutes": consumed}
		var k := int(gains.get("knowledge", 0))
		if k > 0:
			entry["knowledge"] = k
		if gains.has("project"):
			entry["project"] = String(gains["project"])
		var ui := int(gains.get("uy_tin", 0))
		if ui > 0:
			entry["uy_tin"] = ui
		gs.today_activities.append(entry)
	gs.advance_to(new_m)
	return {"ok": true, "reason": "", "gains": gains}
