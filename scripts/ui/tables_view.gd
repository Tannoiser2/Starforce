extends Control
## Tabelle del gioco, consultabili in ogni momento (pulsante "Tabelle" in partita).
## Ogni scheda mostra una famiglia di tabelle con una breve spiegazione di come si legge.

const D := preload("res://scripts/data/sf_data.gd")

var tab := "spostamenti"
var outleap := false
var body: VBoxContainer
var tab_buttons := {}

const TABS := [["spostamenti", "Spostamenti"], ["combattimento", "Combattimento base"],
	["tattico", "Tactical Display"], ["outleap", "Outleap"]]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.01, 0.02, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			queue_free())
	add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel_style(0.98))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 120
	panel.offset_right = -120
	panel.offset_top = 50
	panel.offset_bottom = -50
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	vb.add_child(top)
	top.add_child(UI.title("Tabelle", 40))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var bx := UI.primary(UI.button("Chiudi", 120, 42, 17))
	bx.pressed.connect(queue_free)
	top.add_child(bx)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	vb.add_child(tabs)
	for t in TABS:
		if t[0] == "outleap" and not outleap:
			continue
		var b := UI.button(t[1], 0, 40, 17)
		var key: String = t[0]
		b.pressed.connect(func():
			tab = key
			_build())
		tabs.add_child(b)
		tab_buttons[key] = b
	vb.add_child(UI.hsep())
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	_build()


func _unhandled_key_input(ev: InputEvent) -> void:
	if ev.is_pressed() and ev is InputEventKey and ev.keycode == KEY_ESCAPE:
		queue_free()


func _build() -> void:
	for k in tab_buttons:
		var b: Button = tab_buttons[k]
		if k == tab:
			UI.primary(b)
		else:
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_stylebox_override("hover")
			b.remove_theme_color_override("font_color")
	for c in body.get_children():
		c.queue_free()
	match tab:
		"spostamenti":
			_shifts()
		"combattimento":
			body.add_child(crt_table())
		"tattico":
			_tactical()
		"outleap":
			_outleap()


func _note(t: String) -> void:
	body.add_child(UI.wrap(UI.label(t, 15, UI.MUTED), 1100))


## griglia con intestazione: righe = array di array di stringhe
static func grid(head: Array, rows: Array, hl_col := -1, cell_w := 52) -> GridContainer:
	var g := GridContainer.new()
	g.columns = head.size()
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 2)
	for i in head.size():
		var l := UI.mono(str(head[i]), 14, UI.YELLOW if i != hl_col else UI.YELLOW_L)
		l.custom_minimum_size.x = cell_w if i > 0 else maxi(cell_w, 60)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if i > 0 else HORIZONTAL_ALIGNMENT_LEFT
		if i == hl_col:
			l.add_theme_stylebox_override("normal", UI.box(Color("#6a1c3b"), UI.YELLOW, 1, 3, 1))
		g.add_child(l)
	for r in rows:
		for i in r.size():
			var s := str(r[i])
			var col: Color = UI.YELLOW if i == 0 else (UI.MUTED if s in ["-", ".", ""] else UI.TEXT)
			var l := UI.mono(s, 14, col)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if i > 0 else HORIZONTAL_ALIGNMENT_LEFT
			if i == hl_col:
				l.add_theme_stylebox_override("normal", UI.box(Color("#3a1226"), Color("#3a1226"), 0, 0, 1))
				l.add_theme_color_override("font_color", UI.YELLOW_L if not s in ["-", "."] else UI.MUTED)
			g.add_child(l)
	return g


static func crt_table() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.add_child(UI.head("Risultati del combattimento base (perdite in StarForce)", 18, UI.PINK_L))
	var head := ["chit"]
	for c in range(-3, 7):
		head.append(("%+d" % c) if c != 0 else "0")
	var rows := []
	for r in 10:
		var row := [str(r)]
		for c in 10:
			var v: int = D.SCRT[r][c]
			row.append(str(v) if v > 0 else "-")
		rows.append(row)
	vb.add_child(grid(head, rows, -1, 40))
	vb.add_child(UI.wrap(UI.label("Colonna: attacco meno difesa nemica (sotto -3 non si può attaccare, oltre +6 vale +6). Riga: il chit pescato. Il numero è quante StarForce perde il nemico. Una StarGate vale due perdite e cade solo con un risultato di almeno 2 che superi le StarForce che la difendono.\nValori: StarForce 3 (2 nel primo segmento se è appena entrata), StarGate 5 (dal secondo segmento). Nel primo segmento chi era già nella LiteZulu può rifiutare lo scontro. Sei segmenti di fila senza perdite: chi non difende la StarGate deve ritirarsi.", 15, UI.MUTED), 1000))
	return vb


## colonna dell'oltre-spostamento: quanti chit su dieci danno arrivo, specchio, randomizzazione
static func overshift_odds(col: int) -> Dictionary:
	var o := {"S": 0, "M": 0, "R": 0}
	if col < 1:
		o["S"] = 10
		return o
	for r in 10:
		o[str(D.OVERSHIFT[r][col - 1])] += 1
	return o


static func overshift_table(hl := -1) -> GridContainer:
	var rows := []
	var nm := {"S": "arriva", "M": "specchio", "R": "random"}
	for r in 10:
		var row := [str(r)]
		for c in 6:
			row.append(nm[str(D.OVERSHIFT[r][c])])
		rows.append(row)
	return grid(["chit", "A", "B", "C", "D", "E", "F"], rows, hl, 82)


func _shifts() -> void:
	body.add_child(UI.head("Portata degli spostamenti (Lite)", 18, UI.PINK_L))
	var rows := []
	var names := {"S": "S  normale", "ES": "ES  verso un rinforzo", "GS": "GS  da una StarGate", "EGS": "EGS  StarGate + rinforzo", "GGS": "GGS  da StarGate a StarGate"}
	for k in ["S", "ES", "GS", "EGS", "GGS"]:
		var v: Array = D.SHIFT_TABLE[k]
		rows.append([names[k], str(v[0]), "%d" % v[1], "%d" % v[2], "%d" % v[3], "%d" % v[4], "%d" % v[5], "oltre"])
	var g := grid(["tipo", "sicuro", "A", "B", "C", "D", "E", "F"], rows, -1, 70)
	body.add_child(g)
	_note("Fino al valore \"sicuro\" si arriva senza rischi. Oltre, la colonna è la prima il cui valore copre la distanza (F oltre la colonna E). Entrare nella LiteZulu di una StarGate nemica attiva aggiunge 4 Lite, a meno di partire da una delle 20 LiteZulu adiacenti. Il GateLink (regola opzionale) collega StarGate amiche entro 20 Lite l'una dall'altra senza rischi.")
	body.add_child(UI.head("Esito dell'oltre-spostamento", 18, UI.PINK_L))
	body.add_child(overshift_table())
	var odds := []
	for c in range(1, 7):
		var o := overshift_odds(c)
		odds.append("%s: %d arriva, %d specchio, %d random" % ["ABCDEF"[c - 1], o["S"], o["M"], o["R"]])
	_note("Su dieci chit: " + "; ".join(odds) + ".\nSpecchio: la StarForce finisce alla stessa distanza nella direzione opposta, con la Zulu invertita (nel gioco avanzato resta neutralizzata). Random: nel gioco base esce dalla partita; nel gioco avanzato e con il randomizzatore finisce in un punto a caso, neutralizzata. Gli spostamenti GS e GGS uguali pescano un solo chit per tutto il gruppo.")
	body.add_child(UI.head("Spazio ignoto (scenari degli Xenofobi)", 18, UI.PINK_L))
	var r2 := []
	for k in ["S", "GS"]:
		var v: Array = D.SHIFT_UNKNOWN[k]
		r2.append([k, str(v[0]), str(v[1]), str(v[2]), str(v[3]), str(v[4]), str(v[5]), "oltre"])
	body.add_child(grid(["tipo", "sicuro", "A", "B", "C", "D", "E", "F"], r2, -1, 70))


## tabella di risoluzione delle proiezioni; hl = colonna da evidenziare (0-6)
static func cast_table(hl := -1, cw := 58) -> GridContainer:
	var rows := []
	var nm := {".": "-", "D": "D", "R": "R"}
	for r in 10:
		var row := [str(r)]
		for c in 7:
			row.append(nm[str(D.CAST_TABLE[r][c])])
		rows.append(row)
	return grid(["chit", "0", "+1", "+2/3", "+4/7", "+8/15", "+16/31", "+32"], rows, hl, cw)


static func cast_col(diff: int) -> int:
	if diff >= 32:
		return 6
	if diff >= 16:
		return 5
	if diff >= 8:
		return 4
	if diff >= 4:
		return 3
	if diff >= 2:
		return 2
	if diff >= 1:
		return 1
	return 0


func _tactical() -> void:
	body.add_child(UI.head("TeleValue e costi del Tac-spostamento (TelePunti)", 18, UI.PINK_L))
	var rs := ["stellare (32)"]
	var head := ["MiniLite"]
	for d in range(1, 11):
		head.append(str(d))
		rs.append(str(D.TAC_COST_STELLAR[d]))
	var rb := ["battaglia (64)"]
	for d in range(1, 11):
		rb.append(str(D.TAC_COST_BATTLE[d]) if d < D.TAC_COST_BATTLE.size() else "-")
	var fs := ["FakerForce stell. (8)"]
	var fb := ["FakerForce batt. (16)"]
	for d in range(1, 11):
		fs.append(str(D.FF_COST_STELLAR[d]))
		fb.append(str(D.FF_COST_BATTLE[d]) if d < D.FF_COST_BATTLE.size() else "-")
	body.add_child(grid(head, [rs, rb, fs, fb], -1, 46))
	_note("Il numero fra parentesi è il TeleValue del modo. La StarGate ha 64 punti in ciascuna fase. Cambio di modo (solo prima fase): metà del TeleValue del nuovo modo. Ritirata (solo seconda fase, in modo stellare): 16 punti (4 per una FakerForce). I punti non spesi sono l'anti-proiezione per tutto il Tac-turno.")
	body.add_child(UI.head("Forza della proiezione secondo la distanza", 18, UI.PINK_L))
	var prow := []
	for p in D.CAST_LEVELS:
		var row := [str(p)]
		for d in 6:
			var v: int = int(p) >> d
			row.append(str(v) if v > 0 else "-")
		prow.append(row)
	body.add_child(grid(["punti", "0", "1", "2", "3", "4", "5"], prow, -1, 46))
	_note("Colonne: distanza in MiniLite dal punto di partenza. La proiezione si dimezza a ogni MiniLite e ha portata 5. Riempie un cuneo di 60 gradi verso l'ora scelta (1, 3, 5, 7, 9, 11), allargandosi verso l'alto o verso il basso.")
	body.add_child(UI.head("Risoluzione delle proiezioni", 18, UI.PINK_L))
	body.add_child(cast_table())
	_note("Colonna: somma delle proiezioni che raggiungono l'unità meno la sua anti-proiezione (se è negativa non succede niente). Riga: il chit. D = disgregata (TeleValue dimezzato fino al recupero; una StarForce già disgregata viene randomizzata). R = StarForce randomizzata, StarGate disgregata. Una StarGate disgregata che subisce un'altra R è neutralizzata.")


func _outleap() -> void:
	body.add_child(UI.head("Esplorazione e rendita", 18, UI.PINK_L))
	var rows := []
	for r in 10:
		var tp: String = D.OL_EXPLORE[r]
		var row := [str(r), tp if tp != "" else "-", D.OL_TIPI[tp]]
		rows.append(row)
	body.add_child(grid(["chit", "esito", "scoperta"], rows, -1, 80))
	var ir := []
	for tp in ["VRM", "RM", "SV"]:
		var row := [tp]
		for c in 10:
			row.append(str(D.OL_INCOME[tp][c]))
		row.append(str(D.OL_AVG[tp]))
		ir.append(row)
	body.add_child(grid(["rendita", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "media"], ir, -1, 46))
	_note("Un gruppo EE che esplora pesca un chit: il risultato dice cosa trova. Ogni anno, per ogni scoperta, si pesca un chit sulla riga del suo tipo per sapere quanti MLC rende.")
	body.add_child(UI.head("Costi (MLC)", 18, UI.PINK_L))
	var cr := []
	for k in ["sf", "gate", "seed", "ee", "ss"]:
		var c: Array = D.OL_COST[k]
		cr.append([D.OL_NOMI[k], str(c[0]), str(c[1]), str(c[2])])
	body.add_child(grid(["unità", "popolazione", "nuova", "mantenerla"], cr, -1, 120))
	body.add_child(UI.head("MLC prodotti da una colonia secondo la popolazione", 18, UI.PINK_L))
	var mh := ["pop."]
	var mr := ["MLC"]
	for p in range(1, 19):
		mh.append(str(p))
		mr.append(str(D.OL_COL_MLC[p]))
	body.add_child(grid(mh, [mr], -1, 34))
