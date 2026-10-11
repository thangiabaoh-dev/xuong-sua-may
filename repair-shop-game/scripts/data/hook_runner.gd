class_name HookRunner
extends RefCounted

const WHITELIST := ["knowledge_rate", "complete_project", "uy_tin"]
const RE_PROJ_ID := "^[a-z0-9_]+$"

static func apply(gs: Node, hook: String, consumed: int) -> Dictionary:
	var out := {}
	if hook.is_empty():
		return out
	for pair in hook.split(","):
		var idx := pair.find(":")
		if idx <= 0:
			push_warning("HookRunner: pair sai format: %s" % pair)
			continue
		var key := pair.substr(0, idx).strip_edges()
		var value := pair.substr(idx + 1).strip_edges()
		if not WHITELIST.has(key):
			push_warning("HookRunner: key khong ho tro: %s" % key)
			continue
		match key:
			"knowledge_rate":
				if not value.is_valid_float():
					push_warning("HookRunner: value khong phai so: %s" % value)
					continue
				var rate := value.to_float()
				if rate < 0.0:
					push_warning("HookRunner: rate am: %s" % value)
					continue
				var rem: float = float(gs.knowledge_remainder) + rate * float(consumed)
				var n := int(rem)
				rem -= float(n)
				gs.knowledge_remainder = rem
				gs.knowledge = int(gs.knowledge) + n
				if n > 0:
					out["knowledge"] = n
			"complete_project":
				var re := RegEx.create_from_string(RE_PROJ_ID)
				if re.search(value) == null:
					push_warning("HookRunner: project id khong hop le: %s" % value)
					continue
				gs.project_count = int(gs.project_count) + 1
				if not gs.completed_projects.has(StringName(value)):
					gs.completed_projects.append(StringName(value))
				out["project"] = value
			"uy_tin":
				if not value.is_valid_int():
					push_warning("HookRunner: uy_tin khong phai so nguyen: %s" % value)
					continue
				var n2 := int(value)
				if n2 < 0:
					push_warning("HookRunner: uy_tin am: %s" % value)
					continue
				gs.uy_tin = clampi(int(gs.uy_tin) + n2, 0, 100)
				if n2 > 0:
					out["uy_tin"] = n2
	return out
