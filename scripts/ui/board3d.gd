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
signal hover_tac(p: Vector2i)

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
var input_locked := false      # true con le tendine (hotseat) aperte
const DIST_MIN := 5.0
const DIST_MAX := 140.0
const PITCH_MIN := -1.55
const PITCH_MAX := 0.15
var hover_h := -1
var hot_hex := -1
var top_view := false
const STEM_A := 0.2
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
	if top_view:
		_fix_labels(self)


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
	if top_view:
		# dall'alto si usa la proiezione ortogonale: ogni stella sta esattamente sopra il suo esagono,
		# come sulla mappa di carta
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = dist * 0.83
		cam.position = Vector3(0, 0, 45.0)
	else:
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
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
				var pg := tn.find_child("porta", true, false)
				if pg != null:
					pg.rotation.y += dt * 0.35
	if is_instance_valid(hint):
		var r: Node3D = hint.get_node("anello")
		var k := 1.0 + 0.25 * sin(_t * 5.0)
		r.scale = Vector3(k, k, k)
		if top_view:
			r.rotation = Vector3.ZERO
		else:
			r.rotation.y += dt
	if range_bubble != null and range_bubble.visible:
		var m: StandardMaterial3D = range_bubble.material_override
		m.albedo_color.a = 0.05 + 0.02 * sin(_t * 2.0)


## true se il punto dello schermo è sopra un pannello dell'interfaccia (lì il mouse non muove la mappa)
func _over_gui(sp: Vector2) -> bool:
	var c := get_viewport().gui_get_hovered_control()
	if c == null:
		return false
	return c.get_global_rect().has_point(sp) and c.mouse_filter != Control.MOUSE_FILTER_IGNORE


## Comandi della telecamera. Si usa _input (non _unhandled_input) e si controlla a mano se sotto il
## puntatore c'è un pannello: così il rilascio del tasto arriva sempre e il trascinamento non resta
## "appeso" quando il mouse finisce sopra un pannello, e Maiusc si legge dall'evento stesso
## (nel browser il tasto può risultare premuto per sempre se si perde il rilascio).
func _input(ev: InputEvent) -> void:
	if not is_visible_in_tree() or input_locked:
		_drag = false
		return
	if ev is InputEventScreenTouch:
		if ev.pressed:
			if _over_gui(ev.position):
				return
			_touches[ev.index] = ev.position
		else:
			_touches.erase(ev.index)
		return
	if ev is InputEventScreenDrag:
		if not _touches.has(ev.index):
			return
		if _touches.size() >= 2:
			var old: Vector2 = _touches[ev.index]
			var other := Vector2.ZERO
			for k in _touches:
				if k != ev.index:
					other = _touches[k]
			var d0 := old.distance_to(other)
			var d1: float = ev.position.distance_to(other)
			if d0 > 1.0:
				dist = clampf(dist * d0 / maxf(d1, 1.0), DIST_MIN, DIST_MAX)
			# due dita che scorrono insieme spostano la vista (metà del movimento: il punto medio)
			_pan((ev.position - old) * 0.5)
			_touches[ev.index] = ev.position
		return
	if ev is InputEventMagnifyGesture:
		if not _over_gui(ev.position):
			dist = clampf(dist / ev.factor, DIST_MIN, DIST_MAX)
		return
	if ev is InputEventPanGesture:
		if not _over_gui(ev.position):
			dist = clampf(dist * (1.0 + ev.delta.y * 0.05), DIST_MIN, DIST_MAX)
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is SpinBox:
			return
		match ev.keycode:
			KEY_Q:
				yaw += 0.26
			KEY_E:
				yaw -= 0.26
			KEY_LEFT:
				_pan(Vector2(60, 0))
			KEY_RIGHT:
				_pan(Vector2(-60, 0))
			KEY_UP:
				_pan(Vector2(0, 60))
			KEY_DOWN:
				_pan(Vector2(0, -60))
			KEY_EQUAL, KEY_KP_ADD:
				dist = clampf(dist * 0.85, DIST_MIN, DIST_MAX)
			KEY_MINUS, KEY_KP_SUBTRACT:
				dist = clampf(dist * 1.18, DIST_MIN, DIST_MAX)
		return
	if ev is InputEventMouseButton:
		if ev.pressed and _over_gui(ev.position):
			return
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			dist = clampf(dist * 0.9, DIST_MIN, DIST_MAX)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			dist = clampf(dist * 1.1, DIST_MIN, DIST_MAX)
		elif ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if ev.pressed:
				_drag = true
				_drag_btn = ev.button_index
				_press_pos = ev.position
				_moved = 0.0
			elif _drag and ev.button_index == _drag_btn:
				_drag = false
				if ev.button_index == MOUSE_BUTTON_LEFT and _moved < 8.0 and _touches.size() <= 1 and not _over_gui(ev.position):
					_click(ev.position)
	elif ev is InputEventMouseMotion:
		if _drag and ev.button_mask == 0:
			# il rilascio è andato perso (fuori dalla finestra): si chiude il trascinamento
			_drag = false
		if _drag and _touches.size() <= 1:
			_moved += ev.relative.length()
			if _moved > 6.0:
				if _drag_btn == MOUSE_BUTTON_LEFT and not ev.shift_pressed:
					yaw -= ev.relative.x * 0.006
					if not top_view:
						pitch = clampf(pitch - ev.relative.y * 0.005, PITCH_MIN, PITCH_MAX)
				else:
					_pan(ev.relative)
		elif not _over_gui(ev.position):
			_hover(ev.position)


func _pan(rel: Vector2) -> void:
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var k := dist * 0.0016
	target_goal += (-right * rel.x + fwd * rel.y) * k
	target_goal.y = 0.0
	var lim := 30.0 if not tactical else 14.0
	target_goal.x = clampf(target_goal.x, -lim, lim)
	target_goal.z = clampf(target_goal.z, -lim, lim)


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
		_hover_tac(sp)
		return
	var h := -1
	# prima le stelle vicine al puntatore (in pixel): nella vista inclinata sono lontane dal loro esagono
	var bd := 20.0
	for l in star_nodes:
		var n: Node3D = star_nodes[l]
		if cam.is_position_behind(n.global_position):
			continue
		var d := cam.unproject_position(n.global_position).distance_to(sp)
		if d < bd:
			bd = d
			h = Hex.hexof(l)
	if h < 0:
		var p = _ray_plane(sp)
		if p != null:
			h = hex_at_world(p)
	if h != hover_h:
		hover_h = h
		_highlight_hex(h)
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
	# stelle (quelle della mappa più quelle dello scenario)
	for st in (eng.star_list if eng != null and not eng.star_list.is_empty() else D.STARS):
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
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2
	sm.radial_segments = 32 if style == "reborn" else 20
	sm.rings = 16 if style == "reborn" else 10
	s.mesh = sm
	if style == "reborn":
		# superficie viva: granulazione, macchie e rotazione, col colore del tipo spettrale
		var tp := D.star_type(name, cls)
		var pal: Array = D.STAR_COLORS[tp]
		col = pal[3]
		var h := absi(hash(name))
		var sh := ShaderMaterial.new()
		sh.shader = _star_shader()
		sh.set_shader_parameter("base_color", pal[0])
		sh.set_shader_parameter("hot_color", pal[1])
		sh.set_shader_parameter("cool_color", pal[2])
		sh.set_shader_parameter("seed", float(h % 1000) / 1000.0)
		sh.set_shader_parameter("spin", (0.08 + float(h % 7) * 0.025) * (1.0 if h % 2 == 0 else -1.0))
		sh.set_shader_parameter("boil", 0.15 + float(h % 5) * 0.04 + (0.15 if tp == "M" else 0.0))
		sh.set_shader_parameter("spots", {"A": 0.0, "F": 0.15, "G": 0.55, "K": 0.8, "M": 0.6, "D": 0.0}[tp])
		sh.set_shader_parameter("energy", {"A": 1.15, "F": 1.1, "G": 1.0, "K": 1.0, "M": 1.0, "D": 1.2}[tp])
		s.material_override = sh
		# inclinazione dell'asse, diversa per ogni stella
		s.rotation = Vector3(deg_to_rad(float(h % 40) - 20.0), 0, deg_to_rad(float((h / 40) % 30) - 15.0))
		if tp == "D":
			s.scale = Vector3.ONE * 0.7
		elif tp == "A":
			s.scale = Vector3.ONE * 1.2
	else:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col
		s.material_override = m
	n.add_child(s)
	if style == "reborn":
		var halo := Sprite3D.new()
		halo.texture = _corona_tex()
		halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		halo.modulate = Color(col.r, col.g, col.b, 0.8)
		halo.pixel_size = size * 0.05 * s.scale.x
		halo.shaded = false
		halo.transparent = true
		halo.no_depth_test = false
		halo.name = "corona"
		n.add_child(halo)
	# stelo fino al piano e piccolo anello sul piano
	if l.z != 0:
		var stem := _stem(Vector3.ZERO, Vector3(0, -float(l.z), 0), Color(col.r, col.g, col.b, STEM_A))
		stem.name = "stelo"
		n.add_child(stem)
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
	foot.name = "piede"
	n.add_child(foot)
	n.set_meta("cls", cls)
	n.set_meta("nome", name)
	n.set_meta("lz", l)
	var lab := Label3D.new()
	lab.font = UI.font_body
	lab.font_size = 30 if cls == "h" else (24 if cls == "s" else 20)
	lab.pixel_size = 0.00048
	lab.fixed_size = true
	lab.modulate = Color(col.r, col.g, col.b, 0.85) if cls != "t" else Color(0.85, 0.8, 0.8, 0.7)
	lab.outline_size = 8
	lab.outline_modulate = Color(0, 0, 0, 0.85)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.offset = Vector2(0, 34)
	lab.no_depth_test = false
	lab.name = "nome"
	n.add_child(lab)
	_star_label(n)
	return n


static var _glow: Texture2D
static var _corona: Texture2D
static var _star_sh: Shader

static func _star_shader() -> Shader:
	if _star_sh == null:
		_star_sh = load("res://assets/shaders/stella.gdshader")
	return _star_sh


## corona: trasparente sopra il disco della stella (che deve vedersi), luminosa appena fuori dal bordo
static func _corona_tex() -> Texture2D:
	if _corona != null:
		return _corona
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var d := Vector2(x - 63.5, y - 63.5).length() / 64.0
			var a := 0.0
			if d > 0.27:
				a = smoothstep(0.27, 0.33, d) * pow(clampf(1.0 - (d - 0.31) / 0.69, 0.0, 1.0), 2.2)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_corona = ImageTexture.create_from_image(img)
	return _corona

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
		_star_label(star_nodes[l])


## testo e visibilità del nome di una stella: livello 1 solo i nomi delle stelle principali,
## livello 2 tutte con la posizione; nella vista dall'alto si aggiunge sempre la quota Zulu
## (come sulla mappa di carta); l'esagono sotto il mouse mostra sempre nome e posizione
func _star_label(n: Node3D) -> void:
	var lab: Label3D = n.get_node_or_null("nome")
	if lab == null:
		return
	var cls: String = n.get_meta("cls", "t")
	var l: Vector3i = n.get_meta("lz", Vector3i.ZERO)
	var nm: String = n.get_meta("nome", "")
	var hot := Hex.hexof(l) == hot_hex
	var zs := ("+%d" % l.z) if l.z > 0 else str(l.z)
	if hot or show_names == 2:
		lab.text = "%s %s" % [nm, Hex.fmt(l)]
	elif top_view:
		lab.text = "%s %s" % [nm, zs] if cls != "t" else zs
	else:
		lab.text = nm
	lab.visible = hot or show_names == 2 or (show_names == 1 and cls != "t") or (top_view and show_names >= 1)
	lab.modulate.a = 1.0 if hot else (0.85 if cls != "t" else 0.6)
	# Outleap: colore del proprietario e popolazione; i terziari sfruttati con "EE"
	if eng != null and eng.eco != null and eng.eco.sys.has(Hex.hexof(l)):
		var x: Dictionary = eng.eco.sys[Hex.hexof(l)]
		if int(x["owner"]) >= 0:
			var oc: Color = UI.side_color(eng.sides[int(x["owner"])]["set"]).lightened(0.35)
			lab.modulate = Color(oc.r, oc.g, oc.b, 1.0)
			lab.visible = true
			if int(x["pop"]) > 0:
				lab.text += "  [%d]" % int(x["pop"])
			elif x["cls"] == "t":
				lab.text += "  [EE]"
	var stem: MeshInstance3D = n.get_node_or_null("stelo")
	if stem != null:
		var m: StandardMaterial3D = stem.material_override
		m.albedo_color.a = 0.85 if hot else STEM_A


## evidenzia le stelle dell'esagono sotto il mouse (nome completo e stelo acceso)
func _highlight_hex(h: int) -> void:
	if h == hot_hex:
		return
	var old := hot_hex
	hot_hex = h
	for l in star_nodes:
		var hh := Hex.hexof(l)
		if hh == old or hh == h:
			_star_label(star_nodes[l])


## in proiezione ortogonale le etichette "a dimensione fissa" escono molto più piccole:
## si ingrandiscono di conseguenza (il valore di partenza resta nel meta "px0")
func _fix_labels(root: Node) -> void:
	var k := 2.6 if top_view else 1.0
	for c in root.find_children("*", "Label3D", true, false):
		var lab: Label3D = c
		if not lab.fixed_size:
			continue
		if not lab.has_meta("px0"):
			lab.set_meta("px0", lab.pixel_size)
		lab.pixel_size = float(lab.get_meta("px0")) * k


## vista dall'alto (come la mappa di carta) oppure vista 3D inclinata
func set_top_view(on: bool) -> void:
	top_view = on
	pitch = -PI / 2.0 if on else (-0.65 if tactical else -0.62)
	if not tactical:
		yaw = 0.0 if on else -0.35
	for l in star_nodes:
		_star_label(star_nodes[l])
	refresh()
	_fix_labels(self)


## riporta la vista al punto indicato con l'inclinazione di partenza
func reset_view(p: Vector3, d: float) -> void:
	target_goal = p
	dist = d
	yaw = 0.0 if top_view else -0.35
	pitch = -PI / 2.0 if top_view else (-0.65 if tactical else -0.62)


# ================================================================ unità

func _side_col(s: int) -> Color:
	return UI.side_color(eng.sides[s]["set"])


func refresh() -> void:
	_refresh_units(null)
	if eng != null and eng.eco != null:
		for l in star_nodes:
			_star_label(star_nodes[l])


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
			var sig := "%s|%s|%s|%d|%d|%s" % [vis, style, u["kind"], 1 if neut else 0, l.z, str(u.get("ff", false))]
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
	_stack_tags(stacks, seen, where)
	_draw_overlays()
	if top_view:
		_fix_labels(over_root)


## una sola etichetta per gruppo di unità dello stesso lato nella stessa LiteZulu ("A C"),
## sempre leggibile sopra stelle e nomi; nella vista dall'alto riporta anche la quota Zulu
func _stack_tags(stacks: Dictionary, seen: Dictionary, where: Dictionary) -> void:
	var root := over_root.get_node_or_null("sigle")
	if root != null:
		root.free()
	root = Node3D.new()
	root.name = "sigle"
	over_root.add_child(root)
	for key in stacks:
		var by_side := {}
		for id in stacks[key]:
			var u: Dictionary = eng.units[id]
			if seen[id] != "full":
				continue
			var sd: int = u["side"]
			if not by_side.has(sd):
				by_side[sd] = []
			by_side[sd].append(id)
		var j := 0
		for sd in by_side:
			var ids: Array = by_side[sd]
			var letters := []
			var has_gate := false
			for id in ids:
				if eng.units[id]["kind"] == "gate":
					has_gate = true
				else:
					var uu: Dictionary = eng.units[id]
					var lab := str(uu["label"])
					if uu.get("ff", false) and (uu["side"] == viewer or viewer == -2 or uu.get("ff_known", false)):
						lab = lab.to_lower()
					letters.append(lab)
			var l: Vector3i = where[ids[0]]
			# le StarGate si riconoscono dal modello e dal nome della stella: la sigla è solo per le flotte
			if letters.is_empty():
				continue
			has_gate = false
			if letters.size() > 6:
				var nff := 0
				for id in ids:
					if eng.units[id].get("ff", false) and (sd == viewer or viewer == -2 or eng.units[id].get("ff_known", false)):
						nff += 1
				letters = ["%d %s" % [letters.size(), "FakerForce" if nff == letters.size() else "unità"]]
			var zs := ("+%d" % l.z) if l.z > 0 else str(l.z)
			var txt := " ".join(letters)
			if has_gate:
				txt = "StarGate"
			if top_view:
				txt += "  " + zs
			if style == "originale":
				# le pedine mostrano già la sigla: serve solo la quota, e solo dall'alto
				if not top_view:
					continue
				txt = zs
			_tag(root, txt, Hex.world(l), _side_col(sd), 22 if has_gate else 30, (66 if has_gate else 62) + 44 * j)
			j += 1


func _tag(root: Node3D, txt: String, pos: Vector3, col: Color, fs: int, up := 60) -> void:
	var tag := Label3D.new()
	tag.text = txt
	tag.font = UI.font_head
	tag.font_size = fs
	tag.pixel_size = 0.0006
	tag.fixed_size = true
	tag.modulate = col.lightened(0.45)
	tag.outline_size = 12
	tag.outline_modulate = Color(0, 0, 0, 0.95)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.render_priority = 10
	tag.outline_render_priority = 9
	tag.position = pos
	tag.offset = Vector2(0, up)
	root.add_child(tag)


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
		n.add_child(_stem(Vector3(0, -lim, 0), Vector3(0, lim, 0), Color(col2, 0.08), 0.03))
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
		sp.pixel_size = (0.0135 if u["kind"] == "sf" else 0.016) if vis == "full" else 0.011
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
			model = Ships.fleet(u["race"], col, 1)
			var known_ff: bool = u.get("ff", false) and (u["side"] == viewer or viewer == -2 or u.get("ff_known", false))
			model.scale = Vector3.ONE * (0.8 if known_ff else 1.25)
		body.add_child(model)
		if neut:
			Ships.dim(model)
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


## anello giallo lampeggiante su una LiteZulu (lo usa il tutorial per indicare dove cliccare)
var hint: Node3D

func set_hint(l) -> void:
	if is_instance_valid(hint):
		hint.queue_free()
	hint = null
	if l == null:
		return
	hint = Node3D.new()
	hint.position = Hex.world(l)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.75
	tm.outer_radius = 0.9
	tm.rings = 40
	ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(UI.YELLOW, 0.9)
	m.no_depth_test = true
	ring.material_override = m
	ring.name = "anello"
	hint.add_child(ring)
	_tag(hint, "clicca qui", Vector3.ZERO, UI.YELLOW, 26, -70)
	over_root.add_child(hint)
	if top_view:
		_fix_labels(hint)


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

const TAC_SCALE := 2.2

## replay: Tactical Display ricostruito da un'istantanea registrata (eng.tac non c'è più)
var tac_snap = null
var tac_lz := Vector3i.ZERO


func show_tac_snapshot(lz: Vector3i, snap) -> void:
	if snap == null:
		tac_snap = null
		if tactical:
			show_tactical(false)
		return
	var fresh: bool = tac_snap == null or not tactical or lz != tac_lz
	tac_snap = snap
	tac_lz = lz
	if fresh:
		show_tactical(true)
	else:
		refresh_tac()


func show_tactical(on: bool) -> void:
	tactical = on
	tac_root.visible = on
	stellar.visible = not on
	if on:
		tac_root.position = Vector3.ZERO
		build_tactical()
		target_goal = Vector3.ZERO
		dist = 34.0
		pitch = -PI / 2.0 if top_view else -0.65
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
	# sigla dell'esagono sotto il mouse (una sola, invece di 91 etichette sempre accese)
	var hl := Label3D.new()
	hl.name = "sigla_hover"
	hl.font = UI.font_mono
	hl.font_size = 30
	hl.pixel_size = 0.0007
	hl.fixed_size = true
	hl.modulate = Color(1, 0.85, 0.4)
	hl.outline_size = 8
	hl.outline_modulate = Color(0, 0, 0, 0.9)
	hl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hl.no_depth_test = true
	hl.render_priority = 8
	hl.visible = false
	tac_root.add_child(hl)
	var hx := MeshInstance3D.new()
	hx.name = "esagono_hover"
	var hcy := CylinderMesh.new()
	hcy.top_radius = 0.5773503 * TAC_SCALE * 0.97
	hcy.bottom_radius = hcy.top_radius
	hcy.height = 0.04
	hcy.radial_segments = 6
	hcy.rings = 1
	hx.mesh = hcy
	var hxm := StandardMaterial3D.new()
	hxm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hxm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hxm.albedo_color = Color(1, 0.85, 0.4, 0.18)
	hx.material_override = hxm
	hx.rotation.y = deg_to_rad(30)
	hx.visible = false
	tac_root.add_child(hx)
	# asse delle MiniZulu
	for z in range(-5, 6):
		var lz := Label3D.new()
		lz.text = ("+%d" % z) if z > 0 else str(z)
		lz.font = UI.font_mono
		lz.font_size = 24
		lz.pixel_size = 0.0006
		lz.fixed_size = true
		lz.outline_size = 8
		lz.outline_modulate = Color(0, 0, 0, 0.9)
		lz.modulate = Color(1, 0.85, 0.3, 0.8)
		lz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lz.position = Vector3(-9.6 * TAC_SCALE * 0.5 - 1.5, z * TAC_SCALE, 0)
		tac_root.add_child(lz)
	tac_root.add_child(_stem(Vector3(-9.6 * TAC_SCALE * 0.5 - 0.6, -5 * TAC_SCALE, 0), Vector3(-9.6 * TAC_SCALE * 0.5 - 0.6, 5 * TAC_SCALE, 0), Color(1, 0.85, 0.3, 0.4), 0.03))
	# stella del sistema a 000/-1
	var star_l = null
	if tac_snap != null:
		if not eng.star_at(tac_lz).is_empty():
			star_l = tac_lz
	elif eng.tac != null and eng.tac.star:
		star_l = eng.tac.l
	if star_l != null:
		var st := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.55
		sm.height = 1.1
		sm.radial_segments = 32
		sm.rings = 16
		st.mesh = sm
		var stn: Dictionary = eng.star_at(star_l)
		var tp := D.star_type(str(stn.get("name", "")), str(stn.get("cls", "t")))
		var pal: Array = D.STAR_COLORS[tp]
		var smt := ShaderMaterial.new()
		smt.shader = _star_shader()
		smt.set_shader_parameter("base_color", pal[0])
		smt.set_shader_parameter("hot_color", pal[1])
		smt.set_shader_parameter("cool_color", pal[2])
		smt.set_shader_parameter("spin", 0.1)
		smt.set_shader_parameter("spots", 0.6)
		st.material_override = smt
		st.position = Vector3(0, -TAC_SCALE, 0)
		tac_root.add_child(st)
		var halo := Sprite3D.new()
		halo.texture = _glow_tex()
		halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		halo.pixel_size = 0.04
		halo.texture = _corona_tex()
		halo.pixel_size = 0.55 * 6.4 / 128.0
		halo.modulate = Color(pal[3], 0.8)
		halo.position = st.position
		tac_root.add_child(halo)
	refresh_tac()


func tac_world(p: Vector3i) -> Vector3:
	return Hex.tworld(p) * TAC_SCALE


func _tac_axial(lp: Vector3) -> Vector2i:
	var q := lp.x / (1.5 * 0.5773503)
	var r := lp.z - q * 0.5
	return Hex.cube_round(Vector2(q, r))


var _tac_hover := Vector2i(99, 99)

func _hover_tac(sp: Vector2) -> void:
	var a := Vector2i(99, 99)
	var p = _ray_plane(sp, tac_root.position.y)
	if p != null:
		var lp: Vector3 = (p - tac_root.position) / TAC_SCALE
		var aa := _tac_axial(lp)
		if Hex.adist(aa, Vector2i.ZERO) <= 5:
			a = aa
	if a == _tac_hover:
		return
	_tac_hover = a
	var hl: Label3D = tac_root.get_node_or_null("sigla_hover")
	var hx: MeshInstance3D = tac_root.get_node_or_null("esagono_hover")
	if hl == null:
		return
	var on := a != Vector2i(99, 99)
	hl.visible = on
	hx.visible = on
	if on:
		hl.text = Hex.tlabel(a)
		hl.position = tac_world(Vector3i(a.x, a.y, 0)) + Vector3(0, 0.35, 0)
		hx.position = tac_world(Vector3i(a.x, a.y, 0)) + Vector3(0, 0.02, 0)
	hover_tac.emit(a)


func refresh_tac() -> void:
	if tac_snap != null:
		_refresh_tac_snap()
		return
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
		var sig := "%s|%s|%s|%s|%s|%d" % [known, mode, t.is_disrupted(id), t.tu[id]["neut"], style, pos.z]
		if n == null or n.get_meta("sig", "") != sig:
			if n != null:
				n.free()
			n = _tac_node(u, known, mode, t.is_disrupted(id), t.tu[id]["neut"], pos.z)
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
			off = Vector3(cos(ang) * 0.75, 0.0, sin(ang) * 0.75)
		tac_pos[id] = tac_world(pos) + off
		var sel = n.get_node_or_null("sel")
		if sel != null:
			sel.visible = id == selected
	for c in tac_units.get_children():
		if not alive.has(str(c.name)):
			c.queue_free()
			tac_pos.erase(str(c.name))
	if top_view:
		_fix_labels(tac_root)


func _refresh_tac_snap() -> void:
	var alive := {}
	var stack := {}
	for id in tac_snap:
		if str(tac_snap[id][4]) == "" and eng.units.has(id):
			stack[tac_snap[id][0]] = int(stack.get(tac_snap[id][0], 0)) + 1
	var placed := {}
	for id in tac_snap:
		var e: Array = tac_snap[id]
		if str(e[4]) != "" or not eng.units.has(id):
			continue
		var u: Dictionary = eng.units[id]
		alive[id] = true
		var pos: Vector3i = e[0]
		var n: Node3D = tac_units.get_node_or_null(id)
		var sig := "snap|%s|%s|%s|%s|%d" % [e[1], e[2], e[3], style, pos.z]
		if n == null or n.get_meta("sig", "") != sig:
			if n != null:
				n.free()
			n = _tac_node(u, true, str(e[1]), bool(e[2]), bool(e[3]), pos.z)
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
			off = Vector3(cos(ang) * 0.75, 0.0, sin(ang) * 0.75)
		tac_pos[id] = tac_world(pos) + off
	for c in tac_units.get_children():
		if not alive.has(str(c.name)):
			c.queue_free()
			tac_pos.erase(str(c.name))
	if top_view:
		_fix_labels(tac_root)


func _tac_node(u: Dictionary, known: bool, mode: String, dis: bool, neut: bool, pz := 0) -> Node3D:
	var n := Node3D.new()
	var col := _side_col(u["side"])
	if known and pz != 0:
		# stelo fino al piano 0 con un dischetto: si legge a colpo d'occhio la MiniZulu
		n.add_child(_stem(Vector3.ZERO, Vector3(0, -float(pz) * TAC_SCALE, 0), Color(col, 0.45), 0.03))
	if known:
		var foot := MeshInstance3D.new()
		var fcy := CylinderMesh.new()
		fcy.top_radius = 0.28
		fcy.bottom_radius = 0.28
		fcy.height = 0.03
		fcy.radial_segments = 16
		foot.mesh = fcy
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.albedo_color = Color(col, 0.55)
		foot.material_override = fm
		foot.position = Vector3(0, -float(pz) * TAC_SCALE + 0.02, 0)
		n.add_child(foot)
	if not known:
		n.add_child(_stem(Vector3(0, -5 * TAC_SCALE, 0), Vector3(0, 5 * TAC_SCALE, 0), Color(col, 0.12), 0.05))
	var body := Node3D.new()
	body.name = "corpo"
	n.add_child(body)
	if style == "originale":
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
			model.name = "porta"
		else:
			model = Ships.fleet(u["race"], col, 1, mode == "battle")
			model.scale = Vector3.ONE * 2.4
		body.add_child(model)
		if dis or neut or not known:
			Ships.dim(model)
	var tag := Label3D.new()
	var extra := []
	if not known:
		extra.append("quota ?")
	if u["kind"] == "sf" and mode == "battle":
		extra.append("batt.")
	if dis and u["kind"] == "sf":
		extra.append("disgr.")
	if neut:
		extra.append("neutr.")
	tag.text = (("StarGate " if u["kind"] == "gate" else "") + str(u["label"]) + ("  " + " ".join(extra) if not extra.is_empty() else "")).strip_edges()
	tag.font = UI.font_head
	tag.font_size = 28
	tag.pixel_size = 0.0006
	tag.fixed_size = true
	tag.modulate = col.lightened(0.45)
	tag.outline_size = 12
	tag.outline_modulate = Color(0, 0, 0, 0.95)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.render_priority = 10
	tag.outline_render_priority = 9
	tag.position = Vector3(0, 1.3 if u["kind"] == "gate" else 0.75, 0)
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
## come disegnare i volumi delle proiezioni: "prismi" (esagoni pieni 3D tenui), "piatti" (esagoni
## piatti al loro livello), "ragnatela" (linee fra i centri delle celle vicine), "sfere" (una pallina
## al centro di ogni cella); più chiaro dove il colpo arriva più forte
static var cast_style := "ragnatela"
var _last_casts: Array = []

func set_cast_style(st: String) -> void:
	cast_style = st
	show_casts(_last_casts)


func show_casts(casts: Array) -> void:
	_last_casts = casts
	for c in tac_over.get_children():
		if c.name != "cursore":
			c.queue_free()
	for c in casts:
		var vol: Dictionary = Hex.cast_volume(c["from"], int(c["cl"]), int(c["zs"]))
		var col: Color = c.get("col", UI.YELLOW)
		var pts := int(c.get("p", 32))
		var eff := {}
		for p in vol:
			var e := pts >> int(vol[p])
			if e > 0:
				eff[p] = float(e) / float(pts)
		match cast_style:
			"ragnatela":
				_cast_web(eff, col)
			"sfere":
				_cast_spheres(eff, col)
			_:
				_cast_hexes(eff, col, cast_style == "prismi")


func _cast_mat(col: Color, a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(col, a)
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _cast_hexes(eff: Dictionary, col: Color, full: bool) -> void:
	for p in eff:
		var f: float = eff[p]
		var mi := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = (0.5 if full else 0.42) * TAC_SCALE
		cy.bottom_radius = cy.top_radius
		cy.height = 0.92 * TAC_SCALE if full else 0.06
		cy.radial_segments = 6
		cy.rings = 1
		mi.mesh = cy
		mi.material_override = _cast_mat(col, (0.012 + 0.05 * f) if full else clampf(0.08 + 0.3 * f, 0.08, 0.38))
		mi.position = tac_world(p)
		mi.rotation.y = deg_to_rad(30)
		tac_over.add_child(mi)


## ragnatela: un segmento fra ogni coppia di celle vicine del volume (sei direzioni sul piano e la
## verticale), con un nodo luminoso in ogni cella
func _cast_web(eff: Dictionary, col: Color) -> void:
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	im.surface_begin(Mesh.PRIMITIVE_LINES, m)
	var n := 0
	for p in eff:
		var nb := []
		for d in [Hex.DIRS[0], Hex.DIRS[1], Hex.DIRS[5]]:
			nb.append(Vector3i(p.x + d.x, p.y + d.y, p.z))
		nb.append(Vector3i(p.x, p.y, p.z + 1))
		for q in nb:
			if not eff.has(q):
				continue
			var a := clampf(0.15 + 0.75 * (float(eff[p]) + float(eff[q])) * 0.5, 0.15, 0.9)
			im.surface_set_color(Color(col, a))
			im.surface_add_vertex(tac_world(p))
			im.surface_set_color(Color(col, a))
			im.surface_add_vertex(tac_world(q))
			n += 1
	if n == 0:
		# volume di una sola cella: un segmentino verticale perché si veda qualcosa
		for p in eff:
			im.surface_set_color(Color(col, 0.8))
			im.surface_add_vertex(tac_world(p) - Vector3(0, 0.3, 0))
			im.surface_set_color(Color(col, 0.8))
			im.surface_add_vertex(tac_world(p) + Vector3(0, 0.3, 0))
	im.surface_end()
	tac_over.add_child(mi)
	_cast_spheres(eff, col, 0.45)


func _cast_spheres(eff: Dictionary, col: Color, k := 1.0) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 10
	sm.rings = 5
	mm.mesh = sm
	mm.instance_count = eff.size()
	var i := 0
	for p in eff:
		var f: float = eff[p]
		var r := (0.12 + 0.28 * f) * k
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * r * 2.0), tac_world(p)))
		mm.set_instance_color(i, Color(col, 0.35 + 0.6 * f))
		i += 1
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mi.material_override = m
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
