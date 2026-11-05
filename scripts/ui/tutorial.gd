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
	custom_minimum_size = Vector2(410, 0)
	size = Vector2(410, 0)
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
	body_l.custom_minimum_size = Vector2(382, 0)
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
		"alloc":
			return _req() == "alloc"
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
		 "b": "StarForce è un gioco di guerra nello spazio a tre dimensioni: le 74 stelle entro venti anni luce dal Sole, ognuna alla sua altezza vera.\n\nIn questa partita sei l'[color=#7fd3ff]Egemonia Solare[/color] (blu). La colonia di [color=#9be37a]Alpha Centauri[/color] (verde) si è ribellata e ha una sua [b]StarGate[/b], la stazione che permette alle flotte di saltare lontano.\n\n[b]Obiettivo[/b]: distruggere la StarGate di Alpha Centauri [b]entro 4 segmenti di combattimento[/b] dal primo scontro. Altrimenti vince Alpha Centauri.\n\nQuesto riquadro ti guida passo per passo e illumina in giallo le parti dello schermo di cui parla. Premi [b]Avanti[/b] quando hai letto."},
		{"t": "Lo schermo", "focus": ["barra", "forze", "registro"],
		 "b": "Le parti illuminate:\n\n- [b]in alto[/b]: nome dello scenario, formato (qui [i]Base[/i]), numero del turno e fase in corso. A destra ci sono [b]Registro[/b] (tutto quello che è successo), [b]Regole[/b] e [b]Salva[/b].\n- [b]Forze in campo[/b], qui a sinistra: quante StarForce (le flotte) e StarGate ha ogni lato. Quando passi il mouse su una flotta, sotto compaiono i suoi dati.\n- [b]il registro[/b], in basso: ogni salto, ogni tiro di dado e ogni perdita, con il motivo. Quando non capisci cosa è successo, guarda lì."},
		{"t": "Il pannello delle azioni", "focus": ["azioni"],
		 "b": "A destra c'è il [b]pannello delle azioni[/b]: cambia a seconda della fase e ti chiede quello che c'è da decidere. Ogni pannello comincia con due righe grigie che spiegano cosa fare.\n\nAdesso è il [b]piano degli spostamenti[/b]: c'è una riga per ogni tua StarForce (A, B, C, D) con la posizione e quello che farà; in fondo [b]Conferma il piano[/b] e [b]Piano dell'IA[/b], che riempie il piano con un suggerimento del computer."},
		{"t": "Muovere la vista", "focus": ["vista"],
		 "b": "La mappa è un volume a tre dimensioni:\n\n- [b]trascina[/b] col mouse (o un dito) per ruotarla\n- [b]rotella[/b] (o due dita che si allargano) per avvicinarti\n- [b]tasto destro[/b], o Maiusc + trascina, o due dita insieme, per spostarti\n- da tastiera: Q ed E ruotano, le frecce spostano, + e - avvicinano\n\nI pulsanti illuminati fanno le stesse cose. [b]Centra[/b] torna sulle tue forze.\n\nProva [b]Vista dall'alto[/b]: la mappa diventa piatta come quella di carta e accanto a ogni stella compare la sua altezza. Ripremi per tornare al 3D."},
		{"t": "Esagoni e quote", "focus": ["vista"],
		 "b": "Il piano è diviso in [b]esagoni[/b], ognuno con un numero di quattro cifre: le prime due sono la riga, le altre due la colonna. Sol è nell'esagono [b]2020[/b], al centro.\n\nL'altezza sopra o sotto il piano si chiama [b]quota Zulu[/b]. Ogni stella è appesa al suo esagono con uno [b]stelo[/b] colorato: più lungo, più è lontana dal piano. Alpha Centauri è a [b]1821/-4[/b]: esagono 1821, quattro sotto il piano.\n\nUn esagono più una quota è una [b]LiteZulu[/b]: è il posto preciso dove stanno flotte e stelle. Più ci si allontana dal centro, meno quote ci sono (gli anelli rosa sul piano)."},
		{"t": "Le distanze", 
		 "b": "Le distanze si misurano in [b]Lite[/b] (anni luce) e contano anche l'altezza: due stelle nello stesso esagono ma a quote diverse sono lontane.\n\nPassa il mouse su una stella: in basso compaiono nome e posizione, e il suo stelo si accende. Prova con [b]Alpha Centauri[/b], vicino a Sol, un po' sotto il piano.\n\nIl colore delle stelle ricorda il loro tipo (gialle come il Sole, arancioni, rosse le nane), ma nel gioco non conta: conta dove sono."},
		{"t": "Le forze in campo", "focus": ["forze"],
		 "b": "A Sol (2020/0) hai la tua StarGate e quattro StarForce: le lettere [b]A B C D[/b] sopra la stella.\n\nLe [b]StarGate[/b] si vedono sempre, anche quelle nemiche: quella di Alpha Centauri è là, a 1821/-4.\n\nLe [b]StarForce nemiche[/b] invece si vedono male: il segnalino con il [color=#ffd84d]?[/color] dice in quale esagono c'è qualcosa, ma non a che quota né quante sono. Le vedrai bene solo arrivandoci vicino.\n\nLa colonna trasparente sopra il segnalino attraversa tutte le quote dove potrebbe essere."},
		{"t": "Come va un turno",
		 "b": "Ogni turno ha tre momenti:\n\n1. [b]Piano segreto[/b]: tutti scrivono dove manda ogni flotta, senza vedere il piano degli altri.\n2. [b]Spostamenti[/b]: le flotte saltano tutte insieme.\n3. [b]Combattimenti[/b]: dove si trovano flotte nemiche nella stessa LiteZulu, si combatte.\n\nQuesto scenario dura al massimo 8 turni."},
		{"t": "1. Scegli una flotta", "wait": "sel", "auto": true, "skip": "not_plot", "focus": ["btn:A "],
		 "b": "Cominciamo il piano. Nel pannello a destra clicca sulla riga [b]A[/b] (illuminata). In alternativa puoi cliccare la flotta sulla mappa.\n\nLa riga scelta si colora e sotto compaiono altri pulsanti."},
		{"t": "La portata sicura", "focus": ["azioni"],
		 "b": "Intorno a Sol è comparsa una grande [b]sfera azzurra[/b]: è la [b]portata sicura[/b] di A. Ogni LiteZulu dentro la sfera si raggiunge senza rischi.\n\nLa portata dipende dal [b]tipo di salto[/b]: una flotta da sola salta 5 Lite; partendo da una tua StarGate ne salta [b]10[/b] (la StarGate la spinge). A è a Sol, sulla tua StarGate, quindi arriva fino a 10 Lite.\n\nIl gioco sceglie da solo il tipo di salto migliore."},
		{"t": "2. Scegli dove andare", "wait": "dest1", "auto": true, "skip": "not_plot", "hint": ac,
		 "b": "Ora clicca sulla stella [b]Alpha Centauri[/b], segnata dall'anello giallo con scritto [i]clicca qui[/i].\n\nSe non la vedi bene, avvicinati con la rotella o usa la Vista dall'alto."},
		{"t": "Leggere il salto", "focus": ["txt:Destinazione", "btn:A "],
		 "b": "Guarda le parti illuminate.\n\nLa riga di A ora dice [b]2020/0 > 1821/-4  GS, 8 Lite, sicuro[/b]: parte da Sol, arriva ad Alpha Centauri, con un salto [b]GS[/b] (aiutato dalla StarGate), lungo [b]8 Lite[/b], [b]sicuro[/b] perché è entro la portata di 10.\n\nSotto, il pannello lo spiega a parole. Sulla mappa una [b]scia di puntini[/b] collega partenza e arrivo, e il [b]cursore[/b] all'arrivo è [color=#7fe07f]verde[/color]. Se fosse oltre la portata sarebbe [color=#ffd84d]giallo[/color], [color=#ff9a4d]arancio[/color] o [color=#ff5a5a]rosso[/color]: si può arrivare un po' fuori rotta, o perdere la flotta."},
		{"t": "La quota", "focus": ["btn:Zulu -1", "btn:Zulu +1", "btn:Resta"],
		 "b": "Cliccando una stella, la flotta va alla quota della stella. Cliccando un esagono vuoto, va alla quota che scegli con [b]Zulu -1[/b] e [b]Zulu +1[/b] (o i tasti W e S).\n\n[b]Resta[/b] annulla il salto: la flotta sta ferma.\n\n[b]Rinforza questa LiteZulu[/b] serve per aiutare gli arrivi delle altre flotte: lo vedrai nel terzo tutorial. Per ora lascia tutto così."},
		{"t": "3. Le altre flotte", "wait": "dest3", "auto": true, "skip": "not_plot", "hint": ac, "focus": ["btn:B ", "btn:C "],
		 "b": "Fai lo stesso con [b]B[/b] e [b]C[/b]: clicca la riga, poi Alpha Centauri. In tre si attacca meglio.\n\nAttenzione: una StarGate può spingere al massimo [b]due[/b] salti per turno, oppure fino a quattro se fanno tutti lo stesso salto. Qui A, B e C fanno lo stesso salto, quindi va bene."},
		{"t": "La difesa di casa", "focus": ["btn:D ", "btn:Piano dell'IA"],
		 "b": "Lascia [b]D[/b] a Sol a proteggere la StarGate: se la perdi, perdi la partita.\n\nQuando sei in dubbio, [b]Piano dell'IA[/b] scrive un piano completo che puoi poi cambiare riga per riga. È un buon modo per vedere come ragiona un giocatore esperto."},
		{"t": "4. Conferma il piano", "wait": "not_plot", "auto": true, "focus": ["btn:Conferma il piano"],
		 "b": "Premi [b]Conferma il piano[/b].\n\nAnche Alpha Centauri ha scritto il suo piano in segreto: adesso tutti saltano insieme."},
		{"t": "I salti", "wait": "combat_or_turn", "focus": ["registro"],
		 "b": "Guarda le flotte saltare: le scie luminose mostrano i percorsi.\n\nNel [b]registro[/b] in basso trovi cosa è successo. I salti sicuri arrivano sempre. Un salto oltre la portata fa pescare un [b]chit[/b] (un numero da 0 a 9, come un dado da dieci) e la flotta può arrivare, finire [b]a specchio[/b] dalla parte opposta o essere [b]randomizzata[/b].\n\nAppena arrivi ad Alpha Centauri ci sono la StarGate e forse la StarForce nemica: si combatte. Premi Avanti quando il pannello a destra cambia."},
		{"t": "Come si combatte", "skip": "no_combat_turn2",
		 "b": "Il combattimento si fa a [b]segmenti[/b], come dei round.\n\nOgni unità ha dei [b]punti di forza[/b]: una StarForce vale [b]3[/b], ma nel primo segmento chi è appena arrivato vale solo [b]2[/b]; una StarGate vale [b]5[/b] e combatte dal secondo segmento.\n\nNel [b]primo segmento[/b] si scontrano solo le flotte arrivate contro quelle che erano già lì, e chi era già lì può [b]rifiutare[/b] lo scontro (nel registro lo leggi). Dal secondo segmento combattono tutti, StarGate compresa."},
		{"t": "Il pannello di combattimento", "wait": "alloc", "skip": "no_combat_turn2", "focus": ["azioni"],
		 "b": "Quando il pannello a destra si intitola [b]Combattimento in 1821/-4[/b] tocca a te. In alto leggi i punti di ogni lato e chi c'è.\n\nIn ogni segmento dividi in segreto i tuoi punti fra:\n- [b]attacco[/b] (il numero nella casella [i]Attacco contro Alpha Centauri[/i]), che fa danni al nemico\n- [b]difesa[/b] (quello che resta), che toglie forza agli attacchi nemici\n\nI pulsanti [b]Tutto in difesa[/b], [b]Metà e metà[/b] e [b]Tutto in attacco[/b] fanno la divisione per te."},
		{"t": "La tabella dei risultati", "wait": "alloc", "skip": "no_combat_turn2", "focus": ["txt:Tabella", "txt:Attacco contro"],
		 "b": "La tabella in fondo al pannello dice quante unità perde chi viene attaccato.\n\n- La [b]colonna[/b] è il tuo attacco [b]meno[/b] la difesa nemica: da -3 a +6. Sotto -3 l'attacco non si può fare.\n- La [b]riga[/b] è il chit pescato, da 0 a 9.\n- Il numero è quante unità perde il nemico (un trattino: nessuna).\n\nEsempio: attacchi con 9 e il nemico difende con 5: colonna +4. Con un chit 7 il nemico perde 3 unità.\n\nPiù attacchi più fai male, ma la tua difesa cala e il nemico ti colpisce meglio."},
		{"t": "Le ritirate", "wait": "alloc", "skip": "no_combat_turn2", "focus": ["txt:Ritirate"],
		 "b": "Sotto [b]Ritirate[/b] puoi far scappare una tua flotta verso una LiteZulu vicina: in quel segmento conta [b]2 punti solo in difesa[/b] ed esce alla fine.\n\nIl combattimento continua segmento dopo segmento finché in quella LiteZulu restano nemici; dopo sei segmenti di fila senza perdite qualcuno deve ritirarsi.\n\nQui non ritirarti: hai 4 segmenti per distruggere la StarGate."},
		{"t": "5. Conferma il combattimento", "wait": "not_alloc", "auto": true, "skip": "no_combat_turn2", "focus": ["btn:Conferma"],
		 "b": "Scegli la divisione (per esempio [b]Metà e metà[/b] nel primo segmento, [b]Tutto in attacco[/b] quando resta solo la StarGate) e premi [b]Conferma[/b]."},
		{"t": "I risultati", "focus": ["registro"], "skip": "no_combat_turn2",
		 "b": "Nel registro leggi ogni attacco: [i]Egemonia Solare attacca Alpha Centauri: 9 contro 5 (+4), chit 7: 3 perdite[/i].\n\nNel gioco base ogni perdita [b]elimina[/b] una StarForce. La [b]StarGate[/b] vale due perdite e cade solo quando il risultato è almeno 2 e supera le StarForce che la difendono: prima vanno abbattute le flotte, o serve un colpo molto forte.

Se a fine combattimento nella LiteZulu resta una tua flotta, la StarGate distrutta è persa per sempre: è la tua vittoria. Se invece vieni respinto, riappare al turno dopo.\n\nIl pannello si ripresenta a ogni segmento: ogni volta puoi cambiare la divisione."},
		{"t": "Ora tocca a te",
		 "b": "Hai visto tutto: [b]scegli la flotta, clicca la destinazione, conferma[/b], e in battaglia [b]dividi attacco e difesa[/b].\n\nContinua la partita. Se il combattimento va male puoi riprovare al turno dopo, ma i 4 segmenti contano dal primo scontro.\n\nIl secondo tutorial spiega il [b]gioco avanzato[/b] (il Tactical Display), il terzo i [b]salti lunghi, i rinforzi e le informazioni nascoste[/b]. Le [b]Regole[/b] in alto hanno tutto il resto."},
	]


func _steps_tactical() -> void:
	var ac = _star_lz(1821)
	steps = [
		{"t": "Il gioco avanzato",
		 "b": "Stessa guerra del primo tutorial, ma nel [b]gioco avanzato[/b]: quando le flotte arrivano sul nemico, il combattimento non si risolve con la tabella ma sul [b]Tactical Display[/b], un ingrandimento della LiteZulu dove si manovra e si spara davvero.\n\n[b]Obiettivo[/b]: neutralizzare la StarGate di Alpha Centauri entro [b]4 Tac-turni[/b] dal primo ingresso.\n\nSe non hai fatto il primo tutorial, fallo prima: qui la parte strategica va veloce."},
		{"t": "1. Il salto", "wait": "dest3", "auto": true, "skip": "not_plot", "hint": ac, "focus": ["azioni"],
		 "b": "Come nel primo tutorial: clicca la riga [b]A[/b], poi [b]Alpha Centauri[/b] (anello giallo); poi [b]B[/b] e [b]C[/b]. Lascia [b]D[/b] a casa.\n\nIl salto è un GS di 8 Lite, sicuro."},
		{"t": "2. Conferma", "wait": "not_plot", "auto": true, "focus": ["btn:Conferma il piano"],
		 "b": "Premi [b]Conferma il piano[/b]."},
		{"t": "Si entra nel Tactical Display", "wait": "tac", "retry": ["no_combat_turn2", 1],
		 "b": "Le flotte saltano. Appena arrivano nella LiteZulu della StarGate nemica, la vista passa al [b]Tactical Display[/b].\n\n(Se per caso nessuna flotta arriva, il tutorial ti riporta al passo del salto.)"},
		{"t": "Il volume tattico", "skip": "tac_over", "focus": ["vista"],
		 "b": "Sei dentro la LiteZulu di Alpha Centauri, ingrandita:\n\n- [b]91 esagoni[/b] (si chiamano [b]MiniLite[/b]) in un grande esagono di raggio 5\n- [b]11 livelli[/b] di quota, le [b]MiniZulu[/b] da -5 a +5, scritte sull'asta gialla a sinistra\n\nAl centro (esagono 000, MiniZulu 0) c'è la [b]StarGate[/b] nemica; la [b]stella[/b] è appena sotto, a 000/-1.\n\nI pulsanti della vista funzionano anche qui; con [b]Display stellare[/b] in alto torni alla mappa grande."},
		{"t": "Leggere le posizioni", "skip": "tac_over",
		 "b": "Ogni posizione si scrive con tre cifre più la MiniZulu, per esempio [b]524/+1[/b]: la prima cifra è la distanza dal centro (5 = anello esterno), le altre due il posto sull'anello.\n\nPassa il mouse sul piano: l'esagono sotto il puntatore si illumina, la sua sigla appare in giallo e in basso leggi chi c'è.\n\nOgni flotta ha uno [b]stelo con un dischetto[/b] fino al piano: dalla lunghezza capisci la quota. Una flotta nemica di cui non sai la quota appare scura, con la scritta [i]quota ?[/i]."},
		{"t": "3. Lo schieramento", "wait": "deploy_done", "auto": true, "skip": "tac_over", "focus": ["azioni"],
		 "b": "Chi arriva si schiera sull'[b]anello esterno[/b] (esagoni 5xx) oppure a MiniZulu +5 o -5; le flotte arrivate insieme restano vicine.\n\nIl pannello propone già uno schieramento valido. Puoi scegliere una flotta e cliccare un altro esagono valido, e cambiare la MiniZulu con i pulsanti. Poi premi [b]Conferma lo schieramento[/b]."},
		{"t": "I TelePunti", "wait": "tplot", "skip": "tac_over", "focus": ["azioni"],
		 "b": "In ogni [b]Tac-turno[/b] ogni unità ha dei [b]TelePunti[/b] (il TeleValue):\n\n- una StarForce [b]32[/b] in modo stellare, [b]64[/b] in modo battaglia\n- la StarGate 64 in ognuna delle due fasi\n\nCon i punti ci si muove ([b]Tac-spostamento[/b]) e si spara ([b]Proiezione[/b]). Quelli che [b]non spendi[/b] diventano la tua [b]anti-proiezione[/b], cioè la difesa, per tutto il Tac-turno.\n\nIl pannello lo scrive: [i]TeleValue 32: costi 0 + 0, anti-proiezione 32[/i]."},
		{"t": "Le due fasi", "skip": "tac_over", "focus": ["txt:Fase 1", "txt:Fase 2"],
		 "b": "Ogni Tac-turno ha [b]due fasi[/b]. In ognuna ogni flotta fa [b]una sola cosa[/b], scelta dai menu illuminati:\n\n- [b]Fase 1[/b]: Nulla, Tac-spostamento, Cambio di modo o Proiezione\n- [b]Fase 2[/b]: Nulla, Tac-spostamento, Proiezione o Ritirata\n\nTutti scrivono in segreto le due fasi; poi si eseguono insieme: prima i movimenti, poi le proiezioni, fase per fase.\n\nIn alto nel pannello scegli la flotta da programmare (A, B, C)."},
		{"t": "4. Modo battaglia", "wait": "mode", "auto": true, "skip": "tac_over", "focus": ["txt:Fase 1"],
		 "b": "In modo stellare hai solo 32 punti: troppo pochi per fare danni. Passa in [b]modo battaglia[/b]: avrai 64 punti.\n\nScegli la flotta A in alto, poi nel menu [b]Fase 1[/b] scegli [b]Cambio di modo[/b]. Il cambio costa metà dei nuovi punti (32); lascia la [b]Fase 2[/b] su Nulla, così i 32 che restano ti fanno da difesa. Da lontano la StarGate fa poco danno."},
		{"t": "5. Anche le altre", "wait": "tconfirmed", "skip": "tac_over", "focus": ["btn:Conferma il piano", "btn:Piano dell'IA"],
		 "b": "Fai lo stesso per [b]B[/b] e [b]C[/b], poi premi [b]Conferma il piano[/b].\n\nSe un'azione non è valida, il pannello lo scrive in rosso e spiega perché.\n\n[b]Piano dell'IA[/b] riempie tutto con una proposta che puoi modificare: guardala per imparare."},
		{"t": "Le proiezioni nemiche", "wait": "tplot2", "skip": "tac_over", "focus": ["registro"],
		 "b": "Le due fasi si eseguono. La StarGate spara [b]proiezioni[/b]: un colpo che riempie un [b]cuneo[/b] di esagoni in una direzione e [b]si dimezza per ogni MiniLite[/b] di distanza. Da lontano arriva debole e la tua anti-proiezione lo assorbe.\n\nSu ogni unità si sommano i colpi che la raggiungono, si toglie la sua anti-proiezione e si pesca un risultato:\n- [b]D[/b] disgregata: punti dimezzati per un po'\n- [b]R[/b] randomizzata: sbalzata fuori dal display\n\nLo leggi nel registro."},
		{"t": "6. Avvicinati", "wait": "move", "auto": true, "skip": "tac_over", "focus": ["txt:Fase 1"],
		 "b": "Ora hai 64 punti. Scegli una flotta e nel menu [b]Fase 1[/b] scegli [b]Tac-spostamento[/b], poi clicca un esagono più vicino al centro. La sigla gialla mostra dove arrivi, la quota la cambi con W e S.\n\nIn modo battaglia muoversi costa: 1 MiniLite [b]32[/b], 2 [b]48[/b], 3 [b]56[/b], 4 [b]60[/b], 5 [b]64[/b]. Quanto spendi lo togli dalla difesa: avvicinati di 1 o 2."},
		{"t": "7. Proietta", "wait": "cast", "auto": true, "skip": "tac_over", "focus": ["txt:Fase 2"],
		 "b": "Nel menu [b]Fase 2[/b] scegli [b]Proiezione[/b]. Compaiono:\n- [b]Punti[/b]: quanti metterne (16 è un buon inizio)\n- [b]verso l'alto / verso il basso[/b]: da che parte si allarga il cuneo in quota\n- [b]Direzione: ore[/b]: da che parte spari, come le ore di un orologio (1, 3, 5, 7, 9, 11)\n\nSul display compare il disegno del colpo, più acceso dove arriva più forte (in basso a sinistra puoi scegliere come disegnarlo). Cambia ore e verso finché copre la StarGate al centro."},
		{"t": "8. Conferma e guarda", "wait": "tconfirmed", "skip": "tac_over", "focus": ["btn:Conferma il piano"],
		 "b": "Programma le altre flotte (o guarda la proposta di [b]Piano dell'IA[/b]), poi [b]Conferma il piano[/b].\n\nUn consiglio: tutte le flotte proiettino sullo [b]stesso bersaglio[/b], perché i colpi si sommano."},
		{"t": "Come si abbatte una StarGate", "skip": "tac_over",
		 "b": "Una StarGate colpita da un risultato [b]R[/b] diventa [b]disgregata[/b]; se ne prende un altro mentre è disgregata è [b]neutralizzata[/b]. Se alla fine nella LiteZulu restano solo le tue flotte, è neutralizzata per sempre: hai vinto.\n\nIl metodo: [b]modo battaglia[/b], avvicinarsi [b]un po' alla volta[/b] tenendo una buona difesa, [b]concentrare[/b] tutte le proiezioni sullo stesso bersaglio, da vicino (a distanza 1 il colpo perde solo metà)."},
		{"t": "Ora tocca a te",
		 "b": "Hai i 4 Tac-turni per abbattere la StarGate. Ricorda:\n\n- Fase 1 e Fase 2, una cosa per fase\n- i punti non spesi sono difesa\n- i colpi si dimezzano a ogni MiniLite\n- la [b]Ritirata[/b] (Fase 2, 16 punti, in modo stellare) ti porta fuori dal display\n\n[b]Regole[/b] in alto ha tutti i dettagli del Tactical Display."},
	]


func _steps_shifts() -> void:
	var ei = _star_lz(2523)
	steps = [
		{"t": "Salti e rischi",
		 "b": "Epsilon Eridani (verde) vuole impadronirsi di [b]Epsilon Indi[/b] (2523/-10), un sistema senza StarGate. Tu sei l'[color=#7fd3ff]Egemonia Solare[/color] e devi arrivarci prima.\n\n[b]Si vince occupando Epsilon Indi[/b]: esserci da soli all'inizio e alla fine di [b]due turni di fila[/b]. Si vince anche distruggendo la StarGate nemica.\n\nIl nemico ha appena fatto uno spostamento libero, prima del primo turno."},
		{"t": "Cosa vedi del nemico", "focus": ["forze"],
		 "b": "Del nemico vedi solo [b]in quali esagoni[/b] ha flotte: un segnalino [color=#ffd84d]?[/color] per esagono, con una colonna trasparente che attraversa tutte le quote possibili. Non sai quante sono né a che altezza.\n\nLa quota esatta la scopri se sono [b]vicine a una tua StarGate[/b] (nelle 20 LiteZulu intorno) o [b]nello stesso esagono[/b] di una tua unità. Quante sono lo scopri solo combattendo.\n\nLe StarGate invece si vedono sempre."},
		{"t": "1. La portata", "wait": "sel", "auto": true, "skip": "not_plot", "focus": ["btn:A "],
		 "b": "Clicca la riga [b]A[/b].\n\nLa [b]sfera azzurra[/b] che compare è la portata sicura: dentro la sfera arrivi senza rischi. Le distanze si misurano in [b]Lite[/b] e contano anche la quota."},
		{"t": "I tipi di salto", "focus": ["azioni"],
		 "b": "Ci sono cinque tipi di salto, con portate diverse:\n- [b]S[/b], salto normale: 5 Lite\n- [b]GS[/b], partendo da una tua StarGate: 10\n- [b]ES[/b], verso un punto rinforzato da una tua flotta ferma, o verso una tua StarGate: 10\n- [b]EGS[/b], StarGate alla partenza e rinforzo all'arrivo: 15\n- [b]GGS[/b], da una tua StarGate a un'altra: 20\n\nIl gioco sceglie da solo il più sicuro e lo scrive nella riga della flotta."},
		{"t": "2. Il codice del salto", "wait": "dest_ei", "auto": true, "skip": "not_plot", "hint": ei,
		 "b": "Clicca [b]Epsilon Indi[/b] (anello giallo)."},
		{"t": "Oltre la portata", "hint": ei, "focus": ["btn:A ", "txt:Destinazione"],
		 "b": "La riga di A dice [b]GS, 11 Lite, colonna A[/b]: con l'aiuto della StarGate, 11 Lite, [b]una in più[/b] della portata sicura (10). Il cursore non è verde.\n\nUn salto oltre la portata si tenta lo stesso, ma si pesca un chit: con la [b]colonna A[/b] 7 volte su 10 si arriva, altrimenti si finisce [b]a specchio[/b] (stessa distanza, dalla parte opposta). Più sfori (colonne da B a F) più c'è il rischio di essere [b]randomizzati[/b]: nel gioco base la flotta è persa.\n\nProva a cliccare una stella lontana per vedere i colori, poi riporta A su Epsilon Indi."},
		{"t": "Entrare dal nemico",
		 "b": "Entrare nella LiteZulu di una [b]StarGate nemica[/b] costa [b]4 Lite in più[/b]: le sue difese ti spingono via. Non costa niente in più se parti da una LiteZulu [b]accanto[/b] alla sua.\n\nPer questo conviene spesso avvicinarsi in due tempi: prima accanto, poi dentro."},
		{"t": "3. Il rinforzo", "wait": "enhance", "auto": true, "skip": "not_plot", "focus": ["btn:D ", "btn:Rinforza"],
		 "b": "Una flotta può restare ferma a [b]rinforzare[/b] la sua LiteZulu: un'altra tua flotta che arriva lì ha portata 10 (ES) o 15 (EGS) invece di 5.\n\nProva: clicca la riga [b]D[/b] e premi [b]Rinforza questa LiteZulu[/b]. A Sol non cambia molto, ma ora sai come si fa.\n\nUna flotta che rinforza aiuta un solo salto per turno."},
		{"t": "4. Manda due flotte", "wait": "dest_ei2", "auto": true, "skip": "not_plot", "hint": ei, "focus": ["btn:B "],
		 "b": "Per occupare bisogna restare soli, quindi meglio arrivare in forze: manda anche [b]B[/b] a Epsilon Indi.\n\nUn'idea per i turni dopo: una flotta già arrivata può [b]rinforzare[/b] Epsilon Indi, e le altre ci arrivano con un EGS (portata 15) in tutta sicurezza."},
		{"t": "5. Conferma", "wait": "not_plot", "auto": true, "focus": ["btn:Conferma il piano"],
		 "b": "Premi [b]Conferma il piano[/b] e guarda nel registro dove arriva ognuno."},
		{"t": "Occupare e combattere", "wait": "combat_or_turn", "focus": ["registro"],
		 "b": "Se a Epsilon Indi arriva anche il nemico si combatte (come nel primo tutorial). Chi era già lì può [b]rifiutare[/b] il primo segmento; da lì in poi una flotta può [b]ritirarsi[/b] verso la LiteZulu da cui veniva o verso una tua StarGate.\n\nSe resti solo all'inizio e alla fine del turno, conta come un turno di occupazione: ne servono [b]due di fila[/b]."},
		{"t": "Ora tocca a te",
		 "b": "Tieni Epsilon Indi per due turni. Ricorda:\n- [b]da una StarGate[/b] si salta il doppio\n- il [b]rinforzo[/b] allunga l'arrivo\n- entrare da una StarGate nemica costa [b]4 Lite in più[/b], a meno di partire da accanto\n- del nemico vedi solo gli esagoni, finché non ti avvicini\n\nBuona caccia."},
	]


# ================================================================ avanzamento
## Ogni passo: "wait" = condizione. Con "auto" il passo (un'azione da fare) si chiude da solo quando
## la condizione è vera; senza "auto" il pulsante Avanti resta spento finché la condizione non è vera,
## così il testo resta leggibile anche se la partita va avanti. "focus" = elementi dello schermo da
## evidenziare: "forze", "azioni", "registro", "vista", "barra", oppure "btn:Testo" / "txt:Testo"
## (il primo pulsante o testo visibile che comincia così).

var hl: Control
var _hl_rects: Array = []


func _show() -> void:
	if step >= steps.size():
		_close()
		return
	var s: Dictionary = steps[step]
	title_l.text = s["t"]
	body_l.text = s["b"]
	count_l.text = "%d/%d" % [step + 1, steps.size()]
	_update_button()
	g.board.set_hint(s.get("hint", null))
	# il riquadro si riduce all'altezza del nuovo testo
	size = Vector2(410, 0)
	reset_size.call_deferred()


func _update_button() -> void:
	var s: Dictionary = steps[step]
	var w := str(s.get("wait", ""))
	if w == "":
		next_b.visible = true
		next_b.disabled = false
		next_b.text = "Fine" if step == steps.size() - 1 else "Avanti"
	elif s.get("auto", false):
		next_b.visible = false
	else:
		var ok := _cond(w)
		next_b.visible = true
		next_b.disabled = not ok
		next_b.text = ("Avanti" if step < steps.size() - 1 else "Fine") if ok else "Aspetta..."


func _next() -> void:
	step += 1
	# si saltano i passi che la partita ha reso inutili
	while step < steps.size() and str(steps[step].get("skip", "")) != "" and _cond(str(steps[step]["skip"])):
		step += 1
	_show()


func _find(spec: String) -> Control:
	match spec:
		"forze":
			return g.info_box.get_parent()
		"azioni":
			return g.act_panel if g.act_panel.visible else null
		"registro":
			return g.log_label.get_parent()
		"vista":
			return g.btn_view.get_parent()
		"barra":
			return g.top_turn.get_parent().get_parent() if g.top_turn != null else null
	var pre := spec.substr(4)
	var want_btn := spec.begins_with("btn:")
	var stack: Array = [g]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n == self:
			continue
		if n is Control and (n as Control).is_visible_in_tree():
			if want_btn and n is Button and (n as Button).text.begins_with(pre):
				return n
			if not want_btn and n is Label and (n as Label).text.begins_with(pre):
				return n
			if not want_btn and n is RichTextLabel and (n as RichTextLabel).get_parsed_text().begins_with(pre):
				return n
		var ch := n.get_children()
		for i in range(ch.size() - 1, -1, -1):
			stack.append(ch[i])
	return null


func _highlight() -> void:
	if hl == null:
		hl = Control.new()
		hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hl.set_anchors_preset(Control.PRESET_FULL_RECT)
		hl.draw.connect(_draw_hl)
		g.add_child(hl)
	hl.move_to_front()
	_hl_rects = []
	if step < steps.size():
		var f = steps[step].get("focus", [])
		if f is String:
			f = [f]
		for spec in f:
			var c := _find(str(spec))
			if c != null:
				_hl_rects.append(c.get_global_rect().grow(4))
	hl.queue_redraw()


func _draw_hl() -> void:
	var a := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 180.0)
	for r in _hl_rects:
		hl.draw_rect(r, Color(UI.YELLOW, a), false, 4.0)
		hl.draw_rect(r.grow(5), Color(UI.YELLOW, a * 0.35), false, 2.0)


func _close() -> void:
	g.board.set_hint(null)
	if hl != null:
		hl.queue_free()
	queue_free()


func _process(dt: float) -> void:
	# sempre appena sotto il riquadro delle forze in campo, che cambia altezza
	if g != null and g.info_box != null:
		var lp: Control = g.info_box.get_parent()
		position.y = lp.position.y + lp.size.y + 10.0
	_t += dt
	_highlight()
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
	if s.get("auto", false) and _cond(str(s.get("wait", ""))):
		_next()
		return
	if s.get("auto", false) and str(s.get("skip", "")) != "" and _cond(str(s["skip"])):
		_next()
		return
	_update_button()
