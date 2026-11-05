extends PanelContainer
## Tutorial guidati: partite vere contro l'IA spiegate passo per passo.
##   1  Le basi: muoversi e combattere      (scenario 1, gioco base)
##   2  Il Tactical Display                 (scenario 1, gioco avanzato)
##   3  Salti, rinforzi e informazioni nascoste (scenario 2, gioco base)
## Il riquadro sta a sinistra sotto le forze in campo. Ogni passo si chiude da solo quando il
## giocatore ha fatto quello che chiede, oppure con "Avanti" quando è solo da leggere.
## Ogni passo: t titolo, b testo, wait condizione ("" = pulsante), hint LiteZulu da indicare,
## skip condizione che fa saltare il passo se la partita è già andata oltre.

const LESSONS := [
	{"n": 1, "titolo": "Le basi: muoversi e combattere",
	 "desc": "Leggere la mappa 3D, scrivere il piano degli spostamenti, il combattimento base. Circa 10 minuti.",
	 "cfg": {"scenario": 1, "mode": "base", "seed": 2341, "human": 0}},
	{"n": 2, "titolo": "Il Tactical Display (gioco avanzato)",
	 "desc": "Il combattimento tattico: schieramento, TelePunti, modo battaglia, spostamenti e proiezioni contro una StarGate.",
	 "cfg": {"scenario": 1, "mode": "avanzato", "seed": 2341, "human": 0}},
	{"n": 3, "titolo": "Salti, rinforzi e informazioni nascoste",
	 "desc": "I tipi di spostamento (S, ES, GS, EGS, GGS), i salti rischiosi, il rinforzo, cosa si vede del nemico e come si occupa un sistema.",
	 "cfg": {"scenario": 2, "mode": "base", "seed": 2405, "human": 0}},
]

var g                       # game_view
var lesson := 1
var step := 0
var steps: Array = []
var title_l: Label
var body_l: RichTextLabel
var next_b: Button
var count_l: Label
var _t := 0.0
var _seen_plot := false


## configurazione della partita di una lezione
static func game_config(n: int) -> Dictionary:
	for l in LESSONS:
		if l["n"] == n:
			var c: Dictionary = l["cfg"]
			var seats := []
			for i in 2:
				seats.append({"name": "", "ai": i != int(c["human"]), "level": 1})
			return {"scenario": c["scenario"], "mode": c["mode"], "tutorial": n, "seats": seats,
				"style": "reborn", "anim": 1.0, "ai_delay": 0.5, "seed": c["seed"]}
	return {}


func _ready() -> void:
	add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.03, 0.06, 0.95), UI.YELLOW, 2, 10, 14))
	position = Vector2(10, 232)
	custom_minimum_size = Vector2(390, 0)
	size = Vector2(390, 0)
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
	body_l.custom_minimum_size = Vector2(362, 0)
	body_l.fit_content = true
	vb.add_child(body_l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	next_b = UI.primary(UI.button("Avanti", 150, 40, 17))
	next_b.pressed.connect(_next)
	row.add_child(next_b)
	var skip := UI.button("Chiudi il tutorial", 0, 40, 15)
	skip.pressed.connect(_close)
	row.add_child(skip)
	match lesson:
		2:
			_steps_tactical()
		3:
			_steps_shifts()
		_:
			_steps_basics()
	_show()


func _close() -> void:
	g.board.set_hint(null)
	queue_free()


# ================================================================ letture dello stato della partita

func _star_lz(h: int) -> Variant:
	for st in g.eng.stars.get(h, []):
		return Hex.lz(h, int(st["z"]))
	return null


func _dests(target = null) -> int:
	var n := 0
	for id in g.plot:
		var p: Dictionary = g.plot[id]
		if p.get("c", "") == "E" or not p.has("to") or not g.eng.units.has(id):
			continue
		if p["to"] == g.eng.units[id]["lz"]:
			continue
		if target != null and p["to"] != target:
			continue
		n += 1
	return n


func _req() -> String:
	return str(g.req.get("type", ""))


func _tplan_has(k: String, ph: String) -> bool:
	if _req() != "tplot":
		return false
	for id in g.tplan:
		var p: Dictionary = g.tplan[id]
		if not p.has(ph):
			continue
		var a: Dictionary = p[ph]
		if str(a.get("k", "")) != k:
			continue
		if k == "T" and g.eng.tac != null and a.get("to") == g.eng.tac.tu[id]["pos"]:
			continue
		return true
	return false


func _tt() -> int:
	return g.eng.tac.tt if g.eng.tac != null else 0


## condizioni con nome, usate da wait e skip
func _cond(c: String) -> bool:
	match c:
		"":
			return false
		"sel":
			return g.sel != ""
		"dest1":
			return _dests(_star_lz(1821)) >= 1
		"dest3":
			return _dests(_star_lz(1821)) >= 3
		"dest_ei":
			return _dests(_star_lz(2523)) >= 1
		"dest_ei2":
			return _dests(_star_lz(2523)) >= 2
		"enhance":
			for id in g.plot:
				if g.plot[id].get("c", "") == "E":
					return true
			return false
		"not_plot":
			return _seen_plot and _req() != "plot"
		"combat_or_turn":
			return _req() == "alloc" or (_req() == "plot" and g.eng.turn >= 2)
		"no_combat_turn2":
			return _req() == "plot" and g.eng.turn >= 2
		"not_alloc":
			return _req() != "alloc"
		"tac":
			return g.board.tactical or _req() in ["tdeploy", "tplot"]
		"not_tac":
			return g.eng.tac == null and g.eng.turn >= 1 and _req() == "plot" and g.eng.phase == "plot" and g.eng.turn >= 2
		"deploy_done":
			return _req() == "tplot" or (g.eng.tac != null and _tt() >= 1 and _req() != "tdeploy")
		"tplot":
			return _req() == "tplot"
		"mode":
			return _tplan_has("M", "a1")
		"tconfirmed":
			return _req() != "tplot"
		"tplot2":
			return _req() == "tplot" and _tt() >= 2
		"move":
			return _tplan_has("T", "a1")
		"cast":
			return _tplan_has("C", "a2") or _tplan_has("C", "a1")
		"tplot3":
			return _req() == "tplot" and _tt() >= 3
		"tac_over":
			return g.eng.tac == null and g.eng.turn >= 1 and _req() != "tdeploy"
	return false


# ================================================================ lezioni

func _steps_basics() -> void:
	var ac = _star_lz(1821)
	steps = [
		{"t": "Benvenuto in StarForce",
		 "b": "Sei l'[color=#7fd3ff]Egemonia Solare[/color] (blu). La colonia di [color=#9be37a]Alpha Centauri[/color] (verde) si è ribellata e ha costruito una [b]StarGate[/b], una stazione che permette alle flotte di saltare nello spazio.\n\n[b]Obiettivo[/b]: portare le tue flotte (le [b]StarForce[/b]) dove si trova la StarGate nemica e distruggerla.\n\nQuesto riquadro ti guida: quando ti chiede di fare qualcosa, si accorge da solo che l'hai fatto."},
		{"t": "Muovere la vista",
		 "b": "La mappa è [b]tridimensionale[/b]: le stelle stanno sopra o sotto il piano.\n\n- [b]trascina[/b] col mouse (o un dito) per ruotare\n- [b]rotella[/b] (o due dita) per avvicinarti\n- [b]tasto destro[/b] o Maiusc + trascina per spostarti\n\nIn basso a sinistra ci sono anche i pulsanti. Prova [b]Vista dall'alto[/b]: la mappa diventa piatta come quella di carta, con l'altezza scritta accanto a ogni stella."},
		{"t": "Leggere la mappa",
		 "b": "Ogni esagono ha un numero di quattro cifre ([b]2020[/b] è Sol). L'altezza sopra o sotto il piano si chiama [b]quota Zulu[/b]: Alpha Centauri è a [b]1821/-4[/b], cioè esagono 1821, quattro sotto il piano.\n\nUn esagono più una quota è una [b]LiteZulu[/b]: è lì che stanno flotte e stelle.\n\nPassa il mouse su una stella: in basso leggi nome e posizione, e lo stelo che la collega al piano si accende."},
		{"t": "Le tue forze",
		 "b": "A Sol (2020/0) hai la tua StarGate e quattro StarForce, le lettere [b]A B C D[/b] sopra la stella.\n\nIl nemico di solito non lo vedi bene: il segnalino con il [color=#ffd84d]?[/color] dice in quale esagono si trova qualcosa, ma non a che quota. Lo vedrai davvero solo quando ci arrivi vicino.\n\nIn alto a sinistra c'è il conto delle forze in campo."},
		{"t": "1. Scegli una flotta", "wait": "sel", "skip": "not_plot",
		 "b": "Ogni turno tutti scrivono in segreto dove vanno, e poi ci si muove insieme.\n\nNel pannello a destra clicca sulla riga [b]A[/b] (oppure sulla flotta A sulla mappa) per sceglierla."},
		{"t": "2. Scegli dove andare", "wait": "dest1", "skip": "not_plot", "hint": ac,
		 "b": "Ora clicca sulla stella [b]Alpha Centauri[/b], quella segnata dall'anello giallo lampeggiante.\n\nIl cursore che compare ha un colore: [color=#7fe07f]verde[/color] vuol dire salto sicuro, [color=#ffd84d]giallo[/color] e [color=#ff9a4d]arancio[/color] che la flotta può finire un po' fuori rotta, [color=#ff5a5a]rosso[/color] che è un salto molto rischioso.\n\nLa sfera azzurra intorno alla flotta mostra fin dove si arriva senza rischi."},
		{"t": "3. Le altre flotte", "wait": "dest3", "skip": "not_plot", "hint": ac,
		 "b": "Ottimo. Fai lo stesso con [b]B[/b] e [b]C[/b]: sceglile e clicca Alpha Centauri. In tre si attacca meglio.\n\nLascia [b]D[/b] a Sol a proteggere la tua StarGate: se la perdi, perdi la partita.\n\n(Se ti serve una quota diversa da quella della stella, la cambi con i pulsanti o con i tasti W e S.)"},
		{"t": "4. Conferma il piano", "wait": "not_plot",
		 "b": "Sulla mappa vedi le scie colorate dei salti che hai scritto. Quando ti va bene premi [b]Conferma il piano[/b] in fondo al pannello a destra.\n\nAnche l'IA ha scritto il suo piano in segreto: adesso si muovono tutti insieme."},
		{"t": "I salti", "wait": "combat_or_turn",
		 "b": "Guarda le flotte saltare. Un salto lungo può [b]deviare[/b]: la flotta arriva in una LiteZulu vicina a quella voluta. Nel registro in basso c'è scritto cosa è successo a ognuna.\n\nSe una tua flotta arriva dove c'è il nemico, si combatte."},
		{"t": "Il combattimento", "wait": "not_alloc", "skip": "no_combat_turn2",
		 "b": "Ogni flotta ha dei punti di forza. Devi dividerli in segreto fra [b]attacco[/b] e [b]difesa[/b]: più attacchi, più fai danni, ma più ne subisci.\n\nPer cominciare va bene la proposta già pronta: premi [b]Conferma[/b] nel pannello a destra. La tabella sotto mostra cosa può succedere.\n\nNel primo segmento combattono solo le flotte; dal secondo anche la StarGate, che vale due flotte."},
		{"t": "Ora tocca a te",
		 "b": "Hai visto tutto quello che serve: [b]scegli, punta, conferma[/b], e in battaglia dividi attacco e difesa.\n\nContinua la partita fino a distruggere la StarGate di Alpha Centauri. Se vuoi i dettagli premi [b]Regole[/b] in alto; [b]Registro[/b] mostra tutto quello che è successo.\n\nGli altri tutorial (dal menu) spiegano il gioco avanzato e i salti più lunghi."},
	]


func _steps_tactical() -> void:
	var ac = _star_lz(1821)
	steps = [
		{"t": "Il gioco avanzato",
		 "b": "Stessa guerra del primo tutorial, ma nel [b]gioco avanzato[/b]: quando le flotte arrivano sul nemico, il combattimento si sposta sul [b]Tactical Display[/b], un ingrandimento della LiteZulu dove si manovra davvero.\n\n[b]Obiettivo[/b]: neutralizzare la StarGate di Alpha Centauri entro [b]4 Tac-turni[/b] dall'inizio del combattimento."},
		{"t": "1. Il salto", "wait": "dest3", "skip": "not_plot", "hint": ac,
		 "b": "Prima bisogna arrivarci. Scegli [b]A[/b], clicca [b]Alpha Centauri[/b] (anello giallo), poi fai lo stesso con [b]B[/b] e [b]C[/b]. Lascia [b]D[/b] a casa.\n\n(Se non ricordi come si fa, rifai il primo tutorial.)"},
		{"t": "2. Conferma", "wait": "not_plot",
		 "b": "Premi [b]Conferma il piano[/b]. Con l'aiuto della tua StarGate il salto è sicuro."},
		{"t": "Si entra nel display tattico", "wait": "tac", "retry": ["no_combat_turn2", 1],
		 "b": "Le flotte saltano. Appena arrivano nella LiteZulu della StarGate nemica, la vista passa al [b]Tactical Display[/b].\n\n(Se una flotta devia e non arriva, nessun problema: al prossimo turno riprova.)"},
		{"t": "Il volume tattico", "skip": "tac_over",
		 "b": "Sei dentro la LiteZulu di Alpha Centauri, ingrandita: [b]91 esagoni[/b] (i MiniLite) per [b]11 livelli[/b] di quota, le [b]MiniZulu[/b] da -5 a +5, scritte sull'asta gialla a sinistra.\n\nAl centro (000/0) c'è la StarGate nemica, sotto di lei la stella. Passa il mouse sul piano: l'esagono si illumina e in basso leggi la sua sigla e chi c'è.\n\nOgni flotta ha uno stelo fino al piano: così vedi a che quota sta. La [b]Vista dall'alto[/b] funziona anche qui."},
		{"t": "3. Lo schieramento", "wait": "deploy_done", "skip": "tac_over",
		 "b": "Chi arriva si schiera sull'[b]anello esterno[/b] (gli esagoni 5xx) oppure al livello +5 o -5, e le flotte arrivate insieme restano vicine.\n\nLa proposta nel pannello va già bene: premi [b]Conferma lo schieramento[/b]. (Puoi anche scegliere una flotta e cliccare un altro esagono valido.)"},
		{"t": "I TelePunti", "wait": "", "skip": "tac_over",
		 "b": "In ogni [b]Tac-turno[/b] ogni unità ha dei [b]TelePunti[/b]: una StarForce [b]32[/b] in modo stellare, [b]64[/b] in modo battaglia; la StarGate 64 in ognuna delle due fasi.\n\nCon i punti ci si muove e si spara (le [b]proiezioni[/b]). Quelli che [b]non spendi[/b] diventano la tua [b]difesa[/b] (l'anti-proiezione) per tutto il Tac-turno.\n\nIl Tac-turno ha [b]due fasi[/b]: in ognuna ogni flotta fa una sola cosa."},
		{"t": "4. Modo battaglia", "wait": "mode", "skip": "tac_over",
		 "b": "In modo stellare hai solo 32 punti: troppo pochi. Conviene passare in [b]modo battaglia[/b] (64 punti dal prossimo Tac-turno).\n\nNel pannello a destra scegli la flotta, poi alla riga [b]Fase 1[/b] scegli [b]Cambio di modo[/b]. Costa 32: per questo Tac-turno non resta altro, ma la StarGate da lontano fa poco danno.\n\nFallo per tutte le flotte."},
		{"t": "5. Conferma il Tac-turno", "wait": "tconfirmed", "skip": "tac_over",
		 "b": "Quando tutte le flotte hanno il cambio di modo premi [b]Conferma il piano[/b].\n\nSe hai dubbi, [b]Piano dell'IA[/b] riempie il piano con una proposta che poi puoi modificare: è un buon modo per imparare."},
		{"t": "Le proiezioni nemiche", "wait": "tplot2", "skip": "tac_over",
		 "b": "Le due fasi si eseguono. La StarGate spara [b]proiezioni[/b]: colpiscono un [b]cuneo[/b] di esagoni in una direzione e [b]si dimezzano per ogni MiniLite[/b] di distanza. Da lontano arrivano deboli, e la tua difesa le assorbe.\n\nNel registro in basso leggi cosa è successo: [b]D[/b] vuol dire disgregata (punti dimezzati per un po'), [b]R[/b] randomizzata (la flotta viene sbalzata via)."},
		{"t": "6. Avvicinati", "wait": "move", "skip": "tac_over",
		 "b": "Ora hai 64 punti. Scegli una flotta e alla riga [b]Fase 1[/b] scegli [b]Tac-spostamento[/b], poi clicca un esagono più vicino al centro. La sigla gialla mostra dove arrivi; la quota la cambi con W e S.\n\nIn modo battaglia 1 MiniLite costa 32, 2 costano 48, 3 costano 56: ogni passo costa meno, ma toglie difesa."},
		{"t": "7. Proietta", "wait": "cast", "skip": "tac_over",
		 "b": "Alla riga [b]Fase 2[/b] scegli [b]Proiezione[/b]. Poi scegli:\n- i [b]punti[/b] (16 o 32 vanno bene)\n- la [b]direzione[/b], in ore come su un orologio (1, 3, 5, 7, 9, 11)\n- [b]verso l'alto[/b] o [b]verso il basso[/b]\n\nSul display compaiono dei [b]dischi colorati[/b]: è dove colpisci, più chiari dove il colpo è più forte. Cambia le ore finché i dischi coprono la StarGate al centro. Più sei vicino, più il colpo arriva intero."},
		{"t": "8. Conferma e guarda", "wait": "tconfirmed", "skip": "tac_over",
		 "b": "Ripeti per le altre flotte (o premi [b]Piano dell'IA[/b] e guarda cosa propone), poi [b]Conferma il piano[/b].\n\nSu ogni unità si sommano le proiezioni che la raggiungono, si toglie la sua difesa e si pesca un risultato."},
		{"t": "Come si abbatte una StarGate",
		 "b": "Una StarGate colpita con [b]R[/b] diventa [b]disgregata[/b]; se ne prende un'altra mentre è disgregata è [b]neutralizzata[/b]. Se alla fine nella LiteZulu restano solo le tue flotte, è neutralizzata per sempre: hai vinto.\n\nIl trucco: [b]avvicinarsi in modo battaglia[/b], tenere un po' di difesa, e [b]concentrare[/b] le proiezioni di tutte le flotte sullo stesso bersaglio.\n\nOra continua da solo. [b]Regole[/b] in alto ha tutti i dettagli del Tactical Display."},
	]


func _steps_shifts() -> void:
	var ei = _star_lz(2523)
	steps = [
		{"t": "Salti e rischi",
		 "b": "Epsilon Eridani (verde) vuole impadronirsi di [b]Epsilon Indi[/b], un sistema senza StarGate. Tu sei l'[color=#7fd3ff]Egemonia Solare[/color] e devi arrivarci prima.\n\n[b]Si vince occupando Epsilon Indi[/b]: esserci da soli all'inizio e alla fine di due turni di fila (oppure distruggendo la StarGate nemica).\n\nIl nemico ha appena fatto uno spostamento libero: guarda dove sono i suoi segnalini con il [color=#ffd84d]?[/color]."},
		{"t": "Cosa vedi del nemico",
		 "b": "Del nemico vedi solo [b]in quali esagoni[/b] ha flotte: un segnalino [color=#ffd84d]?[/color] per esagono, con una colonna trasparente che attraversa tutte le quote possibili. Non sai quante sono né a che altezza.\n\nLa quota esatta la scopri solo se sono [b]vicine a una tua StarGate[/b] (nelle 20 LiteZulu intorno) o [b]nello stesso esagono[/b] di una tua unità. Quante sono lo scopri solo combattendo.\n\nLe StarGate invece si vedono sempre."},
		{"t": "1. La portata", "wait": "sel", "skip": "not_plot",
		 "b": "Scegli la flotta [b]A[/b] nel pannello a destra.\n\nLa [b]sfera azzurra[/b] che compare è la portata sicura: dentro la sfera arrivi senza rischi. Le distanze si misurano in [b]Lite[/b] (anni luce) e tengono conto anche della quota."},
		{"t": "2. Il codice del salto", "wait": "dest_ei", "skip": "not_plot", "hint": ei,
		 "b": "Clicca [b]Epsilon Indi[/b] (anello giallo). Nel pannello compare il [b]codice[/b] del salto: qui [b]GS, 11 Lite, colonna A[/b]. Vuol dire salto con l'aiuto della StarGate, 11 Lite di distanza, uno più della portata sicura. I tipi sono:\n- [b]S[/b] normale: 5 Lite\n- [b]GS[/b] partendo da una tua StarGate: 10\n- [b]ES[/b] verso un punto rinforzato: 10\n- [b]EGS[/b] StarGate alla partenza e rinforzo all'arrivo: 15\n- [b]GGS[/b] da una tua StarGate a un'altra: 20\n\nIl gioco sceglie da solo il tipo più sicuro."},
		{"t": "3. Oltre la portata",
		 "b": "Epsilon Indi è appena [b]oltre la portata[/b]. Un salto così si tenta lo stesso, ma si pesca un chit: con la colonna A [b]7 volte su 10 si arriva[/b], altrimenti si finisce [b]a specchio[/b] (stessa distanza, dalla parte opposta). Più sfori (colonne B-F, cursore [color=#ff9a4d]arancio[/color] e [color=#ff5a5a]rosso[/color]), più c'è il rischio di essere [b]randomizzati[/b]: nel gioco base la flotta è persa.\n\nProva a cliccare una stella lontana per vedere i colori, poi riporta A su [b]Epsilon Indi[/b] e premi Avanti.", "hint": ei},
		{"t": "4. Il rinforzo", "wait": "enhance", "skip": "not_plot",
		 "b": "Una flotta può restare ferma a [b]rinforzare[/b] la sua LiteZulu: un'altra tua flotta che arriva lì ha portata 10 (ES) o 15 (EGS) invece di 5. Serve quando non parti da una StarGate.\n\nProva: scegli [b]D[/b] e premi [b]Rinforza questa LiteZulu[/b]. Stando a Sol non cambia molto, ma ora sai dov'è.\n\nAttenzione: una StarGate aiuta al massimo [b]due[/b] salti per turno (quattro se fanno tutti lo stesso salto)."},
		{"t": "5. Manda due flotte", "wait": "dest_ei2", "skip": "not_plot", "hint": ei,
		 "b": "Per occupare bisogna restare soli, quindi meglio arrivare in forze: manda anche [b]B[/b] a Epsilon Indi.\n\nUn consiglio per i turni dopo: una flotta già arrivata a Epsilon Indi può [b]rinforzarla[/b], e allora le altre ci arrivano con un EGS (portata 15) in tutta sicurezza."},
		{"t": "6. Conferma", "wait": "not_plot",
		 "b": "Premi [b]Conferma il piano[/b] e guarda dove arrivano tutti."},
		{"t": "Occupare e combattere", "wait": "combat_or_turn",
		 "b": "Se a Epsilon Indi arriva anche il nemico si combatte. Chi era già lì può [b]rifiutare[/b] il primo segmento; dal secondo una flotta può [b]ritirarsi[/b] (vale solo in difesa) verso la LiteZulu da cui era venuta o verso una tua StarGate.\n\nSe resti solo, all'inizio e alla fine del turno, conta come un turno di occupazione: ne servono due di fila."},
		{"t": "Ora tocca a te",
		 "b": "Tieni Epsilon Indi per due turni, o difendila finché il nemico rinuncia. Ricorda:\n- [b]da una StarGate[/b] si salta il doppio\n- il [b]rinforzo[/b] allunga l'arrivo\n- entrare nella LiteZulu di una StarGate nemica costa [b]4 Lite in più[/b], a meno di partire da una LiteZulu accanto\n\nBuona caccia."},
	]


# ================================================================ avanzamento

func _show() -> void:
	if step >= steps.size():
		_close()
		return
	var s: Dictionary = steps[step]
	title_l.text = s["t"]
	body_l.text = s["b"]
	count_l.text = "%d/%d" % [step + 1, steps.size()]
	next_b.visible = str(s.get("wait", "")) == ""
	next_b.text = "Fine" if step == steps.size() - 1 else "Avanti"
	g.board.set_hint(s.get("hint", null))
	# il riquadro si riduce all'altezza del nuovo testo
	size = Vector2(390, 0)
	reset_size.call_deferred()


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
	if _req() == "plot":
		_seen_plot = true
	var s: Dictionary = steps[step]
	if s.has("retry") and _cond(str(s["retry"][0])):
		# la cosa attesa non è successa (per esempio nessuna flotta è arrivata): si torna indietro
		step = int(s["retry"][1])
		_seen_plot = false
		_show()
		return
	if _cond(str(s.get("wait", ""))):
		_next()
	elif str(s.get("skip", "")) != "" and _cond(str(s["skip"])):
		_next()
