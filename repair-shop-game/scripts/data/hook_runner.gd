class_name HookRunner
extends RefCounted

const WHITELIST := ["knowledge_rate"]

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
	return out
