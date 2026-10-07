extends CanvasLayer

const CHECK_LABELS: Array[String] = ["Đo nguồn", "Nghe quạt", "Kiểm tra RAM", "Nhìn bo mạch"]
const CUSTOMER_NAMES := {"ban_hoc": "Bạn học", "giao_vien": "Giáo viên", "hoai_niem": "Người hoài niệm"}

var session: RepairSession
var game_state
var rng: RandomNumberGenerator
var _built := false
var _last_log := ""
var bought_this_visit := false

func _ready() -> void:
	if session != null:
		return
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		setup(gs)

func setup(p_state, p_rng: RandomNumberGenerator = null) -> void:
	game_state = p_state
	if p_rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	else:
		rng = p_rng
	if not _built:
		_build_ui()
		_connect_signals()
		_built = true
	open_new_order()

func open_new_order() -> void:
	_last_log = ""
	var knowledge := 0
	var uy := 0
	if game_state != null:
		knowledge = int(game_state.knowledge)
		uy = int(game_state.uy_tin)
	var order := OrderFactory.make(rng, knowledge, uy)
	if order == null:
		session = null
	else:
		session = RepairSession.new(order, game_state, rng)
	_render()

func _customer_name(key: String) -> String:
	return String(CUSTOMER_NAMES.get(key, key))

func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var header := HBoxContainer.new()
	header.name = "Header"
	root.add_child(header)
	var lbl_money := Label.new()
	lbl_money.name = "LblMoney"
	header.add_child(lbl_money)
	var lbl_clock := Label.new()
	lbl_clock.name = "LblClock"
	header.add_child(lbl_clock)
	var lbl_uytin := Label.new()
	lbl_uytin.name = "LblUyTin"
	header.add_child(lbl_uytin)
	var btn_close := Button.new()
	btn_close.name = "BtnClose"
	btn_close.text = "✕"
	header.add_child(btn_close)

	var screens := Control.new()
	screens.name = "Screens"
	root.add_child(screens)

	# OFFER
	var offer := Control.new()
	offer.name = "ScreenOffer"
	screens.add_child(offer)
	for n in ["LblMachine", "LblCustomer", "LblQuote", "LblDeadline", "LblReward", "LblWarn"]:
		var l := Label.new()
		l.name = n
		offer.add_child(l)
	var btn_accept := Button.new()
	btn_accept.name = "BtnAccept"
	btn_accept.text = "Nhận"
	offer.add_child(btn_accept)
	var btn_reject := Button.new()
	btn_reject.name = "BtnReject"
	btn_reject.text = "Từ chối"
	offer.add_child(btn_reject)

	# SYMPTOM
	var symptom := Control.new()
	symptom.name = "ScreenSymptom"
	screens.add_child(symptom)
	var lbl_symptom := Label.new()
	lbl_symptom.name = "LblSymptom"
	symptom.add_child(lbl_symptom)
	var btn_next := Button.new()
	btn_next.name = "BtnSymptomNext"
	btn_next.text = "Tiếp →"
	symptom.add_child(btn_next)

	# CHECKS
	var checks := Control.new()
	checks.name = "ScreenChecks"
	screens.add_child(checks)
	for i in 4:
		var b := Button.new()
		b.name = "BtnCheck%d" % i
		b.text = CHECK_LABELS[i]
		checks.add_child(b)
	var lbl_log := Label.new()
	lbl_log.name = "LblLog"
	checks.add_child(lbl_log)
	var lbl_sus := Label.new()
	lbl_sus.name = "LblSuspects"
	checks.add_child(lbl_sus)
	var btn_conc := Button.new()
	btn_conc.name = "BtnConclusion"
	btn_conc.text = "Kết luận"
	checks.add_child(btn_conc)

	# CONCLUSION
	var conc := Control.new()
	conc.name = "ScreenConclusion"
	screens.add_child(conc)
	var box := VBoxContainer.new()
	box.name = "ConclusionBox"
	conc.add_child(box)

	# PARTS
	var parts := Control.new()
	parts.name = "ScreenParts"
	screens.add_child(parts)
	var lbl_part := Label.new()
	lbl_part.name = "LblPart"
	parts.add_child(lbl_part)
	var lbl_money2 := Label.new()
	lbl_money2.name = "LblMoney2"
	parts.add_child(lbl_money2)
	var btn_buy := Button.new()
	btn_buy.name = "BtnBuy"
	btn_buy.text = "Mua ngay (+10')"
	parts.add_child(btn_buy)
	var btn_take := Button.new()
	btn_take.name = "BtnTake"
	btn_take.text = "Lấy từ kho (0đ)"
	parts.add_child(btn_take)
	var btn_give := Button.new()
	btn_give.name = "BtnGiveUp"
	btn_give.text = "Từ bỏ"
	parts.add_child(btn_give)

	# DISASSEMBLE
	var dis := Control.new()
	dis.name = "ScreenDisassemble"
	screens.add_child(dis)
	var lbl_action := Label.new()
	lbl_action.name = "LblAction"
	dis.add_child(lbl_action)
	var btn_dis := Button.new()
	btn_dis.name = "BtnDisassemble"
	btn_dis.text = "Tháo – lắp"
	dis.add_child(btn_dis)

	# TEST
	var test_scr := Control.new()
	test_scr.name = "ScreenTest"
	screens.add_child(test_scr)
	var btn_run := Button.new()
	btn_run.name = "BtnRunTest"
	btn_run.text = "Bật nguồn"
	test_scr.add_child(btn_run)

	# TONE
	var tone := Control.new()
	tone.name = "ScreenTone"
	screens.add_child(tone)
	var lbl_q := Label.new()
	lbl_q.name = "LblToneQuestion"
	lbl_q.text = "Bạn nói chuyện với khách thế nào?"
	tone.add_child(lbl_q)
	var btn_than := Button.new()
	btn_than.name = "BtnToneThan"
	btn_than.text = "Thân"
	tone.add_child(btn_than)
	var btn_neutral := Button.new()
	btn_neutral.name = "BtnToneNeutral"
	btn_neutral.text = "Trung tính"
	tone.add_child(btn_neutral)
	var btn_kho := Button.new()
	btn_kho.name = "BtnToneKho"
	btn_kho.text = "Khô"
	tone.add_child(btn_kho)
	var lbl_risk := Label.new()
	lbl_risk.name = "LblRisk"
	tone.add_child(lbl_risk)

	# RESULT
	var res := Control.new()
	res.name = "ScreenResult"
	screens.add_child(res)
	var lbl_res := Label.new()
	lbl_res.name = "LblResult"
	res.add_child(lbl_res)
	var lbl_reaction := Label.new()
	lbl_reaction.name = "LblReaction"
	res.add_child(lbl_reaction)
	var btn_cont := Button.new()
	btn_cont.name = "BtnContinue"
	btn_cont.text = "Tiếp tục"
	res.add_child(btn_cont)

	# SHOP
	var shop := Control.new()
	shop.name = "ScreenShop"
	screens.add_child(shop)
	var lbl_info := Label.new()
	lbl_info.name = "LblShopInfo"
	shop.add_child(lbl_info)
	var shop_box := VBoxContainer.new()
	shop_box.name = "ShopBox"
	shop.add_child(shop_box)
	for part in PartCatalog.load_all():
		var sb := Button.new()
		sb.text = "%s — %dđ" % [String(part.name), int(part.price)]
		sb.set_meta("part_id", String(part.id))
		sb.set_meta("price", int(part.price))
		sb.pressed.connect(_on_shop_buy.bind(String(part.id)))
		shop_box.add_child(sb)
	var btn_skip := Button.new()
	btn_skip.name = "BtnSkip"
	btn_skip.text = "Ra tiệm →"
	shop.add_child(btn_skip)

	var btn_open := Button.new()
	btn_open.name = "BtnOpen"
	btn_open.text = "Đơn mới"
	btn_open.visible = false
	add_child(btn_open)

func _connect_signals() -> void:
	get_node("Root/Screens/ScreenOffer/BtnAccept").pressed.connect(_on_accept)
	get_node("Root/Screens/ScreenOffer/BtnReject").pressed.connect(_on_reject)
	get_node("Root/Screens/ScreenSymptom/BtnSymptomNext").pressed.connect(_on_symptom_next)
	for i in 4:
		var b: Button = get_node("Root/Screens/ScreenChecks/BtnCheck%d" % i)
		b.pressed.connect(_on_check.bind(i))
	get_node("Root/Screens/ScreenChecks/BtnConclusion").pressed.connect(_on_begin_conclusion)
	get_node("Root/Screens/ScreenParts/BtnBuy").pressed.connect(_on_buy)
	get_node("Root/Screens/ScreenParts/BtnTake").pressed.connect(_on_take)
	get_node("Root/Screens/ScreenParts/BtnGiveUp").pressed.connect(_on_give_up)
	get_node("Root/Screens/ScreenDisassemble/BtnDisassemble").pressed.connect(_on_disassemble)
	get_node("Root/Screens/ScreenTest/BtnRunTest").pressed.connect(_on_run_test)
	get_node("Root/Screens/ScreenTone/BtnToneThan").pressed.connect(_on_tone.bind("than"))
	get_node("Root/Screens/ScreenTone/BtnToneNeutral").pressed.connect(_on_tone.bind("trung_tinh"))
	get_node("Root/Screens/ScreenTone/BtnToneKho").pressed.connect(_on_tone.bind("kho"))
	get_node("Root/Screens/ScreenResult/BtnContinue").pressed.connect(_on_continue)
	get_node("Root/Screens/ScreenShop/BtnSkip").pressed.connect(_on_skip)
	get_node("Root/Header/BtnClose").pressed.connect(_on_close)
	get_node("BtnOpen").pressed.connect(_on_open)

func _on_accept() -> void:
	if session == null:
		return
	session.accept()
	_render()

func _on_reject() -> void:
	if session == null:
		return
	session.reject()
	_render()

func _on_symptom_next() -> void:
	if session == null:
		return
	session.advance_symptom()
	_render()

func _on_check(idx: int) -> void:
	if session == null:
		return
	var key: String = RepairSession.CHECK_KEYS[idx]
	var clue := session.do_check(key)
	if clue != "":
		_last_log = clue
	_render()

func _on_begin_conclusion() -> void:
	if session == null:
		return
	session.begin_conclusion()
	_render()

func _on_conclude_key(key: String) -> void:
	if session == null:
		return
	session.conclude(key)
	_render()

func _on_buy() -> void:
	if session == null:
		return
	session.buy_part()
	_render()

func _on_take() -> void:
	if session == null:
		return
	session.take_part_from_stock()
	_render()

func _on_give_up() -> void:
	if session == null:
		return
	session.give_up()
	_render()

func _on_disassemble() -> void:
	if session == null:
		return
	session.disassemble()
	_render()

func _on_run_test() -> void:
	if session == null:
		return
	session.run_test()
	_render()

func _on_tone(tone_key: String) -> void:
	if session == null:
		return
	session.choose_tone(tone_key)
	_render()

func _on_continue() -> void:
	open_shop()

func _on_skip() -> void:
	open_new_order()

func _on_shop_buy(part_id: String) -> void:
	if bought_this_visit:
		return
	var part := PartCatalog.get_part(part_id)
	if part == null:
		return
	if int(game_state.money) < int(part.price):
		(get_node("Root/Screens/ScreenShop/LblShopInfo") as Label).text = "Cần %dđ" % int(part.price)
		return
	game_state.money = int(game_state.money) - int(part.price)
	game_state.inventory[part_id] = int(game_state.inventory.get(part_id, 0)) + 1
	bought_this_visit = true
	(get_node("Root/Screens/ScreenShop/LblShopInfo") as Label).text = "Đã mua: %s" % String(part.name)
	for c in (get_node("Root/Screens/ScreenShop/ShopBox") as Container).get_children():
		(c as Button).disabled = true

func open_shop() -> void:
	if not _built:
		return
	bought_this_visit = false
	for c in (get_node("Root/Screens/ScreenShop/ShopBox") as Container).get_children():
		(c as Button).disabled = false
	(get_node("Root/Screens/ScreenShop/LblShopInfo") as Label).text = "Chọn linh kiện cho kho"
	_hide_all()
	get_node("Root/Screens/ScreenShop").visible = true

func _on_close() -> void:
	get_node("Root").visible = false
	get_node("BtnOpen").visible = true

func _on_open() -> void:
	if session == null or int(session.state) == int(RepairSession.State.RESULT):
		open_new_order()
	get_node("Root").visible = true
	get_node("BtnOpen").visible = false

func _hide_all() -> void:
	for n in ["ScreenOffer", "ScreenSymptom", "ScreenChecks", "ScreenConclusion", "ScreenParts", "ScreenDisassemble", "ScreenTest", "ScreenTone", "ScreenResult", "ScreenShop"]:
		get_node("Root/Screens/" + n).visible = false

func _render() -> void:
	if not _built:
		return
	if session == null:
		_hide_all()
		get_node("Root/Screens/ScreenResult").visible = true
		get_node("Root/Screens/ScreenResult/LblResult").text = "Hết đơn hôm nay"
		return
	# header
	(get_node("Root/Header/LblMoney") as Label).text = "💰 %dđ" % int(game_state.money)
	(get_node("Root/Header/LblClock") as Label).text = "%d/%d'" % [int(session.elapsed), int(session.order.deadline_min)]
	(get_node("Root/Header/LblUyTin") as Label).text = "⭐ %d" % int(game_state.uy_tin)
	_hide_all()
	var st: int = int(session.state)
	var fault := FaultCatalog.get_fault(String(session.order.fault_key))
	if st == int(RepairSession.State.OFFER):
		var scr = get_node("Root/Screens/ScreenOffer")
		scr.visible = true
		var era_txt := "Hiện đại" if int(session.order.machine.def.era) == 0 else "Cổ"
		(get_node("Root/Screens/ScreenOffer/LblMachine") as Label).text = "%s (%s)" % [String(session.order.machine.def.model), era_txt]
		(get_node("Root/Screens/ScreenOffer/LblCustomer") as Label).text = _customer_name(String(session.order.customer_key))
		(get_node("Root/Screens/ScreenOffer/LblQuote") as Label).text = String(session.order.symptom_quote)
		(get_node("Root/Screens/ScreenOffer/LblDeadline") as Label).text = "Hạn: %d phút" % int(session.order.deadline_min)
		(get_node("Root/Screens/ScreenOffer/LblReward") as Label).text = "Tiền công: %dđ" % int(session.order.money_reward)
		var warn: Label = get_node("Root/Screens/ScreenOffer/LblWarn")
		var wp := PartCatalog.get_part(fault.part_id) if fault != null else null
		var stocked := false
		if fault != null:
			stocked = int(game_state.inventory.get(fault.part_id, 0)) > 0
		if wp != null and not stocked and int(game_state.money) < int(wp.price):
			warn.text = "Cần %dđ để mua %s" % [int(wp.price), String(wp.name)]
			warn.visible = true
		else:
			warn.text = ""
			warn.visible = false
	elif st == int(RepairSession.State.SYMPTOM):
		get_node("Root/Screens/ScreenSymptom").visible = true
		(get_node("Root/Screens/ScreenSymptom/LblSymptom") as Label).text = String(session.order.symptom_quote)
	elif st == int(RepairSession.State.CHECKS):
		get_node("Root/Screens/ScreenChecks").visible = true
		for i in 4:
			var key: String = RepairSession.CHECK_KEYS[i]
			(get_node("Root/Screens/ScreenChecks/BtnCheck%d" % i) as Button).disabled = session.checks_done.has(key)
		(get_node("Root/Screens/ScreenChecks/BtnConclusion") as Button).disabled = not session.can_conclude()
		(get_node("Root/Screens/ScreenChecks/LblLog") as Label).text = _last_log
		(get_node("Root/Screens/ScreenChecks/LblSuspects") as Label).text = "Nghi phạm: %d" % session.suspects.size()
	elif st == int(RepairSession.State.CONCLUSION):
		get_node("Root/Screens/ScreenConclusion").visible = true
		var box: Container = get_node("Root/Screens/ScreenConclusion/ConclusionBox")
		for c in box.get_children():
			box.remove_child(c)
			c.free()
		for sus in session.suspects:
			var f := FaultCatalog.get_fault(String(sus))
			var b := Button.new()
			b.text = String(f.display_name) if f != null else String(sus)
			b.pressed.connect(_on_conclude_key.bind(String(sus)))
			box.add_child(b)
	elif st == int(RepairSession.State.PARTS):
		get_node("Root/Screens/ScreenParts").visible = true
		if fault != null:
			var pp := PartCatalog.get_part(fault.part_id)
			if pp != null:
				(get_node("Root/Screens/ScreenParts/LblPart") as Label).text = "%s — %dđ" % [String(pp.name), int(pp.price)]
		(get_node("Root/Screens/ScreenParts/LblMoney2") as Label).text = "Số dư: %dđ" % int(game_state.money)
		var has_stock := session.stock_available()
		(get_node("Root/Screens/ScreenParts/BtnTake") as Button).visible = has_stock
		(get_node("Root/Screens/ScreenParts/BtnBuy") as Button).visible = not has_stock
	elif st == int(RepairSession.State.DISASSEMBLE):
		get_node("Root/Screens/ScreenDisassemble").visible = true
		var mg := String(fault.minigame) if fault != null else ""
		(get_node("Root/Screens/ScreenDisassemble/LblAction") as Label).text = "Tháo – lắp (%s)" % mg
	elif st == int(RepairSession.State.TEST):
		get_node("Root/Screens/ScreenTest").visible = true
	elif st == int(RepairSession.State.TONE):
		get_node("Root/Screens/ScreenTone").visible = true
		var cust := CustomerCatalog.get_customer(String(session.order.customer_key))
		(get_node("Root/Screens/ScreenTone/LblRisk") as Label).text = String(cust.risk_warning) if cust != null else ""
	elif st == int(RepairSession.State.RESULT):
		get_node("Root/Screens/ScreenResult").visible = true
		var txt := ""
		match int(session.result):
			int(RepairSession.Result.REJECTED):
				txt = "Từ chối đơn"
			int(RepairSession.Result.LOST_TIME):
				txt = "Hết giờ — khách bỏ đi"
			int(RepairSession.Result.LOST_MONEY):
				txt = "Hết tiền — bỏ đơn"
			int(RepairSession.Result.LOST_TONE):
				txt = "Khách bỏ đi — mất đơn (tone khô)"
			int(RepairSession.Result.DONE):
				var tip: int = int(session.earned) - int(session.order.money_reward)
				txt = "Xong! +%dđ (tip %d)" % [int(session.earned), tip]
		(get_node("Root/Screens/ScreenResult/LblResult") as Label).text = txt
		(get_node("Root/Screens/ScreenResult/LblReaction") as Label).text = session.tone_reaction
