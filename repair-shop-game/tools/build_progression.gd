extends SceneTree

func _rule(id: String, kind: String, cond: String) -> UnlockRule:
	var r := UnlockRule.new()
	r.id = id
	r.target_kind = kind
	r.target_id = id
	r.condition = cond
	r.enabled = true
	return r

func _init() -> void:
	var set := UnlockRuleSet.new()
	set.rules = [
		_rule("may_co", "machine", "knowledge >= 50"),
		_rule("may_phuc_tap", "machine", "knowledge >= 80"),
		_rule("khach_giao_vien", "customer", "uy_tin >= 60"),
		_rule("khach_phong_tin", "customer", "uy_tin >= 90 and workspace_tier >= 1"),
	]
	var err := ResourceSaver.save(set, "res://data/unlock_rules.tres")
	print("unlock_rules.tres save err=", err)
	quit(0)
