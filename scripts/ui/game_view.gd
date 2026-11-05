extends Control
## Schermata di gioco: scena 3D, barra in alto, pannello informazioni a sinistra, pannello delle
## decisioni a destra (piano degli spostamenti, ripartizione del combattimento base, schieramento e
## piani dei Tac-turni), registro in basso, sipario per il gioco a turno sullo stesso dispositivo,
## risultato finale con replay dell'intera partita.

const D = preload("res://scripts/data/sf_data.gd")
const FxScript = preload("res://scripts/ui/fx.gd")

var main
var config: Dictionary
var eng: SFEngine
var board: Board3D
var fx
var online: OnlineSession
var viewer := 0
var hotseat := false
var req: Dictionary = {}
var seat := -1
var save_code := ""

# interfaccia
var top_turn: Label
var top_phase: Label
var info_box: VBoxContainer
var act_panel: PanelContainer
var act_box: VBoxContainer
var log_label: RichTextLabel
var hover_label: Label
var curtain: Control
var toast: Label
var log_overlay: Control
var btn_style: Button
var btn_tac: Button
var result_box: Control
var wait_label: Label

# piano stellare
var plot := {}
var sel := ""
var cur_z := 0
# combattimento base
var alloc_att := {}
var alloc_brk := {}
var alloc_ref := false
var alloc_nova := false
# tattico
var dep := {}
var tplan := {}
var tsel := ""
var tz := 0
var tpick := ""          # "a1" / "a2" mentre si sceglie la destinazione di un Tac-spostamento
# replay
var replay_i := -1
var replay_play := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	eng = SFEngine.new()
	var cfg := config.duplicate()
	cfg.erase("online")
	eng.setup(cfg)
	if config.has("preload"):
		eng.preload_acts = config["preload"]
		save_code = str(config.get("save_code", ""))
	add_child(eng)
	online = config.get("online", null)
	if online != null:
		add_child(online)
		online.view = self
		eng.online = online
	# chi guarda
	var hs := []
	for i in eng.players.size():
		if not eng.players[i]["ai"]:
			hs.append(i)
	if online != null:
		viewer = online.seat
	elif hs.size() == 1:
		viewer = hs[0]
	elif hs.is_empty():
		viewer = -2
	else:
		viewer = -1
		hotseat = true
	board = Board3D.new()
	add_child(board)
	board.setup(eng, viewer, str(config.get("style", "reborn")))
	board.picked_unit.connect(_on_pick_unit)
	board.picked_hex.connect(_on_pick_hex)
	board.picked_tac.connect(_on_pick_tac)
	board.hover_hex.connect(_on_hover)
	fx = FxScript.new()
	fx.board = board
	fx.eng = eng
	add_child(fx)
	_build_ui()
	eng.decision_requested.connect(_on_request)
	eng.changed.connect(_refresh)
	eng.log_added.connect(_on_log)
	eng.fx.connect(_on_fx)
	eng.game_ended.connect(_on_end)
	_focus_home()
	if online != null and online.role != "host":
		online.heartbeat_loop()
	await get_tree().process_frame
	eng.run()


func _focus_home() -> void:
	var s := viewer if viewer >= 0 else 0
	for u in eng.live(s, "gate"):
		board.focus(Hex.world(u["lz"]), 46.0)
		return
	for u in eng.live(s, "sf"):
		board.focus(Hex.world(u["lz"]), 46.0)
		return


# ================================================================ costruzione interfaccia

func _build_ui() -> void:
	# barra in alto
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.02, 0.02, 0.88), UI.PINK_D, 0, 0, 8))
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size = Vector2(0, 58)
	add_child(top)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	top.add_child(hb)
	hb.add_child(UI.title("StarForce", 30))
	var sc_l := UI.head("%s  |  %s" % [eng.sc["nome"], {"base": "Base", "modificato": "Base con randomizzatore", "avanzato": "Avanzato"}[eng.mode]], 17, UI.PINK_L)
	sc_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(sc_l)
	top_turn = UI.head("", 18, UI.YELLOW)
	top_turn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(top_turn)
	top_phase = UI.label("", 18, UI.TEXT)
	top_phase.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(top_phase)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	btn_tac = UI.button("Display tattico", 0, 42, 17)
	btn_tac.visible = false
	btn_tac.pressed.connect(func():
		board.show_tactical(not board.tactical)
		btn_tac.text = "Display stellare" if board.tactical else "Display tattico")
	hb.add_child(btn_tac)
	btn_style = UI.button("Grafica: Reborn" if board.style == "reborn" else "Grafica: originale", 0, 42, 17)
	btn_style.pressed.connect(func():
		board.set_style("originale" if board.style == "reborn" else "reborn")
		btn_style.text = "Grafica: Reborn" if board.style == "reborn" else "Grafica: originale")
	hb.add_child(btn_style)
	var bn := UI.button("Nomi: principali", 0, 42, 17)
	bn.pressed.connect(func():
		var lv := (board.show_names + 1) % 3
		board.set_names(lv)
		bn.text = ["Nomi: nessuno", "Nomi: principali", "Nomi: tutti"][lv])
	hb.add_child(bn)
	var bl := UI.button("Registro", 0, 42, 17)
	bl.pressed.connect(_toggle_log)
	hb.add_child(bl)
	var br := UI.button("Regole", 0, 42, 17)
	br.pressed.connect(_show_rules_overlay)
	hb.add_child(br)
	if online == null:
		var bs := UI.button("Salva", 0, 42, 17)
		bs.pressed.connect(_save)
		hb.add_child(bs)
	var bm := UI.button("Menu", 0, 42, 17)
	bm.pressed.connect(_quit)
	hb.add_child(bm)
	# pannello informazioni (sinistra)
	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", UI.panel_style(0.82))
	lp.position = Vector2(10, 70)
	lp.custom_minimum_size = Vector2(360, 0)
	add_child(lp)
	info_box = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 6)
	lp.add_child(info_box)
	# pannello azioni (destra)
	act_panel = PanelContainer.new()
	act_panel.add_theme_stylebox_override("panel", UI.panel_style(0.93))
	act_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	act_panel.offset_left = -470
	act_panel.offset_right = -10
	act_panel.offset_top = 70
	act_panel.offset_bottom = -150
	act_panel.anchor_bottom = 1.0
	add_child(act_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	act_panel.add_child(scroll)
	act_box = VBoxContainer.new()
	act_box.add_theme_constant_override("separation", 8)
	act_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_box.custom_minimum_size = Vector2(430, 0)
	scroll.add_child(act_box)
	act_panel.visible = false
	# registro (basso)
	var bp := PanelContainer.new()
	bp.add_theme_stylebox_override("panel", UI.box(Color(0.04, 0.02, 0.02, 0.82), UI.PINK_D, 1, 6, 8))
	bp.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bp.offset_top = -140
	bp.offset_bottom = -8
	bp.offset_left = 10
	bp.offset_right = -10
	add_child(bp)
	var bv := VBoxContainer.new()
	bp.add_child(bv)
	hover_label = UI.mono("", 17, UI.YELLOW_L)
	bv.add_child(hover_label)
	log_label = UI.rich(17)
	log_label.fit_content = false
	log_label.custom_minimum_size = Vector2(0, 92)
	log_label.scroll_following = true
	log_label.scroll_active = true
	bv.add_child(log_label)
	wait_label = UI.head("", 20, UI.YELLOW)
	wait_label.position = Vector2(390, 76)
	add_child(wait_label)
	toast = UI.head("", 22, UI.YELLOW_L)
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.position.y = 90
	toast.visible = false
	add_child(toast)
	_refresh()


func _say(t: String, sec := 3.0) -> void:
	toast.text = t
	toast.visible = true
	toast.position.x = (size.x - toast.get_minimum_size().x) * 0.5
	var my := t
	await get_tree().create_timer(sec).timeout
	if toast.text == my:
		toast.visible = false


func _clear(box: Container) -> void:
	for c in box.get_children():
		c.queue_free()


# ================================================================ aggiornamenti

func _refresh() -> void:
	if eng == null:
		return
	top_turn.text = "Turno %d" % eng.turn if eng.turn > 0 else ("Preliminari" if eng.turn < 0 else "Preparazione")
	var ph := {"plot": "piano degli spostamenti", "shift": "spostamenti", "combat": "combattimento", "end": "fine turno", "setup": "preparazione", "over": "partita finita"}
	top_phase.text = ph.get(eng.phase, eng.phase)
	if eng.tac != null:
		top_phase.text = "Tactical Display, Tac-turno %d" % eng.tac.tt
	btn_tac.visible = eng.tac != null
	board.viewer = viewer
	board.refresh()
	if board.tactical and eng.tac != null:
		board.refresh_tac()
	_info()


func _info() -> void:
	_clear(info_box)
	info_box.add_child(UI.head("Forze in campo", 18, UI.YELLOW))
	for s in eng.sides.size():
		var sd: Dictionary = eng.sides[s]
		var row := HBoxContainer.new()
		var chip := ColorRect.new()
		chip.color = UI.side_color(sd["set"])
		chip.custom_minimum_size = Vector2(16, 16)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chip)
		var nsf := 0
		var ng := 0
		for u in eng.live(s):
			if u["kind"] == "sf":
				nsf += 1
			else:
				ng += 1
		var who := eng.pname(s)
		if eng.players[s]["ai"]:
			who += " (IA)"
		if sd["perso"]:
			who += ", fuori gara"
		var l := UI.label("%s\n%d StarForce, %d StarGate%s" % [who, nsf, ng, ("  |  punti %d" % eng.vp[s]) if eng.xeno > 0 or eng.scn_id == 38 else ""], 16)
		row.add_child(l)
		info_box.add_child(row)
	if eng.scn_id == 38 and not eng.rescue.is_empty():
		info_box.add_child(UI.label("Popolazione sul pianeta: %d\nSalvati: %d  |  StarForce perse: %d" % [eng.rescue["pop"], eng.rescue["saved"], eng.rescue["lost_sf"]], 16, UI.YELLOW_L))
	var sel_id := sel if sel != "" else tsel
	if sel_id != "" and eng.units.has(sel_id):
		var u: Dictionary = eng.units[sel_id]
		info_box.add_child(UI.hsep())
		var nm: String = eng.uname(u)
		var txt := "%s\n%s" % [nm.substr(0, 1).to_upper() + nm.substr(1), Hex.fmt(u["lz"])]
		if eng.neutralized(u):
			txt += "\nneutralizzata in questo turno"
		if int(u.get("load", 0)) > 0:
			txt += "\na bordo: profughi"
		info_box.add_child(UI.label(txt, 16, UI.PINK_L))


func _on_log(t: String) -> void:
	var col := "#efe6e2"
	if t.begins_with("—"):
		col = "#f6d01e"
	elif t.begins_with("Vince") or t.begins_with("Partita"):
		col = "#fff0a0"
	log_label.append_text("[color=%s]%s[/color]\n" % [col, t])


func _on_fx(kind: String, seg: Dictionary) -> void:
	if eng.replaying():
		return
	match kind:
		"tac_start":
			board.show_tactical(true)
			btn_tac.visible = true
			btn_tac.text = "Display stellare"
		"tac_end":
			await get_tree().create_timer(1.0).timeout
			board.show_tactical(false)
			btn_tac.text = "Display tattico"
		"combat":
			board.focus(Hex.world(seg["lz"]), 34.0)
	_refresh()
	fx.play(kind, seg)


func _on_hover(h: int) -> void:
	if h < 0:
		hover_label.text = ""
		if sel == "":
			board.set_cursor(null)
		return
	var txt := "Esagono %04d  |  limite Zulu +/-%d" % [h, Hex.zlimit(h)]
	if eng.stars.has(h):
		for st in eng.stars[h]:
			txt += "  |  %s (%s)" % [st["name"], Hex.fmt(Hex.lz(h, int(st["z"])))]
	if req.get("type", "") == "plot" and sel != "":
		var u: Dictionary = eng.units[sel]
		var to := Hex.lz(h, clampi(cur_z, -Hex.zlimit(h), Hex.zlimit(h)))
		var trial := plot.duplicate(true)
		trial[sel] = {"c": "", "to": to}
		var r: Dictionary = eng.resolve_plot(seat, trial).get(sel, {})
		if not r.is_empty():
			txt += "  |  verso %s: %d Lite, %s %s" % [Hex.fmt(to), int(r["d"]), r["c"], eng.col_name(int(r["col"]))]
			board.set_cursor(to, _col_color(int(r["col"])))
	hover_label.text = txt


func _col_color(col: int) -> Color:
	if col <= 0:
		return UI.GREEN
	if col <= 2:
		return UI.YELLOW
	if col <= 4:
		return UI.ORANGE
	return UI.RED


# ================================================================ decisioni

func _on_request(r: Dictionary) -> void:
	req = r
	seat = int(r["seat"])
	wait_label.text = ""
	if hotseat:
		_curtain_for(seat)
		return
	_begin_request()


func _begin_request() -> void:
	match str(req["type"]):
		"plot":
			_start_plot()
		"alloc":
			_start_alloc()
		"tdeploy":
			_start_deploy()
		"tplot":
			_start_tplot()
		"xsign":
			_ask_xsign()
		_:
			_provide(null)


func _provide(r) -> void:
	act_panel.visible = false
	_clear(act_box)
	board.set_cursor(null)
	board.set_range(null, 0)
	board.set_plot_lines([])
	board.set_tac_cursor(null)
	board.show_casts([])
	sel = ""
	tsel = ""
	board.select("")
	req = {}
	if hotseat:
		viewer = -1
		board.viewer = -1
	_refresh()
	eng.provide_decision(r)


func _curtain_for(s: int) -> void:
	viewer = -1
	board.viewer = -1
	board.refresh()
	if is_instance_valid(curtain):
		curtain.queue_free()
	curtain = Control.new()
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(curtain)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.01, 0.02, 0.97)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.add_child(shade)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.add_theme_constant_override("separation", 24)
	curtain.add_child(vb)
	vb.add_child(UI.title("Tocca a %s" % eng.pname(s), 54, UI.side_color(eng.sides[s]["set"])))
	var what := {"plot": "piano segreto degli spostamenti", "alloc": "ripartizione segreta di attacco e difesa", "tdeploy": "schieramento sul Tactical Display", "tplot": "piano segreto del Tac-turno", "xsign": "scelta del lato del Volume"}
	vb.add_child(UI.label("Passa il dispositivo: %s.\nGli altri non guardino lo schermo." % what.get(req["type"], "decisione"), 24, UI.TEXT))
	var b := UI.primary(UI.button("Sono pronto", 360, 64, 26))
	b.pressed.connect(func():
		curtain.queue_free()
		viewer = s
		board.viewer = s
		eng._compute_visibility() if eng.tac == null else null
		_refresh()
		_begin_request())
	vb.add_child(b)
	await get_tree().process_frame
	vb.position = (size - vb.get_combined_minimum_size()) * 0.5


func _panel(title_text: String) -> void:
	_clear(act_box)
	act_panel.visible = true
	var t := UI.head(title_text, 20, UI.YELLOW)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 420
	act_box.add_child(t)


func _note(t: String, col := UI.MUTED, size := 16) -> Label:
	var l := UI.wrap(UI.label(t, size, col), 420)
	act_box.add_child(l)
	return l


func _row(parent: Container = null) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	(parent if parent != null else act_box).add_child(h)
	return h


# ---------------------------------------------------------------- piano stellare

func _start_plot() -> void:
	plot = {}
	sel = ""
	if eng.tac == null and board.tactical:
		board.show_tactical(false)
	_plot_panel()
	_plot_lines()


func _plot_panel() -> void:
	var t := "Piano degli spostamenti"
	if req.get("pregame", 0) > 0:
		t = "Turno preliminare xenofobo (ne restano %d)" % int(req["pregame"])
	elif req.get("free", false):
		t = "Spostamento libero prima del primo turno"
	_panel(t)
	_note("Scegli una tua StarForce (clic sulla flotta o nell'elenco), poi clicca un esagono o una stella per la destinazione. La quota Zulu si cambia con i pulsanti o con i tasti W e S. La sfera azzurra mostra la portata sicura.", UI.MUTED, 15)
	var mine: Array = eng.live(seat, "sf")
	for u in mine:
		var id: String = u["id"]
		var b := UI.button(_plot_line_text(u), 420, 40, 16)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if id == sel:
			b.add_theme_stylebox_override("normal", UI.box(Color("#4a1a2e"), UI.YELLOW, 2, 6))
		if eng.neutralized(u):
			b.add_theme_color_override("font_color", UI.MUTED)
		b.pressed.connect(func(): _select_sf(id))
		act_box.add_child(b)
	if sel != "":
		var u: Dictionary = eng.units[sel]
		act_box.add_child(UI.hsep())
		var r1 := _row()
		var bz1 := UI.button("Zulu -1", 100, 42, 16)
		bz1.pressed.connect(func(): _bump_z(-1))
		r1.add_child(bz1)
		var bz2 := UI.button("Zulu +1", 100, 42, 16)
		bz2.pressed.connect(func(): _bump_z(1))
		r1.add_child(bz2)
		var bst := UI.button("Resta", 100, 42, 16)
		bst.pressed.connect(func():
			plot.erase(sel)
			_plot_changed())
		r1.add_child(bst)
		var r2 := _row()
		var be := UI.button("Rinforza questa LiteZulu", 260, 42, 16)
		be.tooltip_text = "La StarForce resta ferma e permette a un'altra StarForce amica di arrivare qui con portata dieci (ES) o quindici (EGS)."
		be.pressed.connect(func():
			plot[sel] = {"c": "E", "to": u["lz"]}
			_plot_changed())
		r2.add_child(be)
		if eng.scn_id == 38:
			var bload := UI.button("Carica / scarica", 160, 42, 16)
			bload.pressed.connect(func():
				plot[sel] = {"c": "L", "to": u["lz"]}
				_plot_changed())
			r2.add_child(bload)
		var info := _plot_detail(sel)
		_note(info, UI.PINK_L, 16)
	act_box.add_child(UI.hsep())
	var rb := _row()
	var bok := UI.primary(UI.button("Conferma il piano", 250, 52, 20))
	bok.pressed.connect(func(): _provide(plot.duplicate(true)))
	rb.add_child(bok)
	var bai := UI.button("Piano dell'IA", 160, 52, 17)
	bai.tooltip_text = "Riempie il piano con i suggerimenti dell'avversario automatico: puoi poi modificarlo."
	bai.pressed.connect(func():
		plot = eng.ais[seat].plot(eng, seat, req)
		_plot_changed())
	rb.add_child(bai)


func _plot_line_text(u: Dictionary) -> String:
	var id: String = u["id"]
	var t := "%s  %s" % [u["label"], Hex.fmt(u["lz"])]
	if eng.neutralized(u):
		return t + "  (neutralizzata)"
	if not plot.has(id):
		return t + "  resta"
	var o: Dictionary = plot[id]
	if o.get("c", "") == "E":
		return t + "  rinforza"
	if o.get("c", "") == "L":
		return t + "  carica/scarica"
	var r: Dictionary = eng.resolve_plot(seat, plot).get(id, {})
	if r.is_empty():
		return t
	return "%s  >  %s   %s, %d Lite, %s" % [t, Hex.fmt(r["to"]), r["c"] if r["c"] != "" else "-", int(r["d"]), eng.col_name(int(r["col"]))]


func _plot_detail(id: String) -> String:
	var u: Dictionary = eng.units[id]
	if eng.neutralized(u):
		return "Neutralizzata: in questo turno non può spostarsi."
	if not plot.has(id) or plot[id].get("c", "") in ["E", "L"]:
		return "Clicca la destinazione sulla mappa."
	var r: Dictionary = eng.resolve_plot(seat, plot).get(id, {})
	var codes := {"S": "spostamento normale (portata 5)", "ES": "verso una LiteZulu rinforzata (portata 10)", "GS": "con l'aiuto della StarGate di partenza (portata 10)", "EGS": "StarGate di partenza e rinforzo all'arrivo (portata 15)", "GGS": "da StarGate a StarGate (portata 20)"}
	var t := "Destinazione %s: %d Lite effettivi.\n%s" % [Hex.fmt(r["to"]), int(r["d"]), codes.get(r["c"], "")]
	if int(r["col"]) == 0:
		t += "\nArrivo sicuro."
	else:
		t += "\nOltre-spostamento, colonna %s: rischio di spostamento a specchio o di randomizzazione." % eng.col_name(int(r["col"]))
	if str(r.get("err", "")) != "":
		t += "\n" + str(r["err"])
	return t


func _select_sf(id: String) -> void:
	sel = id
	var u: Dictionary = eng.units[id]
	cur_z = u["lz"].z
	if plot.has(id) and plot[id].has("to"):
		cur_z = plot[id]["to"].z
	board.select(id)
	var radius := 5.0
	var g := eng.gate_at(u["lz"], seat)
	if not g.is_empty() and eng.gate_active(g):
		radius = 10.0
	board.set_range(u["lz"], radius + 0.5)
	board.focus(Hex.world(u["lz"]))
	_plot_changed()


func _bump_z(d: int) -> void:
	if req.get("type", "") == "plot" and sel != "" and plot.has(sel) and plot[sel].get("c", "") == "":
		var to: Vector3i = plot[sel]["to"]
		var lim := Hex.zlimit(Hex.hexof(to)) + (10 if eng.xeno > 0 else 0)
		to.z = clampi(to.z + d, -lim, lim)
		cur_z = to.z
		plot[sel]["to"] = to
		_plot_changed()
	elif req.get("type", "") == "plot":
		cur_z += d
	elif req.get("type", "") in ["tplot", "tdeploy"]:
		tz = clampi(tz + d, -5, 5)
		_tac_z_changed()


func _plot_changed() -> void:
	_plot_panel()
	_plot_lines()
	_info()


func _plot_lines() -> void:
	var rp: Dictionary = eng.resolve_plot(seat, plot)
	var lines := []
	for id in rp:
		var r: Dictionary = rp[id]
		if r["c"] in ["", "E"] or r["to"] == r["from"]:
			continue
		lines.append({"from": r["from"], "to": r["to"], "col": _col_color(int(r["col"]))})
	board.set_plot_lines(lines)
	if sel != "" and plot.has(sel) and plot[sel].get("c", "") == "":
		var r2: Dictionary = rp.get(sel, {})
		if not r2.is_empty():
			board.set_cursor(r2["to"], _col_color(int(r2["col"])))


func _unhandled_key_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed:
		return
	match ev.keycode:
		KEY_W, KEY_PAGEUP:
			_bump_z(1)
		KEY_S, KEY_PAGEDOWN:
			_bump_z(-1)
		KEY_ESCAPE:
			if sel != "":
				sel = ""
				board.select("")
				board.set_range(null, 0)
				if req.get("type", "") == "plot":
					_plot_panel()


func _on_pick_unit(id: String) -> void:
	if not eng.units.has(id):
		return
	var u: Dictionary = eng.units[id]
	var t := str(req.get("type", ""))
	if t == "plot":
		if u["side"] == seat and u["kind"] == "sf":
			_select_sf(id)
		elif sel != "" and eng.visibility(u, seat) == "full":
			plot[sel] = {"c": "", "to": u["lz"]}
			cur_z = u["lz"].z
			_plot_changed()
		return
	if t in ["tdeploy", "tplot"] and eng.tac != null:
		if u["side"] == seat:
			tsel = id
			board.select(id)
			if t == "tdeploy":
				_deploy_panel()
			else:
				tpick = ""
				_tplot_panel()
		return
	sel = id
	board.select(id)
	_info()


func _on_pick_hex(v: int) -> void:
	var h := v
	var z := cur_z
	var star := false
	if v >= 100000:
		h = v / 1000
		z = v % 1000 - 500
		star = true
	if str(req.get("type", "")) != "plot" or sel == "":
		return
	var lim := Hex.zlimit(h) + (10 if eng.xeno > 0 else 0)
	if not star:
		z = clampi(z, -lim, lim)
	var to := Hex.lz(h, z)
	cur_z = z
	plot[sel] = {"c": "", "to": to}
	_plot_changed()


# ---------------------------------------------------------------- combattimento base

func _start_alloc() -> void:
	alloc_att = {}
	alloc_brk = {}
	alloc_ref = false
	alloc_nova = false
	var l: Vector3i = req["lz"]
	board.focus(Hex.world(l), 30.0)
	# proposta iniziale: quella dell'IA
	var ai: Dictionary = eng.ais[seat].alloc(eng, seat, req)
	for k in ai.get("att", {}):
		alloc_att[int(k)] = int(ai["att"][k])
	_alloc_panel()


func _alloc_pool() -> int:
	var pool: int = req["pool"]
	for id in alloc_brk:
		pool -= eng.strength(eng.units[id], int(req["seg"]))
	return maxi(pool, 0)


func _alloc_panel() -> void:
	var l: Vector3i = req["lz"]
	var stn: Dictionary = eng.star_at(l)
	_panel("Combattimento in %s%s, segmento %d" % [Hex.fmt(l), (" (" + stn["name"] + ")") if not stn.is_empty() else "", int(req["seg"])])
	if req.get("first", false):
		_note("Primo segmento: combattono solo le StarForce appena arrivate (2 punti) contro quelle che erano già qui (3 punti). Le StarGate non partecipano.", UI.MUTED, 15)
	# forze presenti
	for s in req["pools"]:
		var names := []
		for u in eng.units_at(l):
			if u["side"] == int(s):
				names.append("%s %s" % ["StarGate" if u["kind"] == "gate" else "StarForce", u["label"]])
		_note("%s: %d punti (%s)" % [eng.sides[int(s)]["nome"], int(req["pools"][s]), ", ".join(names)], UI.side_color(eng.sides[int(s)]["set"]).lightened(0.3), 16)
	act_box.add_child(UI.hsep())
	var pool := _alloc_pool()
	var used := 0
	for k in alloc_att:
		used += int(alloc_att[k])
	if used > pool:
		alloc_att = {}
		used = 0
	for s in req["pools"]:
		var t := int(s)
		if not eng.hostile(seat, t):
			continue
		var r := _row()
		r.add_child(UI.label("Attacco contro %s" % eng.sides[t]["nome"], 17))
		var sb := SpinBox.new()
		sb.min_value = 0
		sb.max_value = pool
		sb.value = int(alloc_att.get(t, 0))
		sb.custom_minimum_size = Vector2(110, 40)
		sb.value_changed.connect(func(v):
			alloc_att[t] = int(v)
			var tot := 0
			for k in alloc_att:
				tot += int(alloc_att[k])
			if tot > _alloc_pool():
				alloc_att[t] = maxi(0, int(v) - (tot - _alloc_pool()))
			_alloc_panel())
		r.add_child(sb)
	var dfn := pool - used
	var brk_pts := alloc_brk.size() * 2
	_note("Difesa: %d punti%s" % [dfn + brk_pts, (" (di cui %d delle StarForce in ritirata)" % brk_pts) if brk_pts > 0 else ""], UI.YELLOW_L, 18)
	var rq := _row()
	for pair in [["Tutto in difesa", 0.0], ["Metà e metà", 0.5], ["Tutto in attacco", 1.0]]:
		var b := UI.button(pair[0], 0, 40, 15)
		var f: float = pair[1]
		b.pressed.connect(func():
			var enemies := []
			for s2 in req["pools"]:
				if eng.hostile(seat, int(s2)):
					enemies.append(int(s2))
			alloc_att = {}
			if not enemies.is_empty():
				alloc_att[enemies[0]] = int(round(_alloc_pool() * f))
			_alloc_panel())
		rq.add_child(b)
	if req.get("first", false) and req.get("can_refuse", false):
		var cb := CheckBox.new()
		cb.text = "Rifiuta il combattimento in questo primo segmento"
		cb.button_pressed = alloc_ref
		cb.toggled.connect(func(v): alloc_ref = v)
		act_box.add_child(cb)
	if not req.get("first", false):
		act_box.add_child(UI.head("Ritirate", 16, UI.PINK_L))
		_note("Chi si ritira vale 2 punti, solo in difesa, ed esce alla fine del segmento.", UI.MUTED, 14)
		for u in eng.units_at(l):
			if u["side"] != seat or u["kind"] != "sf":
				continue
			var id: String = u["id"]
			var opts: Array = eng.breakoff_options(u)
			if opts.is_empty():
				continue
			var r2 := _row()
			var cb2 := CheckBox.new()
			cb2.text = "StarForce %s" % u["label"]
			cb2.button_pressed = alloc_brk.has(id)
			r2.add_child(cb2)
			var ob := OptionButton.new()
			for o in opts:
				var nm: String = eng.star_at(o).get("name", "")
				ob.add_item("%s%s" % [Hex.fmt(o), (" " + nm) if nm != "" else ""])
			if alloc_brk.has(id):
				ob.select(maxi(0, opts.find(alloc_brk[id])))
			ob.item_selected.connect(func(i):
				if alloc_brk.has(id):
					alloc_brk[id] = opts[i])
			r2.add_child(ob)
			cb2.toggled.connect(func(v):
				if v:
					alloc_brk[id] = opts[ob.selected if ob.selected >= 0 else 0]
				else:
					alloc_brk.erase(id)
				_alloc_panel())
	if eng.xeno > 0 and seat == eng.xeno_side and eng.gate_at(l, 1 - seat).is_empty() and not eng.star_at(l).is_empty():
		var cbn := CheckBox.new()
		cbn.text = "Innesca la nova con una StarForce (si ritira alla fine del segmento)"
		cbn.button_pressed = alloc_nova
		cbn.toggled.connect(func(v): alloc_nova = v)
		act_box.add_child(cbn)
	act_box.add_child(UI.hsep())
	act_box.add_child(_crt_table())
	var bok := UI.primary(UI.button("Conferma", 250, 52, 20))
	bok.pressed.connect(_alloc_done)
	act_box.add_child(bok)


func _alloc_done() -> void:
	var r := {"att": alloc_att.duplicate(), "def": _alloc_pool() - _sum(alloc_att), "brk": alloc_brk.duplicate(), "refuse": alloc_ref}
	if alloc_nova:
		for u in eng.units_at(req["lz"]):
			if u["side"] == seat and u["kind"] == "sf":
				r["nova"] = u["id"]
				break
	_provide(r)


func _sum(d: Dictionary) -> int:
	var t := 0
	for k in d:
		t += int(d[k])
	return t


func _crt_table() -> Control:
	var vb := VBoxContainer.new()
	vb.add_child(UI.head("Tabella dei risultati (perdite in StarForce)", 14, UI.PINK_L))
	var g := GridContainer.new()
	g.columns = 11
	g.add_theme_constant_override("h_separation", 10)
	g.add_child(UI.mono("chit", 13, UI.MUTED))
	for c in range(-3, 7):
		g.add_child(UI.mono(("%+d" % c) if c != 0 else "0", 14, UI.YELLOW))
	for r in 10:
		g.add_child(UI.mono(str(r), 14, UI.YELLOW))
		for c in 10:
			var v: int = D.SCRT[r][c]
			g.add_child(UI.mono(str(v) if v > 0 else "-", 14, UI.TEXT if v > 0 else UI.MUTED))
	vb.add_child(g)
	vb.add_child(UI.wrap(UI.label("Colonna = tuo attacco meno difesa nemica (sotto -3 non si può attaccare, oltre +6 vale +6). Una StarGate vale due StarForce e cade solo con un risultato di almeno 2.", 13, UI.MUTED), 420))
	return vb


# ---------------------------------------------------------------- schieramento tattico

func _start_deploy() -> void:
	board.show_tactical(true)
	btn_tac.visible = true
	dep = eng.ais[seat].tdeploy(eng, seat, req)
	tsel = req["ids"][0]
	tz = dep[tsel][0].z
	_deploy_preview()
	_deploy_panel()


func _deploy_panel() -> void:
	_panel("Schieramento sul Tactical Display")
	_note("Chi era già nella LiteZulu può stare ovunque e anche in modo battaglia; chi è appena arrivato si schiera sull'anello esterno (500) o a MiniZulu +5/-5, e chi arriva dalla stessa LiteZulu resta entro un MiniLite dagli altri. Scegli una StarForce e clicca un esagono; la MiniZulu con W/S o i pulsanti.", UI.MUTED, 15)
	for id in req["ids"]:
		var u: Dictionary = eng.units[id]
		var e: Array = dep[id]
		var r := _row()
		var b := UI.button("%s  %s%s" % [u["label"], Hex.tfmt(e[0]), "  battaglia" if e[1] else ""], 260, 40, 16)
		if id == tsel:
			b.add_theme_stylebox_override("normal", UI.box(Color("#4a1a2e"), UI.YELLOW, 2, 6))
		b.pressed.connect(func():
			tsel = id
			tz = dep[id][0].z
			board.select(id)
			_deploy_panel())
		r.add_child(b)
		if u["start"] == eng.tac.l and not u.get("entered", false):
			var cb := CheckBox.new()
			cb.text = "battaglia"
			cb.button_pressed = e[1]
			cb.toggled.connect(func(v):
				dep[id][1] = v
				_deploy_panel())
			r.add_child(cb)
	var rz := _row()
	var b1 := UI.button("MiniZulu -1", 140, 40, 16)
	b1.pressed.connect(func(): _bump_z(-1))
	rz.add_child(b1)
	var b2 := UI.button("MiniZulu +1", 140, 40, 16)
	b2.pressed.connect(func(): _bump_z(1))
	rz.add_child(b2)
	var ok: bool = eng.tac._deploy_ok(seat, dep)
	if not ok:
		_note("Schieramento non valido: controlla le zone e la distanza fra le StarForce arrivate insieme.", UI.RED, 15)
	var bok := UI.primary(UI.button("Conferma lo schieramento", 300, 52, 19))
	bok.disabled = not ok
	bok.pressed.connect(func(): _provide(dep.duplicate(true)))
	act_box.add_child(bok)


func _deploy_preview() -> void:
	# durante lo schieramento le proprie StarForce si vedono dove le si mette
	for id in dep:
		eng.tac.tu[id]["pos"] = dep[id][0]
	board.refresh_tac()


func _tac_z_changed() -> void:
	if str(req.get("type", "")) == "tdeploy" and tsel != "":
		var p: Vector3i = dep[tsel][0]
		dep[tsel][0] = Vector3i(p.x, p.y, tz)
		_deploy_preview()
		_deploy_panel()
	elif str(req.get("type", "")) == "tplot" and tsel != "" and tpick != "":
		var a: Dictionary = tplan.get(tsel, {}).get(tpick, {})
		if a.get("k", "") == "T":
			var p2: Vector3i = a["to"]
			a["to"] = Vector3i(p2.x, p2.y, tz)
			board.set_tac_cursor(a["to"])
		_tplot_panel()


func _on_pick_tac(a: Vector2i) -> void:
	var t := str(req.get("type", ""))
	if t == "tdeploy" and tsel != "":
		dep[tsel][0] = Vector3i(a.x, a.y, tz)
		_deploy_preview()
		_deploy_panel()
	elif t == "tplot" and tsel != "" and tpick != "":
		if not tplan.has(tsel):
			tplan[tsel] = {"a1": {"k": ""}, "a2": {"k": ""}}
		tplan[tsel][tpick] = {"k": "T", "to": Vector3i(a.x, a.y, tz)}
		board.set_tac_cursor(Vector3i(a.x, a.y, tz))
		_tplot_panel()


# ---------------------------------------------------------------- piano del Tac-turno

func _start_tplot() -> void:
	board.show_tactical(true)
	btn_tac.visible = true
	tplan = {}
	for u in eng.tac.units():
		if u["side"] == seat:
			if u["kind"] == "gate":
				tplan[u["id"]] = {"c1": [], "c2": []}
			else:
				tplan[u["id"]] = {"a1": {"k": ""}, "a2": {"k": ""}}
	tsel = ""
	for id in tplan:
		tsel = id
		break
	tpick = ""
	_tplot_panel()


func _tplot_panel() -> void:
	var t = eng.tac
	_panel("Piano del Tac-turno %d" % t.tt)
	if req.get("forced", false):
		_note("Stallo: le tue StarForce devono ritirarsi entro due Tac-turni.", UI.RED, 15)
	var all_ok := true
	for id in tplan:
		var u: Dictionary = eng.units[id]
		var ok := true
		var txt := ""
		if u["kind"] == "gate":
			var c: Dictionary = t.check_gate(id, tplan[id])
			ok = c["ok"]
			txt = "StarGate %s  %s  anti %d / %d" % [u["label"], "neutralizzata" if t.tu[id]["neut"] else "", int(c.get("anti1", 0)), int(c.get("anti2", 0))]
		else:
			var c2: Dictionary = t.check_sf(id, tplan[id])
			ok = c2["ok"]
			txt = "%s  %s  %s  anti %d" % [u["label"], Hex.tfmt(t.tu[id]["pos"]), "battaglia" if t.tu[id]["mode"] == "battle" else "stellare", int(c2.get("anti", 0))]
			if t.is_disrupted(id):
				txt += "  disgregata"
		if not ok:
			all_ok = false
		var b := UI.button(txt, 420, 40, 15)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if id == tsel:
			b.add_theme_stylebox_override("normal", UI.box(Color("#4a1a2e"), UI.YELLOW, 2, 6))
		if not ok:
			b.add_theme_color_override("font_color", UI.RED)
		b.pressed.connect(func():
			tsel = id
			tpick = ""
			board.select(id)
			_tplot_panel())
		act_box.add_child(b)
	act_box.add_child(UI.hsep())
	if tsel != "":
		if eng.units[tsel]["kind"] == "gate":
			_gate_editor(tsel)
		else:
			_sf_editor(tsel)
	act_box.add_child(UI.hsep())
	var rb := _row()
	var bok := UI.primary(UI.button("Conferma il piano", 250, 52, 20))
	bok.disabled = not all_ok
	bok.pressed.connect(func(): _provide(tplan.duplicate(true)))
	rb.add_child(bok)
	var bai := UI.button("Piano dell'IA", 160, 52, 17)
	bai.pressed.connect(func():
		var p: Dictionary = eng.ais[seat].tplot(eng, seat, req)
		for id in p:
			if tplan.has(id):
				tplan[id] = p[id]
		_tplot_panel())
	rb.add_child(bai)
	_tac_preview()


const SF_A1 := [["", "Nulla"], ["T", "Tac-spostamento"], ["M", "Cambio di modo"], ["C", "Proiezione"]]
const SF_A2 := [["", "Nulla"], ["T", "Tac-spostamento"], ["C", "Proiezione"], ["B", "Ritirata"]]

func _sf_editor(id: String) -> void:
	var t = eng.tac
	var p: Dictionary = tplan[id]
	var c: Dictionary = t.check_sf(id, p)
	_note("TeleValue %d: costi %d + %d, anti-proiezione %d per tutto il Tac-turno." % [int(c.get("tv", t.televalue(id))), int(c.get("cost1", 0)), int(c.get("cost2", 0)), int(c.get("anti", 0))], UI.YELLOW_L, 16)
	if not c["ok"]:
		_note(str(c["err"]), UI.RED, 15)
	for ph in ["a1", "a2"]:
		var opts: Array = SF_A1 if ph == "a1" else SF_A2
		var r := _row()
		r.add_child(UI.label("Fase %s:" % ph.substr(1), 17))
		var ob := OptionButton.new()
		var cur := str(p[ph].get("k", ""))
		for i in opts.size():
			ob.add_item(opts[i][1])
			if opts[i][0] == cur:
				ob.select(i)
		ob.item_selected.connect(func(i):
			var k: String = opts[i][0]
			match k:
				"T":
					tplan[id][ph] = {"k": "T", "to": t.tu[id]["pos"]}
					tpick = ph
					tz = t.tu[id]["pos"].z
				"C":
					tplan[id][ph] = {"k": "C", "p": 16, "cl": 3, "zs": 1}
				"B":
					var bo: Array = eng.breakoff_options(eng.units[id])
					tplan[id][ph] = {"k": "B", "to": bo[0] if not bo.is_empty() else eng.units[id]["lz"]}
				_:
					tplan[id][ph] = {"k": k}
			_tplot_panel())
		r.add_child(ob)
		var a: Dictionary = p[ph]
		match str(a.get("k", "")):
			"T":
				var bt := UI.button("Scegli sul display" if tpick != ph else "Clicca un esagono...", 0, 38, 15)
				bt.pressed.connect(func():
					tpick = ph
					tz = a["to"].z
					_tplot_panel())
				r.add_child(bt)
				_note("Verso %s, %d MiniLite. MiniZulu con W/S." % [Hex.tfmt(a["to"]), Hex.ttrue(t.tu[id]["pos"] if ph == "a1" or str(p["a1"].get("k", "")) != "T" else p["a1"]["to"], a["to"])], UI.PINK_L, 15)
				if tpick == ph:
					var rz := _row()
					var z1 := UI.button("MiniZulu -1", 130, 36, 15)
					z1.pressed.connect(func(): _bump_z(-1))
					rz.add_child(z1)
					var z2 := UI.button("MiniZulu +1", 130, 36, 15)
					z2.pressed.connect(func(): _bump_z(1))
					rz.add_child(z2)
			"C":
				_cast_editor(a, func(): _tplot_panel())
			"B":
				var bo2: Array = eng.breakoff_options(eng.units[id])
				var ob2 := OptionButton.new()
				for o in bo2:
					var nm: String = eng.star_at(o).get("name", "")
					ob2.add_item("%s%s" % [Hex.fmt(o), (" " + nm) if nm != "" else ""])
				ob2.select(maxi(0, bo2.find(a["to"])))
				ob2.item_selected.connect(func(i):
					a["to"] = bo2[i]
					_tplot_panel())
				r.add_child(ob2)


func _cast_editor(a: Dictionary, done: Callable, removable := false, on_remove := Callable()) -> void:
	var r := _row()
	r.add_child(UI.label("Punti", 15))
	var ob := OptionButton.new()
	for v in D.CAST_LEVELS:
		ob.add_item(str(v))
	ob.select(maxi(0, D.CAST_LEVELS.find(int(a.get("p", 16)))))
	ob.item_selected.connect(func(i):
		a["p"] = D.CAST_LEVELS[i]
		done.call())
	r.add_child(ob)
	var bz := UI.button("verso l'alto" if int(a.get("zs", 1)) > 0 else "verso il basso", 130, 36, 15)
	bz.pressed.connect(func():
		a["zs"] = -int(a.get("zs", 1))
		done.call())
	r.add_child(bz)
	if removable:
		var bx := UI.button("Togli", 70, 36, 15)
		bx.pressed.connect(on_remove)
		r.add_child(bx)
	var r2 := _row()
	r2.add_child(UI.label("Direzione: ore", 15))
	for cl in Hex.CLOCKS:
		var b := UI.button(str(cl), 44, 36, 15)
		if int(a.get("cl", 3)) == cl:
			b.add_theme_stylebox_override("normal", UI.box(Color("#6a1c3b"), UI.YELLOW, 2, 6))
		var clv: int = cl
		b.pressed.connect(func():
			a["cl"] = clv
			done.call())
		r2.add_child(b)


func _gate_editor(id: String) -> void:
	var t = eng.tac
	var p: Dictionary = tplan[id]
	if t.tu[id]["neut"]:
		_note("StarGate neutralizzata: non può proiettare.", UI.RED, 15)
		return
	var c: Dictionary = t.check_gate(id, p)
	_note("La StarGate usa tutto il suo TeleValue (%d) in ciascuna fase: anti-proiezione %d nella prima, %d nella seconda." % [t.televalue(id), int(c.get("anti1", 0)), int(c.get("anti2", 0))], UI.YELLOW_L, 15)
	if not c["ok"]:
		_note(str(c["err"]), UI.RED, 15)
	for ph in ["c1", "c2"]:
		act_box.add_child(UI.head("Fase %s" % ph.substr(1), 16, UI.PINK_L))
		var lst: Array = p[ph]
		for i in lst.size():
			var k := i
			_cast_editor(lst[i], func(): _tplot_panel(), true, func():
				lst.remove_at(k)
				_tplot_panel())
		var badd := UI.button("Aggiungi una proiezione", 240, 38, 15)
		badd.pressed.connect(func():
			var used := {}
			for e in lst:
				used["%d|%d" % [int(e["cl"]), int(e["zs"])]] = true
			for cl in Hex.CLOCKS:
				for zs in [1, -1]:
					if not used.has("%d|%d" % [cl, zs]):
						lst.append({"p": 16, "cl": cl, "zs": zs})
						_tplot_panel()
						return)
		act_box.add_child(badd)


func _tac_preview() -> void:
	var t = eng.tac
	var casts := []
	if tsel != "" and tplan.has(tsel):
		var p: Dictionary = tplan[tsel]
		var pos: Vector3i = t.tu[tsel]["pos"]
		if eng.units[tsel]["kind"] == "gate":
			for ph in ["c1", "c2"]:
				for c in p[ph]:
					casts.append({"from": pos, "cl": c["cl"], "zs": c["zs"], "p": c["p"], "col": UI.YELLOW if ph == "c1" else UI.CYAN})
		else:
			var pos2 := pos
			if str(p["a1"].get("k", "")) == "T":
				pos2 = p["a1"]["to"]
				board.set_tac_cursor(pos2)
			if str(p["a2"].get("k", "")) == "T":
				board.set_tac_cursor(p["a2"]["to"])
			if str(p["a1"].get("k", "")) == "C":
				casts.append({"from": pos, "cl": p["a1"]["cl"], "zs": p["a1"]["zs"], "p": p["a1"]["p"], "col": UI.YELLOW})
			if str(p["a2"].get("k", "")) == "C":
				casts.append({"from": pos2, "cl": p["a2"]["cl"], "zs": p["a2"]["zs"], "p": p["a2"]["p"], "col": UI.CYAN})
			if str(p["a1"].get("k", "")) != "T" and str(p["a2"].get("k", "")) != "T":
				board.set_tac_cursor(null)
	board.show_casts(casts)


# ---------------------------------------------------------------- Xenofobi

func _ask_xsign() -> void:
	_panel("Da dove arrivano gli Xenofobi?")
	_note("Le StarGate xenofobe stanno due Lite oltre il limite Zulu, tutte dalla stessa parte del Volume. La Lega non sa quale.", UI.MUTED, 16)
	var r := _row()
	var b1 := UI.primary(UI.button("Sopra il piano", 200, 52, 18))
	b1.pressed.connect(func(): _provide(1))
	r.add_child(b1)
	var b2 := UI.primary(UI.button("Sotto il piano", 200, 52, 18))
	b2.pressed.connect(func(): _provide(-1))
	r.add_child(b2)


# ================================================================ online

func online_waiting(s: int, slow: bool) -> void:
	if s < 0:
		wait_label.text = ""
	else:
		wait_label.text = "In attesa di %s%s" % [eng.pname(s), ": è un po' lento..." if slow else "..."]


func online_status(t: String) -> void:
	_say(t, 4.0)


func online_cancel_decision(t: String) -> void:
	_say(t, 4.0)
	act_panel.visible = false


func online_caught_up() -> void:
	_say("Partita ripresa.", 2.0)


# ================================================================ registro, regole, salvataggi

func _toggle_log() -> void:
	if is_instance_valid(log_overlay):
		log_overlay.queue_free()
		return
	log_overlay = PanelContainer.new()
	log_overlay.add_theme_stylebox_override("panel", UI.panel_style(0.97))
	log_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	log_overlay.offset_left = 380
	log_overlay.offset_right = -480
	log_overlay.offset_top = 70
	log_overlay.offset_bottom = -150
	add_child(log_overlay)
	var sc := ScrollContainer.new()
	log_overlay.add_child(sc)
	var r := UI.rich(17)
	r.custom_minimum_size = Vector2(700, 0)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for ln in eng.log_lines:
		r.append_text(ln + "\n")
	sc.add_child(r)


func _show_rules_overlay() -> void:
	var rv = preload("res://scripts/ui/rules_view.gd").new()
	rv.overlay = true
	add_child(rv)


func _save() -> void:
	if eng.over:
		_say("La partita è finita.")
		return
	var cfg := config.duplicate()
	cfg.erase("online")
	cfg.erase("preload")
	var data := {"cfg": var_to_str(cfg), "acts": var_to_str(eng.rec_acts), "scenario": eng.sc["nome"], "turn": eng.turn}
	_say("Salvo la partita...", 10.0)
	var net: Net = main.get_net()
	var code := await net.save_game(data, save_code)
	if code == "":
		_say("Salvataggio non riuscito: %s" % net.last_error, 5.0)
		return
	save_code = code
	_say("Partita salvata: codice %s (dal menu: Carica una partita)." % code, 8.0)


func _quit() -> void:
	eng.abort = true
	if online != null:
		online.alive = false
	if not req.is_empty():
		eng.provide_decision(null)
	main.show_menu()


# ================================================================ fine partita e replay

func _on_end(res: Dictionary) -> void:
	act_panel.visible = false
	if online != null:
		online.finish()
	viewer = -2
	board.viewer = -2
	_refresh()
	result_box = PanelContainer.new()
	result_box.add_theme_stylebox_override("panel", UI.panel_style(0.96))
	result_box.position = Vector2(size.x * 0.5 - 360, 90)
	result_box.custom_minimum_size = Vector2(720, 0)
	add_child(result_box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	result_box.add_child(vb)
	var w := int(res.get("winner", -1))
	if res.get("solo", false):
		vb.add_child(UI.title("Missione conclusa", 42))
	elif w >= 0:
		vb.add_child(UI.title("Vince %s" % eng.pname(w), 42, UI.side_color(eng.sides[w]["set"]).lightened(0.2)))
	else:
		vb.add_child(UI.title("Partita pari", 42))
	vb.add_child(UI.wrap(UI.label(str(res.get("reason", "")), 20), 680))
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	vb.add_child(r)
	var bre := UI.primary(UI.button("Rivedi la partita", 260, 54, 19))
	bre.pressed.connect(func():
		result_box.queue_free()
		_start_replay())
	r.add_child(bre)
	var bm := UI.button("Torna al menu", 220, 54, 19)
	bm.pressed.connect(func(): main.show_menu())
	r.add_child(bm)


func _start_replay() -> void:
	board.show_tactical(false)
	_clear(act_box)
	act_panel.visible = true
	_panel("Replay della partita")
	_note("Tutte le posizioni, senza segreti. Il replay riparte da capo quando finisce.", UI.MUTED, 15)
	var lab := UI.head("", 18, UI.YELLOW)
	act_box.add_child(lab)
	var sl := HSlider.new()
	sl.min_value = 0
	sl.max_value = maxi(0, eng.history.size() - 1)
	sl.custom_minimum_size = Vector2(420, 30)
	act_box.add_child(sl)
	var r := _row()
	var bp := UI.primary(UI.button("Pausa", 140, 46, 17))
	r.add_child(bp)
	var bm := UI.button("Menu", 140, 46, 17)
	bm.pressed.connect(func(): main.show_menu())
	r.add_child(bm)
	replay_play = true
	bp.pressed.connect(func():
		replay_play = not replay_play
		bp.text = "Pausa" if replay_play else "Riprendi")
	sl.value_changed.connect(func(v):
		_replay_show(int(v), lab))
	replay_i = 0
	while is_inside_tree():
		if replay_play:
			replay_i = (replay_i + 1) % maxi(1, eng.history.size())
			sl.set_value_no_signal(replay_i)
			_replay_show(replay_i, lab)
		await get_tree().create_timer(0.45).timeout


func _replay_show(i: int, lab: Label) -> void:
	if i < 0 or i >= eng.history.size():
		return
	var seg: Dictionary = eng.history[i]
	lab.text = "Turno %d  |  %s" % [int(seg.get("turn", 0)), {"start": "inizio", "shift": "spostamenti", "combat": "combattimento", "segment": "segmento di combattimento", "turn_end": "fine turno", "tac_start": "combattimento tattico", "nova": "nova!", "gate_lost": "StarGate neutralizzata", "end": "fine"}.get(seg["k"], seg["k"])]
	board.show_snapshot(seg["u"])
	if seg["k"] in ["shift", "segment", "nova", "gate_lost"]:
		fx.play(seg["k"], seg)
