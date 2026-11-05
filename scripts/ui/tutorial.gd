extends PanelContainer
## Tutorial guidato: una partita vera (scenario 1, gioco base, contro l'IA) spiegata passo per passo.
## Il riquadro sta a sinistra sotto le forze in campo; ogni passo si chiude da solo quando il
## giocatore ha fatto la cosa richiesta, oppure con "Avanti" quando è solo da leggere.

var g                       # game_view
var step := 0
var steps: Array = []
var title_l: Label
var body_l: RichTextLabel
var next_b: Button
var count_l: Label
var _t := 0.0


func _ready() -> void:
	add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.03, 0.06, 0.95), UI.YELLOW, 2, 10, 14))
	position = Vector2(10, 232)
	custom_minimum_size = Vector2(380, 0)
	size = Vector2(380, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)
	var hb := HBoxContainer.new()
	vb.add_child(hb)
	title_l = UI.head("", 20, UI.YELLOW)
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hb.add_child(title_l)
	count_l = UI.mono("", 14, UI.MUTED)
	hb.add_child(count_l)
	body_l = UI.rich(16)
	body_l.custom_minimum_size = Vector2(352, 0)
	body_l.fit_content = true
	vb.add_child(body_l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	next_b = UI.primary(UI.button("Avanti", 150, 40, 17))
	next_b.pressed.connect(_next)
	row.add_child(next_b)
	var skip := UI.button("Chiudi il tutorial", 0, 40, 15)
	skip.pressed.connect(func():
		g.board.set_hint(null)
		queue_free())
	row.add_child(skip)
	_build_steps()
	_show()


func _ac() -> Vector3i:
	for st in g.eng.stars.get(1821, []):
		return Hex.lz(1821, int(st["z"]))
	return Vector3i(0, 0, 0)


func _dests() -> int:
	var n := 0
	for id in g.plot:
		var p: Dictionary = g.plot[id]
		if p.has("to") and g.eng.units.has(id) and p["to"] != g.eng.units[id]["lz"]:
			n += 1
	return n


func _req() -> String:
	return str(g.req.get("type", ""))


func _build_steps() -> void:
	steps = [
		{"t": "Benvenuto in StarForce",
		 "b": "Sei l'[color=#7fd3ff]Egemonia Solare[/color] (blu). La colonia di [color=#9be37a]Alpha Centauri[/color] (verde) si è ribellata e ha costruito una [b]StarGate[/b], una stazione che permette alle flotte di saltare nello spazio.\n\n[b]Obiettivo[/b]: portare le tue flotte (le [b]StarForce[/b]) dove si trova la StarGate nemica e distruggerla.\n\nQuesto riquadro ti guida: quando ti chiede di fare qualcosa, si accorge da solo che l'hai fatto.",
		 "wait": ""},
		{"t": "Muovere la vista",
		 "b": "La mappa è [b]tridimensionale[/b]: le stelle stanno sopra o sotto il piano.\n\n- [b]trascina[/b] col mouse (o un dito) per ruotare\n- [b]rotella[/b] (o due dita) per avvicinarti\n- [b]tasto destro[/b] o Maiusc + trascina per spostarti\n\nIn basso a sinistra ci sono anche i pulsanti. Prova [b]Vista dall'alto[/b]: la mappa diventa piatta come quella di carta, con l'altezza scritta accanto a ogni stella.",
		 "wait": ""},
		{"t": "Leggere la mappa",
		 "b": "Ogni esagono ha un numero di quattro cifre ([b]2020[/b] è Sol). L'altezza sopra o sotto il piano si chiama [b]quota Zulu[/b]: Alpha Centauri è a [b]1821/-4[/b], cioè esagono 1821, quattro sotto il piano.\n\nUn esagono più una quota è una [b]LiteZulu[/b]: è lì che stanno flotte e stelle.\n\nPassa il mouse su una stella: in basso leggi nome e posizione, e lo stelo che la collega al piano si accende.",
		 "wait": ""},
		{"t": "Le tue forze",
		 "b": "A Sol (2020/0) hai la tua StarGate e quattro StarForce, le lettere [b]A B C D[/b] sopra la stella.\n\nIl nemico di solito non lo vedi bene: il segnalino con il [color=#ffd84d]?[/color] dice in quale esagono si trova qualcosa, ma non a che quota. Lo vedrai davvero solo quando ci arrivi vicino.\n\nIn alto a sinistra c'è il conto delle forze in campo.",
		 "wait": ""},
		{"t": "1. Scegli una flotta",
		 "b": "Ogni turno tutti scrivono in segreto dove vanno, e poi ci si muove insieme.\n\nNel pannello a destra clicca sulla riga [b]A[/b] (oppure sulla flotta A sulla mappa) per sceglierla.",
		 "wait": "sel"},
		{"t": "2. Scegli dove andare",
		 "b": "Ora clicca sulla stella [b]Alpha Centauri[/b], quella segnata dall'anello giallo lampeggiante.\n\nIl cursore che compare ha un colore: [color=#7fe07f]verde[/color] vuol dire salto sicuro, [color=#ffd84d]giallo[/color] e [color=#ff9a4d]arancio[/color] che la flotta può finire un po' fuori rotta, [color=#ff5a5a]rosso[/color] che è un salto molto rischioso.\n\nLa sfera azzurra intorno alla flotta mostra fin dove si arriva senza rischi.",
		 "wait": "dest1"},
		{"t": "3. Le altre flotte",
		 "b": "Ottimo. Fai lo stesso con [b]B[/b] e [b]C[/b]: sceglile e clicca Alpha Centauri. In tre si attacca meglio.\n\nLascia [b]D[/b] a Sol a proteggere la tua StarGate: se la perdi, perdi la partita.\n\n(Se ti serve una quota diversa da quella della stella, la cambi con i pulsanti o con i tasti W e S.)",
		 "wait": "dest3"},
		{"t": "4. Conferma il piano",
		 "b": "Sulla mappa vedi le scie colorate dei salti che hai scritto. Quando ti va bene premi [b]Conferma il piano[/b] in fondo al pannello a destra.\n\nAnche l'IA ha scritto il suo piano in segreto: adesso si muovono tutti insieme.",
		 "wait": "confirmed"},
		{"t": "I salti",
		 "b": "Guarda le flotte saltare. Un salto lungo può [b]deviare[/b]: la flotta arriva in una LiteZulu vicina a quella voluta. Nel registro in basso c'è scritto cosa è successo a ognuna.\n\nSe una tua flotta arriva dove c'è il nemico, si combatte.",
		 "wait": "combat_or_turn"},
		{"t": "Il combattimento",
		 "b": "Ogni flotta ha dei punti di forza. Devi dividerli in segreto fra [b]attacco[/b] e [b]difesa[/b]: più attacchi, più fai danni, ma più ne subisci.\n\nPer cominciare va bene la proposta già pronta: premi il pulsante di conferma nel pannello a destra. La tabella sotto mostra cosa può succedere.",
		 "wait": "alloc_done"},
		{"t": "Ora tocca a te",
		 "b": "Hai visto tutto quello che serve: [b]scegli, punta, conferma[/b], e in battaglia dividi attacco e difesa.\n\nContinua la partita fino a distruggere la StarGate di Alpha Centauri. Se vuoi i dettagli, premi [b]Regole[/b] in alto; [b]Registro[/b] mostra tutto quello che è successo.\n\nQuando vuoi, prova gli altri scenari dal menu, anche il gioco avanzato con il display tattico.",
		 "wait": ""},
	]


func _show() -> void:
	if step >= steps.size():
		g.board.set_hint(null)
		queue_free()
		return
	var s: Dictionary = steps[step]
	title_l.text = s["t"]
	body_l.text = s["b"]
	count_l.text = "%d/%d" % [step + 1, steps.size()]
	next_b.visible = s["wait"] == ""
	next_b.text = "Fine" if step == steps.size() - 1 else "Avanti"
	g.board.set_hint(_ac() if s["wait"] in ["dest1", "dest3"] else null)


func _next() -> void:
	step += 1
	_show()


func _process(dt: float) -> void:
	# sempre appena sotto il riquadro delle forze in campo, che cambia altezza
	if g != null and g.info_box != null:
		var lp: Control = g.info_box.get_parent()
		position.y = lp.position.y + lp.size.y + 10.0
	_t += dt
	if _t < 0.25:
		return
	_t = 0.0
	if step >= steps.size() or g == null or g.eng == null:
		return
	var s: Dictionary = steps[step]
	var ok := false
	match str(s["wait"]):
		"sel":
			ok = g.sel != ""
		"dest1":
			ok = _dests() >= 1
		"dest3":
			ok = _dests() >= 3 or (_req() == "" and g.eng.phase != "plot")
		"confirmed":
			ok = _req() != "plot"
		"combat_or_turn":
			if _req() == "alloc":
				ok = true
			elif _req() == "plot" and g.eng.turn >= 2:
				# nessun combattimento in questo turno: si salta la spiegazione della battaglia
				step += 1
				ok = true
		"alloc_done":
			ok = _req() != "alloc"
	if ok:
		_next()
