class_name Board3D
extends Node3D
## Scena 3D di StarForce.
## - Stellar Display: il piano equatoriale (la mappa originale SPI oppure la griglia "Reborn"), le 74
##   stelle alla loro quota Zulu con lo stelo fino al piano, StarForce e StarGate.
## - Tactical Display: il volume di 91 esagoni × 11 livelli in cui si combatte nel gioco avanzato.
## Telecamera: trascina per ruotare, rotella o pizzico per avvicinare, tasto destro per spostare.
## Selezione: clic su un'unità, su una stella o su un esagono del piano.

const D = preload("res://scripts/data/sf_data.gd")
const Ships = preload("res://scripts/ui/ships.gd")

signal picked_unit(id: String)
signal picked_hex(h: int)
signal picked_tac(p: Vector2i)
signal hover_hex(h: int)

var eng: SFEngine
var viewer := 0                 # lato che guarda (-1 pubblico, -2 tutto)
var style := "reborn"           # "reborn" oppure "originale"
var show_names := 1             # 0 nessuno, 1 natali e secondari, 2 tutti

var cam: Camera3D
var pivot: Node3D
var yaw := -0.35
var pitch := -0.62
var dist := 62.0
var target := Vector3.ZERO
var target_goal := Vector3.ZERO
var env: WorldEnvironment
var sun: DirectionalLight3D

var stellar: Node3D
var static_root: Node3D
var units_root: Node3D
var over_root: Node3D
var fx_root: Node3D
var tac_root: Node3D
var tac_units: Node3D
var tac_over: Node3D
var sky_mesh: MeshInstance3D

var unit_nodes := {}            # id -> Node3D
var unit_pos := {}              # id -> Vector3 (posizione di arrivo)
var star_nodes := {}            # Vector3i -> Node3D
var tactical := false
var tac_pos := {}               # id -> Vector3
var cursor: Node3D
var cursor_lz = null            # Vector3i o null
var selected := ""
var plot_lines := []            # [{from, to, col}]
var range_bubble: MeshInstance3D
var tac_cursor: Node3D
var cast_preview: Node3D
var _drag := false
var _drag_btn := 0
var _press_pos := Vector2.ZERO
var _moved := 0.0
var _touches := {}
var hover_h := -1
var _t := 0.0

const MAP_PX := 3072.0
## posizione del piano della mappa originale: il centro di Sol nell'immagine ritagliata e la scala
const SOL_PX := Vector2((1878.4 - 60.0) * 3072.0 / 3580.0, 1637.0 * 3072.0 / 3580.0)
const PX_X := 91.65 * 3072.0 / 3580.0
const PX_Y := 92.64 * 3072.0 / 3580.0


func setup(e: SFEngine, v: int, st: String) -> void:
	eng = e
	viewer = v
	style = st
	_build_env()
	_build_camera()
	stellar = Node3D.new()
	add_child(stellar)
	static_root = Node3D.new()
	stellar.add_child(static_root)
	units_root = Node3D.new()
	stellar.add_child(units_root)
	over_root = Node3D.new()
	stellar.add_child(over_root)
	fx_root = Node3D.new()
	add_child(fx_root)
	tac_root = Node3D.new()
	tac_root.visible = false
	add_child(tac_root)
	tac_units = Node3D.new()
	tac_root.add_child(tac_units)
	tac_over = Node3D.new()
	tac_root.add_child(tac_over)
	_build_static()
	_build_cursor()
	refresh()


func set_style(st: String) -> void:
	style = st
	for c in static_root.get_children():
		c.queue_free()
	for id in unit_nodes:
		unit_nodes[id].queue_free()
	unit_nodes.clear()
	star_nodes.clear()
	_apply_env()
	_build_static()
	refresh()
	if tactical:
		build_tactical()


# ================================================================ ambiente e telecamera

func _build_env() -> void:
	env = WorldEnvironment.new()
	env.environment = Environment.new()
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	sun.light_energy = 1.1
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(0.5, -2.4, 0)
	fill.light_energy = 0.35
	fill.light_color = Color("#ffb3cf")
	add_child(fill)
	_apply_env()


func _apply_env() -> void:
	var e := env.environment
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.7
	e.glow_bloom = 0.05
	e.glow_hdr_threshold = 0.9
	if style == "reborn":
		e.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var sm := ShaderMaterial.new()
		sm.shader = load("res://assets/shaders/spazio.gdshader")
		sky.sky_material = sm
		e.sky = sky
		e.ambient_light_color = Color("#3a3050")
		e.ambient_light_energy = 0.9
	else:
		e.glow_enabled = false
		e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color("#070404")
		e.ambient_light_color = Color("#6a5a55")
		e.ambient_light_energy = 0.8


func _build_camera() -> void:
	pivot = Node3D.new()
	add_child(pivot)
	cam = Camera3D.new()
	cam.fov = 45.0
	cam.far = 2000.0
	cam.near = 0.1
	pivot.add_child(cam)
	cam.current = true
	_update_cam()


func _update_cam() -> void:
	pivot.position = target
	pivot.rotation = Vector3(pitch, yaw, 0)
	cam.position = Vector3(0, 0, dist)


func focus(p: Vector3, d := -1.0) -> void:
	target_goal = p
	if d > 0:
		dist = d


func _process(dt: float) -> void:
	_t += dt
	target = target.lerp(target_goal, minf(1.0, dt * 4.0))
	_update_cam()
	# leggero dondolio delle astronavi e rotazione delle StarGate
	for id in unit_nodes:
		var n: Node3D = unit_nodes[id]
		if not is_instance_valid(n):
			continue
		var goal: Vector3 = unit_pos.get(id, n.position)
		n.position = n.position.lerp(goal, minf(1.0, dt * 5.0))
		var body := n.get_node_or_null("corpo")
		if body != null:
			if n.has_meta("gate"):
				body.rotation.y += dt * 0.35
			else:
				body.position.y = sin(_t * 1.3 + float(n.get_instance_id() % 17)) * 0.06
	if tactical:
		for id in tac_pos:
			var tn := tac_units.get_node_or_null(id)
			if tn != null:
				tn.position = tn.position.lerp(tac_pos[id], minf(1.0, dt * 5.0))
	if range_bubble != null and range_bubble.visible:
		var m: StandardMaterial3D = range_bubble.material_override
		m.albedo_color.a = 0.05 + 0.02 * sin(_t * 2.0)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_touches[ev.index] = ev.position
		else:
			_touches.erase(ev.index)
		return
	if ev is InputEventScreenDrag and _touches.size() >= 2:
		var old: Vector2 = _touches.get(ev.index, ev.position)
		var other := Vector2.ZERO
		for k in _touches:
			if k != ev.index:
				other = _touches[k]
		var d0 := old.distance_to(other)
		var d1: float = ev.position.distance_to(other)
		if d0 > 1.0:
			dist = clampf(dist * d0 / maxf(d1, 1.0), 6.0, 140.0)
		# due dita che scorrono insieme spostano la vista (metà del movimento: il punto medio)
		var right := cam.global_transform.basis.x
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var rel: Vector2 = (ev.position - old) * 0.5
		target_goal += (-right * rel.x + fwd * rel.y) * dist * 0.0016
		target_goal.y = 0.0
		_touches[ev.index] = ev.position
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventMagnifyGesture:
		dist = clampf(dist / ev.factor, 6.0, 140.0)
		return
	if ev is InputEventPanGesture:
		dist = clampf(dist * (1.0 + ev.delta.y * 0.05), 6.0, 140.0)
		return
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			dist = clampf(dist * 0.9, 6.0, 140.0)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			dist = clampf(dist * 1.1, 6.0, 140.0)
		elif ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if ev.pressed:
				_drag = true
				_drag_btn = ev.button_index
				_press_pos = ev.position
				_moved = 0.0
			else:
				_drag = false
				if ev.button_index == MOUSE_BUTTON_LEFT and _moved < 8.0 and _touches.size() <= 1:
					_click(ev.position)
	elif ev is InputEventMouseMotion:
		if _drag and _touches.size() <= 1:
			_moved += ev.relative.length()
			if _moved > 6.0:
				if _drag_btn == MOUSE_BUTTON_LEFT and not Input.is_key_pressed(KEY_SHIFT):
					yaw -= ev.relative.x * 0.006
					pitch = clampf(pitch - ev.relative.y * 0.005, -1.5, 0.15)
				else:
					var right := cam.global_transform.basis.x
					var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
					var k := dist * 0.0016
					target_goal += (-right * ev.relative.x + fwd * ev.relative.y) * k
					target_goal.y = 0.0
		else:
			_hover(ev.position)


## raggio dal punto dello schermo al piano orizzontale y = h
func _ray_plane(sp: Vector2, h := 0.0) -> Variant:
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	if absf(d.y) < 1e-4:
		return null
	var t := (h - o.y) / d.y
	if t < 0:
		return null
	return o + d * t


static func hex_at_world(p: Vector3) -> int:
	var r0 := int(round(20.0 - p.z / 0.8660254))
	var best := -1
	var bd := 1e9
	for r in range(r0 - 1, r0 + 2):
		var c0 := int(round(p.x + 20.0 + 0.5 * float(r & 1)))
		for c in range(c0 - 1, c0 + 2):
			var h := Hex.code(r, c)
			if not Hex.on_map(h):
				continue
			var w := Hex.world_hex(h)
			var dd := (w.x - p.x) * (w.x - p.x) + (w.y - p.z) * (w.y - p.z)
			if dd < bd:
				bd = dd
				best = h
	return best if bd < 0.45 else -1


func _hover(sp: Vector2) -> void:
	if tactical:
		return
	var p = _ray_plane(sp)
	var h := -1
	if p != null:
		h = hex_at_world(p)
	if h != hover_h:
		hover_h = h
		hover_hex.emit(h)


func _click(sp: Vector2) -> void:
	# prima le unità e le stelle vicine al punto (in pixel), poi il piano
	var best := ""
	var bd := 26.0
	var nodes: Dictionary = unit_nodes if not tactical else {}
	if tactical:
		for c in tac_units.get_children():
			nodes[c.name] = c
	for id in nodes:
		var n: Node3D = nodes[id]
		if not is_instance_valid(n) or not n.visible:
			continue
		if cam.is_position_behind(n.global_position):
			continue
		var s := cam.unproject_position(n.global_position)
		var d := s.distance_to(sp)
		if d < bd:
			bd = d
			best = str(id)
	if best != "":
		picked_unit.emit(best)
		return
	if tactical:
		var p = _ray_plane(sp, tac_root.position.y)
		if p != null:
			var lp: Vector3 = (p - tac_root.position) / TAC_SCALE
			var a := _tac_axial(lp)
			if Hex.adist(a, Vector2i.ZERO) <= 5:
				picked_tac.emit(a)
		return
	for l in star_nodes:
		var n: Node3D = star_nodes[l]
		var s := cam.unproject_position(n.global_position)
		if s.distance_to(sp) < 18.0 and not cam.is_position_behind(n.global_position):
			picked_hex.emit(Hex.hexof(l) * 1000 + 500 + l.z)
			return
	var p2 = _ray_plane(sp)
	if p2 != null:
		var h := hex_at_world(p2)
		if h >= 0:
			picked_hex.emit(h)


# ================================================================ parte statica

func _build_static() -> void:
	if style == "originale":
		var tex: Texture2D = load("res://assets/board/stellare.jpg")
		var q := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		var w := tex.get_width()
		var h := tex.get_height()
		pm.size = Vector2(float(w) / PX_X, float(h) / PX_Y)
		q.mesh = pm
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1, 1, 1, 0.92)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		q.material_override = m
		# centro dell'immagine rispetto a Sol
		var cx := (float(w) * 0.5 - SOL_PX.x) / PX_X
		var cz := (float(h) * 0.5 - SOL_PX.y) / PX_Y
		q.position = Vector3(cx, -0.02, cz)
		static_root.add_child(q)
	else:
		static_root.add_child(_grid_mesh())
	# stelle
	for st in D.STARS:
		var l := Hex.lz(int(st[0]), int(st[1]))
		var n := _star_node(l, st[2], st[3])
		static_root.add_child(n)
		star_nodes[l] = n


func _grid_mesh() -> MeshInstance3D:
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var rad := 0.5 / 0.8660254 * 0.5 * 2.0 * 0.5773503 * 0.8660254 * 2.0
	rad = 0.5773503
	for h in Hex.all_hexes():
		var c := Hex.world_hex(h)
		var ring := Hex.pdist(h, Hex.SOL)
		for k in 6:
			var a1 := deg_to_rad(60.0 * k + 30.0)
			var a2 := deg_to_rad(60.0 * (k + 1) + 30.0)
			var p1 := Vector3(c.x + cos(a1) * rad, 0, c.y + sin(a1) * rad)
			var p2 := Vector3(c.x + cos(a2) * rad, 0, c.y + sin(a2) * rad)
			# lato di confine fra anelli di limite zulu diversi: più marcato
			var mid := Vector2((p1.x + p2.x) * 0.5, (p1.z + p2.z) * 0.5)
			var nb := hex_at_world(Vector3(c.x + (mid.x - c.x) * 2.0, 0, c.y + (mid.y - c.y) * 2.0))
			var border := nb < 0 or Hex.zlimit(nb) != Hex.zlimit(h)
			var col := Color(0.92, 0.45, 0.65, 0.55) if border else Color(0.85, 0.4, 0.6, 0.11 if ring % 5 else 0.16)
			im.surface_set_color(col)
			im.surface_add_vertex(p1)
			im.surface_set_color(col)
			im.surface_add_vertex(p2)
	im.surface_end()
	return mi


func _star_node(l: Vector3i, cls: String, name: String) -> Node3D:
	var n := Node3D.new()
	n.position = Hex.world(l)
	var size: float = {"h": 0.55, "s": 0.36, "t": 0.22}[cls]
	var col := Color("#ffffff") if l.z > 0 else (Color("#ff5a8c") if l.z < 0 else Color("#ffb0cc"))
	if style == "reborn":
		# colore "stellare" deterministico secondo il nome
		var hsh := absi(hash(name)) % 5
		col = [Color("#fff4e0"), Color("#ffd8a0"), Color("#ffb070"), Color("#cfe0ff"), Color("#ff9070")][hsh]
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2
	sm.radial_segments = 20
	sm.rings = 10
	s.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col * (2.2 if style == "reborn" else 1.0)
	s.material_override = m
	n.add_child(s)
	if style == "reborn":
		var halo := Sprite3D.new()
		halo.texture = _glow_tex()
		halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		halo.modulate = Color(col.r, col.g, col.b, 0.75)
		halo.pixel_size = size * 0.05
		halo.shaded = false
		halo.transparent = true
		halo.no_depth_test = false
		n.add_child(halo)
	# stelo fino al piano e piccolo anello sul piano
	if l.z != 0:
		n.add_child(_stem(Vector3.ZERO, Vector3(0, -float(l.z), 0), Color(col.r, col.g, col.b, 0.45)))
	var foot := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.16
	tm.outer_radius = 0.2
	foot.mesh = tm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(col.r, col.g, col.b, 0.6)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foot.material_override = fm
	foot.position = Vector3(0, -float(l.z) + 0.01, 0)
	n.add_child(foot)
	if true:
		var lab := Label3D.new()
		lab.text = "%s %s" % [name, Hex.fmt(l)] if cls != "t" else name
		lab.font = UI.font_body
		lab.font_size = 34 if cls == "h" else (28 if cls == "s" else 22)
		lab.pixel_size = 0.00048
		lab.fixed_size = true
		lab.visible = show_names == 2 or (show_names == 1 and cls != "t")
		lab.set_meta("cls", cls)
		lab.modulate = Color(col.r, col.g, col.b, 0.95) if cls != "t" else Color(0.85, 0.8, 0.8, 0.75)
		lab.outline_size = 8
		lab.outline_modulate = Color(0, 0, 0, 0.8)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.position = Vector3(0, size + 0.35, 0)
		lab.no_depth_test = false
		lab.name = "nome"
		n.add_child(lab)
	return n


static var _glow: Texture2D

static func _glow_tex() -> Texture2D:
	if _glow != null:
		return _glow
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_glow = ImageTexture.create_from_image(img)
	return _glow


func _stem(a: Vector3, b: Vector3, col: Color, width := 0.025) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	var len := a.distance_to(b)
	cm.top_radius = width
	cm.bottom_radius = width
	cm.height = maxf(len, 0.001)
	cm.radial_segments = 6
	cm.rings = 1
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position = (a + b) * 0.5
	var dir := (b - a).normalized()
	if dir.length() > 0.5 and absf(dir.dot(Vector3.UP)) < 0.999:
		mi.basis = Basis(Quaternion(Vector3.UP, dir))
	elif dir.dot(Vector3.UP) < 0:
		mi.rotation = Vector3(PI, 0, 0)
	return mi


func set_names(level: int) -> void:
	show_names = level
	for l in star_nodes:
		var lab = star_nodes[l].get_node_or_null("nome")
		if lab != null:
			lab.visible = level == 2 or (level == 1 and lab.get_meta("cls", "t") != "t")


# ================================================================ unità

func _side_col(s: int) -> Color:
	return UI.side_color(eng.sides[s]["set"])


func refresh() -> void:
	_refresh_units(null)


## mostra le posizioni registrate in un momento della partita (replay): tutto visibile
func show_snapshot(snap: Dictionary) -> void:
	_refresh_units(snap)


func _refresh_units(snap) -> void:
	if eng == null:
		return
	# StarGate e StarForce: le StarForce nella stessa LiteZulu si dispongono una accanto all'altra
	var seen := {}
	var where := {}
	var stacks := {}
	for id in eng.order:
		var u: Dictionary = eng.units[id]
		var vis := "none"
		var l: Vector3i = u["lz"]
		if snap != null:
			if not snap.has(id):
				continue
			vis = "full"
			l = snap[id][0]
		elif u["st"] == "on" or u["st"] == "limbo":
			vis = eng.visibility(u, viewer)
		if vis == "none":
			continue
		var key := ""
		if vis == "hex":
			key = "h%d|%d" % [Hex.hexof(l), u["side"]]
		else:
			key = str(l)
		if not stacks.has(key):
			stacks[key] = []
		stacks[key].append(id)
		seen[id] = vis
		where[id] = l
	for id in unit_nodes.keys():
		if not seen.has(id):
			unit_nodes[id].queue_free()
			unit_nodes.erase(id)
			unit_pos.erase(id)
	var hidden_done := {}
	for key in stacks:
		var ids: Array = stacks[key]
		var k := 0
		for id in ids:
			var u: Dictionary = eng.units[id]
			var vis: String = seen[id]
			var l: Vector3i = where[id]
			if vis == "hex":
				# semi-nascosta: un solo segnalino per esagono e lato, sul piano, con la colonna del dubbio
				if hidden_done.has(key):
					if unit_nodes.has(id):
						unit_nodes[id].queue_free()
						unit_nodes.erase(id)
					continue
				hidden_done[key] = true
			var neut: bool = (snap[id][1] == 1) if snap != null else eng.neutralized(u)
			var n: Node3D = unit_nodes.get(id, null)
			var sig := "%s|%s|%s|%d|%d" % [vis, style, u["kind"], 1 if neut else 0, l.z]
			if n == null or n.get_meta("sig", "") != sig:
				var oldp = null
				if n != null:
					oldp = n.position
					n.queue_free()
				n = _unit_node(u, vis, l, neut)
				n.set_meta("sig", sig)
				n.name = id
				units_root.add_child(n)
				unit_nodes[id] = n
				n.position = oldp if oldp != null else (Hex.world(l) if vis == "full" else _hex_pos(Hex.hexof(l)))
			var base := Hex.world(l) if vis == "full" else _hex_pos(Hex.hexof(l))
			var off := Vector3.ZERO
			if u["kind"] == "sf":
				var cnt := ids.size()
				if cnt > 1 and vis == "full":
					var a := TAU * float(k) / float(cnt)
					var r := 0.38 + 0.04 * cnt
					off = Vector3(cos(a) * r, 0.25, sin(a) * r)
				else:
					off = Vector3(0, 0.25, 0)
				k += 1
			unit_pos[id] = base + off
			var sel = n.get_node_or_null("sel")
			if sel != null:
				sel.visible = id == selected
	_draw_overlays()


func _hex_pos(h: int) -> Vector3:
	var w := Hex.world_hex(h)
	return Vector3(w.x, 0.0, w.y)


func _unit_node(u: Dictionary, vis: String, l: Vector3i, neut: bool) -> Node3D:
	var n := Node3D.new()
	var col := _side_col(u["side"])
	neut = neut or u["st"] == "limbo"
	if u["kind"] == "gate":
		n.set_meta("gate", true)
	if vis == "hex":
		# colonna del dubbio: la zulu non è nota
		var h := Hex.hexof(l)
		var lim := Hex.zlimit(h)
		var col2 := Color(col.r, col.g, col.b, 0.13)
		n.add_child(_stem(Vector3(0, -lim, 0), Vector3(0, lim, 0), col2, 0.035))
	var body := Node3D.new()
	body.name = "corpo"
	n.add_child(body)
	if style == "originale" or vis == "hex":
		var sp := Sprite3D.new()
		var label: String = u["label"]
		sp.texture = UI.counter_tex(eng.sides[u["side"]]["set"], label, u["kind"] == "gate")
		if sp.texture == null:
			sp.texture = _generic_counter(col, label, u["kind"] == "gate")
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.pixel_size = 0.0135 if u["kind"] == "sf" else 0.016
		sp.shaded = false
		sp.no_depth_test = false
		if vis == "hex":
			sp.modulate = Color(1, 1, 1, 0.75)
		if neut:
			sp.modulate = Color(0.6, 0.6, 0.6, 0.85)
		body.add_child(sp)
		if vis == "hex":
			var q := Label3D.new()
			q.text = "?"
			q.font = UI.font_title
			q.font_size = 48
			q.pixel_size = 0.01
			q.modulate = UI.YELLOW
			q.outline_size = 10
			q.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			q.position = Vector3(0.36, 0.36, 0)
			body.add_child(q)
	else:
		var model: Node3D
		if u["kind"] == "gate":
			model = Ships.gate_model(u["race"], col)
		else:
			model = Ships.fleet(u["race"], col, 4)
		body.add_child(model)
		if neut:
			Ships.dim(model)
		var tag := Label3D.new()
		tag.text = u["label"]
		tag.font = UI.font_head
		tag.font_size = 30
		tag.pixel_size = 0.0006
		tag.fixed_size = true
		tag.modulate = col.lightened(0.3)
		tag.outline_size = 8
		tag.outline_modulate = Color(0, 0, 0, 0.9)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = Vector3(0, 0.55 if u["kind"] == "sf" else 0.95, 0)
		body.add_child(tag)
	# stelo verso il piano
	if vis == "full" and l.z != 0:
		n.add_child(_stem(Vector3.ZERO, Vector3(0, -float(l.z) - 0.25, 0), Color(col.r, col.g, col.b, 0.35), 0.018))
	# anello di selezione
	var sel := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.5
	sel.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(UI.YELLOW, 0.95)
	sel.material_override = m
	sel.name = "sel"
	sel.visible = false
	n.add_child(sel)
	return n


static var _gen_cache := {}

func _generic_counter(col: Color, label: String, gate: bool) -> Texture2D:
	var key := "%s|%s|%s" % [col.to_html(), label, gate]
	if _gen_cache.has(key):
		return _gen_cache[key]
	var img := Image.create(46, 46, false, Image.FORMAT_RGBA8)
	img.fill(col.darkened(0.15))
	for i in 46:
		img.set_pixel(i, 0, Color.BLACK)
		img.set_pixel(i, 45, Color.BLACK)
		img.set_pixel(0, i, Color.BLACK)
		img.set_pixel(45, i, Color.BLACK)
	var t := ImageTexture.create_from_image(img)
	_gen_cache[key] = t
	return t


func select(id: String) -> void:
	selected = id
	for k in unit_nodes:
		var sel = unit_nodes[k].get_node_or_null("sel")
		if sel != null:
			sel.visible = k == id


# ================================================================ sovrapposizioni (piani, cursore, portata)

func _build_cursor() -> void:
	cursor = Node3D.new()
	cursor.visible = false
	over_root.add_child(cursor)
	var mk := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	mk.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = UI.YELLOW * 1.6
	mk.material_override = m
	mk.name = "punto"
	cursor.add_child(mk)
	range_bubble = MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 1.0
	bm.height = 2.0
	bm.radial_segments = 48
	bm.rings = 24
	range_bubble.mesh = bm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(0.5, 0.9, 1.0, 0.06)
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	rm.no_depth_test = false
	range_bubble.material_override = rm
	range_bubble.visible = false
	over_root.add_child(range_bubble)


## cursore di destinazione (LiteZulu) con stelo e alone
func set_cursor(l, col := UI.YELLOW) -> void:
	cursor_lz = l
	for c in cursor.get_children():
		if c.name != "punto":
			c.queue_free()
	if l == null:
		cursor.visible = false
		return
	cursor.visible = true
	cursor.position = Hex.world(l)
	var p: MeshInstance3D = cursor.get_node("punto")
	(p.material_override as StandardMaterial3D).albedo_color = col * 1.6
	if l.z != 0:
		cursor.add_child(_stem(Vector3.ZERO, Vector3(0, -float(l.z), 0), Color(col, 0.7), 0.03))
	var lim := Hex.zlimit(Hex.hexof(l))
	cursor.add_child(_stem(Vector3(0, -float(l.z) - lim, 0), Vector3(0, -float(l.z) + lim, 0), Color(col, 0.15), 0.05))


func set_range(center, radius: float) -> void:
	if center == null or radius <= 0:
		range_bubble.visible = false
		return
	range_bubble.visible = true
	range_bubble.position = Hex.world(center)
	range_bubble.scale = Vector3.ONE * radius


## linee dei piani: [{from: Vector3i, to: Vector3i, col: Color}]
func set_plot_lines(lines: Array) -> void:
	plot_lines = lines
	_draw_overlays()


func _draw_overlays() -> void:
	var old := over_root.get_node_or_null("piani")
	if old != null:
		old.queue_free()
	if plot_lines.is_empty():
		return
	var root := Node3D.new()
	root.name = "piani"
	over_root.add_child(root)
	for ln in plot_lines:
		var a := Hex.world(ln["from"]) + Vector3(0, 0.25, 0)
		var b := Hex.world(ln["to"]) + Vector3(0, 0.25, 0)
		var col: Color = ln["col"]
		root.add_child(_arc(a, b, col))
		var tip := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		tip.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col * 1.5
		tip.material_override = m
		tip.position = b
		root.add_child(tip)


func _arc(a: Vector3, b: Vector3, col: Color, segs := 24) -> Node3D:
	# scia a puntini lungo un arco: si vede bene da ogni angolazione
	var n := Node3D.new()
	var lift := a.distance_to(b) * 0.18
	var steps := maxi(6, int(a.distance_to(b) / 0.35))
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	sm.radial_segments = 6
	sm.rings = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = sm
	mm.instance_count = steps + 1
	for i in steps + 1:
		var t := float(i) / float(steps)
		var p := a.lerp(b, t) + Vector3(0, sin(t * PI) * lift, 0)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * (0.7 + 0.6 * t)), p))
		mm.set_instance_color(i, Color(col.r, col.g, col.b, 0.45 + 0.55 * t))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	n.add_child(mi)
	return n


# ================================================================ Tactical Display

const TAC_SCALE := 1.6

func show_tactical(on: bool) -> void:
	tactical = on
	tac_root.visible = on
	stellar.visible = not on
	if on:
		tac_root.position = Vector3.ZERO
		build_tactical()
		target_goal = Vector3.ZERO
		dist = 24.0
		pitch = -0.6
	else:
		target_goal = Vector3.ZERO
		dist = 62.0


func build_tactical() -> void:
	for c in tac_root.get_children():
		if c != tac_units and c != tac_over:
			c.queue_free()
	for c in tac_units.get_children():
		tac_units.remove_child(c)
		c.queue_free()
	tac_pos.clear()
	# griglia sul piano 0 e cornici dei livelli +/-5
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var rad := 0.5773503 * TAC_SCALE
	for lvl in [-5, 0, 5]:
		for a in Hex.t_all():
			var c := Hex.tworld(Vector3i(a.x, a.y, lvl)) * TAC_SCALE
			var al := 0.5 if lvl == 0 else 0.12
			for k in 6:
				var a1 := deg_to_rad(60.0 * k)
				var a2 := deg_to_rad(60.0 * (k + 1))
				im.surface_set_color(Color(0.92, 0.5, 0.68, al))
				im.surface_add_vertex(c + Vector3(cos(a1), 0, sin(a1)) * rad)
				im.surface_set_color(Color(0.92, 0.5, 0.68, al))
				im.surface_add_vertex(c + Vector3(cos(a2), 0, sin(a2)) * rad)
	im.surface_end()
	tac_root.add_child(mi)
	# etichette degli esagoni (sigla a tre cifre) sul piano 0
	for a in Hex.t_all():
		var lab := Label3D.new()
		lab.text = Hex.tlabel(a)
		lab.font = UI.font_mono
		lab.font_size = 22
		lab.pixel_size = 0.01
		lab.modulate = Color(0.95, 0.6, 0.75, 0.55)
		lab.rotation = Vector3(-PI / 2, 0, 0)
		lab.position = Hex.tworld(Vector3i(a.x, a.y, 0)) * TAC_SCALE + Vector3(0, 0.01, 0.42)
		tac_root.add_child(lab)
	# asse delle MiniZulu
	for z in range(-5, 6):
		var lz := Label3D.new()
		lz.text = ("+%d" % z) if z > 0 else str(z)
		lz.font = UI.font_mono
		lz.font_size = 26
		lz.pixel_size = 0.012
		lz.modulate = Color(1, 0.85, 0.3, 0.8)
		lz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lz.position = Vector3(-9.6 * TAC_SCALE * 0.5 - 1.5, z * TAC_SCALE, 0)
		tac_root.add_child(lz)
	tac_root.add_child(_stem(Vector3(-9.6 * TAC_SCALE * 0.5 - 0.6, -5 * TAC_SCALE, 0), Vector3(-9.6 * TAC_SCALE * 0.5 - 0.6, 5 * TAC_SCALE, 0), Color(1, 0.85, 0.3, 0.4), 0.03))
	# stella del sistema a 000/-1
	if eng.tac != null and eng.tac.star:
		var st := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.3
		sm.height = 0.6
		st.mesh = sm
		var smt := StandardMaterial3D.new()
		smt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smt.albedo_color = Color("#ffe0a0") * 1.3
		st.material_override = smt
		st.position = Vector3(0, -TAC_SCALE, 0)
		tac_root.add_child(st)
		var halo := Sprite3D.new()
		halo.texture = _glow_tex()
		halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		halo.pixel_size = 0.04
		halo.modulate = Color(1, 0.8, 0.4, 0.5)
		halo.position = st.position
		tac_root.add_child(halo)
	refresh_tac()


func tac_world(p: Vector3i) -> Vector3:
	return Hex.tworld(p) * TAC_SCALE


func _tac_axial(lp: Vector3) -> Vector2i:
	var q := lp.x / (1.5 * 0.5773503)
	var r := lp.z - q * 0.5
	return Hex.cube_round(Vector2(q, r))


func refresh_tac() -> void:
	if eng.tac == null:
		return
	var t = eng.tac
	var alive := {}
	var stack := {}
	for u in t.units():
		var pp = t.known_pos(u, viewer)
		var rr: Vector3i = t.tu[u["id"]]["pos"]
		var key: Vector3i = pp if pp != null else Vector3i(rr.x, rr.y, 0)
		stack[key] = int(stack.get(key, 0)) + 1
	var placed := {}
	for u in t.units():
		var id: String = u["id"]
		alive[id] = true
		var p = t.known_pos(u, viewer)
		var real: Vector3i = t.tu[id]["pos"]
		var known := p != null
		var pos: Vector3i = p if known else Vector3i(real.x, real.y, 0)
		var n: Node3D = tac_units.get_node_or_null(id)
		var mode: String = t.tu[id]["mode"]
		var sig := "%s|%s|%s|%s|%s" % [known, mode, t.is_disrupted(id), t.tu[id]["neut"], style]
		if n == null or n.get_meta("sig", "") != sig:
			if n != null:
				n.free()
			n = _tac_node(u, known, mode, t.is_disrupted(id), t.tu[id]["neut"])
			n.name = id
			n.set_meta("sig", sig)
			tac_units.add_child(n)
			n.position = tac_world(pos)
		var off := Vector3.ZERO
		var cnt: int = stack.get(pos, 1)
		if cnt > 1 and u["kind"] == "sf":
			var k: int = placed.get(pos, 0)
			placed[pos] = k + 1
			var ang := TAU * float(k) / float(cnt)
			off = Vector3(cos(ang), 0.3, sin(ang)) * 0.55
		tac_pos[id] = tac_world(pos) + off
		var sel = n.get_node_or_null("sel")
		if sel != null:
			sel.visible = id == selected
	for c in tac_units.get_children():
		if not alive.has(str(c.name)):
			c.queue_free()
			tac_pos.erase(str(c.name))


func _tac_node(u: Dictionary, known: bool, mode: String, dis: bool, neut: bool) -> Node3D:
	var n := Node3D.new()
	var col := _side_col(u["side"])
	if not known:
		n.add_child(_stem(Vector3(0, -5 * TAC_SCALE, 0), Vector3(0, 5 * TAC_SCALE, 0), Color(col, 0.25), 0.07))
	var body := Node3D.new()
	body.name = "corpo"
	n.add_child(body)
	if style == "originale" or not known:
		var sp := Sprite3D.new()
		sp.texture = UI.counter_tex(eng.sides[u["side"]]["set"], u["label"], u["kind"] == "gate")
		if sp.texture == null:
			sp.texture = _generic_counter(col, u["label"], u["kind"] == "gate")
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.pixel_size = 0.02
		sp.shaded = false
		if dis or neut:
			sp.modulate = Color(0.55, 0.55, 0.6)
		body.add_child(sp)
	else:
		var model: Node3D
		if u["kind"] == "gate":
			model = Ships.gate_model(u["race"], col)
			model.scale = Vector3.ONE * 1.9
		else:
			model = Ships.fleet(u["race"], col, 4, mode == "battle")
			model.scale = Vector3.ONE * 2.6
		body.add_child(model)
		if dis or neut:
			Ships.dim(model)
	var tag := Label3D.new()
	tag.text = u["label"] + ("  B" if mode == "battle" and u["kind"] == "sf" else "") + ("  disgregata" if dis and u["kind"] == "sf" else "") + ("  neutralizzata" if neut else "")
	tag.font = UI.font_head
	tag.font_size = 30
	tag.pixel_size = 0.012
	tag.modulate = col.lightened(0.35)
	tag.outline_size = 8
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0, 1.0, 0)
	body.add_child(tag)
	var sel := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.7
	tm.outer_radius = 0.8
	sel.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = UI.YELLOW
	sel.material_override = m
	sel.name = "sel"
	sel.visible = false
	n.add_child(sel)
	return n


## anteprima di uno o più volumi di proiezione: [{from: Vector3i, cl, zs, p, col}]
func show_casts(casts: Array) -> void:
	for c in tac_over.get_children():
		c.queue_free()
	for c in casts:
		var vol: Dictionary = Hex.cast_volume(c["from"], int(c["cl"]), int(c["zs"]))
		var col: Color = c.get("col", UI.YELLOW)
		var pts := int(c.get("p", 32))
		for p in vol:
			var eff := pts >> int(vol[p])
			if eff <= 0:
				continue
			var mi := MeshInstance3D.new()
			var cy := CylinderMesh.new()
			cy.top_radius = 0.5 * TAC_SCALE
			cy.bottom_radius = 0.5 * TAC_SCALE
			cy.height = 0.9 * TAC_SCALE
			cy.radial_segments = 6
			cy.rings = 1
			mi.mesh = cy
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(col, clampf(0.05 + 0.25 * float(eff) / float(pts), 0.05, 0.3))
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.no_depth_test = false
			mi.material_override = m
			mi.position = tac_world(p)
			mi.rotation.y = deg_to_rad(30)
			tac_over.add_child(mi)


func set_tac_cursor(p) -> void:
	var old := tac_over.get_node_or_null("cursore")
	if old != null:
		old.free()
	if p == null:
		return
	var n := Node3D.new()
	n.name = "cursore"
	var mk := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	mk.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = UI.YELLOW * 1.6
	mk.material_override = m
	n.add_child(mk)
	n.position = tac_world(p)
	n.add_child(_stem(Vector3(0, -float(p.z) * TAC_SCALE, 0), Vector3.ZERO, Color(UI.YELLOW, 0.6), 0.03))
	tac_over.add_child(n)
