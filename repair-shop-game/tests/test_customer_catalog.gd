extends "res://tests/test_case.gd"

const THREE := ["ban_hoc", "giao_vien", "hoai_niem"]
const TONES := ["than", "trung_tinh", "kho"]

func run() -> void:
	var all := CustomerCatalog.load_all()
	check_eq(all.size(), 3, "3 customer files")
	var keys := {}
	for c in all:
		keys[c.key] = true
		check(c.display_name != "" and c.risk_warning != "", "names " + c.key)
		for t in TONES:
			check(String(c.reactions.get(t, "")) != "", "reaction %s/%s" % [c.key, t])
			var fx = c.effects.get(t, null)
			check(fx != null, "effect exists %s/%s" % [c.key, t])
	for k in THREE:
		check(keys.has(k), "covers " + k)
	check_eq(keys.size(), 3, "keys unique")
	# effect so lieu chot §8
	var bh := CustomerCatalog.get_customer("ban_hoc")
	check_eq(int(bh.effects["than"].get("tip_percent", 0)), 10, "ban_hoc than tip10")
	check_eq(bool(bh.effects["kho"].get("lost_order", false)), true, "ban_hoc kho lost")
	check_eq(int(bh.effects["trung_tinh"].get("tip_percent", 0)), 0, "neutral no tip")
	var gv := CustomerCatalog.get_customer("giao_vien")
	check_eq(int(gv.effects["than"].get("uy_tin", 0)), 3, "giao_vien than +3")
	check_eq(int(gv.effects["kho"].get("uy_tin", 0)), -3, "giao_vien kho -3")
	var hn := CustomerCatalog.get_customer("hoai_niem")
	check_eq(int(hn.effects["than"].get("uy_tin", 0)), 3, "hoai_niem than +3")
	check(String(hn.effects["than"].get("story", "")) != "", "hoai_niem story")
	check_eq(int(hn.effects["kho"].get("uy_tin", 0)), -10, "hoai_niem kho -10")
	# catalog khop factory gating
	for k in OrderFactory.CUSTOMER_MIN_UY_TIN:
		check(keys.has(k), "factory key in catalog " + k)
	check(CustomerCatalog.get_customer("xxx") == null, "get_customer miss")
