extends RefCounted
## Modelli 3D delle TeleNavi e delle StarGate per la grafica "Reborn".
## Se esiste un modello in assets/models/<razza>.glb (fatto con Blender) si usa quello, altrimenti si
## compone un modello con forme semplici, nello spirito delle illustrazioni della scatola:
## - Umani: scafo lungo con anello rotante (come la nave della copertina);
## - L'Chal-Dah: navi organiche dorate, a goccia con pinne;
## - Rame: cristalli verdi sfaccettati;
## - Xenofobi: lame scure e rosse;
## - Lega Pan-Senziente: bianco e azzurro.
## Una StarForce sono quattro TeleNavi in formazione; una FakerForce una sola.

const MODELS := "res://assets/models/%s.glb"

static var _cache := {}

## correzioni per i modelli che non sono già orientati e scalati come il gioco si aspetta:
## rotazione (radianti) e scala che portano la nave lunga circa 1 con la prua verso -Z,
## e la StarGate con l'anello di raggio circa 1 sul piano XZ
const FIX := {
	"nave_umani": {"rot": Vector3(-PI / 2, 0, 0), "scale": 0.53, "accent": Vector3(0, 0, 0.45)},
	"porta": {"rot": Vector3.ZERO, "scale": 1.2, "ring": 1.15},
}


static func _mat(col: Color, metal := 0.6, rough := 0.35, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	if emit > 0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m


static func _mesh(mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	return mi


static func _glb(name: String) -> Node3D:
	var p := MODELS % name
	if not ResourceLoader.exists(p):
		return null
	if not _cache.has(p):
		_cache[p] = load(p)
	var ps: PackedScene = _cache[p]
	if ps == null:
		return null
	var inst: Node3D = ps.instantiate()
	if not FIX.has(name):
		return inst
	var fx: Dictionary = FIX[name]
	var w := Node3D.new()
	inst.rotation = fx["rot"]
	inst.scale = Vector3.ONE * float(fx["scale"])
	w.add_child(inst)
	w.set_meta("fix", name)
	return w


## una TeleNave della razza indicata, lunga circa 1 unità, con la prua verso -Z
static func ship(race: String, col: Color) -> Node3D:
	var g := _glb("nave_" + race)
	if g != null:
		_tint(g, col)
		return g
	var n := Node3D.new()
	var hull_col := Color("#c9cdd6")
	var acc := col
	match race:
		"lcd":
			hull_col = Color("#d9b25a")
		"rame":
			hull_col = Color("#6fd38a")
		"xeno":
			hull_col = Color("#3a1e22")
		"psl":
			hull_col = Color("#e8eef8")
	var hull := _mat(hull_col, 0.7, 0.3)
	var trim := _mat(acc, 0.4, 0.4, 0.6)
	var glow := _mat(Color("#9fe3ff") if race != "xeno" else Color("#ff3a2a"), 0.0, 1.0, 4.0)
	match race:
		"lcd":
			var body := SphereMesh.new()
			body.radius = 0.18
			body.height = 0.36
			n.add_child(_mesh(body, hull, Vector3(0, 0, 0.05), Vector3.ZERO, Vector3(1, 0.7, 2.4)))
			var fin := PrismMesh.new()
			fin.size = Vector3(0.5, 0.25, 0.04)
			n.add_child(_mesh(fin, trim, Vector3(0, 0.12, 0.25), Vector3(0, PI / 2, 0)))
			n.add_child(_mesh(fin, trim, Vector3(0.18, -0.05, 0.25), Vector3(0, PI / 2, -2.2)))
			n.add_child(_mesh(fin, trim, Vector3(-0.18, -0.05, 0.25), Vector3(0, PI / 2, 2.2)))
			var eng := SphereMesh.new()
			eng.radius = 0.07
			eng.height = 0.14
			n.add_child(_mesh(eng, glow, Vector3(0, 0, 0.48)))
		"rame":
			var cr := PrismMesh.new()
			cr.size = Vector3(0.3, 0.9, 0.3)
			n.add_child(_mesh(cr, hull, Vector3.ZERO, Vector3(-PI / 2, 0, 0)))
			n.add_child(_mesh(cr, trim, Vector3(0, 0, 0.1), Vector3(-PI / 2, 0, PI), Vector3(0.6, 0.5, 0.6)))
			var sh := BoxMesh.new()
			sh.size = Vector3(0.12, 0.12, 0.12)
			n.add_child(_mesh(sh, glow, Vector3(0, 0, 0.35), Vector3(0.6, 0.6, 0)))
			n.add_child(_mesh(sh, hull, Vector3(0.2, 0, 0.15), Vector3(0.3, 0.9, 0.4), Vector3(0.8, 2.0, 0.8)))
			n.add_child(_mesh(sh, hull, Vector3(-0.2, 0, 0.15), Vector3(0.3, -0.9, -0.4), Vector3(0.8, 2.0, 0.8)))
		"xeno":
			var bl := PrismMesh.new()
			bl.size = Vector3(0.6, 1.0, 0.08)
			n.add_child(_mesh(bl, hull, Vector3.ZERO, Vector3(-PI / 2, 0, 0)))
			n.add_child(_mesh(bl, trim, Vector3(0, 0.05, 0.1), Vector3(-PI / 2, 0, 0), Vector3(0.5, 0.6, 1.8)))
			var core := SphereMesh.new()
			core.radius = 0.08
			core.height = 0.16
			n.add_child(_mesh(core, glow, Vector3(0, 0.03, 0.15)))
		_:
			# Umani e Lega: scafo cilindrico, anello rotante, motori
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.06
			cyl.bottom_radius = 0.09
			cyl.height = 0.95
			cyl.radial_segments = 10
			n.add_child(_mesh(cyl, hull, Vector3.ZERO, Vector3(PI / 2, 0, 0)))
			var nose := CylinderMesh.new()
			nose.top_radius = 0.0
			nose.bottom_radius = 0.06
			nose.height = 0.22
			nose.radial_segments = 10
			n.add_child(_mesh(nose, hull, Vector3(0, 0, -0.58), Vector3(-PI / 2, 0, 0)))
			var ring := TorusMesh.new()
			ring.inner_radius = 0.2
			ring.outer_radius = 0.25
			ring.rings = 24
			ring.ring_segments = 8
			var r := _mesh(ring, trim, Vector3(0, 0, -0.05), Vector3(PI / 2, 0, 0))
			r.name = "anello"
			n.add_child(r)
			var spoke := BoxMesh.new()
			spoke.size = Vector3(0.44, 0.02, 0.02)
			n.add_child(_mesh(spoke, hull, Vector3(0, 0, -0.05)))
			n.add_child(_mesh(spoke, hull, Vector3(0, 0, -0.05), Vector3(0, 0, PI / 2)))
			var pod := BoxMesh.new()
			pod.size = Vector3(0.1, 0.1, 0.3)
			n.add_child(_mesh(pod, hull, Vector3(0.12, 0, 0.32)))
			n.add_child(_mesh(pod, hull, Vector3(-0.12, 0, 0.32)))
			var e := SphereMesh.new()
			e.radius = 0.05
			e.height = 0.1
			n.add_child(_mesh(e, glow, Vector3(0.12, 0, 0.48)))
			n.add_child(_mesh(e, glow, Vector3(-0.12, 0, 0.48)))
	return n


## una StarForce: `count` TeleNavi in formazione (a rombo); in modo battaglia la formazione si stringe
static func fleet(race: String, col: Color, count := 4, battle := false) -> Node3D:
	var f := Node3D.new()
	var offs := [Vector3(0, 0, -0.18), Vector3(0.22, 0.04, 0.08), Vector3(-0.22, -0.04, 0.08), Vector3(0, 0.08, 0.3)]
	var k := 0.7 if battle else 1.0
	for i in mini(count, 4):
		var s := ship(race, col)
		s.scale = Vector3.ONE * 0.36
		s.position = offs[i] * k
		f.add_child(s)
	# luce del colore del lato, per riconoscere le flotte da lontano
	var halo := Sprite3D.new()
	halo.texture = Board3D._glow_tex()
	halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	halo.modulate = Color(col, 0.35)
	halo.pixel_size = 0.018
	f.add_child(halo)
	return f


## StarGate: grande anello con raggi e mozzo centrale, come la stazione della copertina
static func gate_model(race: String, col: Color) -> Node3D:
	var g := _glb("porta_" + race)
	if g == null:
		g = _glb("porta")
	if g != null:
		_tint(g, col)
		return g
	var n := Node3D.new()
	var hull := _mat(Color("#bfc4cc"), 0.75, 0.3)
	var trim := _mat(col, 0.3, 0.4, 0.9)
	var light := _mat(Color("#bff4ff"), 0.0, 1.0, 3.0)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.62
	ring.outer_radius = 0.72
	ring.rings = 48
	ring.ring_segments = 10
	n.add_child(_mesh(ring, hull))
	var ring2 := TorusMesh.new()
	ring2.inner_radius = 0.7
	ring2.outer_radius = 0.74
	ring2.rings = 48
	ring2.ring_segments = 6
	n.add_child(_mesh(ring2, trim, Vector3(0, 0.05, 0)))
	var hub := CylinderMesh.new()
	hub.top_radius = 0.12
	hub.bottom_radius = 0.16
	hub.height = 0.55
	hub.radial_segments = 12
	n.add_child(_mesh(hub, hull))
	var dish := SphereMesh.new()
	dish.radius = 0.14
	dish.height = 0.14
	dish.is_hemisphere = true
	n.add_child(_mesh(dish, light, Vector3(0, 0.28, 0)))
	var spoke := CylinderMesh.new()
	spoke.top_radius = 0.025
	spoke.bottom_radius = 0.025
	spoke.height = 1.3
	spoke.radial_segments = 6
	for k in 3:
		n.add_child(_mesh(spoke, hull, Vector3.ZERO, Vector3(PI / 2, k * PI / 3, 0)))
	var node := BoxMesh.new()
	node.size = Vector3(0.1, 0.1, 0.1)
	for k in 6:
		var a := k * PI / 3
		n.add_child(_mesh(node, light, Vector3(cos(a) * 0.67, 0, sin(a) * 0.67)))
	return n


## i modelli senza materiale "colore_lato" ricevono un anello luminoso del colore del lato
static func _accent(w: Node3D, col: Color) -> void:
	if not w.has_meta("fix"):
		return
	var fx: Dictionary = FIX[str(w.get_meta("fix"))]
	var m := _mat(col, 0.2, 0.4, 1.6)
	if fx.has("ring"):
		var r: float = fx["ring"]
		var t := TorusMesh.new()
		t.inner_radius = r
		t.outer_radius = r + 0.035
		t.rings = 64
		t.ring_segments = 8
		w.add_child(_mesh(t, m))
	if fx.has("accent"):
		var t2 := TorusMesh.new()
		t2.inner_radius = 0.07
		t2.outer_radius = 0.11
		t2.rings = 24
		t2.ring_segments = 6
		w.add_child(_mesh(t2, m, fx["accent"], Vector3(PI / 2, 0, 0)))


static func _tint(n: Node, col: Color) -> void:
	# i modelli .glb hanno un materiale "colore_lato" che prende il colore della fazione
	if n is Node3D and n.has_meta("fix"):
		_accent(n, col)
	for c in n.get_children():
		_tint(c, col)
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		for s in mi.get_surface_override_material_count():
			var m := mi.mesh.surface_get_material(s)
			if m != null and m.resource_name.begins_with("colore_lato"):
				var mm: StandardMaterial3D = (m as StandardMaterial3D).duplicate()
				mm.albedo_color = col
				mm.emission = col
				mi.set_surface_override_material(s, mm)


## aspetto spento per unità neutralizzate o disgregate
static func dim(n: Node) -> void:
	for c in n.get_children():
		dim(c)
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		if mi.material_override is StandardMaterial3D:
			var m: StandardMaterial3D = mi.material_override.duplicate()
			m.albedo_color = m.albedo_color.darkened(0.55)
			m.emission_energy_multiplier *= 0.2
			mi.material_override = m
	if n is Sprite3D:
		(n as Sprite3D).modulate = (n as Sprite3D).modulate.darkened(0.5)
