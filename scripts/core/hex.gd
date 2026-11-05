class_name Hex
extends RefCounted
## Geometria dello Stellar Display e del Tactical Display.
##
## Stellar Display: esagoni a punta in alto numerati XXYY (XX = riga, YY = colonna), le righe dispari
## sono spostate di mezzo esagono verso sinistra (Sol = 2020 al centro). Una LiteZulu è Vector3i(riga,
## colonna, zulu). Distanze vere in Lite: radice di (distanza planare al quadrato + differenza zulu al quadrato), arrotondata
## come la True Distance Table.
##
## Tactical Display: esagoni a lato piatto in coordinate assiali Vector2i(q, r), raggio 5, MiniZulu +/-5.
## Una MiniLiteZulu è Vector3i(q, r, z). Le direzioni dell'orologio delle proiezioni sono 1, 3, 5, 7, 9, 11.

const D = preload("res://scripts/data/sf_data.gd")

# ---------------------------------------------------------------- Stellar Display

static func code(r: int, c: int) -> int:
	return r * 100 + c


static func row(h: int) -> int:
	return h / 100


static func col(h: int) -> int:
	return h % 100


## coordinate cubiche (q, r) per la numerazione "righe pari spostate a destra"
static func axial(h: int) -> Vector2i:
	var r := row(h)
	var c := col(h)
	return Vector2i(c - (r + (r & 1)) / 2, r)


static func from_axial(a: Vector2i) -> int:
	var r := a.y
	var c := a.x + (r + (r & 1)) / 2
	return code(r, c)


static func adist(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return (absi(dq) + absi(dr) + absi(dq + dr)) / 2


static func pdist(a: int, b: int) -> int:
	return adist(axial(a), axial(b))


const SOL := 2020

static func on_map(h: int) -> bool:
	var r := row(h)
	var c := col(h)
	if r < 1 or r > 39 or c < 1 or c > 39:
		return false
	return pdist(h, SOL) <= D.MAP_RADIUS


static func zlimit(h: int) -> int:
	var d := pdist(h, SOL)
	for ring in D.ZULU_RINGS:
		if d <= int(ring[0]):
			return int(ring[1])
	return 0


static func valid(lz: Vector3i) -> bool:
	var h := code(lz.x, lz.y)
	return on_map(h) and absi(lz.z) <= zlimit(h)


static func lz(h: int, z: int) -> Vector3i:
	return Vector3i(row(h), col(h), z)


static func hexof(l: Vector3i) -> int:
	return code(l.x, l.y)


## distanza vera arrotondata (la tabella arrotonda al Lite più vicino)
static func tdist2(pd: int, zd: int) -> int:
	return int(floor(sqrt(float(pd * pd + zd * zd)) + 0.5))


static func tdist(a: Vector3i, b: Vector3i) -> int:
	return tdist2(pdist(hexof(a), hexof(b)), absi(a.z - b.z))


## le 20 LiteZulu adiacenti (stesso esagono sopra/sotto, sei esagoni vicini a zulu -1, 0, +1)
const DIRS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]

static func neighbors(h: int) -> Array:
	var a := axial(h)
	var out := []
	for d in DIRS:
		out.append(from_axial(a + d))
	return out


static func adjacent_lz(l: Vector3i) -> Array:
	var out := []
	var h := hexof(l)
	for dz in [-1, 1]:
		var p := Vector3i(l.x, l.y, l.z + dz)
		if valid(p):
			out.append(p)
	for n in neighbors(h):
		for dz in [-1, 0, 1]:
			var p := lz(n, l.z + dz)
			if valid(p):
				out.append(p)
	return out


static func is_adjacent(a: Vector3i, b: Vector3i) -> bool:
	if a == b:
		return false
	var pd := pdist(hexof(a), hexof(b))
	var zd := absi(a.z - b.z)
	return (pd == 0 and zd == 1) or (pd == 1 and zd <= 1)


static func fmt(l: Vector3i) -> String:
	var z := l.z
	var zs := "0" if z == 0 else ("+%d" % z if z > 0 else "-%d" % (-z))
	return "%02d%02d/%s" % [l.x, l.y, zs]


static func hfmt(h: int) -> String:
	return "%04d" % h


static func parse(s: String) -> Vector3i:
	var parts := s.split("/")
	var h := int(parts[0])
	var z := 0
	if parts.size() > 1:
		z = int(parts[1].replace("+", ""))
	return lz(h, z)


## Mirror shift [7.54]: stessa distanza nella direzione opposta, zulu invertito; riportato dentro la mappa
static func mirror(origin: Vector3i, dest: Vector3i) -> Vector3i:
	var ao := axial(hexof(origin))
	var ad := axial(hexof(dest))
	var am := ao - (ad - ao)
	var zm := origin.z - (dest.z - origin.z)
	return clamp_line(origin, from_axial(am), zm)


## porta dentro la mappa una posizione fuori, tornando indietro lungo la linea dall'origine
static func clamp_line(origin: Vector3i, h: int, z: int) -> Vector3i:
	var ao := axial(hexof(origin))
	var at := axial(h)
	var n := adist(ao, at)
	var best := hexof(origin)
	if n > 0:
		for i in range(n, -1, -1):
			var t := float(i) / float(n)
			var c := cube_round(Vector2(lerp(float(ao.x), float(at.x), t), lerp(float(ao.y), float(at.y), t)))
			var hh := from_axial(c)
			if on_map(hh):
				best = hh
				break
	var lim := zlimit(best)
	return lz(best, clampi(z, -lim, lim))


static func cube_round(f: Vector2) -> Vector2i:
	var x := f.x
	var zz := f.y
	var y := -x - zz
	var rx := roundf(x)
	var ry := roundf(y)
	var rz := roundf(zz)
	var dx := absf(rx - x)
	var dy := absf(ry - y)
	var dz := absf(rz - zz)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(int(rx), int(rz))


## posizione randomizzata fuori mappa riportata dentro [15.3]: si correggono le ultime due cifre
static func clamp_random(h: int, z: int) -> Vector3i:
	var r := clampi(row(h), 1, 39)
	var c := col(h)
	var best := -1
	var bd := 999
	for cc in range(1, 40):
		var hh := code(r, cc)
		if on_map(hh) and absi(cc - c) < bd:
			bd = absi(cc - c)
			best = hh
	var lim := zlimit(best)
	return lz(best, clampi(z, -lim, lim))


## posizione nel mondo 3D: 1 Lite = 1 unità; x verso destra, -z verso le righe più alte, y = zulu
static func world(l: Vector3i) -> Vector3:
	return Vector3(world_hex(hexof(l)).x, float(l.z), world_hex(hexof(l)).y)


static func world_hex(h: int) -> Vector2:
	var r := row(h)
	var c := col(h)
	var x := float(c) - 0.5 * float(r & 1) - 20.0
	var y := -float(r - 20) * 0.8660254
	return Vector2(x, y)


static func all_hexes() -> Array:
	var out := []
	for r in range(1, 40):
		for c in range(1, 40):
			var h := code(r, c)
			if on_map(h):
				out.append(h)
	return out


# ---------------------------------------------------------------- Tactical Display

const TRADIUS := 5
const TZMAX := 5
## direzioni assiali delle facce (esagoni a lato piatto) indicizzate per ora dell'orologio
const TFACE := {2: Vector2i(1, -1), 4: Vector2i(1, 0), 6: Vector2i(0, 1), 8: Vector2i(-1, 1), 10: Vector2i(-1, 0), 12: Vector2i(0, -1)}
## ogni direzione di proiezione (ora del vertice) sta fra due facce
const CLOCKS := [1, 3, 5, 7, 9, 11]


static func tdist_ax(a: Vector2i, b: Vector2i) -> int:
	return adist(a, b)


static func tvalid(p: Vector3i) -> bool:
	return adist(Vector2i(p.x, p.y), Vector2i.ZERO) <= TRADIUS and absi(p.z) <= TZMAX


static func ttrue(a: Vector3i, b: Vector3i) -> int:
	return tdist2(adist(Vector2i(a.x, a.y), Vector2i(b.x, b.y)), absi(a.z - b.z))


static func tring(p: Vector3i) -> int:
	return adist(Vector2i(p.x, p.y), Vector2i.ZERO)


static func clock_faces(clock: int) -> Array:
	var a := clock - 1
	var b := clock + 1
	if a <= 0:
		a += 12
	if b > 12:
		b -= 12
	return [TFACE[a], TFACE[b]]


## esagoni (assiali) del cuneo di proiezione verso `clock`, con la distanza planare
static func wedge(origin: Vector2i, clock: int) -> Array:
	var f: Array = clock_faces(clock)
	var out := []
	for k in range(0, 6):
		for a in range(0, k + 1):
			var b := k - a
			var h: Vector2i = origin + f[0] * a + f[1] * b
			out.append([h, k])
			if k == 0:
				break
	return out


## MiniLiteZulu colpite da una proiezione: {Vector3i: distanza vera} (solo dentro il display)
static func cast_volume(origin: Vector3i, clock: int, zsign: int) -> Dictionary:
	var out := {}
	for e in wedge(Vector2i(origin.x, origin.y), clock):
		var h: Vector2i = e[0]
		var pd: int = e[1]
		for dz in range(0, 6):
			var d := tdist2(pd, dz)
			if d > 5:
				break
			var p := Vector3i(h.x, h.y, origin.z + dz * zsign)
			if tvalid(p):
				out[p] = d
	return out


## sigla a tre cifre: anello, sestante, posizione in senso orario (000 = centro)
static func tlabel(p: Vector2i) -> String:
	var k := adist(p, Vector2i.ZERO)
	if k == 0:
		return "000"
	# si parte dall'esagono a ore 12 e si gira in senso orario
	var cur := TFACE[12] * k
	var walk := [TFACE[4], TFACE[6], TFACE[8], TFACE[10], TFACE[12], TFACE[2]]
	var idx := 0
	for s in 6:
		for i in k:
			if cur == p:
				return "%d%d%d" % [k, s, i]
			cur += walk[s]
			idx += 1
	return "?"


static func tfmt(p: Vector3i) -> String:
	var zs := "0" if p.z == 0 else ("+%d" % p.z if p.z > 0 else "-%d" % (-p.z))
	return "%s/%s" % [tlabel(Vector2i(p.x, p.y)), zs]


static func t_all() -> Array:
	var out := []
	for q in range(-TRADIUS, TRADIUS + 1):
		for r in range(-TRADIUS, TRADIUS + 1):
			var a := Vector2i(q, r)
			if adist(a, Vector2i.ZERO) <= TRADIUS:
				out.append(a)
	return out


## posizione nel mondo del display tattico (1 MiniLite = 1 unità), lato piatto: x = 1.5 q
static func tworld(p: Vector3i) -> Vector3:
	var x := 1.5 * float(p.x) * 0.5773503
	var y := (float(p.y) + float(p.x) * 0.5)
	return Vector3(x, float(p.z), y)
