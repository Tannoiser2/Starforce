extends RefCounted
## Outleap (scenario 100, Moves): la campagna economica per anni (EcoYear).
## Ogni anno: diplomazia (dichiarazioni di guerra), entrate, spese, organizzazione delle flotte,
## alcuni turni stellari del gioco normale, consolidamento.
##
## sistemi[esagono] = {"owner": lato o -1, "pop": popolazione, "home": bool, "cls": "h"/"s"/"t",
##                     "ee": {lato: {"type": "VRM"/"RM"/"SV"/""/"X", "explored": bool}}, "ss": {lato: n}}
## lati[s] = {"mlc": cassa, "pop_prev": popolazione dell'anno prima, "pop_free": aumenti non spesi,
##            "inv": {"sf", "gate", "seed", "ee", "ss"} costruiti (le StarGate stanno sulla mappa),
##            "act": {...} attivi quest'anno, "income": ultimo reddito, "log": []}

const D = preload("res://scripts/data/sf_data.gd")

var eng
var year := 0
var years := 5
var sys := {}
var sd: Array = []
var wars := {}            # "a|b" -> true per l'anno in corso
var spent_pop := {}


func setup() -> void:
	years = int(eng.sc.get("anni", 5))
	for st in eng.star_list:
		var h := int(st[0])
		if sys.has(h):
			continue
		var cls: String = st[2]
		if not D.OL_MAX_POP.has(h):
			cls = "t"
		elif cls == "t":
			cls = "s"
		sys[h] = {"owner": -1, "pop": 0, "home": false, "cls": cls, "ee": {}, "ss": {}, "name": st[3]}
	for s in eng.sides.size():
		var home: int = int(eng.sc["lati"][s]["ol_casa"])
		var race: String = eng.sides[s]["razza"]
		var hv: Array = D.OL_HOME.get(race, D.OL_HOME["altri"])
		sys[home]["owner"] = s
		sys[home]["home"] = true
		sys[home]["pop"] = int(hv[0])
		sd.append({"mlc": 0, "pop_prev": 0, "pop_free": 0, "inv": {"sf": 0, "gate": 0, "seed": 0, "ee": 0, "ss": 0},
			"act": {"sf": 0, "seed": 0, "ee": 0, "ss": 0}, "income": 0, "home": home})


# ================================================================ consultazioni

func at_war(a: int, b: int) -> bool:
	return wars.has("%d|%d" % [mini(a, b), maxi(a, b)])


func pop_total(s: int) -> int:
	var t := 0
	for h in sys:
		if sys[h]["owner"] == s and sys[h]["cls"] != "t":
			t += int(sys[h]["pop"])
	return t


## reddito normale di un sistema abitato (senza crescita)
func sys_mlc(h: int) -> int:
	var x: Dictionary = sys[h]
	if x["home"]:
		var race: String = eng.sides[x["owner"]]["razza"]
		return int(D.OL_HOME.get(race, D.OL_HOME["altri"])[1])
	return int(D.OL_COL_MLC[clampi(int(x["pop"]), 0, 18)])


func colonies(s: int) -> Array:
	var out := []
	for h in sys:
		var x: Dictionary = sys[h]
		if x["owner"] == s and not x["home"] and x["cls"] != "t" and int(x["pop"]) > 0:
			out.append(h)
	out.sort()
	return out


func can_grow(h: int) -> bool:
	return int(sys[h]["pop"]) < int(D.OL_MAX_POP.get(h, 0))


## popolazione impegnata in TeleNavi e StarGate (106.2)
func pop_in_items(s: int) -> int:
	var gates := 0
	for g in eng.live(s, "gate"):
		gates += 1
	return int(sd[s]["inv"]["sf"]) * 4 + gates * 7


## sistemi dove si può costruire una StarGate: primari o secondari controllati, popolazione 3+, senza StarGate
func gate_sites(s: int) -> Array:
	var out := []
	for h in sys:
		var x: Dictionary = sys[h]
		if x["owner"] != s or x["cls"] == "t" or int(x["pop"]) < 3:
			continue
		var has := false
		for g in eng.live(-1, "gate"):
			if Hex.hexof(g["lz"]) == h:
				has = true
		if not has:
			out.append(h)
	out.sort()
	return out


## ricchezza (113.4): (2H + T) P / 10 S + C
func wealth(s: int) -> float:
	var hh := 0.0
	var tt := 0.0
	var n := 0
	for h in sys:
		var x: Dictionary = sys[h]
		if x["owner"] != s:
			continue
		n += 1
		if x["cls"] == "t":
			var e: Dictionary = x["ee"].get(s, {})
			tt += float(D.OL_AVG.get(e.get("type", ""), 0.0))
		elif int(x["pop"]) > 0:
			hh += float(sys_mlc(h))
	var p := float(pop_total(s))
	return (2.0 * hh + tt) * p / (10.0 * float(maxi(n, 1))) + float(sd[s]["mlc"])


func summary(s: int) -> String:
	return "anno %d/%d | popolazione %d | MLC %d | colonie %d | ricchezza %.0f" % [year, years, pop_total(s), int(sd[s]["mlc"]), colonies(s).size(), wealth(s)]


# ================================================================ fasi dell'anno

## guerre (109): ogni giocatore può dichiarare guerra a chi ha un sistema entro 20 Lite dai suoi
func war_targets(s: int) -> Array:
	var out := []
	for o in eng.sides.size():
		if o == s:
			continue
		var near := false
		for h in sys:
			if sys[h]["owner"] != s:
				continue
			for k in sys:
				if sys[k]["owner"] == o and Hex.tdist(eng.star_hex_lz(h), eng.star_hex_lz(k)) <= 20:
					near = true
					break
			if near:
				break
		if near:
			out.append(o)
	return out


func apply_diplomacy(decls: Dictionary) -> void:
	wars = {}
	for s in decls:
		for o in decls[s]:
			if int(o) in war_targets(int(s)):
				var key := "%d|%d" % [mini(int(s), int(o)), maxi(int(s), int(o))]
				if not wars.has(key):
					wars[key] = true
					eng.log_msg("%s dichiara guerra a %s." % [eng.sides[int(s)]["nome"], eng.sides[int(o)]["nome"]])
	if wars.is_empty():
		eng.log_msg("Nessuna guerra quest'anno.")


## entrate (104-105): `grow` = esagoni delle colonie da far crescere
func apply_income(s: int, grow: Array, first := false) -> void:
	var tot := 0
	for h in sys:
		var x: Dictionary = sys[h]
		if x["owner"] != s or x["cls"] == "t":
			continue
		if x["home"]:
			tot += sys_mlc(h)
			continue
		if int(x["pop"]) <= 0:
			continue
		if h in grow and can_grow(h) and not first:
			x["pop"] = int(x["pop"]) + 1
			tot += sys_mlc(h) / 2
		else:
			tot += sys_mlc(h)
	# sistemi terziari con un gruppo EE: prima l'esplorazione, poi il reddito
	for h in sys:
		var x: Dictionary = sys[h]
		if x["cls"] != "t" or not x["ee"].has(s):
			continue
		var e: Dictionary = x["ee"][s]
		var c: int = eng.d10()
		if not e.get("explored", false):
			e["explored"] = true
			e["type"] = D.OL_EXPLORE[c]
			if e["type"] == "X":
				x["ee"].erase(s)
				sd[s]["inv"]["ee"] = maxi(0, int(sd[s]["inv"]["ee"]) - 1)
				eng.log_msg("%s: l'esplorazione di %s è finita male, il gruppo EE è perduto." % [eng.sides[s]["nome"], x["name"]])
			else:
				eng.log_msg("%s ha esplorato %s." % [eng.sides[s]["nome"], x["name"]])
			continue
		if x["owner"] != s:
			continue
		var tp: String = e.get("type", "")
		var inc := 0
		if D.OL_INCOME.has(tp):
			inc = int(D.OL_INCOME[tp][c])
		if inc > 0:
			tot += inc
			eng.log_msg("%s: %s rende %d MLC (chit %d)." % [eng.sides[s]["nome"], x["name"], inc, c])
	if first:
		tot *= 2
	sd[s]["income"] = tot
	sd[s]["mlc"] = int(sd[s]["mlc"]) + tot
	var p := pop_total(s)
	if p > int(sd[s]["pop_prev"]):
		sd[s]["pop_free"] = int(sd[s]["pop_free"]) + p - int(sd[s]["pop_prev"])
	sd[s]["pop_prev"] = p
	eng.log_msg("%s: entrate %d MLC, popolazione %d." % [eng.sides[s]["nome"], tot, p])


## verifica e costo di un piano di spesa: {"keep": {k: n}, "build": {k: n}, "gates": [esagoni]}
func spend_check(s: int, plan: Dictionary) -> Dictionary:
	var res := {"ok": true, "err": "", "mlc": 0, "pop": 0}
	var keep: Dictionary = plan.get("keep", {})
	var build: Dictionary = plan.get("build", {})
	var cost := 0
	for k in ["sf", "seed", "ee", "ss"]:
		var n := clampi(int(keep.get(k, 0)), 0, int(sd[s]["inv"][k]))
		cost += n * int(D.OL_COST[k][2])
	# StarGate già costruite: mantenimento di tutte quelle sulla mappa che si vogliono attive
	cost += int(keep.get("gate", 0)) * int(D.OL_COST["gate"][2])
	var pop := 0
	for k in ["sf", "seed", "ee", "ss"]:
		var n2 := maxi(0, int(build.get(k, 0)))
		cost += n2 * int(D.OL_COST[k][1])
		pop += n2 * int(D.OL_COST[k][0])
	var gates: Array = plan.get("gates", [])
	var sites := gate_sites(s)
	for h in gates:
		if not int(h) in sites:
			return _bad(res, "una StarGate nuova va in un sistema tuo con almeno 3 di popolazione e senza StarGate")
	cost += gates.size() * int(D.OL_COST["gate"][1])
	pop += gates.size() * int(D.OL_COST["gate"][0])
	res["mlc"] = cost
	res["pop"] = pop
	if cost > int(sd[s]["mlc"]):
		return _bad(res, "servono %d MLC, ne hai %d" % [cost, int(sd[s]["mlc"])])
	if pop > int(sd[s]["pop_free"]):
		return _bad(res, "servono %d punti di popolazione nuova, ne hai %d" % [pop, int(sd[s]["pop_free"])])
	if pop > 0 and pop_in_items(s) + pop > pop_total(s):
		return _bad(res, "TeleNavi e StarGate supererebbero la popolazione (%d su %d)" % [pop_in_items(s) + pop, pop_total(s)])
	return res


func _bad(res: Dictionary, e: String) -> Dictionary:
	res["ok"] = false
	res["err"] = e
	return res


func apply_spend(s: int, plan: Dictionary) -> void:
	var c := spend_check(s, plan)
	if not c["ok"]:
		plan = {"keep": {}, "build": {}, "gates": []}
		c = spend_check(s, plan)
	var keep: Dictionary = plan.get("keep", {})
	var build: Dictionary = plan.get("build", {})
	sd[s]["mlc"] = int(sd[s]["mlc"]) - int(c["mlc"])
	sd[s]["pop_free"] = int(sd[s]["pop_free"]) - int(c["pop"])
	for k in ["sf", "seed", "ee", "ss"]:
		var n := clampi(int(keep.get(k, 0)), 0, int(sd[s]["inv"][k]))
		var b := maxi(0, int(build.get(k, 0)))
		sd[s]["inv"][k] = int(sd[s]["inv"][k]) + b
		sd[s]["act"][k] = n + b
	# StarGate: quelle non mantenute restano inattive per l'anno
	var kg := int(keep.get("gate", 0))
	var gs: Array = eng.live(s, "gate")
	for i in gs.size():
		gs[i]["unmaint"] = i >= kg
	for h in plan.get("gates", []):
		eng.add_unit(s, "gate", eng.star_hex_lz(int(h)))
		eng.log_msg("%s costruisce una StarGate a %s." % [eng.sides[s]["nome"], sys[int(h)]["name"]])
	var parts := []
	for k in ["sf", "seed", "ee", "ss"]:
		if int(sd[s]["act"][k]) > 0:
			parts.append("%d %s" % [int(sd[s]["act"][k]), D.OL_NOMI[k]])
	eng.log_msg("%s: spese %d MLC, in campo %s." % [eng.sides[s]["nome"], int(c["mlc"]), ", ".join(parts) if not parts.is_empty() else "niente"])


## dove possono partire le StarForce: sistemi primari o secondari controllati (107.4)
func deploy_sites(s: int) -> Array:
	var out := []
	for h in sys:
		var x: Dictionary = sys[h]
		if x["owner"] == s and x["cls"] != "t" and (x["home"] or int(x["pop"]) > 0):
			out.append(h)
	out.sort()
	return out


## organizzazione (107): carichi delle StarForce e schieramento.
## plan = {"carico": [{"k": "seed"/"ee"/"ss"/"", "n": quanti}, ...] uno per StarForce, "at": [esagono, ...]}
func apply_org(s: int, plan: Dictionary) -> void:
	var n := int(sd[s]["act"]["sf"])
	var cargo: Array = plan.get("carico", [])
	var at: Array = plan.get("at", [])
	var left := {"seed": int(sd[s]["act"]["seed"]), "ee": int(sd[s]["act"]["ee"]), "ss": int(sd[s]["act"]["ss"])}
	var sites := deploy_sites(s)
	var home: int = sd[s]["home"]
	var count := {}
	for i in n:
		var h: int = int(at[i]) if i < at.size() and int(at[i]) in sites else home
		# senza StarGate al massimo una forza per sistema (107.4)
		var has_gate := false
		for g in eng.live(s, "gate"):
			if Hex.hexof(g["lz"]) == h:
				has_gate = true
		if not has_gate and int(count.get(h, 0)) >= 1:
			h = home
		count[h] = int(count.get(h, 0)) + 1
		var u: Dictionary = eng.add_unit(s, "sf", eng.star_hex_lz(h))
		var c: Dictionary = cargo[i] if i < cargo.size() and cargo[i] is Dictionary else {}
		var k := str(c.get("k", ""))
		var q := int(c.get("n", 1))
		if k in ["seed", "ee"] and int(left[k]) > 0:
			left[k] = int(left[k]) - 1
			u["carico"] = {"k": k, "n": 1}
		elif k == "ss" and int(left["ss"]) > 0:
			q = clampi(q, 1, mini(6, int(left["ss"])))
			left["ss"] = int(left["ss"]) - q
			u["carico"] = {"k": "ss", "n": q}


## carico di una StarForce, in parole
static func cargo_text(u: Dictionary) -> String:
	var c: Dictionary = u.get("carico", {})
	match str(c.get("k", "")):
		"seed":
			return "colonia seme"
		"ee":
			return "gruppo EE"
		"ss":
			return "%d divisioni" % int(c.get("n", 1))
	return ""


## turni di sbarco necessari (108.2): due per colonie seme e gruppi EE, uno per le divisioni
func db_need(u: Dictionary) -> int:
	return 1 if str(u.get("carico", {}).get("k", "")) == "ss" else 2


## che cosa si può sbarcare qui: "" se niente
func db_ok(u: Dictionary, l: Vector3i) -> String:
	var c: Dictionary = u.get("carico", {})
	var k := str(c.get("k", ""))
	if k == "":
		return ""
	var st: Dictionary = eng.star_at(l)
	if st.is_empty():
		return ""
	var h := Hex.hexof(l)
	if not sys.has(h):
		return ""
	var x: Dictionary = sys[h]
	for e in eng.units_at(l):
		if eng.hostile(e["side"], u["side"]) and (e["kind"] == "sf" or eng.gate_active(e)):
			return ""
	match k:
		"seed":
			if x["cls"] != "t" and int(x["pop"]) == 0 and x["owner"] < 0:
				return "seed"
		"ee":
			if x["cls"] == "t" and not x["ee"].has(u["side"]):
				for o in x["ee"]:
					if eng.hostile(int(o), u["side"]):
						return ""
				for o in x["ss"]:
					if eng.hostile(int(o), u["side"]):
						return ""
				return "ee"
		"ss":
			var o: int = x["owner"]
			if o >= 0 and o != u["side"] and at_war(o, u["side"]) and not x["home"] and (x["cls"] == "t" or int(x["pop"]) > 0):
				return "ss"
	return ""


## fine di ogni turno stellare: avanzamento degli sbarchi
func after_turn() -> void:
	for u in eng.live(-1, "sf"):
		if not u.get("db", false):
			u["db_n"] = 0
			continue
		u.erase("db")
		var l: Vector3i = u["lz"]
		if u["start"] != l or eng.neutralized(u) or db_ok(u, l) == "":
			u["db_n"] = 0
			continue
		u["db_n"] = int(u.get("db_n", 0)) + 1
		if int(u["db_n"]) >= db_need(u):
			_debark(u, l)


func _debark(u: Dictionary, l: Vector3i) -> void:
	var s: int = u["side"]
	var h := Hex.hexof(l)
	var x: Dictionary = sys[h]
	var c: Dictionary = u["carico"]
	var who: String = eng.sides[s]["nome"]
	match str(c["k"]):
		"seed":
			x["pop"] = 1
			x["owner"] = s
			sd[s]["inv"]["seed"] = maxi(0, int(sd[s]["inv"]["seed"]) - 1)
			eng.log_msg("%s fonda una colonia a %s." % [who, x["name"]])
		"ee":
			x["ee"][s] = {"explored": false, "type": ""}
			if x["owner"] < 0:
				x["owner"] = s
			eng.log_msg("%s sbarca un gruppo EE a %s." % [who, x["name"]])
		"ss":
			var n := int(c["n"])
			var enemy := 0
			for o in x["ss"]:
				if eng.hostile(int(o), s):
					enemy += int(x["ss"][o])
			var need := int(x["pop"]) if enemy == 0 else enemy * 2
			sd[s]["inv"]["ss"] = maxi(0, int(sd[s]["inv"]["ss"]) - n)
			if x["cls"] == "t":
				# divisioni contro un gruppo EE nemico: lo distruggono e cadono con lui (108.5a)
				for o in x["ee"].keys():
					if eng.hostile(int(o), s):
						x["ee"].erase(o)
						sd[int(o)]["inv"]["ee"] = maxi(0, int(sd[int(o)]["inv"]["ee"]) - 1)
				eng.log_msg("%s sbarca divisioni a %s e distrugge il gruppo EE nemico." % [who, x["name"]])
			elif n >= need:
				for o in x["ss"].keys():
					if eng.hostile(int(o), s):
						x["ss"].erase(o)
				x["ss"][s] = int(x["ss"].get(s, 0)) + n
				var old: int = x["owner"]
				x["owner"] = s
				eng.log_msg("%s conquista %s con %d divisioni (era di %s)." % [who, x["name"], n, eng.sides[old]["nome"] if old >= 0 else "nessuno"])
			else:
				eng.log_msg("Lo sbarco di %s a %s fallisce: %d divisioni contro %d necessarie." % [who, x["name"], n, need])
	u.erase("carico")
	u["db_n"] = 0
	eng._rec({"k": "debark", "lz": l, "side": s})


## consolidamento (110): StarGate prese, neutralizzazioni tolte, flotte e divisioni ritirate
func consolidate() -> void:
	var takes := []
	for h in sys:
		var x: Dictionary = sys[h]
		x["ss"] = {}
		if x["owner"] < 0 or x["cls"] == "t":
			continue
		for id in eng.order:
			var g: Dictionary = eng.units[id]
			if g["kind"] != "gate" or Hex.hexof(g["lz"]) != h:
				continue
			if g["side"] != x["owner"] and g["st"] == "dead":
				g["st"] = "gone"
				takes.append([x["owner"], g["lz"], x["name"]])
	for t in takes:
		eng.add_unit(int(t[0]), "gate", t[1])
		eng.log_msg("%s prende la StarGate di %s." % [eng.sides[int(t[0])]["nome"], t[2]])
	for id in eng.order:
		var u: Dictionary = eng.units[id]
		u["neut"] = -1
		if u["kind"] == "gate" and u["st"] == "dead":
			# la neutralizzazione "permanente" si toglie a fine anno (110.2), se la StarGate è ancora del suo lato
			var h2 := Hex.hexof(u["lz"])
			if sys.has(h2) and sys[h2]["owner"] == u["side"]:
				u["st"] = "on"
		if u["kind"] == "sf" and u["st"] in ["on", "rand", "off"]:
			u["st"] = "gone"
	# le StarForce perse non si possono mantenere: l'inventario segue quelle sopravvissute
	for s in sd.size():
		var alive := 0.0
		for id in eng.order:
			var u2: Dictionary = eng.units[id]
			if u2["kind"] == "sf" and u2["side"] == s and u2["st"] == "gone" and not u2.get("counted", false):
				u2["counted"] = true
				alive += eng.weight(u2)
		var lost := maxi(0, int(sd[s]["act"]["sf"]) - int(floor(alive + 0.01)))
		sd[s]["inv"]["sf"] = maxi(0, int(sd[s]["inv"]["sf"]) - lost)
		# cariche non sbarcate tornano in magazzino (non si perdono)
	eng.sides_reset_letters()
	wars = {}
