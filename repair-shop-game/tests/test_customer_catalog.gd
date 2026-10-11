extends "res://tests/test_case.gd"

const THREE := ["ban_hoc", "giao_vien", "hoai_niem"]
const TONES := ["than", "trung_tinh", "kho"]

func run() -> void:
	var all := CustomerCatalog.load_all()
	check_eq(all.size(), 5, "5 customer files")
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
	check(keys.has("truong_nhom"), "covers truong_nhom")
	check(keys.has("giam_doc"), "covers giam_doc")
	check_eq(keys.size(), 5, "keys unique")
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
	var tn := CustomerCatalog.get_customer("truong_nhom")
	check_eq(int(tn.effects["than"].get("tip_percent", 0)), 15, "truong_nhom than tip15")
	check_eq(bool(tn.effects["kho"].get("lost_order", false)), true, "truong_nhom kho lost")
	var gd := CustomerCatalog.get_customer("giam_doc")
	check_eq(int(gd.effects["than"].get("tip_percent", 0)), 20, "giam_doc than tip20")
	check_eq(int(gd.effects["trung_tinh"].get("tip_percent", 0)), 5, "giam_doc trung tinh tip5")
	check_eq(bool(gd.effects["kho"].get("lost_order", false)), true, "giam_doc kho lost")
	# catalog khop factory gating
	for k in OrderFactory.CUSTOMER_MIN_UY_TIN:
		check(keys.has(k), "factory key in catalog " + k)
	check(CustomerCatalog.get_customer("xxx") == null, "get_customer miss")
