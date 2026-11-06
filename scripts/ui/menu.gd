extends Control
## Menu principale: scelta dello scenario, del formato (base, base con randomizzatore, avanzato),
## dei giocatori (persone o IA), della grafica; partite online con codice; caricamento di una
## partita salvata; regole.

const D = preload("res://scripts/data/sf_data.gd")

var main
var scen_id := 1
var fmt := ""
var who: Array = []          # per lato: 0 = persona, 1 = IA
var names: Array = []
var style := "reborn"
var speed := 1.0
var page: Control
var detail: VBoxContainer
var list_box: VBoxContainer
var seats_box: VBoxContainer
var fmt_box: HBoxContainer

# online
var on_panel: Control
var on_name: LineEdit
var on_code: LineEdit
var on_lbl: Label
var on_start: Button
var host_side := 0
var opz := {}


## scenari raggruppati per periodo e tipo, nell'ordine in cui conviene scoprirli
const GROUPS := [
	["Per cominciare", "Due lati, poche flotte: il modo migliore per imparare.", [1, 2, 3]],
	["Le guerre del XXV secolo", "La frontiera si allarga: EPU, Lega Umana, L'Chal-Dah e Rame.", [4, 5, 6, 7, 8, 9, 10]],
	["Tre fazioni", "Alleanze che cambiano: per tre persone, o due con la terza fazione politica.", [11, 21, 12]],
	["Gli Xenofobi", "Un nemico sconosciuto che può far esplodere le stelle.", [13, 14, 15]],
	["Il futuro remoto", "XXX-XXXV secolo: FakerForce, incrociatori a tachioni, mappa estesa.", [16, 17, 18, 19]],
	["Outleap", "La campagna economica: colonie, commerci e guerre per un secolo.", [100, 101]],
	["Solitari", "Una missione contro il gioco stesso.", [38, 20]],
]
const FMT_DESC := {
	"base": "Il combattimento si risolve con la tabella dei risultati: le unità colpite sono eliminate. Partite rapide.",
	"modificato": "Come il base, ma le unità colpite o fuori rotta vengono randomizzate: finiscono in un punto a caso del Volume invece di sparire.",
	"avanzato": "Ogni scontro si gioca sul Tactical Display: manovre, modi di volo e proiezioni. Più lungo e più ricco.",
}

var right_scroll: ScrollContainer
var foot: VBoxContainer
var list_scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var st: Dictionary = main.menu_state
	scen_id = int(st.get("scenario", 1))
	style = str(st.get("style", "reborn"))
	speed = float(st.get("speed", 1.0))
	who = st.get("who", []).duplicate()
	names = st.get("names", []).duplicate()
	fmt = str(st.get("fmt", ""))
	opz = st.get("opz", {}).duplicate()
	page = Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 40
	outer.offset_right = -40
	outer.offset_top = 20
	outer.offset_bottom = -24
	outer.add_theme_constant_override("separation", 14)
	page.add_child(outer)
	# testata: logo a sinistra, azioni generali a destra
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	outer.add_child(head)
	var logo := VBoxContainer.new()
	logo.add_theme_constant_override("separation", 0)
	head.add_child(logo)
	var lt := HBoxContainer.new()
	lt.add_theme_constant_override("separation", 18)
	logo.add_child(lt)
	lt.add_child(UI.title("StarForce", 64))
	var sub := UI.head("ALPHA CENTAURI", 24, UI.YELLOW_L)
	sub.size_flags_vertical = Control.SIZE_SHRINK_END
	lt.add_child(sub)
	logo.add_child(UI.label("Conflitto interstellare nel XXV secolo  |  SPI 1974, Redmond A. Simonsen", 16, UI.PINK_L))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 10)
	acts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(acts)
	var bt := UI.primary(UI.button("Tutorial guidati", 0, 52, 19))
	bt.tooltip_text = "Partite brevi contro l'IA, spiegate passo per passo"
	bt.pressed.connect(_tutorial_panel)
	acts.add_child(bt)
	var br := UI.button("Regole", 0, 52, 19)
	br.pressed.connect(func():
		_store()
		main.show_rules())
	acts.add_child(br)
	var bl := UI.button("Carica una partita", 0, 52, 19)
	bl.tooltip_text = "Riprendi una partita salvata con il suo codice"
	bl.pressed.connect(_load_panel)
	acts.add_child(bl)
	var bj := UI.button("Entra in una partita online", 0, 52, 19)
	bj.tooltip_text = "Hai ricevuto un codice da un amico? Entra da qui"
	bj.pressed.connect(_online_join_panel)
	acts.add_child(bj)
	# corpo: elenco degli scenari | scheda dello scenario scelto
	var root := HBoxContainer.new()
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 24)
	outer.add_child(root)
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", UI.panel_style(0.8))
	left.custom_minimum_size = Vector2(580, 0)
	root.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	left.add_child(lv)
	lv.add_child(UI.head("1. Scegli uno scenario", 22, UI.YELLOW))
	list_scroll = ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(list_scroll)
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 4)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list_box)
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UI.panel_style(0.86))
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 10)
	right.add_child(rv)
	right_scroll = ScrollContainer.new()
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(right_scroll)
	detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation", 10)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(detail)
	# piede fisso: riepilogo e pulsanti di avvio, sempre visibili
	rv.add_child(UI.hsep())
	foot = VBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	rv.add_child(foot)
	_refresh()
	_scroll_to_selected.call_deferred()


func _scroll_to_selected() -> void:
	await get_tree().process_frame
	for c in list_box.get_children():
		if c.has_meta("sid") and int(c.get_meta("sid")) == scen_id:
			list_scroll.ensure_control_visible(c)


func _store() -> void:
	main.menu_state = {"scenario": scen_id, "style": style, "speed": speed, "who": who.duplicate(), "names": names.duplicate(), "fmt": fmt, "opz": opz.duplicate()}


func _sel_style(b: Button) -> void:
	b.add_theme_stylebox_override("normal", UI.box(Color("#5a1d36"), UI.YELLOW, 2, 6))
	b.add_theme_stylebox_override("hover", UI.box(Color("#6a2440"), UI.YELLOW_L, 2, 6))
	b.add_theme_color_override("font_color", UI.YELLOW_L)


## giocatori e altre etichette brevi di uno scenario
func _tags(sc: Dictionary) -> String:
	var t := []
	if sc.get("solitario", false):
		t.append("solitario")
	else:
		var n: int = int(sc.get("giocatori", sc["lati"].size()))
		t.append("%d giocatori" % n)
	t.append({"base": "base", "modificato": "base + random.", "avanzato": "avanzato"}[sc["formato"]])
	if sc.has("turni_max"):
		t.append("%d turni" % int(sc["turni_max"]))
	if sc.has("anni"):
		t.append("%d anni" % int(sc["anni"]))
	return "  |  ".join(t)


func _section(t: String, n := 0) -> void:
	detail.add_child(UI.head(("%d. " % n if n > 0 else "") + t, 20, UI.YELLOW))


func _refresh() -> void:
	for c in list_box.get_children():
		c.queue_free()
	for gr in GROUPS:
		var gl := UI.head(gr[0], 18, UI.PINK_L)
		list_box.add_child(gl)
		list_box.add_child(UI.wrap(UI.label(gr[1], 14, UI.MUTED), 540))
		for id: int in gr[2]:
			var s: Dictionary = D.scenario(id)
			if s.is_empty():
				continue
			var b := Button.new()
			b.custom_minimum_size = Vector2(540, 52)
			b.focus_mode = Control.FOCUS_NONE
			b.set_meta("sid", id)
			var hb := HBoxContainer.new()
			hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			hb.offset_left = 12
			hb.offset_right = -12
			hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_theme_constant_override("separation", 10)
			b.add_child(hb)
			var vb := VBoxContainer.new()
			vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.add_theme_constant_override("separation", -2)
			vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hb.add_child(vb)
			var sel := id == scen_id
			var ln := UI.label(str(s["nome"]), 18, UI.YELLOW_L if sel else UI.TEXT)
			ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.add_child(ln)
			var lt := UI.label("%s  |  %s" % [s["anno"], _tags(s)], 13, UI.MUTED)
			lt.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.add_child(lt)
			if sel:
				_sel_style(b)
			b.pressed.connect(func():
				if scen_id != id:
					scen_id = id
					fmt = ""
					who = []
					_refresh()
					right_scroll.scroll_vertical = 0)
			list_box.add_child(b)
		var gap := Control.new()
		gap.custom_minimum_size.y = 6
		list_box.add_child(gap)
	for c in detail.get_children():
		c.queue_free()
	for c in foot.get_children():
		c.queue_free()
	var sc: Dictionary = D.scenario(scen_id)
	var lati: Array = sc["lati"]
	if fmt == "":
		fmt = sc["formato"]
	if who.size() != lati.size():
		who = []
		for i in lati.size():
			who.append(0 if i == 0 else 1)
	while names.size() < lati.size():
		names.append("")
	# --- scheda dello scenario
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	detail.add_child(top)
	var cov := TextureRect.new()
	cov.texture = UI.tex("res://assets/misc/copertina.webp")
	cov.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cov.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cov.custom_minimum_size = Vector2(140, 184)
	top.add_child(cov)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 6)
	top.add_child(tv)
	tv.add_child(UI.title(sc["nome"], 38))
	tv.add_child(UI.label("%s  |  %s  |  %s" % [sc["anno"], sc["orig"], _tags(sc)], 16, UI.MUTED))
	tv.add_child(UI.wrap(UI.label(sc["intro"], 18), 760))
	var vic := VBoxContainer.new()
	vic.add_theme_constant_override("separation", 4)
	detail.add_child(vic)
	vic.add_child(UI.head("Come si vince", 18, UI.PINK_L))
	for v in sc["vittoria"]:
		vic.add_child(UI.wrap(UI.label("- " + v, 16), 1000))
	if sc.get("note", "") != "":
		vic.add_child(UI.wrap(UI.label(sc["note"], 16, UI.PINK_L), 1000))
	detail.add_child(UI.hsep())
	# --- 2. giocatori
	_section("Chi gioca", 2)
	for i: int in lati.size():
		var sd: Dictionary = lati[i]
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		detail.add_child(r)
		var chip := ColorRect.new()
		chip.color = UI.side_color(sd["set"])
		chip.custom_minimum_size = Vector2(22, 22)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(chip)
		var l := UI.label(sd["nome"], 19)
		l.custom_minimum_size.x = 300
		r.add_child(l)
		var k := i
		if sd.get("neutrale", false) or (sc.get("solitario", false) and sc.has("solo_umano") and i != int(sc["solo_umano"])):
			who[i] = 1
			r.add_child(UI.label("si schiera durante la partita" if sd.get("neutrale", false) else "computer", 17, UI.MUTED))
			continue
		for opt in [[0, "Persona"], [1, "Computer"]]:
			var v: int = opt[0]
			var b := UI.button(opt[1], 130, 42, 17)
			if who[i] == v:
				_sel_style(b)
			b.pressed.connect(func():
				who[k] = v
				_refresh())
			r.add_child(b)
		if who[i] == 0:
			var le := LineEdit.new()
			le.placeholder_text = "nome (facoltativo)"
			le.text = names[i]
			le.custom_minimum_size = Vector2(220, 42)
			le.text_changed.connect(func(t): names[k] = t)
			r.add_child(le)
	var hum := 0
	for w in who:
		if w == 0:
			hum += 1
	if hum >= 2:
		detail.add_child(UI.wrap(UI.label("Più persone sullo stesso dispositivo: i piani restano segreti, e prima di ogni scelta lo schermo chiede di passare il dispositivo. Per giocare ognuno dal suo, usa Gioca online.", 15, UI.MUTED), 1000))
	elif hum == 0:
		detail.add_child(UI.wrap(UI.label("Nessuna persona: guarderai il computer giocare contro se stesso.", 15, UI.MUTED), 1000))
	# --- 3. formato
	_section("Formato", 3)
	fmt_box = HBoxContainer.new()
	fmt_box.add_theme_constant_override("separation", 8)
	detail.add_child(fmt_box)
	for f in [["base", "Base"], ["modificato", "Base con randomizzatore"], ["avanzato", "Avanzato (Tactical Display)"]]:
		var key: String = f[0]
		var b := UI.button(f[1] + ("  (consigliato)" if key == sc["formato"] else ""), 0, 44, 17)
		if key == fmt:
			_sel_style(b)
		if sc.has("formati") and not key in sc["formati"]:
			b.disabled = true
			b.tooltip_text = "Questo scenario si gioca solo nel formato indicato."
		elif sc.has("xeno") and key == "avanzato":
			b.tooltip_text = "Il regolamento consiglia il gioco base per gli Xenofobi; nel gioco avanzato la nova si innesca sul Tactical Display (31.52)."
		b.pressed.connect(func():
			fmt = key
			_refresh())
		fmt_box.add_child(b)
	detail.add_child(UI.wrap(UI.label(FMT_DESC[fmt], 15, UI.MUTED), 1000))
	# --- 4. regole opzionali (32.0-36.0)
	var n_opt := 0
	if not sc.get("solitario", false) and not sc.get("senza_opzioni", false):
		_section("Regole opzionali", 4)
		detail.add_child(UI.wrap(UI.label("Facoltative: aggiungono dettaglio. Passa il mouse su una regola per leggere cosa fa.", 15, UI.MUTED), 1000))
		var ro := HFlowContainer.new()
		ro.add_theme_constant_override("h_separation", 8)
		ro.add_theme_constant_override("v_separation", 6)
		detail.add_child(ro)
		var forced: Array = sc.get("opzioni", [])
		for k in D.OPTIONS:
			var key3: String = k
			var on: bool = key3 in forced or bool(opz.get(key3, false))
			var b := UI.button(("%s: sì" if on else "%s: no") % D.OPTIONS[k][0], 0, 40, 16)
			b.tooltip_text = D.OPTIONS[k][1]
			if on:
				_sel_style(b)
				n_opt += 1
			if key3 in forced:
				b.disabled = true
				b.tooltip_text += " (sempre attiva in questo scenario)"
			else:
				b.pressed.connect(func():
					opz[key3] = not bool(opz.get(key3, false))
					_refresh())
			ro.add_child(b)
	# --- aspetto
	_section("Aspetto")
	var rg := HBoxContainer.new()
	rg.add_theme_constant_override("separation", 8)
	detail.add_child(rg)
	rg.add_child(UI.label("Grafica", 16, UI.MUTED))
	for g in [["reborn", "Astronavi 3D"], ["originale", "Mappa e pedine SPI"]]:
		var key2: String = g[0]
		var b := UI.button(g[1], 0, 40, 16)
		if style == key2:
			_sel_style(b)
		b.pressed.connect(func():
			style = key2
			_refresh())
		rg.add_child(b)
	var gap := Control.new()
	gap.custom_minimum_size.x = 20
	rg.add_child(gap)
	rg.add_child(UI.label("Animazioni", 16, UI.MUTED))
	for sp in [[1.0, "Normali"], [2.5, "Veloci"]]:
		var v2: float = sp[0]
		var b := UI.button(sp[1], 0, 40, 16)
		if is_equal_approx(speed, v2):
			_sel_style(b)
		b.pressed.connect(func():
			speed = v2
			_refresh())
		rg.add_child(b)
	# --- piede: riepilogo e avvio
	var sum := []
	var people := []
	var comps := 0
	for i in lati.size():
		if who[i] == 0:
			people.append(str(lati[i]["nome"]))
		else:
			comps += 1
	if people.is_empty():
		sum.append("solo computer")
	else:
		sum.append("tu: " + ", ".join(people) + (" contro il computer" if comps > 0 else ""))
	sum.append({"base": "gioco base", "modificato": "base con randomizzatore", "avanzato": "gioco avanzato"}[fmt])
	if n_opt > 0:
		sum.append("%d regol%s opzional%s" % [n_opt, "a" if n_opt == 1 else "e", "e" if n_opt == 1 else "i"])
	foot.add_child(UI.wrap(UI.label("%s  |  %s" % [sc["nome"], ", ".join(sum)], 16, UI.PINK_L), 1000))
	var rb := HBoxContainer.new()
	rb.add_theme_constant_override("separation", 14)
	foot.add_child(rb)
	var bp := UI.primary(UI.button("Gioca", 260, 60, 26))
	bp.tooltip_text = "Tutti sullo stesso dispositivo (con il computer per i lati non umani)"
	bp.pressed.connect(_on_start)
	rb.add_child(bp)
	if not sc.get("solitario", false):
		var bo := UI.button("Crea una partita online", 0, 60, 20)
		bo.tooltip_text = "Ognuno dal suo dispositivo: ricevi un codice da mandare agli altri"
		bo.pressed.connect(_online_create_panel)
		rb.add_child(bo)


func _config() -> Dictionary:
	var sc: Dictionary = D.scenario(scen_id)
	var seats := []
	for i in sc["lati"].size():
		seats.append({"name": str(names[i]).strip_edges(), "ai": who[i] == 1, "level": 1})
	var on := {}
	for k in opz:
		if opz[k] and not k in sc.get("opzioni", []):
			on[k] = true
	return {"scenario": scen_id, "mode": fmt, "seats": seats, "style": style, "anim": speed, "ai_delay": 0.5 / speed, "opzioni": on}


func _on_start() -> void:
	_store()
	main.start_game(_config())


# ================================================================ caricamento

func _tutorial_panel() -> void:
	_store()
	var Tut = preload("res://scripts/ui/tutorial.gd")
	var p := _overlay()
	var vb: VBoxContainer = p.get_meta("vb")
	vb.add_child(UI.title("Tutorial guidati", 44))
	vb.add_child(UI.wrap(UI.label("Partite vere contro l'IA: un riquadro ti spiega ogni passo e si accorge da solo quando hai fatto quello che chiede. Meglio farli in ordine.", 19), 760))
	for l in Tut.LESSONS:
		var n: int = l["n"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		vb.add_child(row)
		var b := UI.primary(UI.button("%d" % n, 64, 64, 28)) if n == 1 else UI.button("%d" % n, 64, 64, 28)
		b.pressed.connect(func(): main.start_game(Tut.game_config(n)))
		row.add_child(b)
		var col := VBoxContainer.new()
		col.add_child(UI.head(l["titolo"], 21, UI.YELLOW))
		col.add_child(UI.wrap(UI.label(l["desc"], 17, UI.TEXT), 660))
		row.add_child(col)
	var bc := UI.button("Indietro", 200, 52, 20)
	bc.pressed.connect(func(): p.queue_free())
	vb.add_child(bc)


func _load_panel() -> void:
	_store()
	var p := _overlay()
	var vb: VBoxContainer = p.get_meta("vb")
	vb.add_child(UI.title("Carica una partita", 44))
	vb.add_child(UI.wrap(UI.label("Scrivi il codice di cinque lettere che hai ricevuto quando hai salvato.", 19), 700))
	var le := _line("Codice", 5)
	le.text_changed.connect(func(t):
		le.text = t.to_upper()
		le.caret_column = t.length())
	vb.add_child(le)
	var msg := UI.wrap(UI.label("", 19, UI.YELLOW_L), 700)
	vb.add_child(msg)
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	vb.add_child(r)
	var bo := UI.primary(UI.button("Carica", 240, 56, 22))
	r.add_child(bo)
	var bc := UI.button("Indietro", 200, 56, 20)
	bc.pressed.connect(func(): p.queue_free())
	r.add_child(bc)
	bo.pressed.connect(func():
		var code := le.text.strip_edges().to_upper()
		if code.length() < 4:
			msg.text = "Codice non valido."
			return
		msg.text = "Carico..."
		var net: Net = main.get_net()
		var d: Dictionary = await net.load_game(code)
		if d.is_empty():
			msg.text = "Partita %s non trovata. %s" % [code, net.last_error]
			return
		var cfg = str_to_var(str(d.get("cfg", "")))
		var acts = str_to_var(str(d.get("acts", "")))
		if not (cfg is Dictionary) or not (acts is Array):
			msg.text = "Salvataggio non leggibile."
			return
		cfg["preload"] = acts
		cfg["save_code"] = code
		main.start_game(cfg))


func _overlay() -> Control:
	var p := Control.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(p)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.add_child(shade)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.panel_style(0.98))
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.custom_minimum_size = Vector2(840, 0)
	box.offset_left = -420
	box.offset_right = 420
	box.offset_top = 110
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	box.add_child(vb)
	p.set_meta("vb", vb)
	return p


func _line(ph: String, maxlen: int) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = ph
	le.max_length = maxlen
	le.custom_minimum_size = Vector2(0, 56)
	le.add_theme_font_size_override("font_size", 24)
	return le


# ================================================================ online

var on_join := false


func _online_join_panel() -> void:
	on_join = true
	_online_panel()


func _online_create_panel() -> void:
	on_join = false
	_online_panel()


func _online_panel() -> void:
	_store()
	if is_instance_valid(on_panel):
		on_panel.queue_free()
	on_panel = _overlay()
	var vb: VBoxContainer = on_panel.get_meta("vb")
	vb.add_child(UI.title("Entra in una partita online" if on_join else "Crea una partita online", 44))
	var sc: Dictionary = D.scenario(scen_id)
	if on_join:
		vb.add_child(UI.wrap(UI.label("Scrivi il tuo nome e il codice di quattro lettere che ti ha mandato chi ha creato la stanza. Scenario e regole li ha già scelti lui.", 19, UI.MUTED), 800))
	else:
		vb.add_child(UI.wrap(UI.label("Scenario: %s, %s. Scegli il tuo lato e crea la stanza: riceverai un codice da mandare agli amici. Scenario, formato e regole scelti nel menu valgono per tutti; i posti rimasti liberi li gioca il computer." % [sc["nome"], {"base": "gioco base", "modificato": "base con randomizzatore", "avanzato": "gioco avanzato"}[fmt]], 19, UI.MUTED), 800))
	var ses: Dictionary = main.get_net().load_session()
	on_name = _line("Il tuo nome", 20)
	on_name.text = str(ses.get("name", ""))
	vb.add_child(on_name)
	var r0 := HBoxContainer.new()
	r0.add_theme_constant_override("separation", 8)
	r0.visible = not on_join
	vb.add_child(r0)
	r0.add_child(UI.label("Tu giochi:", 19))
	for i in sc["lati"].size():
		var k: int = i
		var b := UI.button(sc["lati"][i]["nome"], 0, 44, 17)
		if host_side == i:
			b.add_theme_stylebox_override("normal", UI.box(Color("#5a1d36"), UI.YELLOW, 2, 6))
		b.pressed.connect(func():
			host_side = k
			_online_panel())
		r0.add_child(b)
	var b_create := UI.primary(UI.button("Crea una stanza", 0, 56, 22))
	b_create.pressed.connect(_online_create)
	b_create.visible = not on_join
	vb.add_child(b_create)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	on_code = _line("Codice", 4)
	on_code.custom_minimum_size.x = 220
	on_code.text_changed.connect(func(t):
		on_code.text = t.to_upper()
		on_code.caret_column = t.length())
	row.add_child(on_code)
	var b_join := UI.button("Entra", 200, 56, 22)
	b_join.pressed.connect(_online_join)
	row.add_child(b_join)
	row.visible = on_join
	vb.add_child(row)
	on_lbl = UI.wrap(UI.label("", 20, Color.WHITE), 780)
	on_lbl.custom_minimum_size.y = 100
	vb.add_child(on_lbl)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	on_start = UI.primary(UI.button("Inizia online", 380, 60, 24))
	on_start.pressed.connect(_online_start)
	on_start.visible = main.lobby.get("role", "") == "host"
	row2.add_child(on_start)
	var b_close := UI.button("Indietro", 260, 60, 22)
	b_close.pressed.connect(func(): on_panel.queue_free())
	row2.add_child(b_close)
	vb.add_child(row2)
	if not main.lobby.is_empty():
		on_code.text = main.lobby["code"]
		on_lbl.text = "Stanza %s..." % main.lobby["code"]
	elif str(ses.get("room", "")) != "":
		on_code.text = str(ses["room"])
		on_lbl.text = "Eri nella stanza %s: premi Entra per rientrare." % ses["room"]


func _say(t: String) -> void:
	if is_instance_valid(on_lbl):
		on_lbl.text = t


func _seat_names() -> Array:
	var out := []
	for sd in D.scenario(scen_id)["lati"]:
		out.append(sd["nome"])
	return out


func _seats_text(room: Dictionary) -> String:
	var seats := Net._as_dict(room.get("seats", {}))
	var parts := []
	for idx in room.get("open", []):
		var k := str(int(idx))
		var w := str(seats[k].get("name", "?")) if seats.has(k) and seats[k] is Dictionary else "libero (IA)"
		parts.append("%s: %s" % [_seat_names()[int(idx)], w])
	return ", ".join(parts)


func _online_create() -> void:
	var nm := on_name.text.strip_edges()
	if nm == "":
		_say("Scrivi il tuo nome.")
		return
	var seats := [host_side]
	for i in _seat_names().size():
		if i != host_side:
			seats.append(i)
	_say("Creo la stanza...")
	var net: Net = main.get_net()
	var code := await net.create_room(nm, seats)
	if code == "":
		_say("Non riesco a creare la stanza.\n%s" % net.last_error)
		return
	main.lobby = {"role": "host", "code": code, "seat": host_side}
	net.remember_room(code, host_side)
	net._save({"name": nm})
	if is_instance_valid(on_code):
		on_code.text = code
	if is_instance_valid(on_start):
		on_start.visible = true
	_lobby_poll(code)


func _online_join() -> void:
	var code := on_code.text.strip_edges().to_upper()
	var nm := on_name.text.strip_edges()
	if nm == "" or code.length() != 4:
		_say("Scrivi il tuo nome e il codice di 4 lettere.")
		return
	_say("Entro nella stanza %s..." % code)
	var net: Net = main.get_net()
	var s := await net.join_room(code, nm)
	if s == -2:
		_say("Stanza %s non trovata, oppure la partita è già iniziata.%s" % [code, ("\n" + net.last_error) if net.last_error != "" else ""])
		return
	if s == -1:
		_say("Nella stanza %s non ci sono posti liberi." % code)
		return
	var room: Dictionary = net.last_room
	main.lobby = {"role": "host" if room.get("host", "") == net.uid else "guest", "code": code, "seat": s}
	net.remember_room(code, s)
	net._save({"name": nm})
	if room.get("status", "") in ["playing", "over"] and room.has("game"):
		_say("Rientro nella partita della stanza %s..." % code)
		_begin(room["game"], true)
		return
	if is_instance_valid(on_start):
		on_start.visible = main.lobby["role"] == "host"
	_lobby_poll(code)


func _lobby_poll(code: String) -> void:
	var net: Net = main.get_net()
	while is_inside_tree() and main.lobby.get("code", "") == code:
		var room := await net.room(code)
		if not is_inside_tree() or main.lobby.get("code", "") != code:
			return
		if room.is_empty():
			_say("La stanza %s non esiste più." % code)
			main.lobby = {}
			return
		if main.lobby["role"] == "host":
			_say("Stanza [ %s ]: dai il codice ai tuoi amici.\nPosti: %s.\nQuando ci sono tutti premi Inizia online." % [code, _seats_text(room)])
		else:
			if room.get("status", "") == "playing" and room.has("game"):
				_begin(room["game"], false)
				return
			_say("Sei nella stanza [ %s ] (giochi: %s).\nAspetta che chi l'ha creata avvii la partita." % [code, _seat_names()[int(main.lobby["seat"])]])
		await get_tree().create_timer(2.0).timeout


func _online_start() -> void:
	var code: String = main.lobby["code"]
	var net: Net = main.get_net()
	var room := await net.room(code)
	if room.is_empty():
		_say("La stanza %s non esiste più." % code)
		main.lobby = {}
		return
	var seats_db := Net._as_dict(room.get("seats", {}))
	var cfg := _config()
	for i in cfg["seats"].size():
		var k := str(i)
		if seats_db.has(k) and seats_db[k] is Dictionary:
			cfg["seats"][i]["name"] = str(seats_db[k].get("name", ""))
			cfg["seats"][i]["ai"] = false
		else:
			cfg["seats"][i]["ai"] = true
	cfg["seed"] = 1 + randi() % 2000000000
	var g := {"cfg": var_to_str(cfg)}
	if not await net.start_room(code, g):
		_say("Non riesco ad avviare la partita (%s)." % net.last_error)
		return
	_begin(g, false)


func _begin(g: Dictionary, rejoin: bool) -> void:
	var net: Net = main.get_net()
	var lob: Dictionary = main.lobby
	var backlog: Array = []
	if rejoin:
		backlog = await net.get_acts(lob["code"])
		net.set_away(lob["code"], int(lob["seat"]), false)
	var cfg = str_to_var(str(g.get("cfg", "")))
	if not (cfg is Dictionary):
		_say("Configurazione della partita non valida.")
		return
	cfg["style"] = style
	var ses := OnlineSession.new()
	ses.setup(net, lob["code"], int(lob["seat"]), lob["role"], backlog)
	cfg["online"] = ses
	main.lobby = {}
	main.start_game(cfg)
