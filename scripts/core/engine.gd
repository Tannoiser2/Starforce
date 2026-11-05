class_name SFEngine
extends Node
## Motore delle regole di StarForce (SPI, 1974), senza dipendenze dalla grafica.
## Ogni scelta passa da `decide()`: l'IA risponde subito; per le persone viene emesso
## `decision_requested` e si attende `provide_decision()`. Online le scelte viaggiano nel registro di
## mosse (OnlineSession): con lo stesso seme ogni dispositivo gioca la stessa partita.
##
## Unità (units[id]):
##   kind "sf" (StarForce, quattro TeleNavi) oppure "gate" (StarGate)
##   lz: Vector3i(riga, colonna, zulu)  st: "on", "dead", "rand" (in attesa di randomizzazione),
##   "limbo" (StarGate in sospeso, 9.31), "off" (Xenofobi fuori gioco per tre turni)
##   neut: ultimo turno in cui l'unità è neutralizzata (-1 = mai)
##   start: LiteZulu di inizio turno
##
## Richieste (req["type"]):
##  - "plot": piano segreto degli spostamenti; risposta {uid: {"c": codice, "to": Vector3i}}
##           codici: "S", "ES", "GS", "EGS", "GGS" (si calcola da solo se vuoto), "E" (rinforza la propria
##           LiteZulu), "L" (carica/scarica, missione di soccorso)
##  - "alloc": ripartizione dei punti nel combattimento base;
##           risposta {"att": {lato: punti}, "def": punti, "brk": {uid: Vector3i}, "refuse": bool, "nova": uid}
##  - "tdeploy" / "tplot": combattimento avanzato sul Tactical Display (vedi tactical.gd)
##  - "xsign": Xenofobi, lato del Volume delle StarGate (+1 o -1)

const D = preload("res://scripts/data/sf_data.gd")
const Tac = preload("res://scripts/core/tactical.gd")

signal changed
signal log_added(text: String)
signal decision_requested(req: Dictionary)
signal decision_provided(result)
signal game_ended(result: Dictionary)
signal fx(kind: String, data: Dictionary)

var scn_id := 1
var sc: Dictionary
var mode := "avanzato"            # "base", "modificato", "avanzato"
var players: Array = []           # [{name, ai, level}] uno per lato
var sides: Array = []             # [{nome, razza, set, casa: [hex], persi: n, perso: bool}]
var ais: Array = []
var online = null
var ai_delay := 0.5
var anim := 1.0
var headless := false
var abort := false
var rng := RandomNumberGenerator.new()
var max_turns := 60

var units := {}
var order: Array = []
var stars := {}                   # esagono -> [{z, cls, name}]
var star_lz := {}                 # Vector3i -> {cls, name}
var destroyed_stars := {}         # Vector3i -> true (nova)
var turn := 0
var phase := ""
var over := false
var result := {}
var log_lines: Array = []
var history: Array = []
var last_chit := -1

# stato del turno
var contested := {}               # LiteZulu contese in questo turno
var gate_used := {}               # uid porta -> [[tipo, origine, destinazione], ...]
var gate_reserved := {}           # capacità impegnata per il turno seguente (ritirate verso la porta)
var shift_log: Array = []         # spostamenti del turno (per la vista)
var tac = null                    # combattimento tattico in corso (Tactical)
var cur_combat := {}              # combattimento base in corso: {lz, seg, ...}
var gates_lost := []              # per lato: StarGate perse in modo permanente
var first_neut := -1              # scenario 7: primo lato a neutralizzare una StarGate
var occupy := {}                  # obiettivi da occupare: lato -> turni consecutivi
var s1_start := -1                # scenario 1: tac-turno del primo ingresso
var vp := []
# Xenofobi
var xeno := 0
var xeno_side := -1
var xeno_sign := 1
var xeno_last_attack := 0
var xeno_known := {}              # uid porta xenofoba -> scoperta dalla Lega
var reinf_left := 0
var pregame := 0
# missione di soccorso
var rescue := {}

# visibilità: per lato, unità nemiche di cui si conosce la zulu in questo turno
var seen_z := []
# registro delle decisioni (salvataggi) e decisioni da rigiocare al caricamento
var rec_acts: Array = []
var preload_acts: Array = []
var pre_i := 0


# ================================================================ preparazione

func setup(cfg: Dictionary) -> void:
	scn_id = int(cfg.get("scenario", 1))
	sc = D.scenario(scn_id)
	mode = str(cfg.get("mode", sc.get("formato", "avanzato")))
	if sc.has("xeno") and mode == "avanzato":
		mode = "modificato"
	if cfg.has("seed"):
		rng.seed = int(cfg["seed"])
	else:
		rng.randomize()
	ai_delay = float(cfg.get("ai_delay", 0.5))
	anim = float(cfg.get("anim", 1.0))
	max_turns = int(cfg.get("max_turns", sc.get("turni_max", 60)))
	var nsides: int = sc["lati"].size()
	players = cfg.get("seats", [])
	while players.size() < nsides:
		players.append({"name": "", "ai": players.size() > 0, "level": 1})
	for st in D.STARS:
		var h := int(st[0])
		var l := Hex.lz(h, int(st[1]))
		if not stars.has(h):
			stars[h] = []
		stars[h].append({"z": int(st[1]), "cls": st[2], "name": st[3]})
		star_lz[l] = {"cls": st[2], "name": st[3], "hex": h}
	for i in nsides:
		var sd: Dictionary = sc["lati"][i]
		var casa: Array = []
		for c in sd.get("casa", []):
			casa.append(int(c))
		sides.append({"nome": sd["nome"], "razza": sd["razza"], "set": sd["set"], "casa": casa, "perso": false, "next_letter": 0, "next_gate": 0})
		gates_lost.append(0)
		vp.append(0)
		seen_z.append({})
	xeno = int(sc.get("xeno", 0))
	_place_forces()
	for i in nsides:
		ais.append(SFAI.new(int(players[i].get("level", 1))))


func pname(s: int) -> String:
	if s < 0 or s >= players.size():
		return "?"
	var n := str(players[s].get("name", ""))
	if n == "" or players[s].get("ai", false):
		return sides[s]["nome"]
	return "%s (%s)" % [n, sides[s]["nome"]]


func star_at(l: Vector3i) -> Dictionary:
	if destroyed_stars.has(l):
		return {}
	return star_lz.get(l, {})


func star_name(h: int) -> String:
	if stars.has(h):
		return stars[h][0]["name"]
	return ""


func star_hex_lz(h: int) -> Vector3i:
	return Hex.lz(h, int(stars[h][0]["z"]))


func _next_label(side: int, kind: String) -> String:
	var st: Dictionary = D.SETS[sides[side]["set"]]
	if kind == "sf":
		var letters: String = st["lettere"]
		var i: int = sides[side]["next_letter"]
		sides[side]["next_letter"] = i + 1
		if i < letters.length():
			return letters[i]
		return "%s%d" % [letters[i % letters.length()], i / letters.length() + 1]
	var gl: Array = st["porte"]
	var g: int = sides[side]["next_gate"]
	sides[side]["next_gate"] = g + 1
	if g < gl.size():
		return str(gl[g])
	return str(int(gl[0]) + g + (40 if int(gl[0]) > 8 else 20))


func add_unit(side: int, kind: String, l: Vector3i, race := "") -> Dictionary:
	var id := "%d%s%d" % [side, kind[0], order.size()]
	var u := {"id": id, "side": side, "kind": kind, "label": _next_label(side, kind), "lz": l, "start": l,
		"st": "on", "neut": -1, "race": race if race != "" else sides[side]["razza"], "mode": "stellar",
		"cargo": 0, "load": 0, "back": 0}
	units[id] = u
	order.append(id)
	return u


func _place_forces() -> void:
	var lati: Array = sc["lati"]
	if sc.has("sorteggio"):
		# 20.4 / 22.4: pari al primo lato, dispari all'altro; i chit non si rimettono nel sacchetto
		var bag := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
		for spec in sc["sorteggio"]:
			var k := rng.randi_range(0, bag.size() - 1)
			var c: int = bag[k]
			bag.remove_at(k)
			var s := 0 if c % 2 == 0 else 1
			_system(s, spec)
	for i in lati.size():
		var sd: Dictionary = lati[i]
		for spec in sd.get("sistemi", []):
			_system(i, spec)
		for ex in sd.get("extra", []):
			var l := Hex.parse(ex[0])
			for k in int(ex[1]):
				var u := add_unit(i, "sf", l)
				u["start"] = Hex.lz(2626, 7)   # arrivano da 61 Cygni (scenario 5)
				u["entered"] = true
		if sd.has("tutti_i_sistemi"):
			var excl: Array = sd.get("esclusi", [])
			for st in D.STARS:
				if st[0] in excl:
					continue
				add_unit(i, "gate", Hex.lz(int(st[0]), int(st[1])))
			var n: int = sd["tutti_i_sistemi"]
			var homes := [2020, 2326, 2036]
			for k in n:
				var h: int = homes[k % 3]
				if str(h) in excl:
					h = 2020
				add_unit(i, "sf", star_hex_lz(h))
			reinf_left = int(sd.get("rinforzi", 0))
			sides[i]["casa"] = [2020, 2326, 2036]
		if sd.has("xeno_porte"):
			xeno_side = i
	for i in sides.size():
		var cnt := 0
		for id in order:
			if units[id]["side"] == i and units[id]["kind"] == "sf":
				cnt += 1
		sides[i]["sf0"] = cnt
		if sides[i]["casa"].is_empty():
			# sistema natale: la prima StarGate del lato
			for id in order:
				var u: Dictionary = units[id]
				if u["side"] == i and u["kind"] == "gate":
					sides[i]["casa"] = [Hex.hexof(u["lz"])]
					break


func _system(side: int, spec: Array) -> void:
	var h := int(spec[0])
	var l := star_hex_lz(h)
	var race: String = spec[2] if spec.size() > 2 else ""
	var no_gate := false
	# scenari 2 e 3: Epsilon Indi senza StarGate è l'obiettivo; nello scenario 12 Delta Pavonis
	if str(h) == str(sc.get("obiettivo", "")):
		no_gate = true
	if not no_gate:
		add_unit(side, "gate", l, race)
	for k in int(spec[1]):
		add_unit(side, "sf", l, race)


# ================================================================ consultazioni

func alive(u: Dictionary) -> bool:
	return u["st"] == "on"


func neutralized(u: Dictionary) -> bool:
	return int(u["neut"]) >= turn


func gate_active(u: Dictionary) -> bool:
	return u["kind"] == "gate" and u["st"] == "on" and not neutralized(u)


func hostile(a: int, b: int) -> bool:
	return a != b


func live(side := -1, kind := "") -> Array:
	var out := []
	for id in order:
		var u: Dictionary = units[id]
		if u["st"] != "on":
			continue
		if side >= 0 and u["side"] != side:
			continue
		if kind != "" and u["kind"] != kind:
			continue
		out.append(u)
	return out


func units_at(l: Vector3i) -> Array:
	var out := []
	for id in order:
		var u: Dictionary = units[id]
		if u["st"] == "on" and u["lz"] == l:
			out.append(u)
	return out


func gate_at(l: Vector3i, side := -1) -> Dictionary:
	for u in units_at(l):
		if u["kind"] == "gate" and (side < 0 or u["side"] == side):
			return u
	return {}


func sides_at(l: Vector3i) -> Array:
	var out := []
	for u in units_at(l):
		if not u["side"] in out:
			out.append(u["side"])
	return out


func valid_lz(l: Vector3i) -> bool:
	if xeno > 0:
		var h := Hex.hexof(l)
		return Hex.on_map(h) and absi(l.z) <= Hex.zlimit(h) + 10
	return Hex.valid(l)


func d10() -> int:
	last_chit = rng.randi_range(0, 9)
	return last_chit


func log_msg(t: String) -> void:
	log_lines.append(t)
	log_added.emit(t)


func _pace(sec: float) -> void:
	if headless or anim <= 0.0 or abort or not is_inside_tree():
		return
	if online != null and online.catchup:
		return
	if replaying():
		return
	await get_tree().create_timer(sec / anim).timeout


# ================================================================ decisioni

func decide(seat: int, req: Dictionary):
	req["seat"] = seat
	req["turn"] = turn
	if abort:
		return ais[seat].decide(self, seat, req)
	if online != null:
		changed.emit()
		var r0 = await online.decide(self, seat, req)
		return r0
	if pre_i < preload_acts.size():
		var rp = preload_acts[pre_i]
		pre_i += 1
		rec_acts.append(rp)
		return rp
	changed.emit()
	var r = null
	if players[seat]["ai"]:
		if ai_delay > 0.0 and not headless and is_inside_tree():
			await get_tree().create_timer(ai_delay * 0.5).timeout
		r = ais[seat].decide(self, seat, req)
	else:
		decision_requested.emit(req)
		r = await decision_provided
		if r == null:
			r = ais[seat].decide(self, seat, req)
	rec_acts.append(r)
	return r


func replaying() -> bool:
	return pre_i < preload_acts.size()


## Decisioni simultanee (piani segreti): ognuno sceglie senza vedere le scelte altrui.
func decide_all(seats: Array, reqs: Array) -> Array:
	if online != null and online.has_method("decide_all") and not abort:
		var rr = await online.decide_all(self, seats, reqs)
		return rr
	var out := []
	for i in seats.size():
		var r = await decide(seats[i], reqs[i])
		out.append(r)
	return out


func provide_decision(r) -> void:
	decision_provided.emit(r)


func humans() -> int:
	var n := 0
	for p in players:
		if not p["ai"]:
			n += 1
	return n


# ================================================================ registrazione

func snapshot() -> Dictionary:
	var out := {}
	for id in order:
		var u: Dictionary = units[id]
		if u["st"] == "on":
			out[id] = [u["lz"], 1 if neutralized(u) else 0, u.get("load", 0)]
	return out


func _rec(seg: Dictionary) -> void:
	seg["u"] = snapshot()
	seg["turn"] = turn
	seg["ph"] = phase
	seg["nova"] = destroyed_stars.keys()
	history.append(seg)
	fx.emit(seg["k"], seg)


func fingerprint() -> String:
	return "%d|%d|%s" % [turn, log_lines.size(), str(hash(var_to_str(snapshot()) + str(result)))]


# ================================================================ partita

func run() -> void:
	phase = "setup"
	log_msg("Scenario: %s (%s), %s." % [sc["nome"], sc["anno"], {"base": "gioco base", "modificato": "gioco base con randomizzatore", "avanzato": "gioco avanzato"}[mode]])
	if xeno > 0:
		await _xeno_setup()
	if scn_id == 38:
		_rescue_setup()
	_rec({"k": "start"})
	turn = 0
	# spostamenti liberi prima del primo turno (scenari 2, 3, 9) e combattimento iniziale (scenario 5)
	var free := []
	for i in sides.size():
		if sc["lati"][i].get("spostamento_libero", false):
			free.append(i)
	if not free.is_empty():
		log_msg("— Spostamento libero —")
		await _stellar_turn(free)
	elif scn_id == 5:
		log_msg("— Il contatto a Eta Cassiopeiae —")
		await _combat_phase()
		_end_turn()
	if xeno > 0 and not over and not abort:
		await _xeno_pregame()
	while not over and not abort:
		turn += 1
		log_msg("— Turno %d —" % turn)
		_turn_start()
		var who := []
		for i in sides.size():
			who.append(i)
		await _stellar_turn(who)
		if over or abort:
			break
		_check_victory(true)
		if over:
			break
		if turn >= max_turns:
			_time_up()
	if abort:
		return
	_finish()


func _finish() -> void:
	phase = "over"
	_rec({"k": "end"})
	changed.emit()
	game_ended.emit(result)


func _win(w: int, reason: String) -> void:
	if over:
		return
	over = true
	result = {"winner": w, "reason": reason, "turn": turn, "vp": vp.duplicate()}
	log_msg(("Vince %s: " % pname(w) if w >= 0 else "Partita pari: ") + reason)


func _turn_start() -> void:
	contested = {}
	gate_used = gate_reserved.duplicate(true)
	gate_reserved = {}
	shift_log = []
	for s in seen_z.size():
		seen_z[s] = {}
	for u in live():
		u["start"] = u["lz"]
		u.erase("entered")
	# Xenofobi: rinforzi della Lega nei turni pari e ritorno degli Xenofobi randomizzati
	if xeno > 0:
		_xeno_turn_start()
	if scn_id == 7 and first_neut >= 0 and not sc.has("_lcd_done"):
		pass


# ---------------------------------------------------------------- turno stellare

func _stellar_turn(who: Array) -> void:
	phase = "plot"
	_compute_visibility()
	changed.emit()
	var reqs := []
	var seats := []
	for s in who:
		if sides[s]["perso"] and scn_id != 11:
			continue
		if live(s, "sf").is_empty():
			continue
		seats.append(s)
		reqs.append({"type": "plot", "free": turn == 0})
	var plots := {}
	if not seats.is_empty():
		var rr: Array = await decide_all(seats, reqs)
		for i in seats.size():
			plots[seats[i]] = rr[i] if rr[i] is Dictionary else {}
	if abort:
		return
	phase = "shift"
	await _execute_shifts(plots)
	if over or abort:
		return
	_compute_visibility()
	await _combat_phase()
	if over or abort:
		return
	_end_turn()


## Risolve il piano di un lato: per ogni StarForce il tipo di spostamento più favorevole fra quelli
## possibili, nel rispetto della capacità delle StarGate e dei rinforzi. Restituisce
## {uid: {"c", "from", "to", "d" (distanza effettiva), "safe", "col" (0 = sicuro, 1-6 = A-F), "err", "via": [porte, rinforzi]}}
func resolve_plot(side: int, plot: Dictionary) -> Dictionary:
	var out := {}
	var used := gate_used.duplicate(true)
	var enh_free := {}          # LiteZulu -> [uid rinforzi disponibili]
	for id in plot:
		if not units.has(id):
			continue
		var u: Dictionary = units[id]
		if u["side"] != side or u["kind"] != "sf" or u["st"] != "on":
			continue
		var o: Dictionary = plot[id]
		if str(o.get("c", "")) == "E" and not neutralized(u):
			if not enh_free.has(u["lz"]):
				enh_free[u["lz"]] = []
			enh_free[u["lz"]].append(id)
			out[id] = {"c": "E", "from": u["lz"], "to": u["lz"], "d": 0, "safe": true, "col": 0, "err": ""}
	var ids := plot.keys()
	ids.sort()
	# prima le richieste esplicite (codice indicato), poi le altre
	var explicit := []
	var auto := []
	for id in ids:
		if out.has(id) or not units.has(id):
			continue
		var o: Dictionary = plot[id]
		if not o.has("to"):
			continue
		if str(o.get("c", "")) in ["S", "ES", "GS", "EGS", "GGS"]:
			explicit.append(id)
		else:
			auto.append(id)
	for id in explicit + auto:
		var u: Dictionary = units[id]
		if u["side"] != side or u["kind"] != "sf" or u["st"] != "on":
			continue
		var o: Dictionary = plot[id]
		var to = o["to"]
		if to is Array:
			to = Vector3i(int(to[0]), int(to[1]), int(to[2]))
		if not (to is Vector3i):
			continue
		var r := _shift_option(u, to, str(o.get("c", "")), used, enh_free)
		out[id] = r
	return out


func _same_race_ok(u: Dictionary, helper: Dictionary) -> bool:
	return u["race"] == helper["race"] or not _race_rules()


func _race_rules() -> bool:
	return true


## valuta lo spostamento di `u` verso `to`, scegliendo il codice migliore disponibile e prenotando
## le risorse usate (capacità delle porte e rinforzi)
func _shift_option(u: Dictionary, to: Vector3i, want: String, used: Dictionary, enh_free: Dictionary) -> Dictionary:
	var from: Vector3i = u["lz"]
	var res := {"c": "S", "from": from, "to": to, "d": 0, "safe": true, "col": 0, "err": "", "via": []}
	if neutralized(u):
		res["err"] = "neutralizzata: non può spostarsi in questo turno"
		res["c"] = ""
		res["to"] = from
		return res
	if to == from:
		res["c"] = ""
		return res
	if not valid_lz(to):
		res["err"] = "fuori dal Volume"
		res["c"] = ""
		res["to"] = from
		return res
	var dist := Hex.tdist(from, to)
	var add := 0
	var auto_safe := false
	if xeno == 0:
		for g in units_at(to):
			if g["kind"] == "gate" and hostile(g["side"], u["side"]) and gate_active(g):
				add = 4
				if Hex.is_adjacent(u["start"], to) or u["start"] == to:
					auto_safe = true
	var d := dist + add
	res["d"] = d
	# risorse disponibili
	var og := gate_at(from, u["side"])
	var origin_gate := {}
	if not og.is_empty() and gate_active(og):
		origin_gate = og
	var dg := gate_at(to, u["side"])
	var dest_gate := {}
	if not dg.is_empty() and gate_active(dg) and _same_race_ok(u, dg):
		dest_gate = dg
	var enh := ""
	for e in enh_free.get(to, []):
		if _same_race_ok(u, units[e]):
			enh = e
			break
	var opts := []
	if not origin_gate.is_empty() and not dest_gate.is_empty() and (origin_gate["race"] == dest_gate["race"] or not _race_rules()):
		opts.append("GGS")
	if not origin_gate.is_empty() and enh != "":
		opts.append("EGS")
	if not origin_gate.is_empty():
		opts.append("GS")
	if not dest_gate.is_empty() or enh != "":
		opts.append("ES")
	opts.append("S")
	if want != "" and want in opts:
		opts = [want]
	elif want != "" and not want in opts:
		res["err"] = "%s non disponibile" % want
	var best := ""
	var best_col := 99
	for c in opts:
		if not _can_use(c, u, from, to, origin_gate, dest_gate, used):
			continue
		var col := shift_column(c, d, from, to, u["side"])
		if auto_safe:
			col = 0
		if col < best_col:
			best_col = col
			best = c
		if col == 0:
			break
	if best == "":
		best = "S"
		best_col = 0 if auto_safe else shift_column("S", d, from, to, u["side"])
	res["c"] = best
	res["col"] = best_col
	res["safe"] = best_col == 0
	# prenotazione delle risorse
	match best:
		"GGS":
			_use_gate(used, origin_gate["id"], best, from, to)
			_use_gate(used, dest_gate["id"], "in", from, to)
			res["via"] = [origin_gate["id"], dest_gate["id"]]
		"EGS":
			_use_gate(used, origin_gate["id"], best, from, to)
			enh_free[to].erase(enh)
			res["via"] = [origin_gate["id"], enh]
		"GS":
			_use_gate(used, origin_gate["id"], best, from, to)
			res["via"] = [origin_gate["id"]]
		"ES":
			if enh != "":
				enh_free[to].erase(enh)
				res["via"] = [enh]
			else:
				_use_gate(used, dest_gate["id"], "in", from, to)
				res["via"] = [dest_gate["id"]]
	return res


func _can_use(c: String, u: Dictionary, from: Vector3i, to: Vector3i, og: Dictionary, dg: Dictionary, used: Dictionary) -> bool:
	match c:
		"GGS":
			return _gate_free(used, og["id"], c, from, to) and _gate_free(used, dg["id"], "in", from, to)
		"EGS", "GS":
			return _gate_free(used, og["id"], c, from, to)
		"ES":
			# con un rinforzo libero non serve la porta
			return true if dg.is_empty() else true
	return true


## capacità della StarGate [7.24-7.25]: due usi qualunque, oppure fino a quattro se tutti fanno
## esattamente lo stesso spostamento
func _gate_free(used: Dictionary, gid: String, kind: String, from: Vector3i, to: Vector3i) -> bool:
	var lst: Array = used.get(gid, [])
	if lst.size() < 2:
		return true
	if lst.size() >= 4:
		return false
	for e in lst:
		if e[0] != kind or e[1] != from or e[2] != to:
			return false
	return kind != "in" or true


func _use_gate(used: Dictionary, gid: String, kind: String, from: Vector3i, to: Vector3i) -> void:
	if not used.has(gid):
		used[gid] = []
	used[gid].append([kind, from, to])


## colonna dell'oltre-spostamento: 0 = sicuro, 1-5 = A-E, 6 = F
func shift_column(c: String, d: int, from: Vector3i, to: Vector3i, side: int) -> int:
	var tab: Array = D.SHIFT_TABLE.get(c, D.SHIFT_TABLE["S"])
	if xeno > 0 and c in ["S", "GS"] and _unknown_space(to, side):
		tab = D.SHIFT_UNKNOWN[c]
	if d <= int(tab[0]):
		return 0
	for i in range(1, 6):
		if d <= int(tab[i]):
			return i
	return 6


func col_name(col: int) -> String:
	return ["sicuro", "A", "B", "C", "D", "E", "F"][clampi(col, 0, 6)]


func _execute_shifts(plots: Dictionary) -> void:
	var moves := []        # [u, res]
	for s in plots:
		var rp := resolve_plot(int(s), plots[s])
		for id in rp:
			var r: Dictionary = rp[id]
			var u: Dictionary = units[id]
			if r["c"] == "E":
				u["enh"] = true
				continue
			if str(plots[s][id].get("c", "")) == "L":
				continue
			if r["c"] == "" or r["to"] == u["lz"]:
				continue
			moves.append([u, r])
		# capacità effettivamente impegnata
		for id in rp:
			var r: Dictionary = rp[id]
			for v in r.get("via", []):
				if units.has(v) and units[v]["kind"] == "gate":
					if not gate_used.has(v):
						gate_used[v] = []
					gate_used[v].append([r["c"], r["from"], r["to"]])
		# operazioni speciali (missione di soccorso)
		for id in plots[s]:
			if str(plots[s][id].get("c", "")) == "L" and units.has(id):
				units[id]["loading"] = true
	# 1. spostamenti sicuri, 2. oltre-spostamenti
	var group_draw := {}
	var arrivals := []
	for m in moves:
		var u: Dictionary = m[0]
		var r: Dictionary = m[1]
		var res := "S"
		if r["col"] > 0:
			var key := ""
			if r["c"] in ["GS", "GGS"]:
				key = "%s|%s|%s" % [r["c"], str(r["from"]), str(r["to"])]
			var chit := -1
			if key != "" and group_draw.has(key):
				chit = group_draw[key]
			else:
				chit = d10()
				if key != "":
					group_draw[key] = chit
			res = D.OVERSHIFT[chit][r["col"] - 1]
			log_msg("%s: oltre-spostamento %s verso %s (%s, colonna %s), chit %d: %s." % [uname(u), Hex.fmt(r["from"]), Hex.fmt(r["to"]), r["c"], col_name(r["col"]), chit, {"S": "arriva", "M": "spostamento a specchio", "R": "randomizzata"}[res]])
		var dest: Vector3i = r["to"]
		match res:
			"M":
				dest = Hex.mirror(r["from"], r["to"])
				if not valid_lz(dest):
					dest = Hex.clamp_line(r["from"], Hex.hexof(dest), dest.z)
				if mode != "base":
					_neutralize(u, turn + 1)
			"R":
				shift_log.append({"id": u["id"], "from": r["from"], "to": r["to"], "res": "R", "c": r["c"]})
				_overshift_random(u)
				continue
		u["lz"] = dest
		u["entered"] = true
		shift_log.append({"id": u["id"], "from": r["from"], "to": dest, "res": res, "c": r["c"]})
		arrivals.append(u)
	_rec({"k": "shift", "moves": shift_log.duplicate(true)})
	await _pace(1.6)
	# soccorso: carico e scarico
	if scn_id == 38:
		_rescue_after_shift()
	# Xenofobi: rivelazione e ricerca nello spazio ignoto
	if xeno > 0:
		_xeno_reveal()


## R sull'oltre-spostamento: nel gioco base l'unità esce dalla partita, altrimenti randomizzazione
func _overshift_random(u: Dictionary) -> void:
	if mode == "base":
		_kill(u, "persa nello spostamento")
		return
	var r := _randomize_draw(u, true)
	match r["k"]:
		"dstr":
			_kill(u, "distrutta (randomizzatore: Dstr)")
		"brkf":
			_neutralize(u, turn + 1)
			log_msg("%s resta neutralizzata dove si trova (Brkf)." % uname(u))
		_:
			u["st"] = "rand"
			u["rand_to"] = r["lz"]
			_neutralize(u, turn + 1)
			log_msg("%s è stata randomizzata: riapparirà alla fine del turno." % uname(u))


## Tre pesche dal randomizzatore stellare [15.2]: {"k": "dstr" | "brkf" | "lz", "lz"}
func _randomize_draw(u: Dictionary, overshift: bool) -> Dictionary:
	var ch := D.stellar_chits()
	var a: Array = ch[rng.randi_range(0, ch.size() - 1)]
	if a[0] == "Dstr":
		return {"k": "dstr", "chits": [a]}
	if a[0] == "Brkf":
		return {"k": "brkf", "chits": [a]}
	var b: Array = ch[rng.randi_range(0, ch.size() - 1)]
	if b[0] == "Dstr":
		return {"k": "dstr", "chits": [a, b]}
	if b[0] == "Brkf":
		return {"k": "brkf", "chits": [a, b]}
	var c: Array = ch[rng.randi_range(0, ch.size() - 1)]
	var h := int(a[0] + b[0])
	var z: int = c[1]
	var l := Hex.lz(h, z)
	if not Hex.valid(l):
		l = Hex.clamp_random(h, z)
	if l == u["lz"]:
		return {"k": "brkf", "chits": [a, b, c]}
	if not star_at(l).is_empty():
		return {"k": "dstr", "chits": [a, b, c]}
	return {"k": "lz", "lz": l, "chits": [a, b, c]}


func _neutralize(u: Dictionary, until: int) -> void:
	u["neut"] = maxi(int(u["neut"]), until)


func _kill(u: Dictionary, why: String) -> void:
	if u["st"] == "dead":
		return
	u["st"] = "dead"
	log_msg("%s %s." % [uname(u), why])
	if u["kind"] == "sf" and xeno > 0:
		var other: int = (1 - int(u["side"])) if sides.size() == 2 else -1
		if other >= 0:
			if u["side"] == xeno_side:
				vp[other] += 1
			else:
				vp[xeno_side] += 5
	if scn_id == 38:
		rescue["lost_sf"] = int(rescue.get("lost_sf", 0)) + 1
		rescue["lost_pop"] = int(rescue.get("lost_pop", 0)) + int(u.get("load", 0))
		u["load"] = 0


func uname(u: Dictionary) -> String:
	if u["kind"] == "gate":
		var n := star_name(Hex.hexof(u["lz"]))
		return "la StarGate %s%s (%s)" % [u["label"], " di " + n if n != "" else "", sides[u["side"]]["nome"]]
	return "la StarForce %s (%s)" % [u["label"], sides[u["side"]]["nome"]]


func uname_short(u: Dictionary) -> String:
	if u["kind"] == "gate":
		return "StarGate %s" % u["label"]
	return "StarForce %s" % u["label"]


# ---------------------------------------------------------------- visibilità [7.4]

## Calcola, per ogni lato, quali zulu nemiche conosce: StarForce adiacenti a una propria StarGate
## e unità nello stesso esagono numerato.
func _compute_visibility() -> void:
	for s in sides.size():
		var known := {}
		var my_hexes := {}
		var my_gates := []
		for u in live(s):
			if u["kind"] == "sf" and not neutralized(u):
				my_hexes[Hex.hexof(u["lz"])] = true
			if u["kind"] == "gate" and u["st"] == "on":
				my_hexes[Hex.hexof(u["lz"])] = true
				if not neutralized(u):
					my_gates.append(u)
		for e in live():
			if e["side"] == s:
				continue
			if e["kind"] == "gate":
				if xeno > 0 and e["side"] == xeno_side and not xeno_known.has(e["id"]):
					continue
				known[e["id"]] = true
				continue
			if xeno > 0 and (s == xeno_side or e["side"] == xeno_side):
				# movimento nascosto: solo nella stessa LiteZulu o adiacenti a una StarGate
				for g in my_gates:
					if Hex.is_adjacent(e["lz"], g["lz"]) or e["lz"] == g["lz"]:
						known[e["id"]] = true
				for f in live(s, "sf"):
					if f["lz"] == e["lz"]:
						known[e["id"]] = true
				continue
			if my_hexes.has(Hex.hexof(e["lz"])):
				known[e["id"]] = true
			for g in my_gates:
				if Hex.is_adjacent(e["lz"], g["lz"]):
					known[e["id"]] = true
		seen_z[s] = known


## Cosa vede `viewer` di un'unità: "full" (posizione esatta), "hex" (solo l'esagono), "none".
## viewer = -1: informazioni pubbliche (gioco a turno sullo stesso dispositivo).
func visibility(u: Dictionary, viewer: int) -> String:
	if viewer == -2:
		return "full"
	if u["side"] == viewer:
		return "full"
	if u["kind"] == "gate":
		if xeno > 0 and u["side"] == xeno_side and not xeno_known.has(u["id"]):
			return "none"
		return "full"
	if viewer >= 0 and seen_z[viewer].has(u["id"]):
		return "full"
	if viewer == -1:
		for s in sides.size():
			if s != u["side"] and seen_z[s].has(u["id"]):
				return "full"
	if xeno > 0 and (u["side"] == xeno_side or viewer == xeno_side):
		return "none"
	return "hex"


# ---------------------------------------------------------------- combattimento

func _combat_phase() -> void:
	var sits := {}
	for u in live():
		var l: Vector3i = u["lz"]
		var ss := sides_at(l)
		if ss.size() >= 2:
			var hostile_pair := false
			for a in ss:
				for b in ss:
					if hostile(a, b):
						hostile_pair = true
			if hostile_pair:
				sits[l] = units_at(l).size()
	if sits.is_empty():
		return
	for l in sits:
		contested[l] = true
	var lst := sits.keys()
	lst.sort_custom(func(a, b): return sits[a] > sits[b] or (sits[a] == sits[b] and str(a) < str(b)))
	phase = "combat"
	for l in lst:
		if over or abort:
			return
		if sides_at(l).size() < 2:
			continue
		if xeno > 0:
			xeno_last_attack = turn
		if mode == "avanzato":
			tac = Tac.new()
			tac.eng = self
			await tac.run(l)
			tac = null
		else:
			await _basic_combat(l)
		_check_victory(false)
	phase = "shift"


## Valore di combattimento [8.3]: StarGate 5, StarForce 3 (2 se appena entrata, nel primo segmento),
## neutralizzate 1 (StarGate 0) nel gioco base modificato.
func strength(u: Dictionary, seg: int) -> int:
	if u["kind"] == "gate":
		if u["st"] == "limbo":
			return 0
		return 0 if neutralized(u) and mode != "base" else 5
	if neutralized(u) and mode != "base":
		return 1
	if seg == 1 and u["start"] != u["lz"]:
		return 2
	return 3


func _basic_combat(l: Vector3i) -> void:
	var seg := 0
	var quiet := 0
	var any_loss := false
	cur_combat = {"lz": l, "seg": 0, "results": []}
	log_msg("Combattimento in %s%s." % [Hex.fmt(l), (" (" + star_at(l)["name"] + ")") if not star_at(l).is_empty() else ""])
	_rec({"k": "combat", "lz": l})
	var gates_here := {}
	for g in units_at(l):
		if g["kind"] == "gate":
			gates_here[g["id"]] = g["side"]
	while not over and not abort:
		seg += 1
		cur_combat["seg"] = seg
		var here := units_at(l)
		var ss := sides_at(l)
		if not _hostile_present(ss):
			break
		if seg > 60:
			break
		# primo segmento: solo fra StarForce appena entrate e StarForce che vi avevano iniziato il turno
		var first := seg == 1
		var pools := {}
		var eligible := {}
		for s in ss:
			var p := 0
			var el := []
			for u in here:
				if u["side"] != s:
					continue
				if first:
					if u["kind"] == "gate":
						continue
				p += strength(u, seg)
				el.append(u["id"])
			pools[s] = p
			eligible[s] = el
		if first:
			var stay_sides := []
			var enter_sides := []
			for s in ss:
				for u in here:
					if u["side"] == s and u["kind"] == "sf":
						if u["start"] == l:
							if not s in stay_sides:
								stay_sides.append(s)
						elif not s in enter_sides:
							enter_sides.append(s)
			var possible := false
			for a in stay_sides:
				for b in enter_sides:
					if hostile(a, b):
						possible = true
			if not possible:
				continue
		# ripartizione segreta e simultanea
		var seats := []
		var reqs := []
		for s in ss:
			if sides[s]["perso"] and scn_id != 11:
				pass
			var can_ref := false
			if first:
				for u in here:
					if u["side"] == s and u["kind"] == "sf" and u["start"] == l:
						can_ref = true
			seats.append(s)
			reqs.append({"type": "alloc", "lz": l, "seg": seg, "first": first, "pool": pools[s], "can_refuse": can_ref, "pools": pools.duplicate()})
		cur_combat["pools"] = pools.duplicate()
		var rr: Array = await decide_all(seats, reqs)
		if abort:
			return
		var alloc := {}
		var refused := false
		for i in seats.size():
			var a := _clean_alloc(seats[i], rr[i], pools, l, seg, first)
			alloc[seats[i]] = a
			if a.get("refuse", false):
				refused = true
		if first and refused:
			log_msg("Il difensore rifiuta il combattimento nel primo segmento.")
			continue
		# risoluzione: ogni attaccante contro ogni bersaglio, risultati applicati insieme
		var losses := {}
		var seg_res := []
		for a in seats:
			var att: Dictionary = alloc[a]["att"]
			for t in att:
				var pts: int = att[t]
				if pts <= 0 or not t in seats:
					continue
				var dfn: int = alloc[t]["defp"]
				var diff := pts - dfn
				if diff < -3:
					seg_res.append({"a": a, "t": t, "att": pts, "def": dfn, "diff": diff, "chit": -1, "loss": 0})
					log_msg("%s attacca %s con %d contro %d in difesa: differenza %d, attacco non ammesso." % [sides[a]["nome"], sides[t]["nome"], pts, dfn, diff])
					continue
				var colx := clampi(diff, -3, 6) + 3
				var ch := d10()
				var n: int = D.SCRT[ch][colx]
				losses[t] = int(losses.get(t, 0)) + n
				seg_res.append({"a": a, "t": t, "att": pts, "def": dfn, "diff": diff, "chit": ch, "loss": n})
				log_msg("%s attacca %s: %d contro %d (%+d), chit %d: %s." % [sides[a]["nome"], sides[t]["nome"], pts, dfn, clampi(diff, -3, 6), ch, ("%d perdite" % n) if n > 0 else "nessun effetto"])
		cur_combat["results"] = seg_res
		_rec({"k": "segment", "lz": l, "seg": seg, "res": seg_res.duplicate(true), "alloc": alloc.duplicate(true)})
		await _pace(1.3)
		var lost_any := false
		for t in losses:
			if int(losses[t]) > 0:
				if _apply_losses(int(t), l, int(losses[t]), first, alloc):
					lost_any = true
		if lost_any:
			any_loss = true
		# nova (Xenofobi): l'innesco riesce se la StarForce sopravvive e si ritira
		for s in seats:
			var nv: String = str(alloc[s].get("nova", ""))
			if nv != "" and units.has(nv) and units[nv]["st"] == "on" and units[nv]["lz"] == l:
				_nova(l, units[nv])
		# ritirate [8.6]
		for s in seats:
			for id in alloc[s].get("brk", {}):
				if units.has(id) and units[id]["st"] == "on" and units[id]["lz"] == l:
					_breakoff(units[id], alloc[s]["brk"][id])
		_rec({"k": "after_segment", "lz": l, "seg": seg})
		# stallo [8.68]: sei segmenti senza perdite
		if not first:
			if lost_any:
				quiet = 0
			else:
				quiet += 1
			if quiet >= 6:
				quiet = 0
				_stalemate_breakoff(l)
	# fine del combattimento: StarGate in sospeso [9.31]
	var survivors := sides_at(l)
	for gid in gates_here:
		var g: Dictionary = units[gid]
		if g["st"] == "limbo_pending":
			var enemy_left := false
			for s in survivors:
				if hostile(s, g["side"]):
					enemy_left = true
			if enemy_left:
				_gate_lost(g)
			else:
				g["st"] = "limbo"
				g["limbo_turn"] = turn + 1
				log_msg("%s è stata distrutta ma il nemico è stato respinto: riapparirà al prossimo turno." % uname(g))
	cur_combat = {}
	_rec({"k": "combat_end", "lz": l})


func _hostile_present(ss: Array) -> bool:
	for a in ss:
		for b in ss:
			if hostile(a, b):
				return true
	return false


func _clean_alloc(s: int, r, pools: Dictionary, l: Vector3i, seg: int, first: bool) -> Dictionary:
	var out := {"att": {}, "defp": 0, "brk": {}, "refuse": false, "nova": ""}
	if not (r is Dictionary):
		r = ais[s].decide(self, s, {"type": "alloc", "lz": l, "seg": seg, "first": first, "pool": pools[s], "pools": pools, "can_refuse": false})
	var pool: int = pools[s]
	# StarForce che si ritirano: valgono 2 e solo in difesa
	var brk: Dictionary = {}
	if not first:
		for id in r.get("brk", {}):
			if units.has(id) and units[id]["side"] == s and units[id]["kind"] == "sf" and units[id]["lz"] == l and units[id]["st"] == "on":
				var dst = r["brk"][id]
				if dst is Array:
					dst = Vector3i(int(dst[0]), int(dst[1]), int(dst[2]))
				if dst is Vector3i and breakoff_ok(units[id], dst):
					brk[id] = dst
	var brk_pts := 0
	for id in brk:
		pool -= strength(units[id], seg)
		brk_pts += 2
	pool = maxi(pool, 0)
	var tot := 0
	for t in r.get("att", {}):
		var p := clampi(int(r["att"][t]), 0, pool - tot)
		if p > 0 and hostile(s, int(t)) and pools.has(int(t)):
			out["att"][int(t)] = p
			tot += p
	out["defp"] = clampi(int(r.get("def", pool - tot)), 0, pool - tot) + brk_pts
	out["brk"] = brk
	out["refuse"] = bool(r.get("refuse", false)) and first
	out["nova"] = str(r.get("nova", ""))
	return out


## Perdite [9.3]: il numero indica StarForce; una StarGate vale due e si perde solo se il risultato
## è almeno 2 e le StarForce non bastano. Nel gioco modificato le StarForce vengono randomizzate.
func _apply_losses(side: int, l: Vector3i, n: int, first: bool, alloc: Dictionary) -> bool:
	var pool := []
	var gate := {}
	for u in units_at(l):
		if u["side"] != side:
			continue
		if u["kind"] == "gate":
			if not first:
				gate = u
		else:
			pool.append(u)
	# nel primo segmento: chi è appena entrato può essere colpito solo da chi c'era, e viceversa
	pool.sort_custom(func(a, b): return _loss_order(a, l) < _loss_order(b, l))
	var lost := false
	var k := 0
	if pool.size() < n and not gate.is_empty() and n >= 2:
		# la StarGate assorbe due perdite
		_destroy_gate_basic(gate)
		n -= 2
		lost = true
	while n > 0 and k < pool.size():
		var u: Dictionary = pool[k]
		k += 1
		n -= 1
		lost = true
		if mode == "modificato" or (xeno > 0 and u["side"] == xeno_side):
			_combat_random(u)
		else:
			_kill(u, "è stata eliminata")
	return lost


func _loss_order(u: Dictionary, l: Vector3i) -> int:
	return (0 if neutralized(u) else 10) + (0 if u["start"] != l else 1)


func _combat_random(u: Dictionary) -> void:
	if xeno > 0 and u["side"] == xeno_side:
		var r := _randomize_draw(u, false)
		if r["k"] == "dstr":
			_kill(u, "è stata distrutta")
			return
		u["st"] = "off"
		u["back"] = turn + 4
		log_msg("%s è stata randomizzata: tornerà fra tre turni." % uname(u))
		return
	var r := _randomize_draw(u, false)
	match r["k"]:
		"dstr":
			_kill(u, "è stata distrutta (randomizzatore: Dstr)")
		"brkf":
			var dst := _any_adjacent_free(u["lz"])
			_neutralize(u, turn + 1)
			if dst != u["lz"]:
				u["lz"] = dst
			log_msg("%s si ritira in %s (Brkf)." % [uname(u), Hex.fmt(dst)])
		_:
			u["st"] = "rand"
			u["rand_to"] = r["lz"]
			_neutralize(u, turn + 1)
			log_msg("%s è stata randomizzata." % uname(u))


func _destroy_gate_basic(g: Dictionary) -> void:
	if mode == "base" or mode == "modificato":
		g["st"] = "limbo_pending"
		log_msg("%s è stata distrutta." % uname(g))


func _gate_lost(g: Dictionary) -> void:
	g["st"] = "dead"
	gates_lost[g["side"]] += 1
	log_msg("%s è stata neutralizzata in modo permanente." % uname(g))
	if scn_id == 7 and first_neut < 0:
		# il primo lato a neutralizzare una StarGate nemica riceve i L'Chal-Dah
		var winner: int = 1 - int(g["side"])
		first_neut = winner
	if xeno > 0 and g["side"] == xeno_side:
		vp[1 - xeno_side] += 25
	_rec({"k": "gate_lost", "id": g["id"], "lz": g["lz"]})


func _nova(l: Vector3i, by: Dictionary) -> void:
	var st := star_at(l)
	if st.is_empty():
		return
	destroyed_stars[l] = true
	var pts: int = {"h": 20, "s": 10, "t": 3}[st["cls"]]
	if scn_id == 15:
		pts = {"h": 50, "s": 30, "t": 5}[st["cls"]]
	if by["side"] == xeno_side and xeno_side >= 0:
		vp[xeno_side] += pts
	log_msg("La stella %s è esplosa in nova!" % st["name"])
	for g in units_at(l):
		if g["kind"] == "gate" and g["st"] == "on":
			g["st"] = "dead"
			gates_lost[g["side"]] += 1
	_breakoff(by, _any_adjacent_free(l))
	_rec({"k": "nova", "lz": l})


## Destinazioni di ritirata [8.63-8.64, 13.33]: LiteZulu di partenza se non contesa, una propria
## StarGate entro dieci Lite non contesa, altrimenti una LiteZulu adiacente non contesa.
func breakoff_options(u: Dictionary) -> Array:
	var out := []
	var l: Vector3i = u["lz"]
	var st: Vector3i = u["start"]
	if st != l and not contested.has(st) and valid_lz(st):
		out.append(st)
	for g in live(u["side"], "gate"):
		if gate_active(g) and not contested.has(g["lz"]) and Hex.tdist(g["lz"], l) <= 10 and g["lz"] != l:
			var used: Array = gate_reserved.get(g["id"], [])
			if used.size() < 2:
				out.append(g["lz"])
	for a in Hex.adjacent_lz(l):
		if not contested.has(a) and valid_lz(a) and not a in out:
			var enemy := false
			for e in units_at(a):
				if hostile(e["side"], u["side"]):
					enemy = true
			if not enemy:
				out.append(a)
	return out


func breakoff_ok(u: Dictionary, dst: Vector3i) -> bool:
	return dst in breakoff_options(u)


func _any_adjacent_free(l: Vector3i) -> Vector3i:
	for a in Hex.adjacent_lz(l):
		if not contested.has(a):
			return a
	return l


func _breakoff(u: Dictionary, dst: Vector3i) -> void:
	if u["st"] != "on":
		return
	var g := gate_at(dst, u["side"])
	if not g.is_empty():
		if not gate_reserved.has(g["id"]):
			gate_reserved[g["id"]] = []
		gate_reserved[g["id"]].append(["in", u["lz"], dst])
	u["lz"] = dst
	if mode != "base":
		_neutralize(u, turn + 1)
	log_msg("%s si ritira in %s." % [uname(u), Hex.fmt(dst)])


func _stalemate_breakoff(l: Vector3i) -> void:
	var ss := sides_at(l)
	var gate_side := -1
	for u in units_at(l):
		if u["kind"] == "gate":
			gate_side = u["side"]
	var forced := []
	if gate_side >= 0:
		for s in ss:
			if s != gate_side:
				forced.append(s)
	else:
		var best := -1
		var most := -1
		for s in ss:
			var n := 0
			for u in units_at(l):
				if u["side"] == s and u["kind"] == "sf" and u["start"] != l:
					n += 1
			if n > most:
				most = n
				best = s
		if most <= 0:
			forced = ss.duplicate()
		else:
			forced = [best]
	log_msg("Stallo: sei segmenti senza perdite, %s deve ritirarsi." % ", ".join(forced.map(func(s): return sides[s]["nome"])))
	for s in forced:
		for u in units_at(l):
			if u["side"] == s and u["kind"] == "sf":
				var opts := breakoff_options(u)
				_breakoff(u, opts[0] if not opts.is_empty() else _any_adjacent_free(l))


# ---------------------------------------------------------------- fine turno

func _end_turn() -> void:
	phase = "end"
	# StarGate in sospeso [9.31]
	for g in live(-1, "gate"):
		pass
	for id in order:
		var g: Dictionary = units[id]
		if g["kind"] != "gate":
			continue
		if g["st"] == "limbo" and int(g.get("limbo_turn", 0)) <= turn:
			var enemy := false
			for e in live():
				if e["lz"] == g["lz"] and hostile(e["side"], g["side"]):
					enemy = true
			if enemy:
				_gate_lost(g)
			else:
				g["st"] = "on"
				log_msg("%s torna in servizio." % uname(g))
		# StarGate neutralizzate (gioco avanzato): restano tali se il nemico è nella loro LiteZulu
		if g["st"] == "on" and int(g["neut"]) == turn:
			var enemy2 := false
			for e in live():
				if e["lz"] == g["lz"] and hostile(e["side"], g["side"]) and e["kind"] == "sf":
					enemy2 = true
			if enemy2 and g.get("tneut", false):
				g["neut"] = turn + 1
	# randomizzate: piazzamento [15.3]
	for id in order:
		var u: Dictionary = units[id]
		if u["st"] == "rand":
			u["st"] = "on"
			u["lz"] = u["rand_to"]
			u.erase("rand_to")
			log_msg("%s riappare in %s, neutralizzata." % [uname(u), Hex.fmt(u["lz"])])
	if scn_id == 38:
		_rescue_end_turn()
	for u in live():
		u.erase("enh")
		u.erase("loading")
	if scn_id == 7 and first_neut >= 0 and not occupy.has("lcd"):
		occupy["lcd"] = true
		for spec in sc.get("rinforzi_lcd", []):
			var l := star_hex_lz(int(spec[0]))
			add_unit(first_neut, "gate", l, "lcd")
			for k in int(spec[1]):
				add_unit(first_neut, "sf", l, "lcd")
		log_msg("I L'Chal-Dah si schierano con %s." % sides[first_neut]["nome"])
	_rec({"k": "turn_end"})


# ---------------------------------------------------------------- vittoria

func _gates_alive(side: int) -> Array:
	var out := []
	for id in order:
		var g: Dictionary = units[id]
		if g["kind"] == "gate" and g["side"] == side and g["st"] != "dead":
			out.append(g)
	return out


func _gate_dead_at(h: int) -> bool:
	for id in order:
		var g: Dictionary = units[id]
		if g["kind"] == "gate" and Hex.hexof(g["lz"]) == h:
			return g["st"] == "dead"
	return false


func _sole_occupant(l: Vector3i) -> int:
	var ss := []
	for u in live(-1, "sf"):
		if u["lz"] == l and not u["side"] in ss:
			ss.append(u["side"])
	return ss[0] if ss.size() == 1 else -1


func _check_victory(end_of_turn: bool) -> void:
	if over:
		return
	var vc: String = sc["vc"]
	match vc:
		"s1":
			if gates_lost[1] > 0:
				_win(0, "la StarGate di Alpha Centauri è stata neutralizzata.")
		"s2":
			for s in 2:
				if gates_lost[1 - s] > 0:
					_win(s, "la StarGate nemica è stata neutralizzata.")
					return
			if end_of_turn:
				_occupation(star_hex_lz(2523), 2)
		"s3":
			var phh: bool = gates_lost[1] >= 2 or (gates_lost[1] >= 1 and int(occupy.get(0, 0)) >= 2)
			var hl: bool = _gate_dead_at(2020) or _gate_dead_at(1821)
			if hl:
				_win(1, "la Lega Umana ha neutralizzato una StarGate dell'EPU.")
			elif phh:
				_win(0, "l'EPU ha raggiunto il suo obiettivo.")
			elif end_of_turn:
				_occupation(star_hex_lz(2523), 999, 0)
		"conta":
			var need := [2, 2]
			if sides[0]["sf0"] > sides[1]["sf0"]:
				need = [2, 1]
			elif sides[1]["sf0"] > sides[0]["sf0"]:
				need = [1, 2]
			for s in 2:
				if gates_lost[1 - s] >= need[s]:
					_win(s, ("ha neutralizzato %d StarGate nemiche." % gates_lost[1 - s]) if gates_lost[1 - s] > 1 else "ha neutralizzato una StarGate nemica.")
					return
		"s5":
			if _gates_alive(1).is_empty():
				_win(0, "tutte le StarGate dei L'Chal-Dah sono neutralizzate.")
			elif _gate_dead_at(2020) or gates_lost[0] >= 2:
				_win(1, "i L'Chal-Dah hanno colpito le StarGate umane.")
		"s7":
			if _gate_dead_at(2523) or gates_lost[1] >= 2:
				_win(0, "l'EPU ha piegato la rivolta.")
			elif _gate_dead_at(2020) or gates_lost[0] >= 2:
				_win(1, "la rivolta di Epsilon Indi ha vinto.")
		"s8":
			if _gate_dead_at(2020) or _gate_dead_at(2326):
				_win(0, "la Lega Umana ha perso una StarGate vitale: i Rame resistono.")
			elif _gates_alive(0).is_empty():
				_win(1, "tutte le StarGate dei Rame sono neutralizzate.")
		"casa_o_due":
			for s in 2:
				var home: int = sides[1 - s]["casa"][0]
				if _gate_dead_at(home) or gates_lost[1 - s] >= 2:
					_win(s, "ha colpito il sistema natale nemico o due StarGate.")
					return
		"s10":
			if _gate_dead_at(2020):
				_win(0, "la StarGate di Sol è caduta.")
			elif (_gate_dead_at(2326) and _gate_dead_at(2036)) or gates_lost[0] >= 4:
				_win(1, "l'EPU ha spezzato la Lega di Difesa.")
		"ultimo":
			_elimination(true)
		"s12":
			_elimination(false)
			if not over and end_of_turn:
				_occupation(star_hex_lz(2427), 4)
		"xeno":
			_xeno_victory(end_of_turn)
		"soccorso":
			pass


## occupazione: lato solo nella LiteZulu all'inizio e alla fine del turno (qui: a fine turno, contando
## i turni consecutivi); `need` turni per vincere
func _occupation(l: Vector3i, need: int, only := -1) -> void:
	var s := _sole_occupant(l)
	for k in sides.size():
		if k != s:
			occupy[k] = 0
	if s < 0 or (only >= 0 and s != only):
		return
	occupy[s] = int(occupy.get(s, 0)) + 1
	if int(occupy[s]) >= need and need < 999:
		_win(s, "ha occupato %s per %d turni consecutivi." % [star_at(l).get("name", Hex.fmt(l)), need])


func _elimination(colonies: bool) -> void:
	for s in sides.size():
		if sides[s]["perso"]:
			continue
		var home_lost := false
		for h in sides[s]["casa"]:
			if _gate_dead_at(int(h)):
				home_lost = true
		var col_lost := 0
		for id in order:
			var g: Dictionary = units[id]
			if g["kind"] == "gate" and g["side"] == s and g["st"] == "dead" and not Hex.hexof(g["lz"]) in sides[s]["casa"]:
				col_lost += 1
		if home_lost or (colonies and col_lost >= 2):
			sides[s]["perso"] = true
			log_msg("%s esce dalla corsa alla vittoria." % sides[s]["nome"])
	var left := []
	for s in sides.size():
		if not sides[s]["perso"]:
			left.append(s)
	if left.size() == 1:
		_win(left[0], "è l'ultimo giocatore rimasto in gara.")
	elif left.is_empty():
		_win(-1, "tutti i giocatori sono stati sconfitti.")


func _time_up() -> void:
	match sc["vc"]:
		"s1":
			_win(1, "Sol non è riuscita a neutralizzare la StarGate in tempo.")
		"s8":
			_win(0, "i Rame hanno resistito per %d turni." % turn)
		"s10":
			_win(0, "la Lega di Difesa ha impedito la vittoria dell'EPU.")
		"xeno":
			_xeno_victory(true, true)
		"soccorso":
			_rescue_score("La partita è finita.")
		_:
			var best := -1
			var bl := -1
			var tie := false
			for s in sides.size():
				var g := 0
				for k in sides.size():
					if k != s:
						g += gates_lost[k]
				if g > bl:
					bl = g
					best = s
					tie = false
				elif g == bl:
					tie = true
			_win(-1 if tie else best, "limite di %d turni raggiunto." % turn)


# ================================================================ Xenofobi (31.0)

func _xeno_setup() -> void:
	var lati: Array = sc["lati"]
	var spec: Dictionary = lati[xeno_side]
	# lato del Volume: lo sceglie il giocatore xenofobo
	var r = await decide(xeno_side, {"type": "xsign"})
	xeno_sign = 1 if int(r if r != null else 1) >= 0 else -1
	var gates := []
	for k in int(spec["xeno_porte"]):
		var ch := D.stellar_chits()
		var h := 0
		while true:
			var a: Array = ch[rng.randi_range(0, ch.size() - 1)]
			var b: Array = ch[rng.randi_range(0, ch.size() - 1)]
			if a[0] in ["Dstr", "Brkf"] or b[0] in ["Dstr", "Brkf"]:
				continue
			h = int(a[0] + b[0])
			if not Hex.on_map(h):
				h = Hex.hexof(Hex.clamp_random(h, 0))
			break
		var l := Hex.lz(h, xeno_sign * (Hex.zlimit(h) + 2))
		gates.append(add_unit(xeno_side, "gate", l, "xeno"))
	sides[xeno_side]["casa"] = []
	var n: int = spec["xeno_sf"]
	for k in n:
		var g: Dictionary = gates[k % gates.size()]
		add_unit(xeno_side, "sf", g["lz"], "xeno")
	sides[xeno_side]["sf0"] = n
	log_msg("Gli Xenofobi hanno schierato %d StarGate ai margini del Volume, dove la Lega non le vede." % gates.size())


func _xeno_pregame() -> void:
	var n := 10 if xeno == 1 else 5
	pregame = n
	log_msg("Turni preliminari degli Xenofobi: fino a %d spostamenti mentre la Lega non sa nulla." % n)
	for k in n:
		if over or abort:
			return
		turn = -n + k
		_turn_start()
		phase = "plot"
		_compute_visibility()
		var r = await decide(xeno_side, {"type": "plot", "free": true, "pregame": n - k})
		phase = "shift"
		await _execute_shifts({xeno_side: r if r is Dictionary else {}})
		if _xeno_adjacent_any():
			break
	turn = 0
	pregame = 0


func _xeno_adjacent_any() -> bool:
	for u in live(xeno_side, "sf"):
		for g in live(1 - xeno_side, "gate"):
			if Hex.is_adjacent(u["lz"], g["lz"]):
				return true
	return false


func _xeno_turn_start() -> void:
	var psl := 1 - xeno_side
	if turn >= 2 and turn % 2 == 0 and reinf_left > 0:
		var home := {}
		for h in [2020, 2326, 2036]:
			for g in live(psl, "gate"):
				if Hex.hexof(g["lz"]) == h and gate_active(g):
					home = g
					break
			if not home.is_empty():
				break
		if home.is_empty():
			for g in live(psl, "gate"):
				if gate_active(g):
					home = g
					break
		if not home.is_empty():
			add_unit(psl, "sf", home["lz"])
			reinf_left -= 1
			log_msg("Una nuova StarForce della Lega arriva a %s." % star_name(Hex.hexof(home["lz"])))
	for id in order:
		var u: Dictionary = units[id]
		if u["st"] == "off" and int(u["back"]) <= turn:
			var gs := []
			for g in live(xeno_side, "gate"):
				if gate_active(g):
					gs.append(g)
			if gs.is_empty():
				continue
			u["st"] = "on"
			u["lz"] = gs[rng.randi_range(0, gs.size() - 1)]["lz"]
			u["start"] = u["lz"]
			u["neut"] = -1


func _unknown_space(to: Vector3i, side: int) -> bool:
	var h := Hex.hexof(to)
	var inside := absi(to.z) <= Hex.zlimit(h)
	if side != xeno_side:
		return not inside
	if inside:
		return true
	for g in live(xeno_side, "gate"):
		if Hex.tdist(g["lz"], to) <= 10:
			return false
	return true


func _xeno_reveal() -> void:
	var psl := 1 - xeno_side
	for g in live(xeno_side, "gate"):
		if xeno_known.has(g["id"]):
			continue
		for u in live(psl, "sf"):
			if Hex.is_adjacent(u["lz"], g["lz"]) or u["lz"] == g["lz"]:
				xeno_known[g["id"]] = true
				log_msg("La Lega ha scoperto una StarGate xenofoba in %s!" % Hex.fmt(g["lz"]))
				_rec({"k": "xeno_found", "lz": g["lz"]})
				break
	# attacco a sorpresa (prima incursione, primo turno) [31.42]
	if xeno == 1 and turn == 1:
		var best := {}
		var bn := 1
		for g in live(psl, "gate"):
			if Hex.hexof(g["lz"]) in [2020, 2326, 2036]:
				continue
			var n := 0
			for u in live(xeno_side, "sf"):
				if u["lz"] == g["lz"]:
					n += 1
			if n > bn:
				bn = n
				best = g
		if not best.is_empty():
			log_msg("Attacco a sorpresa degli Xenofobi!")
			var trig := {}
			for u in live(xeno_side, "sf"):
				if u["lz"] == best["lz"]:
					trig = u
					break
			best["st"] = "dead"
			gates_lost[psl] += 1
			for u in units_at(best["lz"]):
				if u["side"] == psl and u["kind"] == "sf":
					_breakoff(u, _any_adjacent_free(best["lz"]))
			_nova(best["lz"], trig)


func _xeno_victory(end_of_turn: bool, time_up := false) -> void:
	var psl := 1 - xeno_side
	var homes_left := 0
	for h in [2020, 2326, 2036]:
		var l := star_hex_lz(h)
		if not destroyed_stars.has(l):
			homes_left += 1
	if homes_left == 0:
		_win(xeno_side, "tutti i sistemi natali della Lega sono esplosi.")
		return
	if _gates_alive(xeno_side).is_empty():
		_win(psl if vp[psl] >= vp[xeno_side] else xeno_side, "tutte le StarGate xenofobe sono distrutte (punti: Lega %d, Xenofobi %d)." % [vp[psl], vp[xeno_side]])
		return
	if end_of_turn and turn - xeno_last_attack >= 15 and turn >= 15:
		_win(psl, "gli Xenofobi non hanno attaccato per 15 turni e perdono la partita.")
		return
	if time_up:
		_win(psl if vp[psl] >= vp[xeno_side] else xeno_side, "limite di turni (punti: Lega %d, Xenofobi %d)." % [vp[psl], vp[xeno_side]])


# ================================================================ missione di soccorso (38.0)

func _rescue_setup() -> void:
	var ruined := [2036, 2626, 3018, 1521, 1532, 2026, 2228, 2623]
	var target := -1
	var guard := 0
	while target < 0 and guard < 200:
		guard += 1
		var ch := D.stellar_chits()
		var c: Array = ch[rng.randi_range(0, ch.size() - 1)]
		if c[0] in ["Dstr", "Brkf"]:
			continue
		var start := Hex.code(int(c[0]), 20)
		if not Hex.on_map(start):
			continue
		var rad := Hex.pdist(start, Hex.SOL)
		if rad == 0:
			continue
		var ring := _ring_walk(rad, start, int(c[1]) >= 0)
		for h in ring:
			if stars.has(h) and stars[h][0]["cls"] == "t" and not h in ruined:
				target = h
				break
	if target < 0:
		target = 2026
	var tl := star_hex_lz(target)
	rescue = {"star": target, "lz": tl, "pop": 60, "saved": 0, "lost_sf": 0, "lost_pop": 0, "bag": []}
	for k in 20:
		rescue["bag"].append(k % 10)
	# StarGate in tutti i sistemi tranne quello in pericolo e quelli distrutti nella prima incursione
	for st in D.STARS:
		var h := int(st[0])
		if h == target or h in ruined:
			continue
		add_unit(0, "gate", Hex.lz(h, int(st[1])))
	# vicino terziario più prossimo
	var near := -1
	var nd := 999
	for st in D.STARS:
		var h := int(st[0])
		if st[2] != "t" or h == target or h in ruined:
			continue
		var d := Hex.tdist(Hex.lz(h, int(st[1])), tl)
		if d < nd or (d == nd and Hex.tdist(Hex.lz(h, int(st[1])), Hex.lz(2020, 0)) < Hex.tdist(star_hex_lz(near), Hex.lz(2020, 0))):
			nd = d
			near = h
	for spec in [[2020, 4], [2326, 2], [target, 4], [near, 2]]:
		for k in int(spec[1]):
			add_unit(0, "sf", star_hex_lz(int(spec[0])))
	sides[0]["sf0"] = 12
	log_msg("La stella in pericolo è %s (%s): 60 punti popolazione da salvare." % [star_name(target), Hex.fmt(tl)])


func _ring_walk(rad: int, start: int, clockwise: bool) -> Array:
	var out := []
	var cur := Hex.axial(start)
	var center := Hex.axial(Hex.SOL)
	var visited := {}
	for step in rad * 6 + 1:
		out.append(Hex.from_axial(cur))
		visited[cur] = true
		# passo al vicino sullo stesso anello, nel verso richiesto (rispetto al centro)
		var best := Vector2i.ZERO
		var found := false
		for d in Hex.DIRS:
			var n: Vector2i = cur + d
			if Hex.adist(n, center) != rad or visited.has(n):
				continue
			var a := cur - center
			var b := n - center
			var pa := Hex.world_hex(Hex.from_axial(cur))
			var pb := Hex.world_hex(Hex.from_axial(n))
			var cross := pa.x * pb.y - pa.y * pb.x
			if (cross < 0) == clockwise:
				best = n
				found = true
				break
		if not found:
			break
		cur = best
	return out


func _rescue_after_shift() -> void:
	pass


func _rescue_end_turn() -> void:
	var tl: Vector3i = rescue["lz"]
	for u in live(0, "sf"):
		if not u.get("loading", false):
			continue
		if u["start"] != u["lz"]:
			continue
		if u["lz"] == tl and int(u["load"]) == 0 and int(rescue["pop"]) > 0:
			u["load"] = 1
			rescue["pop"] = int(rescue["pop"]) - 1
			log_msg("%s imbarca un punto popolazione (%d ancora sul pianeta)." % [uname(u), rescue["pop"]])
		elif u["lz"] != tl and int(u["load"]) > 0 and not star_at(u["lz"]).is_empty():
			var h := Hex.hexof(u["lz"])
			if not h in [2036, 2626, 3018, 1521, 1532, 2026, 2228, 2623]:
				u["load"] = 0
				rescue["saved"] = int(rescue["saved"]) + 1
				log_msg("%s sbarca i profughi a %s (salvati: %d)." % [uname(u), star_at(u["lz"])["name"], rescue["saved"]])
	# la nova [38.3]
	var bag: Array = rescue["bag"]
	if bag.is_empty():
		_rescue_nova()
		return
	var k := rng.randi_range(0, bag.size() - 1)
	var c: int = bag[k]
	if c != 0:
		bag.remove_at(k)
		log_msg("La stella regge ancora (chit %d)." % c)
	else:
		var k2 := rng.randi_range(0, bag.size() - 1)
		var c2: int = bag[k2]
		if c2 != 0:
			bag.remove_at(k2)
			log_msg("Segnali preoccupanti dalla stella (chit 0, poi %d)." % c2)
		else:
			_rescue_nova()
			return
	if int(rescue["pop"]) == 0:
		var aboard := 0
		for u in live(0, "sf"):
			aboard += int(u["load"])
		if aboard == 0:
			_rescue_score("Tutta la popolazione è in salvo.")


func _rescue_nova() -> void:
	var tl: Vector3i = rescue["lz"]
	log_msg("La stella %s è esplosa in nova!" % star_name(rescue["star"]))
	destroyed_stars[tl] = true
	for u in units_at(tl):
		if u["kind"] == "sf":
			_kill(u, "è stata incenerita")
	rescue["lost_pop"] = int(rescue["lost_pop"]) + int(rescue["pop"])
	rescue["pop"] = 0
	_rec({"k": "nova", "lz": tl})
	_rescue_score("La stella è esplosa.")


func _rescue_score(why: String) -> void:
	var pts := int(rescue["saved"]) - 3 * int(rescue["lost_sf"])
	vp[0] = pts
	var lvl := "sconfitta"
	if pts >= 60:
		lvl = "vittoria decisiva"
	elif pts >= 50:
		lvl = "vittoria sostanziale"
	elif pts >= 40:
		lvl = "vittoria marginale"
	over = true
	result = {"winner": 0 if pts >= 40 else -1, "reason": "%s %d punti: %s." % [why, pts, lvl], "turn": turn, "vp": vp.duplicate(), "solo": true}
	log_msg(result["reason"])
