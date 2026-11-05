extends RefCounted
## Sequenza tattica del gioco avanzato [11.0-14.0]: il combattimento in una LiteZulu si sposta sul
## Tactical Display (91 esagoni × 11 livelli MiniZulu). Ogni Tac-turno: piano segreto, due fasi di
## esecuzione (Tac-spostamenti, cambi di modo, ritirate, proiezioni), rivelazione delle posizioni,
## recupero dalla disgregazione, giudizio della situazione.
##
## tu[uid] = {pos: Vector3i, mode: "stellar"/"battle", dis: Tac-turno dell'ultima disgregazione (-1),
##            neut: StarGate neutralizzata, out: "" / "brk" / "rand"}
##
## Piano (richiesta "tplot"): {uid: {"a1": azione, "a2": azione}} per le StarForce,
##   {uid: {"c1": [proiezioni], "c2": [proiezioni]}} per le StarGate.
##   azione: {"k": "T", "to": Vector3i} | {"k": "M"} (solo prima fase) | {"k": "B", "to": LiteZulu}
##   (solo seconda fase, in modo stellare) | {"k": "C", "p": punti, "cl": ora, "zs": +1/-1} | {"k": ""}

const D = preload("res://scripts/data/sf_data.gd")

var eng
var l: Vector3i
var tu := {}
var tt := 0
var star := false
var last_cast := 0
var forced_brk := {}       # lato -> Tac-turno entro cui ritirarsi (stallo)
var casts_shown: Array = []   # proiezioni dell'ultima fase (per la vista)
var known := {}            # lato -> {uid: Vector3i ultima posizione nota}
var phase_n := 0
var plans := {}
var nova_armed := {}       # {"tt": Tac-turno dell'esplosione, "by": uid} (31.52)
var nova_done := false
var transport := ""        # scenario 20: il trasporto xenofobo
var extra_tt := 0          # Tac-turni concessi agli Xenofobi per innescare la nova


## chi può piantare l'innesco della nova in questa LiteZulu: gli Xenofobi in un sistema della Lega,
## la Lega nel sistema natale xenofobo (scenario 20)
func can_trigger(side: int) -> bool:
	if not star or nova_done:
		return false
	if eng.scn_id == 20:
		return side == 0
	return eng.xeno > 0 and side == eng.xeno_side


## la StarGate del sistema (nemica di chi innesca) è disgregata o neutralizzata?
func gate_down(side: int) -> bool:
	for u in units():
		if u["kind"] == "gate" and eng.hostile(u["side"], side):
			if not (tu[u["id"]]["neut"] or is_disrupted(u["id"])):
				return false
	return true


func units() -> Array:
	var out := []
	for id in tu:
		if tu[id]["out"] == "" and eng.units.has(id) and eng.units[id]["st"] == "on":
			out.append(eng.units[id])
	return out


func sides() -> Array:
	var out := []
	for u in units():
		if not u["side"] in out:
			out.append(u["side"])
	return out


func is_disrupted(id: String) -> bool:
	var t: Dictionary = tu[id]
	if eng.units[id]["kind"] == "sf" and eng.neutralized(eng.units[id]):
		return true
	return int(t["dis"]) >= 0


## TeleValue disponibile nel Tac-turno (dimezzato se disgregata)
func televalue(id: String, mode := "") -> int:
	var u: Dictionary = eng.units[id]
	if u["kind"] == "gate":
		if tu[id]["neut"]:
			return 0
		return D.TELE_GATE / 2 if is_disrupted(id) else D.TELE_GATE
	var m: String = mode if mode != "" else tu[id]["mode"]
	var v: int = D.TELE_BATTLE if m == "battle" else D.TELE_STELLAR
	if u.get("ff", false):
		v = D.FF_TELE_BATTLE if m == "battle" else D.FF_TELE_STELLAR
	return v / 2 if is_disrupted(id) else v


func tac_cost(mode: String, dist: int, ff := false) -> int:
	if dist <= 0:
		return 0
	if mode == "battle":
		var tb: Array = D.FF_COST_BATTLE if ff else D.TAC_COST_BATTLE
		return tb[dist] if dist < tb.size() else 999
	var ts: Array = D.FF_COST_STELLAR if ff else D.TAC_COST_STELLAR
	return ts[dist] if dist < ts.size() else 999


## Verifica il piano di una StarForce e calcola costi e anti-proiezione:
## {"ok", "err", "cost1", "cost2", "tv", "anti", "mode2"}
func check_sf(id: String, p: Dictionary) -> Dictionary:
	var t: Dictionary = tu[id]
	var a1: Dictionary = p.get("a1", {})
	var a2: Dictionary = p.get("a2", {})
	var mode: String = t["mode"]
	var res := {"ok": true, "err": "", "cost1": 0, "cost2": 0, "tv": 0, "anti": 0, "mode2": mode}
	var k1 := str(a1.get("k", ""))
	var k2 := str(a2.get("k", ""))
	var mode2 := mode
	var tv := televalue(id)
	var pos: Vector3i = t["pos"]
	var ff: bool = eng.units[id].get("ff", false)
	if int(t.get("late", -1)) == tt and k1 != "":
		return _bad(res, "la riserva appena arrivata agisce solo nella seconda fase")
	if k1 == "M":
		mode2 = "stellar" if mode == "battle" else "battle"
		tv = televalue(id, mode2)
		res["cost1"] = (D.TELE_BATTLE if mode2 == "battle" else D.TELE_STELLAR) / 2
		if ff:
			res["cost1"] = (D.FF_TELE_BATTLE if mode2 == "battle" else D.FF_TELE_STELLAR) / 2
	elif k1 == "T":
		var to: Vector3i = a1["to"]
		if not Hex.tvalid(to):
			return _bad(res, "destinazione fuori dal Tactical Display")
		var d := Hex.ttrue(pos, to)
		if not _star_ok(pos, to, d):
			return _bad(res, "la stella si può raggiungere o lasciare solo da un MiniLite")
		res["cost1"] = tac_cost(mode, d, ff)
		pos = to
	elif k1 == "C":
		res["cost1"] = int(a1.get("p", 0))
		if not int(a1.get("p", 0)) in D.CAST_LEVELS:
			return _bad(res, "proiezione non valida")
	elif k1 == "B":
		return _bad(res, "la ritirata si fa solo nella seconda fase")
	elif k1 == "N":
		# innesco della nova: un intero Tac-turno nel MiniLite della stella, in modo stellare, metà dei
		# TelePunti; la StarGate deve essere disgregata o neutralizzata (31.52)
		if not can_trigger(eng.units[id]["side"]):
			return _bad(res, "qui non si può innescare una nova")
		if pos != Vector3i(0, 0, -1):
			return _bad(res, "bisogna essere nel MiniLite della stella (000/-1)")
		if mode != "stellar":
			return _bad(res, "per innescare la nova bisogna essere in modo stellare")
		if not gate_down(eng.units[id]["side"]):
			return _bad(res, "la StarGate del sistema deve essere disgregata o neutralizzata")
		if k2 != "":
			return _bad(res, "l'innesco occupa tutto il Tac-turno")
		res["cost1"] = tv / 2
	res["mode2"] = mode2
	if k2 == "M":
		return _bad(res, "il cambio di modo si fa solo nella prima fase")
	elif k2 == "T":
		var to2: Vector3i = a2["to"]
		if not Hex.tvalid(to2):
			return _bad(res, "destinazione fuori dal Tactical Display")
		var d2 := Hex.ttrue(pos, to2)
		if not _star_ok(pos, to2, d2):
			return _bad(res, "la stella si può raggiungere o lasciare solo da un MiniLite")
		res["cost2"] = tac_cost(mode2, d2, ff)
	elif k2 == "C":
		res["cost2"] = int(a2.get("p", 0))
		if not int(a2.get("p", 0)) in D.CAST_LEVELS:
			return _bad(res, "proiezione non valida")
	elif k2 == "B":
		if mode2 != "stellar":
			return _bad(res, "per ritirarsi bisogna essere in modo stellare")
		res["cost2"] = D.FF_BREAKOFF_COST if ff else D.BREAKOFF_COST
		var bto = a2.get("to", null)
		if not (bto is Vector3i) or not eng.breakoff_ok(eng.units[id], bto):
			return _bad(res, "destinazione di ritirata non valida")
	res["tv"] = tv
	# fatica (36.1 B): nessuna proiezione con più di metà dei TelePunti
	if eng.fatigue(eng.units[id]) >= 2:
		for a in [a1, a2]:
			if str(a.get("k", "")) == "C" and int(a.get("p", 0)) > tv / 2:
				return _bad(res, "equipaggio affaticato: al massimo metà dei TelePunti in una proiezione")
	if nova_done and pos == Vector3i(0, 0, -1) and k1 == "T":
		return _bad(res, "la stella è esplosa: il suo MiniLite non si può più raggiungere")
	var spent: int = res["cost1"] + res["cost2"]
	if k1 == "M":
		spent = res["cost1"] + res["cost2"]
	if spent > tv:
		return _bad(res, "TelePunti insufficienti (%d su %d)" % [spent, tv])
	res["anti"] = tv - spent
	return res


func _bad(res: Dictionary, e: String) -> Dictionary:
	res["ok"] = false
	res["err"] = e
	return res


func _star_ok(a: Vector3i, b: Vector3i, d: int) -> bool:
	if not star:
		return true
	var sp := Vector3i(0, 0, -1)
	if (a == sp or b == sp) and d > 1:
		return false
	return true


func check_gate(id: String, p: Dictionary) -> Dictionary:
	var res := {"ok": true, "err": "", "anti1": 0, "anti2": 0}
	var tv := televalue(id)
	for ph in ["c1", "c2"]:
		var lst: Array = p.get(ph, [])
		var tot := 0
		var dirs := {}
		if lst.size() > 12:
			return _bad(res, "al massimo dodici proiezioni per fase")
		for c in lst:
			var pts := int(c.get("p", 0))
			if not pts in D.CAST_LEVELS:
				return _bad(res, "proiezione non valida")
			var key := "%d|%d" % [int(c.get("cl", 3)), int(c.get("zs", 1))]
			if dirs.has(key):
				return _bad(res, "ogni proiezione deve andare in una direzione diversa")
			dirs[key] = true
			tot += pts
		if tot > tv:
			return _bad(res, "TelePunti insufficienti (%d su %d)" % [tot, tv])
		res["anti" + ph.substr(1)] = tv - tot
	return res


# ================================================================ sequenza

func run(lz: Vector3i) -> void:
	l = lz
	star = not eng.star_at(l).is_empty()
	tt = 0
	last_cast = 0
	for u in eng.units_at(l):
		tu[u["id"]] = {"pos": Vector3i.ZERO, "mode": "stellar", "dis": -1, "neut": false, "out": "", "hit": -1}
	for s in eng.sides.size():
		known[s] = {}
	eng.log_msg("Situazione tattica in %s%s: il combattimento passa sul Tactical Display." % [Hex.fmt(l), (" (" + eng.star_at(l)["name"] + ")") if star else ""])
	await _deploy()
	if eng.abort:
		return
	eng._rec({"k": "tac_start", "lz": l, "tac": snapshot()})
	var cycle := 0
	if eng.has_opt("continuita"):
		cycle = 24 if eng.prolonged.has(l) else 12
		eng.prolonged.erase(l)
	while not eng.abort and not eng.over:
		tt += 1
		if eng.scn_id == 1 and eng.s1_start < 0:
			eng.s1_start = tt
		if cycle > 0 and tt > cycle:
			eng.prolonged[l] = true
			eng.log_msg("Il combattimento in %s non è risolto e prosegue nel prossimo turno." % Hex.fmt(l))
			break
		if tt == 3 and eng.has_opt("riserve"):
			_reserves_in()
		await _tac_turn()
		if eng.abort:
			return
		if _judgment():
			break
		if tt >= 60:
			eng.log_msg("Il combattimento tattico si interrompe dopo 60 Tac-turni.")
			for u in units():
				if u["kind"] == "sf":
					_do_breakoff(u, _brk_default(u))
			break
		if eng.scn_id == 1 and tt - eng.s1_start + 1 >= 4 and not eng.over:
			eng._time_up()
			return
	_finish()


func _deploy() -> void:
	var ss := sides()
	var seats := []
	var reqs := []
	for s in ss:
		var ids := []
		for u in units():
			if u["side"] == s and u["kind"] == "sf":
				ids.append(u["id"])
		for u in units():
			if u["kind"] == "gate":
				tu[u["id"]]["pos"] = Vector3i.ZERO
				if eng.neutralized(u):
					tu[u["id"]]["neut"] = true
		if ids.is_empty():
			continue
		seats.append(s)
		reqs.append({"type": "tdeploy", "lz": l, "ids": ids})
	var rr: Array = await eng.decide_all(seats, reqs)
	for i in seats.size():
		var s: int = seats[i]
		var r = rr[i]
		var ok := r is Dictionary and _deploy_ok(s, r)
		if not ok:
			r = eng.ais[s].decide(eng, s, reqs[i])
		for id in r:
			if not tu.has(id):
				continue
			var e: Array = r[id]
			tu[id]["pos"] = e[0]
			var u: Dictionary = eng.units[id]
			if e.size() > 1 and bool(e[1]) and u["start"] == l:
				tu[id]["mode"] = "battle"
	if transport != "" and tu.has(transport):
		var cells: Array = []
		for c in Hex.t_all():
			if Hex.tring(Vector3i(c.x, c.y, 0)) <= 2:
				cells.append(c)
		var a: Vector2i = cells[eng.rng.randi_range(0, cells.size() - 1)]
		var z: int = eng.rng.randi_range(-2, 2)
		if a == Vector2i.ZERO and z in [0, -1]:
			z = 3
		tu[transport]["pos"] = Vector3i(a.x, a.y, z)
		tu[transport]["mode"] = "stellar"
	for u in units():
		if u["kind"] == "sf":
			known[u["side"]][u["id"]] = tu[u["id"]]["pos"]
	_reveal()


## zone di schieramento [11.11]: chi c'era può stare ovunque, chi è appena arrivato sull'anello 5 o a
## MiniZulu +/-5, e chi arriva dalla stessa LiteZulu entro un MiniLite dagli altri del gruppo
func deploy_zone_ok(u: Dictionary, p: Vector3i) -> bool:
	if not Hex.tvalid(p):
		return false
	if u["start"] == l and not u.get("entered", false):
		return true
	return Hex.tring(p) == 5 or absi(p.z) == 5


func _deploy_ok(s: int, r: Dictionary) -> bool:
	var groups := {}
	for id in r:
		if not tu.has(id) or eng.units[id]["side"] != s:
			return false
		var e = r[id]
		if not (e is Array) or e.is_empty() or not (e[0] is Vector3i):
			return false
		var u: Dictionary = eng.units[id]
		if not deploy_zone_ok(u, e[0]):
			return false
		if u["start"] != l or u.get("entered", false):
			var k := str(u["start"])
			if not groups.has(k):
				groups[k] = []
			groups[k].append(e[0])
	for k in groups:
		var ps: Array = groups[k]
		for a in ps:
			for b in ps:
				if Hex.ttrue(a, b) > 1:
					return false
	for u in units():
		if u["side"] == s and u["kind"] == "sf" and not r.has(u["id"]):
			return false
	return true


func _tac_turn() -> void:
	eng.log_msg("Tac-turno %d." % tt)
	eng.cur_combat = {"lz": l, "tt": tt}
	# A. piano
	var ss := sides()
	var seats := []
	var reqs := []
	for s in ss:
		seats.append(s)
		reqs.append({"type": "tplot", "lz": l, "tt": tt, "forced": forced_brk.has(s)})
	var rr: Array = await eng.decide_all(seats, reqs)
	if eng.abort:
		return
	plans = {}
	for i in seats.size():
		var s: int = seats[i]
		var r = rr[i]
		plans[s] = _clean_plan(s, r if r is Dictionary else {})
		if forced_brk.has(s) and tt >= int(forced_brk[s]):
			for u in units():
				if u["side"] == s and u["kind"] == "sf":
					plans[s][u["id"]] = _forced_plan(u)
	# B. prima fase
	phase_n = 1
	var antis := _antis()
	_exec_moves(1)
	eng._rec({"k": "tac_move", "lz": l, "ph": 1, "tac": snapshot()})
	await eng._pace(0.8)
	_nova_blast()
	var hit1 := await _exec_casts(1, antis)
	# modifica del piano per chi è stato disgregato nella prima fase [12.5]
	for id in hit1:
		_modify(id)
	# C. seconda fase: prima le ritirate
	phase_n = 2
	for s in plans:
		for id in plans[s]:
			if not tu.has(id) or tu[id]["out"] != "":
				continue
			var a2: Dictionary = plans[s][id].get("a2", {})
			if str(a2.get("k", "")) == "B" and not plans[s][id].get("_cancel2", false):
				_do_breakoff(eng.units[id], a2["to"])
	antis = _antis(2)
	_exec_moves(2)
	eng._rec({"k": "tac_move", "lz": l, "ph": 2, "tac": snapshot()})
	await eng._pace(0.8)
	await _exec_casts(2, antis)
	_nova_plant()
	# D. rivelazione, E. recupero dalla disgregazione
	_reveal()
	for id in tu:
		var t: Dictionary = tu[id]
		if t["out"] != "":
			continue
		if int(t["dis"]) >= 0 and int(t["hit"]) < tt:
			t["dis"] = -1
	# stallo [11.12G]
	if tt - last_cast >= 12 and forced_brk.is_empty():
		var gs := -1
		for u in units():
			if u["kind"] == "gate" and not tu[u["id"]]["neut"]:
				gs = u["side"]
		var who := []
		for s in sides():
			if gs >= 0:
				if s != gs:
					who.append(s)
			else:
				var arrived := false
				for u in units():
					if u["side"] == s and u["kind"] == "sf" and u["start"] == l and not u.get("entered", false):
						arrived = true
				if not arrived:
					who.append(s)
		if who.is_empty():
			who = sides()
		for s in who:
			forced_brk[s] = tt + 2
		eng.log_msg("Stallo: dodici Tac-turni senza proiezioni efficaci; chi non difende deve ritirarsi.")
	eng._rec({"k": "tac_turn", "lz": l, "tac": snapshot()})


## riserve chiamate all'inizio del terzo Tac-turno (32.1): compaiono in modo stellare sulla posizione
## di un'unità amica non neutralizzata già presente
func _reserves_in() -> void:
	for u in eng.call_reserves(l):
		var spot := Vector3i(5, 0, 0)
		for f in units():
			if f["side"] == u["side"] and not (f["kind"] == "gate" and tu[f["id"]]["neut"]):
				spot = tu[f["id"]]["pos"]
				break
		tu[u["id"]] = {"pos": spot, "mode": "stellar", "dis": -1, "neut": false, "out": "", "hit": -1, "late": tt}
		known[u["side"]][u["id"]] = spot


## fine del Tac-turno: l'innesco è piantato se chi lo piantava è ancora lì, non disgregato
func _nova_plant() -> void:
	if not nova_armed.is_empty() or nova_done:
		return
	for s in plans:
		for id in plans[s]:
			if str(plans[s][id].get("a1", {}).get("k", "")) != "N":
				continue
			if not tu.has(id) or tu[id]["out"] != "" or int(tu[id]["hit"]) == tt or is_disrupted(id):
				continue
			if tu[id]["pos"] != Vector3i(0, 0, -1) or not gate_down(eng.units[id]["side"]):
				continue
			nova_armed = {"tt": tt + 1, "by": id}
			eng.log_msg("%s ha piantato l'innesco nella stella: esploderà nel prossimo Tac-turno!" % eng.uname(eng.units[id]))
			return


func _nova_blast() -> void:
	if nova_armed.is_empty() or nova_done or int(nova_armed["tt"]) != tt:
		return
	nova_done = true
	eng.log_msg("La stella esplode in nova!")
	eng._rec({"k": "nova", "lz": l})
	for u in units():
		if u["kind"] == "sf" and tu[u["id"]]["pos"] == Vector3i(0, 0, -1):
			tu[u["id"]]["out"] = "dead"
			eng._kill(u, "è stata incenerita dalla nova")


func _clean_plan(s: int, r: Dictionary) -> Dictionary:
	var out := {}
	for u in units():
		if u["side"] != s:
			continue
		var id: String = u["id"]
		var p: Dictionary = r.get(id, {})
		if u["kind"] == "gate":
			if tu[id]["neut"]:
				out[id] = {"c1": [], "c2": []}
				continue
			var c := check_gate(id, p)
			out[id] = p if c["ok"] else {"c1": [], "c2": []}
			out[id]["_chk"] = check_gate(id, out[id])
		else:
			if int(tu[id].get("late", -1)) == tt:
				p = p.duplicate(true)
				p["a1"] = {"k": ""}
			var c2 := check_sf(id, p)
			if not c2["ok"]:
				p = {"a1": {"k": ""}, "a2": {"k": ""}}
				c2 = check_sf(id, p)
			out[id] = p.duplicate(true)
			out[id]["_chk"] = c2
	return out


func _forced_plan(u: Dictionary) -> Dictionary:
	var p := {"a1": {"k": ""}, "a2": {"k": "B", "to": _brk_default(u)}}
	if tu[u["id"]]["mode"] == "battle":
		p["a1"] = {"k": "M"}
	var c := check_sf(u["id"], p)
	p["_chk"] = c
	return p


func _brk_default(u: Dictionary) -> Vector3i:
	var opts: Array = eng.breakoff_options(u)
	return opts[0] if not opts.is_empty() else eng._any_adjacent_free(l)


## anti-proiezioni in vigore: StarForce per tutto il Tac-turno, StarGate per fase
func _antis(ph := 1) -> Dictionary:
	var out := {}
	for s in plans:
		for id in plans[s]:
			if not tu.has(id):
				continue
			var p: Dictionary = plans[s][id]
			var c: Dictionary = p.get("_chk", {})
			if eng.units[id]["kind"] == "gate":
				out[id] = int(c.get("anti%d" % ph, 0))
			else:
				out[id] = int(p.get("_anti2", c.get("anti", 0))) if ph == 2 else int(c.get("anti", 0))
	return out


func _exec_moves(ph: int) -> void:
	for s in plans:
		for id in plans[s]:
			if not tu.has(id) or tu[id]["out"] != "":
				continue
			var p: Dictionary = plans[s][id]
			if eng.units[id]["kind"] == "gate":
				continue
			var a: Dictionary = p.get("a%d" % ph, {})
			if ph == 2 and p.get("_cancel2", false):
				continue
			match str(a.get("k", "")):
				"T":
					tu[id]["pos"] = a["to"]
				"M":
					tu[id]["mode"] = "battle" if tu[id]["mode"] == "stellar" else "stellar"
					if tu[id]["mode"] == "battle":
						tu[id]["was_battle"] = true
					eng.log_msg("%s passa in modo %s." % [eng.uname(eng.units[id]), "battaglia" if tu[id]["mode"] == "battle" else "stellare"])


## Proiezioni simultanee della fase: somma degli effetti per bersaglio, un chit per bersaglio,
## risultati applicati tutti insieme. Restituisce le unità disgregate (per la modifica del piano).
func _exec_casts(ph: int, antis: Dictionary) -> Array:
	var casts := []     # [caster_id, side, origin, pts, clock, zsign]
	for s in plans:
		for id in plans[s]:
			if not tu.has(id) or tu[id]["out"] != "":
				continue
			var u: Dictionary = eng.units[id]
			var p: Dictionary = plans[s][id]
			if u["kind"] == "gate":
				if tu[id]["neut"]:
					continue
				for c in p.get("c%d" % ph, []):
					var pts = int(c["p"])
					if ph == 2 and p.get("_half2", false):
						pts = pts / 2
					if pts >= 2:
						casts.append([id, s, tu[id]["pos"], pts, int(c.get("cl", 3)), int(c.get("zs", 1))])
			else:
				var a: Dictionary = p.get("a%d" % ph, {})
				if str(a.get("k", "")) == "C":
					var pts2 := int(a["p"])
					if ph == 2 and p.get("_half2", false):
						pts2 = pts2 / 2
					if pts2 >= 2:
						casts.append([id, s, tu[id]["pos"], pts2, int(a.get("cl", 3)), int(a.get("zs", 1))])
	casts_shown = []
	if casts.is_empty():
		return []
	var vols := []
	for c in casts:
		vols.append(Hex.cast_volume(c[2], c[4], c[5]))
		casts_shown.append({"id": c[0], "side": c[1], "from": c[2], "p": c[3], "cl": c[4], "zs": c[5]})
	eng._rec({"k": "tac_cast", "lz": l, "ph": ph, "casts": casts_shown.duplicate(true), "tac": snapshot()})
	await eng._pace(1.0)
	var results := {}
	var outcome := []
	for t in units():
		var tid: String = t["id"]
		var tp: Vector3i = tu[tid]["pos"]
		var tot := 0
		var hit := false
		for i in casts.size():
			var c: Array = casts[i]
			if not eng.hostile(c[1], t["side"]):
				continue
			var v: Dictionary = vols[i]
			if v.has(tp):
				hit = true
				# la proiezione rivela le unità nel suo volume [14.42]
				known[c[1]][tid] = tp
				tot += int(c[3]) >> int(v[tp])
		if not hit or tot < 1:
			continue
		var diff: int = tot - int(antis.get(tid, 0))
		if diff < 0:
			outcome.append({"id": tid, "tot": tot, "anti": antis.get(tid, 0), "chit": -1, "res": "."})
			continue
		var col := 0
		if diff >= 32:
			col = 6
		elif diff >= 16:
			col = 5
		elif diff >= 8:
			col = 4
		elif diff >= 4:
			col = 3
		elif diff >= 2:
			col = 2
		elif diff >= 1:
			col = 1
		var ch: int = eng.d10()
		last_cast = tt
		var r: String = D.CAST_TABLE[ch][col]
		results[tid] = r
		outcome.append({"id": tid, "tot": tot, "anti": antis.get(tid, 0), "chit": ch, "res": r})
		eng.log_msg("Proiezioni su %s: %d contro anti-proiezione %d, chit %d: %s." % [eng.uname(t), tot, antis.get(tid, 0), ch, {".": "nessun effetto", "D": "disgregata", "R": "randomizzata" if t["kind"] == "sf" and tid != transport else "disgregata"}[r]])
	var dis := []
	for tid in results:
		var r: String = results[tid]
		var u: Dictionary = eng.units[tid]
		if r == ".":
			continue
		tu[tid]["hit"] = tt
		if u["kind"] == "gate":
			if r == "R":
				if int(tu[tid]["dis"]) >= 0:
					tu[tid]["neut"] = true
					tu[tid]["dis"] = -1
					eng.log_msg("%s è neutralizzata." % eng.uname(u))
				else:
					tu[tid]["dis"] = tt
					dis.append(tid)
			continue
		if r == "D" and not is_disrupted(tid):
			tu[tid]["dis"] = tt
			dis.append(tid)
		elif tid == transport:
			tu[tid]["dis"] = tt
			dis.append(tid)
		else:
			_randomize(u)
	eng._rec({"k": "tac_result", "lz": l, "ph": ph, "out": outcome, "tac": snapshot()})
	await eng._pace(0.8)
	return dis


func _modify(id: String) -> void:
	if not tu.has(id) or tu[id]["out"] != "":
		return
	var u: Dictionary = eng.units[id]
	for s in plans:
		if not plans[s].has(id):
			continue
		var p: Dictionary = plans[s][id]
		if u["kind"] == "gate":
			p["_half2"] = true
			var c: Dictionary = p.get("_chk", {})
			c["anti2"] = int(c.get("anti2", 0)) / 2
			return
		var c2: Dictionary = p.get("_chk", {})
		var anti := int(c2.get("anti", 0)) / 2
		var a2: Dictionary = p.get("a2", {})
		var k := str(a2.get("k", ""))
		if k == "T" or k == "B":
			p["_cancel2"] = true
			anti += int(c2.get("cost2", 0)) / 2
		elif k == "C":
			var pts := int(a2.get("p", 0)) / 2
			if pts < 2:
				p["_cancel2"] = true
				anti += 1
			else:
				p["_half2"] = true
		p["_anti2"] = anti


func _randomize(u: Dictionary) -> void:
	var id: String = u["id"]
	tu[id]["out"] = "rand"
	if eng.xeno > 0 and u["side"] == eng.xeno_side:
		# Xenofobi randomizzati: fuori per tre turni (31.53)
		eng._combat_random(u)
		return
	var r: Dictionary = eng._randomize_draw(u, false)
	match r["k"]:
		"dstr":
			eng._kill(u, "è stata distrutta (randomizzatore: Dstr)")
		"brkf":
			# ritirata obbligata in una LiteZulu adiacente non contesa [15.12]
			tu[id]["out"] = "brk"
			var dst: Vector3i = eng._any_adjacent_free(l)
			u["lz"] = dst
			eng._neutralize(u, eng.turn + 1)
			eng.log_msg("%s è costretta a ritirarsi in %s (Brkf)." % [eng.uname(u), Hex.fmt(dst)])
		_:
			u["st"] = "rand"
			u["rand_to"] = r["lz"]
			eng._neutralize(u, eng.turn + 1)
			eng.log_msg("%s è stata randomizzata." % eng.uname(u))


func _do_breakoff(u: Dictionary, dst: Vector3i) -> void:
	var id: String = u["id"]
	if tu[id]["out"] != "":
		return
	tu[id]["out"] = "brk"
	eng._breakoff(u, dst)


## [11.12F] la sequenza finisce quando non restano unità ostili fra loro (StarGate neutralizzate escluse)
func _judgment() -> bool:
	# Xenofobi: con la StarGate a terra la sequenza prosegue finché possono innescare la nova (31.52)
	if eng.xeno > 0 and star and not nova_done:
		if not nova_armed.is_empty():
			return false
		var xs := false
		for u in units():
			if u["side"] == eng.xeno_side and u["kind"] == "sf" and not is_disrupted(u["id"]):
				xs = true
		if xs and gate_down(eng.xeno_side) and int(extra_tt) < 4:
			for u in units():
				if u["kind"] == "gate" and eng.hostile(u["side"], eng.xeno_side):
					extra_tt += 1
					return false
	if eng.scn_id == 20:
		if nova_done:
			return true
		if transport != "" and (not tu.has(transport) or tu[transport]["out"] != ""):
			return true
	var ss := []
	for u in units():
		if u["kind"] == "gate" and tu[u["id"]]["neut"]:
			continue
		if not u["side"] in ss:
			ss.append(u["side"])
	for a in ss:
		for b in ss:
			if eng.hostile(a, b):
				return false
	return true


func _finish() -> void:
	# nova innescata: la stella e il sistema sono distrutti alla fine della sequenza (31.52)
	if nova_done:
		var by: Dictionary = eng.units.get(nova_armed.get("by", ""), {})
		if by.is_empty():
			for u in units():
				by = u
				break
		if not by.is_empty():
			eng._nova(l, by)
	# StarGate neutralizzate [14.72]
	var ss := []
	for u in units():
		if u["kind"] == "sf" and not u["side"] in ss:
			ss.append(u["side"])
	for u in units():
		if u["kind"] != "gate" or not tu[u["id"]]["neut"]:
			continue
		var enemy_only := not ss.is_empty()
		for s in ss:
			if not eng.hostile(s, u["side"]):
				enemy_only = false
		if enemy_only:
			eng._gate_lost(u)
		else:
			u["neut"] = eng.turn + 1
			u["tneut"] = true
			eng.log_msg("%s resta neutralizzata per il prossimo turno." % eng.uname(u))
	# modo battaglia e posizioni non contano più sullo Stellar Display
	for id in tu:
		if eng.units.has(id):
			if tu[id].get("was_battle", false) or tu[id]["mode"] == "battle":
				eng.units[id]["bm_now"] = true
			eng.units[id]["mode"] = "stellar"
			if eng.units[id].get("ff", false):
				eng.units[id]["ff_known"] = true
	eng._rec({"k": "tac_end", "lz": l})
	eng.cur_combat = {}


func _reveal() -> void:
	var gate_eyes := {}
	for u in units():
		if u["kind"] == "gate" and not tu[u["id"]]["neut"] and not is_disrupted(u["id"]):
			gate_eyes[u["side"]] = true
	for s in eng.sides.size():
		for u in units():
			if u["side"] == s:
				continue
			var p: Vector3i = tu[u["id"]]["pos"]
			if gate_eyes.has(s) or u["kind"] == "gate":
				known[s][u["id"]] = p
				continue
			for f in units():
				if f["side"] == s and tu[f["id"]]["pos"].x == p.x and tu[f["id"]]["pos"].y == p.y:
					known[s][u["id"]] = p


## posizione nota a `viewer`: Vector3i esatto, oppure null se si conosce solo l'esagono
func known_pos(u: Dictionary, viewer: int):
	var id: String = u["id"]
	if viewer == -2 or u["side"] == viewer or u["kind"] == "gate":
		return tu[id]["pos"]
	if viewer >= 0 and known.get(viewer, {}).get(id, null) == tu[id]["pos"]:
		return tu[id]["pos"]
	if viewer == -1:
		for s in known:
			if s != u["side"] and known[s].get(id, null) == tu[id]["pos"]:
				return tu[id]["pos"]
	return null


func snapshot() -> Dictionary:
	var out := {}
	for id in tu:
		if not eng.units.has(id):
			continue
		var t: Dictionary = tu[id]
		out[id] = [t["pos"], t["mode"], int(t["dis"]) >= 0, t["neut"], t["out"]]
	return out
