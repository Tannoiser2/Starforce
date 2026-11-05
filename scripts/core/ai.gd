class_name SFAI
extends RefCounted
## Avversario automatico di StarForce. Usa solo ciò che il suo lato può sapere sullo Stellar Display
## (posizioni semi-nascoste: esagono delle StarForce nemiche, zulu solo se rivelata) e sceglie:
## - dove spostare le StarForce (difesa delle StarGate, gruppi d'attacco che si radunano accanto alla
##   StarGate nemica e poi entrano senza rischio, occupazione degli obiettivi);
## - come ripartire attacco e difesa nel combattimento base;
## - schieramento e piani dei Tac-turni nel combattimento avanzato.

const D = preload("res://scripts/data/sf_data.gd")

var level := 1
var memo := {}
## generatore casuale proprio: l'IA non deve consumare quello del motore, altrimenti online i
## dispositivi (e i salvataggi ricaricati) divergerebbero
var rng := RandomNumberGenerator.new()
var _seeded := false


func _init(lv := 1) -> void:
	level = lv


func decide(eng, s: int, req: Dictionary):
	if not _seeded:
		rng.seed = hash(str(eng.rng.seed) + "|" + str(s))
		_seeded = true
	match str(req.get("type", "")):
		"plot":
			return plot(eng, s, req)
		"alloc":
			return alloc(eng, s, req)
		"tdeploy":
			return tdeploy(eng, s, req)
		"tplot":
			return tplot(eng, s, req)
		"xsign":
			return 1 if rng.randi_range(0, 1) == 0 else -1
		"reserve":
			return reserve(eng, s, req)
		"eco_diplo":
			return eco_diplo(eng, s, req)
		"eco_income":
			return eco_income(eng, s, req)
		"eco_spend":
			return eco_spend(eng, s, req)
		"eco_org":
			return eco_org(eng, s, req)
	return {}


# ================================================================ Outleap: economia

func eco_diplo(eng, s: int, req: Dictionary) -> Array:
	var e = eng.eco
	var out := []
	for o in req.get("targets", []):
		var mine := int(e.sd[s]["inv"]["sf"])
		var theirs := int(e.sd[int(o)]["inv"]["sf"])
		if mine >= 3 and mine >= theirs * 3 / 2 + 1 and int(e.sd[s]["inv"]["ss"]) >= 2 and rng.randi_range(0, 2) > 0:
			out.append(int(o))
	return out


func eco_income(eng, s: int, req: Dictionary) -> Array:
	var e = eng.eco
	if e.year >= e.years:
		return []          # l'ultimo anno conta il reddito pieno
	var out := []
	for h in req.get("colonies", []):
		if e.can_grow(int(h)):
			out.append(int(h))
	return out


func eco_spend(eng, s: int, req: Dictionary) -> Dictionary:
	var e = eng.eco
	var inv: Dictionary = e.sd[s]["inv"]
	var plan := {"keep": {"sf": inv["sf"], "seed": inv["seed"], "ee": inv["ee"], "ss": inv["ss"], "gate": eng.live(s, "gate").size()}, "build": {"sf": 0, "seed": 0, "ee": 0, "ss": 0}, "gates": []}
	# se non basta l'MLC per mantenere tutto, si lasciano a riposo prima le divisioni, poi le flotte
	for k in ["ss", "seed", "ee", "sf", "gate"]:
		while not e.spend_check(s, plan)["ok"] and int(plan["keep"][k]) > 0:
			plan["keep"][k] = int(plan["keep"][k]) - 1
	# nuove StarGate dove si può (la casa per prima)
	for h in req.get("sites", []):
		plan["gates"].append(int(h))
		if not e.spend_check(s, plan)["ok"]:
			plan["gates"].pop_back()
	# colonie seme e gruppi EE secondo i sistemi liberi, poi StarForce, poi divisioni
	var free_hab := 0
	var free_t := 0
	for h in e.sys:
		var x: Dictionary = e.sys[h]
		if x["owner"] < 0 and x["cls"] != "t":
			free_hab += 1
		elif x["cls"] == "t" and not x["ee"].has(s):
			free_t += 1
	# a turno: una StarForce, una colonia seme, un gruppo EE... finché bastano MLC e popolazione;
	# le divisioni solo se si pensa alla guerra
	var wish := {"seed": maxi(0, mini(2, free_hab) - int(inv["seed"])), "ee": maxi(0, mini(3, free_t) - int(inv["ee"])), "sf": 8,
		"ss": (6 - int(inv["ss"])) if int(inv["sf"]) >= 3 else 0}
	var order := ["sf", "seed", "ee", "sf", "seed", "ee", "sf", "ss", "sf", "ss", "sf", "sf"]
	for k in order:
		if int(plan["build"][k]) >= int(wish[k]):
			continue
		plan["build"][k] = int(plan["build"][k]) + 1
		if not e.spend_check(s, plan)["ok"]:
			plan["build"][k] = int(plan["build"][k]) - 1
	return plan


func eco_org(eng, s: int, req: Dictionary) -> Dictionary:
	var n := int(req.get("n", 0))
	var cargo := []
	var left := {"seed": int(req.get("seed", 0)), "ee": int(req.get("ee", 0)), "ss": int(req.get("ss", 0))}
	for i in n:
		var c := {"k": "", "n": 0}
		for k in (["seed", "ee"] if i % 2 == 0 else ["ee", "seed"]):
			if int(left[k]) > 0 and c["k"] == "":
				c = {"k": k, "n": 1}
				left[k] = int(left[k]) - 1
		if c["k"] == "" and int(left["ss"]) > 0:
			var q := mini(6, int(left["ss"]))
			c = {"k": "ss", "n": q}
			left["ss"] = int(left["ss"]) - q
		cargo.append(c)
	var at := []
	var sites: Array = req.get("sites", [])
	var home: int = eng.eco.sd[s]["home"]
	for i in n:
		at.append(home)
	return {"carico": cargo, "at": at}


## piano stellare dell'Outleap: chi porta un carico va a sbarcarlo, gli altri fanno la guerra (se c'è)
## o scortano
func _eco_plot(eng, s: int) -> Dictionary:
	var e = eng.eco
	var plan := {}
	var carriers := []
	var others := []
	for u in eng.live(s, "sf"):
		if eng.neutralized(u):
			continue
		if str(u.get("carico", {}).get("k", "")) != "":
			carriers.append(u)
		else:
			others.append(u)
	var claimed := {}
	for u in carriers:
		if e.db_ok(u, u["lz"]) != "":
			plan[u["id"]] = {"c": "DB"}
			claimed[u["lz"]] = true
			continue
		var best = null
		var bd := 1e9
		for h in e.sys:
			var l: Vector3i = eng.star_hex_lz(int(h))
			if claimed.has(l) or e.db_ok(u, l) == "":
				continue
			if str(u["carico"]["k"]) == "ss" and int(e.sys[h]["pop"]) > int(u["carico"]["n"]):
				continue
			var d := float(Hex.tdist(u["lz"], l)) + rng.randf()
			if d < bd:
				bd = d
				best = l
		if best == null:
			continue
		claimed[best] = true
		plan[u["id"]] = {"c": "", "to": _toward(eng, s, u, best, plan, true)}
	if e.wars.is_empty() or others.is_empty():
		return plan
	# guerra: le altre StarForce usano il piano solito
	var war := plot_general(eng, s, others)
	for id in war:
		plan[id] = war[id]
	return plan


## destinazione delle riserve (32.0): la LiteZulu contesa raggiungibile senza rischi, preferendo
## quella dove il lato ha una StarGate da difendere o più unità impegnate
func reserve(eng, s: int, req: Dictionary) -> Dictionary:
	var out := {}
	var opts: Dictionary = req.get("opts", {})
	for id in opts:
		var u: Dictionary = eng.units[id]
		var best = null
		var bv := -1.0
		for l in opts[id]:
			var rc: Dictionary = eng.reserve_reach(u, l)
			if int(rc["col"]) > 0:
				continue
			var v := 1.0
			if not eng.gate_at(l, s).is_empty():
				v += 3.0
			for f in eng.units_at(l):
				if f["side"] == s:
					v += 0.5
			if v > bv:
				bv = v
				best = l
		if best != null:
			out[id] = best
	return out


# ================================================================ piano stellare

func plot(eng, s: int, req: Dictionary) -> Dictionary:
	if eng.scn_id == 38:
		return _rescue_plot(eng, s)
	if eng.scn_id == 16:
		return _faker_plot(eng, s)
	if eng.eco != null:
		return _eco_plot(eng, s)
	return plot_general(eng, s, [])


func plot_general(eng, s: int, only: Array) -> Dictionary:
	var mine: Array = []
	for u in eng.live(s, "sf"):
		if not eng.neutralized(u) and (only.is_empty() or u in only):
			mine.append(u)
	if mine.is_empty():
		return {}
	var plan := {}
	var targets := _targets(eng, s)
	var my_gates: Array = eng.live(s, "gate")
	# minacce: StarForce nemiche vicine alle nostre StarGate (stima per esagono)
	var threat := {}
	for g in my_gates:
		var n := 0
		for e in eng.live(-1, "sf"):
			if not eng.hostile(e["side"], s):
				continue
			var vis: String = eng.visibility(e, s)
			if vis == "none":
				continue
			if Hex.pdist(Hex.hexof(e["lz"]), Hex.hexof(g["lz"])) <= 8:
				n += 1
		threat[g["id"]] = n
	# difensori: una StarForce resta sulle StarGate più importanti se minacciate
	var free: Array = mine.duplicate()
	var homes: Array = eng.sides[s]["casa"]
	var need_def := 0
	for g in my_gates:
		var important: bool = Hex.hexof(g["lz"]) in homes or _vital(eng, s, g)
		if int(threat.get(g["id"], 0)) > 0 and important:
			need_def += 1
			for u in free:
				if u["lz"] == g["lz"]:
					plan[u["id"]] = {"c": "", "to": u["lz"]}
					free.erase(u)
					break
	if targets.is_empty() or free.is_empty():
		return plan
	# obiettivo principale: il più vicino al centro delle forze libere, con un po' di caso
	var best = null
	var bscore := -1e9
	var cen := _centroid(free)
	for t in targets:
		var lz: Vector3i = t["lz"]
		var d := Hex.tdist(cen, lz)
		var sc: float = float(t["w"]) * 10.0 - float(d) + rng.randf() * 3.0
		var guard := 0
		for e in eng.live(-1, "sf"):
			if eng.hostile(e["side"], s) and eng.visibility(e, s) != "none" and Hex.hexof(e["lz"]) == Hex.hexof(lz):
				guard += 1
		sc -= guard * 3.0
		# fedeltà all'obiettivo scelto nei turni precedenti: senza, con molti bersagli simili le forze
		# cambierebbero idea a ogni turno e non si radunerebbero mai
		if memo.get("tgt", null) == lz:
			sc += 8.0
		if sc > bscore:
			bscore = sc
			best = t
	var tlz: Vector3i = best["lz"]
	memo["tgt"] = tlz
	var occupy: bool = best.get("occ", false)
	# punto di raccolta accanto all'obiettivo: si entra solo da adiacenti (senza i +4 della StarGate)
	var stage := _stage_point(eng, s, tlz, cen)
	var at_stage := []
	for u in free:
		if u["lz"] == stage or Hex.is_adjacent(u["start"], tlz):
			at_stage.append(u)
	var guarded := false
	for e in eng.live(-1, "sf"):
		if eng.hostile(e["side"], s) and eng.visibility(e, s) != "none" and Hex.hexof(e["lz"]) == Hex.hexof(tlz):
			guarded = true
	var go := at_stage.size() >= 3 or (at_stage.size() >= 2 and at_stage.size() >= free.size()) or (not guarded and at_stage.size() >= free.size() and at_stage.size() > 0) or occupy
	if eng.xeno > 0 and s == eng.xeno_side:
		go = at_stage.size() >= 2
	for u in free:
		if plan.has(u["id"]):
			continue
		var dest: Vector3i
		if (go and (u["lz"] == stage or Hex.is_adjacent(u["start"], tlz))) or u["lz"] == tlz:
			dest = tlz
		else:
			dest = _toward(eng, s, u, stage, plan)
		plan[u["id"]] = {"c": "", "to": dest}
	# controlla la sicurezza: chi rischierebbe troppo resta fermo o si avvicina di meno
	var rp: Dictionary = eng.resolve_plot(s, plan)
	var max_col := 1 if level >= 1 else 2
	if eng.xeno > 0 and s == eng.xeno_side:
		max_col = 2
	for id in rp:
		var r: Dictionary = rp[id]
		if int(r.get("col", 0)) > max_col:
			var u: Dictionary = eng.units[id]
			plan[id] = {"c": "", "to": _toward(eng, s, u, plan[id]["to"], plan, true)}
	# FakerForce (33.0): ogni tanto una StarForce ferma si divide per confondere il nemico
	if eng.faker_left(s) > 0:
		for u in mine:
			var p0: Dictionary = plan.get(u["id"], {})
			var stay0: bool = not p0.has("to") or p0["to"] == u["lz"]
			if stay0 and str(p0.get("c", "")) == "" and not u.get("ff", false) and rng.randi_range(0, 3) == 0:
				plan[u["id"]] = {"c": "F"}
				break
	# riserve (32.0): una StarForce che resterebbe ferma su una propria StarGate resta in riserva
	var nres: int = eng.reserve_max(s)
	if nres > 0:
		for u in mine:
			if nres <= 0:
				break
			var p: Dictionary = plan.get(u["id"], {})
			var stay: bool = not p.has("to") or p["to"] == u["lz"]
			if stay and str(p.get("c", "")) == "" and not u.get("ff", false) and int(u.get("res_lock", -1)) != eng.turn \
					and not eng.gate_at(u["lz"], s).is_empty() and rng.randi_range(0, 2) == 0:
				plan[u["id"]] = {"c": "Rs"}
				nres -= 1
	return plan


func _vital(eng, s: int, g: Dictionary) -> bool:
	var vc: String = eng.sc["vc"]
	var h := Hex.hexof(g["lz"])
	if vc in ["s3"] and h in [2020, 1821]:
		return true
	if vc in ["s8"] and h in [2020, 2326]:
		return true
	if vc in ["s10"] and h in [2020, 2326, 2036]:
		return true
	return false


func _centroid(us: Array) -> Vector3i:
	var best: Vector3i = us[0]["lz"]
	var bd := 1e9
	for a in us:
		var t := 0
		for b in us:
			t += Hex.tdist(a["lz"], b["lz"])
		if t < bd:
			bd = t
			best = a["lz"]
	return best


## obiettivi: StarGate nemiche (peso secondo le condizioni di vittoria) e LiteZulu da occupare
func _targets(eng, s: int) -> Array:
	var out := []
	var vc: String = eng.sc["vc"]
	for g in eng.live(-1, "gate"):
		if not eng.hostile(g["side"], s) or eng.visibility(g, s) == "none":
			continue
		var w := 1.0
		var h := Hex.hexof(g["lz"])
		if h in eng.sides[g["side"]]["casa"]:
			w = 1.6
		if vc == "s3" and s == 1 and h in [2020, 1821]:
			w = 2.0
		if vc == "s7" and s == 0 and h == 2523:
			w = 2.0
		if vc == "s10" and s == 1 and h in [2326, 2036]:
			w = 1.8
		out.append({"lz": g["lz"], "w": w})
	var obj = str(eng.sc.get("obiettivo", ""))
	if obj != "" and vc in ["s2", "s3", "s12"]:
		out.append({"lz": eng.star_hex_lz(int(obj)), "w": 2.2, "occ": true})
	if eng.xeno > 0 and s != eng.xeno_side and out.is_empty():
		# la Lega cerca le StarGate xenofobe ai margini del Volume
		var k: int = memo.get("search", rng.randi_range(0, 1000))
		memo["search"] = k
		var hexes: Array = Hex.all_hexes()
		var h2: int = hexes[k % hexes.size()]
		var sign := 1 if (k / 7) % 2 == 0 else -1
		out.append({"lz": Hex.lz(h2, sign * (Hex.zlimit(h2) + 2)), "w": 0.5})
		if eng.turn % 6 == 0:
			memo["search"] = rng.randi_range(0, 1000)
	return out


func _stage_point(eng, s: int, tlz: Vector3i, cen: Vector3i) -> Vector3i:
	var best := tlz
	var bd := 1e9
	for a in Hex.adjacent_lz(tlz):
		if not eng.valid_lz(a) or not eng.star_at(a).is_empty():
			continue
		var enemy := false
		for e in eng.units_at(a):
			if eng.hostile(e["side"], s):
				enemy = true
		if enemy:
			continue
		var d = float(Hex.tdist(cen, a)) + rng.randf() * 0.5
		if d < bd:
			bd = d
			best = a
	return best


## punto verso `target` raggiungibile senza oltre-spostamento: prova prima con le proprie StarGate
## (GS/GGS), poi uno spostamento normale di cinque Lite lungo la linea
func _toward(eng, s: int, u: Dictionary, target: Vector3i, plan: Dictionary, cautious := false) -> Vector3i:
	var from: Vector3i = u["lz"]
	if from == target:
		return from
	var dist := Hex.tdist(from, target)
	var trial := plan.duplicate(true)
	# 1. StarGate amica di destinazione più vicina all'obiettivo e raggiungibile (GGS dalla nostra porta)
	var best := from
	var bscore := float(dist)
	var cands := []
	for g in eng.live(s, "gate"):
		if eng.gate_active(g) and g["race"] == u["race"]:
			cands.append(g["lz"])
	# 2. punti lungo la linea a distanze crescenti
	var ah := Hex.world(from)
	var bh := Hex.world(target)
	for k in range(1, 21):
		var t := float(k) / float(maxi(dist, 1))
		if t > 1.0:
			break
		var p := ah.lerp(bh, t)
		var l := _nearest_lz(eng, p)
		if l != from and eng.valid_lz(l) and not l in cands:
			cands.append(l)
	for c in cands:
		var d2 := float(Hex.tdist(c, target))
		if d2 >= bscore:
			continue
		trial[u["id"]] = {"c": "", "to": c}
		var rp: Dictionary = eng.resolve_plot(s, trial)
		var r: Dictionary = rp.get(u["id"], {})
		if r.is_empty() or r.get("to") != c:
			continue
		var col := int(r.get("col", 9))
		var limit := 0
		if eng.xeno > 0 and s == eng.xeno_side and not cautious:
			limit = 2
		if col > limit:
			continue
		# evita di finire da soli in una LiteZulu nemica
		var enemy := false
		for e in eng.units_at(c):
			if eng.hostile(e["side"], s) and c != target:
				enemy = true
		if enemy:
			continue
		bscore = d2
		best = c
	return best


func _nearest_lz(eng, p: Vector3) -> Vector3i:
	var best := Vector3i(20, 20, 0)
	var bd := 1e9
	# ricerca locale sugli esagoni vicini al punto
	var r0 := int(round(20.0 - p.z / 0.8660254))
	for r in range(r0 - 1, r0 + 2):
		for c in range(1, 40):
			var h := Hex.code(r, c)
			if not Hex.on_map(h):
				continue
			var w := Hex.world_hex(h)
			var dd := (w.x - p.x) * (w.x - p.x) + (w.y - p.z) * (w.y - p.z)
			if dd < bd:
				bd = dd
				best = Hex.lz(h, int(round(p.y)))
	var lim := Hex.zlimit(Hex.hexof(best))
	if eng.xeno == 0 and not eng.extended:
		best.z = clampi(best.z, -lim, lim)
	return best


## scenario 16: ogni FakerForce va a tenere un sistema terziario diverso (il più vicino libero),
## le restanti puntano a Wandering's End
func _faker_plot(eng, s: int) -> Dictionary:
	var plan := {}
	var mine: Array = []
	for u in eng.live(s, "sf"):
		if not eng.neutralized(u):
			mine.append(u)
	var targets := []
	for l in eng.star_lz:
		if eng.star_lz[l]["cls"] != "t" or eng.destroyed_stars.has(l):
			continue
		var enemy := false
		for e in eng.units_at(l):
			if e["side"] != s and e["kind"] == "sf" and eng.visibility(e, s) != "none":
				enemy = true
		if not enemy:
			targets.append(l)
	var taken := {}
	# chi è già su un obiettivo resta
	for u in mine:
		if u["lz"] in targets and not taken.has(u["lz"]):
			taken[u["lz"]] = true
			plan[u["id"]] = {"c": "", "to": u["lz"]}
	var we: Vector3i = eng.star_hex_lz(2223)
	for u in mine:
		if plan.has(u["id"]):
			continue
		var best = null
		var bd := 1e9
		for l in targets:
			if taken.has(l):
				continue
			var d := float(Hex.tdist(u["lz"], l)) + rng.randf() * 2.0
			if d < bd:
				bd = d
				best = l
		if best == null or taken.size() >= 9:
			best = we
		else:
			taken[best] = true
		plan[u["id"]] = {"c": "", "to": _toward(eng, s, u, best, plan, true)}
	return plan


func _rescue_plot(eng, s: int) -> Dictionary:
	var plan := {}
	var tl: Vector3i = eng.rescue["lz"]
	var used := {}
	for u in eng.live(s, "sf"):
		if eng.neutralized(u):
			continue
		var load := int(u.get("load", 0))
		if load == 0 and int(eng.rescue["pop"]) > 0:
			if u["lz"] == tl:
				plan[u["id"]] = {"c": "L", "to": tl}
			else:
				plan[u["id"]] = {"c": "", "to": _toward(eng, s, u, tl, plan)}
				if Hex.tdist(u["lz"], tl) <= 10 and eng.gate_at(u["lz"], s).size() > 0:
					plan[u["id"]] = {"c": "", "to": tl}
		elif load > 0:
			if u["lz"] != tl and not eng.star_at(u["lz"]).is_empty() and not eng.gate_at(u["lz"], s).is_empty():
				plan[u["id"]] = {"c": "L", "to": u["lz"]}
			else:
				# StarGate più vicina (non quella in pericolo)
				var best := tl
				var bd := 999
				for g in eng.live(s, "gate"):
					var d := Hex.tdist(u["lz"], g["lz"])
					if d < bd and g["lz"] != tl:
						bd = d
						best = g["lz"]
				plan[u["id"]] = {"c": "", "to": best if bd <= 10 else _toward(eng, s, u, best, plan)}
	return plan


# ================================================================ combattimento base

## media delle perdite inflitte per differenziale (colonne -3..+6)
static func exp_loss(diff: int) -> float:
	if diff < -3:
		return 0.0
	var c := clampi(diff, -3, 6) + 3
	var t := 0.0
	for r in 10:
		t += float(D.SCRT[r][c])
	return t / 10.0


func alloc(eng, s: int, req: Dictionary) -> Dictionary:
	var pool: int = req["pool"]
	var pools: Dictionary = req.get("pools", {})
	var l: Vector3i = req["lz"]
	var enemies := []
	var epool := 0
	for k in pools:
		if eng.hostile(int(k), s) and int(pools[k]) > 0:
			enemies.append(int(k))
			epool += int(pools[k])
	var out := {"att": {}, "def": pool, "brk": {}, "refuse": false}
	if enemies.is_empty() or pool <= 0:
		return out
	var my_gate = not eng.gate_at(l, s).is_empty()
	if req.get("first", false) and req.get("can_refuse", false):
		# meglio aspettare il secondo segmento con la StarGate in campo
		if my_gate or pool < epool:
			out["refuse"] = true
			return out
	# ritirata se senza speranza
	if not req.get("first", false) and not my_gate and epool >= pool * 2 + 3 and pool > 0:
		for u in eng.units_at(l):
			if u["side"] == s and u["kind"] == "sf":
				var opts: Array = eng.breakoff_options(u)
				if not opts.is_empty():
					out["brk"][u["id"]] = opts[0]
		return {"att": {}, "def": pool, "brk": out["brk"]}
	var target: int = enemies[0]
	var tpool: int = pools[target]
	var e_att := tpool / 2
	var e_def := tpool - e_att
	var best_a := 0
	var best := -1e9
	for a in range(0, pool + 1):
		var dfn := pool - a
		var gain := exp_loss(a - e_def) if a > 0 else 0.0
		var risk := exp_loss(e_att - dfn)
		var v := gain * (1.2 if level > 0 else 1.0) - risk * (1.4 if my_gate else 1.0)
		if v > best:
			best = v
			best_a = a
	if best_a > 0:
		out["att"][target] = best_a
	out["def"] = pool - best_a
	# Xenofobi: innesco della nova se la StarGate della Lega è caduta
	if eng.xeno > 0 and s == eng.xeno_side and eng.gate_at(l, 1 - s).is_empty() and not eng.star_at(l).is_empty():
		for u in eng.units_at(l):
			if u["side"] == s and u["kind"] == "sf":
				out["nova"] = u["id"]
				break
	return out


# ================================================================ combattimento avanzato

func tdeploy(eng, s: int, req: Dictionary) -> Dictionary:
	var out := {}
	var t = eng.tac
	var groups := {}
	var spot := {}
	for id in req["ids"]:
		var u: Dictionary = eng.units[id]
		if u["start"] == t.l and not u.get("entered", false):
			# difensori: vicino alla StarGate, in modo battaglia
			var p := Vector3i(0, 0, 0)
			if not eng.gate_at(t.l, s).is_empty():
				var dirs := Hex.DIRS
				var k := out.size()
				p = Vector3i(dirs[k % 6].x, dirs[k % 6].y, (k / 6) - 1)
			out[id] = [p, true]
		else:
			var key := str(u["start"])
			if not groups.has(key):
				var ring := []
				for a in Hex.t_all():
					if Hex.adist(a, Vector2i.ZERO) == 5:
						ring.append(a)
				var a0: Vector2i = ring[rng.randi_range(0, ring.size() - 1)]
				groups[key] = Vector3i(a0.x, a0.y, rng.randi_range(-2, 2))
			out[id] = [groups[key], false]
	return out


func _enemy_positions(eng, s: int) -> Array:
	var t = eng.tac
	var out := []
	for u in t.units():
		if not eng.hostile(u["side"], s):
			continue
		if u["kind"] == "gate" and t.tu[u["id"]]["neut"]:
			continue
		var p = t.known_pos(u, s)
		if p == null:
			var real: Vector3i = t.tu[u["id"]]["pos"]
			p = Vector3i(real.x, real.y, 0)
		out.append([u, p])
	return out


## scenario 20: il trasporto tenta la ritirata dal Tactical Display (in modo stellare, seconda fase)
## con chit 0-1, dal secondo Tac-turno; altrimenti resta fermo con tutta l'anti-proiezione
func _flee_plan(eng, t, u: Dictionary) -> Dictionary:
	var id: String = u["id"]
	var none := {"a1": {"k": ""}, "a2": {"k": ""}}
	if t.tt < 2 or rng.randi_range(0, 9) > 1:
		return none
	var opts: Array = eng.breakoff_options(u)
	if opts.is_empty():
		return none
	var p := {"a1": {"k": "M"} if t.tu[id]["mode"] == "battle" else {"k": ""}, "a2": {"k": "B", "to": opts[0]}}
	return p if t.check_sf(id, p)["ok"] else none


## migliore direzione di proiezione da `from` con `pts` punti: [ora, verso, valore]
func best_cast(from: Vector3i, enemies: Array, pts: int) -> Array:
	var best := [3, 1, 0]
	for cl in Hex.CLOCKS:
		for zs in [1, -1]:
			var vol: Dictionary = Hex.cast_volume(from, cl, zs)
			var v := 0
			for e in enemies:
				var p: Vector3i = e[1]
				if vol.has(p):
					var w = 2 if e[0]["kind"] == "gate" else 1
					v += (pts >> int(vol[p])) * w
			if v > int(best[2]):
				best = [cl, zs, v]
	return best


func tplot(eng, s: int, req: Dictionary) -> Dictionary:
	var t = eng.tac
	var out := {}
	var enemies := _enemy_positions(eng, s)
	var mine := []
	for u in t.units():
		if u["side"] == s:
			mine.append(u)
	var my_n := 0
	for u in mine:
		if u["kind"] == "sf":
			my_n += 1
	var en_n := 0
	for e in enemies:
		if e[0]["kind"] == "sf":
			en_n += 1
		else:
			en_n += 2
	for u in mine:
		var id: String = u["id"]
		var pos: Vector3i = t.tu[id]["pos"]
		if u["kind"] == "gate":
			var tv: int = t.televalue(id)
			var p := {"c1": [], "c2": []}
			if tv >= 4:
				var pts := 32 if tv >= 64 else tv / 2
				if pts >= 2:
					var bc := best_cast(pos, enemies, pts)
					if int(bc[2]) > 0:
						p["c1"] = [{"p": pts, "cl": bc[0], "zs": bc[1]}]
						p["c2"] = [{"p": pts, "cl": bc[0], "zs": bc[1]}]
			out[id] = p
			continue
		var mode: String = t.tu[id]["mode"]
		var dis: bool = t.is_disrupted(id)
		var tv: int = t.televalue(id)
		# scenario 20: il trasporto xenofobo fugge verso il bordo, ma esita secondo un chit
		if id == t.transport:
			out[id] = _flee_plan(eng, t, u)
			continue
		# nova (31.52): con la StarGate a terra, la StarForce più vicina va alla stella e pianta l'innesco
		if t.can_trigger(s) and t.gate_down(s) and t.star and not dis:
			var sp := Vector3i(0, 0, -1)
			var closest := id
			var cd := 99
			for f in mine:
				if f["kind"] == "sf" and not t.is_disrupted(f["id"]):
					var dd := Hex.ttrue(t.tu[f["id"]]["pos"], sp)
					if dd < cd:
						cd = dd
						closest = f["id"]
			if closest == id:
				var np := {"a1": {"k": ""}, "a2": {"k": ""}}
				var dsp := Hex.ttrue(pos, sp)
				if pos == sp and mode == "stellar":
					np = {"a1": {"k": "N"}, "a2": {"k": ""}}
				elif mode == "battle":
					np = {"a1": {"k": "M"}, "a2": {"k": ""}}
					if dsp == 1:
						np["a2"] = {"k": "T", "to": sp}
				elif dsp == 1:
					np = {"a1": {"k": "T", "to": sp}, "a2": {"k": ""}}
				else:
					var step := pos
					for k in 10:
						var nx := _tstep(step, sp, t)
						if Hex.ttrue(nx, sp) < 1 or t.tac_cost(mode, Hex.ttrue(pos, nx), u.get("ff", false)) > tv:
							break
						step = nx
					np = {"a1": {"k": "T", "to": step}, "a2": {"k": ""}}
				if t.check_sf(id, np)["ok"]:
					out[id] = np
					continue
		# bersaglio: la StarGate nemica se c'è, altrimenti la StarForce nemica più vicina
		var tgt = null
		var near := 99
		for e in enemies:
			var d := Hex.ttrue(pos, e[1])
			if e[0]["kind"] == "gate":
				d -= 20
			if d < near:
				near = d
				tgt = e[1]
		var plan := {"a1": {"k": ""}, "a2": {"k": ""}}
		# ritirata se sopraffatti
		if (dis and en_n > my_n * 2) or (en_n >= my_n * 3 and eng.gate_at(t.l, s).is_empty()):
			var opts: Array = eng.breakoff_options(u)
			if not opts.is_empty():
				plan = {"a1": {"k": "M"} if mode == "battle" else {"k": ""}, "a2": {"k": "B", "to": opts[0]}}
				if t.check_sf(id, plan)["ok"]:
					out[id] = plan
					continue
		if tgt != null:
			var dist := Hex.ttrue(pos, tgt)
			var defender: bool = u["start"] == t.l and not u.get("entered", false)
			if dist == 0 or (dist <= 1 and mode == "battle") or (defender and dist <= 2):
				# a contatto: modo battaglia e proiezioni piene
				if mode == "stellar":
					if dis:
						var b0 := best_cast(pos, enemies, 16)
						plan = {"a1": {"k": "C", "p": 16, "cl": b0[0], "zs": b0[1]}, "a2": {"k": ""}}
					else:
						var b1 := best_cast(pos, enemies, 32)
						plan = {"a1": {"k": "M"}, "a2": {"k": "C", "p": 16 if defender else 32, "cl": b1[0], "zs": b1[1]}}
				else:
					var pts := 32 if tv >= 64 else 16
					var b2 := best_cast(pos, enemies, pts)
					plan = {"a1": {"k": "C", "p": pts, "cl": b2[0], "zs": b2[1]}, "a2": {"k": ""}}
					if not defender and tv >= 64 and level > 1:
						plan["a2"] = {"k": "C", "p": 16, "cl": b2[0], "zs": b2[1]}
			elif defender:
				# chi difende aspetta con la piena anti-proiezione, o colpisce chi è a tiro
				var b3 := best_cast(pos, enemies, 32 if tv >= 64 else 16)
				if int(b3[2]) >= 4 and mode == "battle":
					plan = {"a1": {"k": "C", "p": 32 if tv >= 64 else 16, "cl": b3[0], "zs": b3[1]}, "a2": {"k": ""}}
				elif mode == "stellar" and not dis:
					plan = {"a1": {"k": "M"}, "a2": {"k": ""}}
			elif mode == "stellar" and not dis:
				# prima si passa in modo battaglia, fuori dalla portata piena delle proiezioni
				plan = {"a1": {"k": "M"}, "a2": {"k": ""}}
			else:
				# avvicinamento in modo battaglia mantenendo almeno 16 punti di anti-proiezione
				var dest2 := pos
				var friends := 0
				for f in mine:
					if f["kind"] == "sf" and Hex.ttrue(t.tu[f["id"]]["pos"], tgt) <= 2:
						friends += 1
				if dist == 2 and mode == "battle" and tv >= 64 and friends >= 5:
					var b4 := best_cast(pos, enemies, 32)
					plan = {"a1": {"k": "C", "p": 32, "cl": b4[0], "zs": b4[1]}, "a2": {"k": ""}}
				else:
					var step := _tstep(pos, tgt, t)
					var step2 := _tstep(step, tgt, t)
					if Hex.ttrue(step, tgt) >= 2:
						dest2 = step
					if Hex.ttrue(step2, tgt) >= 2 and t.tac_cost(mode, Hex.ttrue(pos, step2)) <= tv - 16:
						dest2 = step2
					if dist <= 2 and dest2 == pos:
						dest2 = step
				if t.tac_cost(mode, Hex.ttrue(pos, dest2)) > tv:
					dest2 = pos
				if dest2 != pos:
					plan = {"a1": {"k": "T", "to": dest2}, "a2": {"k": ""}}
		# adatta i punti delle proiezioni ai TelePunti (FakerForce, disgregate, equipaggi affaticati)
		var tries := 0
		while not t.check_sf(id, plan)["ok"] and tries < 6:
			tries += 1
			var changed := false
			for ph in ["a1", "a2"]:
				var a: Dictionary = plan[ph]
				if str(a.get("k", "")) == "C" and int(a.get("p", 0)) > 2:
					a["p"] = int(a["p"]) / 2
					changed = true
			if not changed:
				break
		if not t.check_sf(id, plan)["ok"]:
			plan = {"a1": {"k": ""}, "a2": {"k": ""}}
		out[id] = plan
	return out


func _tstep(from: Vector3i, to: Vector3i, t) -> Vector3i:
	var best := from
	var bd := Hex.ttrue(from, to)
	for d in Hex.DIRS:
		for dz in [-1, 0, 1]:
			var p := Vector3i(from.x + d.x, from.y + d.y, from.z + dz)
			if not Hex.tvalid(p) or Hex.ttrue(from, p) > 1:
				continue
			if not t._star_ok(from, p, 1):
				continue
			var dd := Hex.ttrue(p, to)
			if dd < bd:
				bd = dd
				best = p
	return best
