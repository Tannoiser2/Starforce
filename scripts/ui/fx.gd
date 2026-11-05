extends Node
## Effetti speciali della scena 3D, guidati dai segmenti registrati dal motore:
## - shift: scia luminosa dalla partenza all'arrivo e lampo d'arrivo (rosso per lo spostamento a
##   specchio, viola per la randomizzazione);
## - segment: raggi fra le flotte nella LiteZulu contesa ed esplosioni per le perdite;
## - tac_cast: i volumi delle proiezioni che si accendono sul Tactical Display;
## - tac_result: lampi sulle unità colpite (giallo = disgregata, viola = randomizzata);
## - nova: la stella che esplode; gate_lost: la StarGate che si spegne.

var board: Board3D
var eng: SFEngine


func play(kind: String, seg: Dictionary) -> void:
	if board == null or not is_instance_valid(board):
		return
	match kind:
		"shift":
			for m in seg.get("moves", []):
				_shift(m)
		"segment":
			_battle(seg)
		"combat":
			_alarm(Hex.world(seg["lz"]))
		"nova":
			_nova(Hex.world(seg["lz"]))
		"gate_lost":
			_boom(Hex.world(seg["lz"]), Color("#ff8a3d"), 2.4)
		"xeno_found":
			_ring(Hex.world(seg["lz"]), Color("#ff3030"), 3.0)
		"tac_cast":
			_casts(seg)
		"tac_result":
			_tac_hits(seg)


func _mat(col: Color, add := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


func _shift(m: Dictionary) -> void:
	var a := Hex.world(m["from"])
	var b := Hex.world(m["to"])
	var res: String = m.get("res", "S")
	var col := Color("#9fe8ff")
	if res == "M":
		col = Color("#ff4a3d")
	elif res == "R":
		col = Color("#c060ff")
		b = a + Vector3(0, 1.5, 0)
	# la "finestra" di discontinuità alla partenza e all'arrivo, unita da una scia
	_ring(a, col, 1.2)
	var beam := _beam(a, b, col, 0.07)
	board.fx_root.add_child(beam)
	var tw := beam.create_tween()
	tw.tween_property(beam.material_override, "albedo_color:a", 0.0, 1.1).from(0.9)
	tw.tween_callback(beam.queue_free)
	if res != "R":
		await get_tree().create_timer(0.25).timeout
		_flash(b, col, 1.4)
		_ring(b, col, 1.6)
	if res == "M":
		_flash(Hex.world(m["to"]), Color("#ff4a3d"), 0.8)


func _beam(a: Vector3, b: Vector3, col: Color, w: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = w
	cm.bottom_radius = w
	cm.height = maxf(a.distance_to(b), 0.01)
	cm.radial_segments = 6
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = _mat(Color(col, 0.9))
	mi.position = (a + b) * 0.5
	var dir := (b - a).normalized()
	if dir.length() > 0.5 and absf(dir.dot(Vector3.UP)) < 0.999:
		mi.basis = Basis(Quaternion(Vector3.UP, dir))
	return mi


func _flash(p: Vector3, col: Color, size: float) -> void:
	var sp := Sprite3D.new()
	sp.texture = Board3D._glow_tex()
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.modulate = col
	sp.pixel_size = 0.01
	sp.position = p
	board.fx_root.add_child(sp)
	var tw := sp.create_tween()
	tw.set_parallel(true)
	tw.tween_property(sp, "pixel_size", 0.05 * size, 0.6)
	tw.tween_property(sp, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(sp.queue_free)


func _ring(p: Vector3, col: Color, size: float) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 32
	tm.ring_segments = 6
	mi.mesh = tm
	mi.material_override = _mat(Color(col, 0.9))
	mi.position = p
	mi.scale = Vector3.ONE * 0.1
	board.fx_root.add_child(mi)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.9)
	tw.chain().tween_callback(mi.queue_free)


func _boom(p: Vector3, col: Color, size: float) -> void:
	_flash(p, Color(1, 0.9, 0.6), size)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	mi.mesh = sm
	mi.material_override = _mat(Color(col, 0.8))
	mi.position = p
	mi.scale = Vector3.ONE * 0.2
	board.fx_root.add_child(mi)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size, 0.7).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.8)
	tw.chain().tween_callback(mi.queue_free)
	# schegge
	for i in 10:
		var sh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.06, 0.06, 0.06)
		sh.mesh = bm
		sh.material_override = _mat(Color(1, 0.7, 0.3, 1))
		sh.position = p
		board.fx_root.add_child(sh)
		var d := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * size * 0.9
		var t2 := sh.create_tween()
		t2.set_parallel(true)
		t2.tween_property(sh, "position", p + d, 0.8).set_ease(Tween.EASE_OUT)
		t2.tween_property(sh.material_override, "albedo_color:a", 0.0, 0.8)
		t2.chain().tween_callback(sh.queue_free)


func _alarm(p: Vector3) -> void:
	_ring(p, Color("#ff4a3d"), 2.2)
	_flash(p, Color("#ff7a5a"), 1.5)


func _battle(seg: Dictionary) -> void:
	var c := Hex.world(seg["lz"])
	for r in seg.get("res", []):
		var col := board._side_col(int(r["a"]))
		for k in 5:
			var a := c + Vector3(randf_range(-0.7, 0.7), randf_range(0.0, 0.7), randf_range(-0.7, 0.7))
			var b := c + Vector3(randf_range(-0.7, 0.7), randf_range(0.0, 0.7), randf_range(-0.7, 0.7))
			var beam := _beam(a, b, col.lightened(0.3), 0.025)
			board.fx_root.add_child(beam)
			var tw := beam.create_tween()
			tw.tween_interval(0.08 * k)
			tw.tween_property(beam.material_override, "albedo_color:a", 0.0, 0.35).from(1.0)
			tw.tween_callback(beam.queue_free)
		for i in int(r.get("loss", 0)):
			await get_tree().create_timer(0.25).timeout
			_boom(c + Vector3(randf_range(-0.6, 0.6), 0.3, randf_range(-0.6, 0.6)), Color("#ff8a3d"), 1.2)


func _nova(p: Vector3) -> void:
	_flash(p, Color(1, 1, 0.9), 8.0)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 32
	sm.rings = 16
	mi.mesh = sm
	mi.material_override = _mat(Color(1, 0.75, 0.4, 0.9))
	mi.position = p
	board.fx_root.add_child(mi)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 9.0, 2.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi.material_override, "albedo_color", Color(1, 0.2, 0.1, 0.0), 2.4)
	tw.chain().tween_callback(mi.queue_free)
	_ring(p, Color(1, 0.6, 0.3), 12.0)


func _casts(seg: Dictionary) -> void:
	var lst := []
	for c in seg.get("casts", []):
		var e: Dictionary = c.duplicate()
		e["col"] = board._side_col(int(c["side"]))
		lst.append(e)
	board.show_casts(lst)
	for c in seg.get("casts", []):
		var a: Vector3 = board.tac_world(c["from"])
		_flash(a, board._side_col(int(c["side"])).lightened(0.4), 1.2)
	await get_tree().create_timer(1.6).timeout
	if is_instance_valid(board):
		board.show_casts([])


func _tac_hits(seg: Dictionary) -> void:
	if eng.tac == null:
		return
	for o in seg.get("out", []):
		var id: String = o["id"]
		if not eng.tac.tu.has(id):
			continue
		var p: Vector3 = board.tac_world(eng.tac.tu[id]["pos"])
		match str(o["res"]):
			"D":
				_flash(p, Color(1, 0.9, 0.2), 2.0)
				_ring(p, Color(1, 0.9, 0.2), 1.5)
			"R":
				_boom(p, Color("#c060ff"), 2.0)
			_:
				_flash(p, Color(0.6, 0.9, 1.0, 0.6), 1.0)
