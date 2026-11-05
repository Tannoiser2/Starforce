extends SceneTree
## Prova del tutorial: simula i clic del giocatore e controlla che i passi avanzino.
## godot --path . -s tests/tutorial.gd -- [file.png]

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(1920, 1080)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_game({"scenario": 1, "mode": "base", "tutorial": true,
		"seats": [{"name": "", "ai": false, "level": 1}, {"name": "", "ai": true, "level": 1}],
		"style": "reborn", "anim": 4.0, "ai_delay": 0.1, "seed": 2341})
	await create_timer(1.5).timeout
	var g = main.current
	var tut = null
	for c in g.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("tutorial.gd"):
			tut = c
	assert(tut != null)
	for i in 4:
		print("passo ", tut.step, ": ", tut.title_l.text)
		tut._next()
	await create_timer(0.5).timeout
	print("passo ", tut.step, ": ", tut.title_l.text)
	var mine: Array = g.eng.live(0, "sf")
	g._select_sf(mine[0]["id"])
	await create_timer(0.6).timeout
	print("passo ", tut.step, ": ", tut.title_l.text)
	var ac: Vector3i = tut._ac()
	g._on_pick_hex(Hex.hexof(ac) * 1000 + 500 + ac.z)
	await create_timer(0.6).timeout
	if a.size() > 0:
		await create_timer(0.5).timeout
		root.get_viewport().get_texture().get_image().save_png(a[0])
	print("passo ", tut.step, ": ", tut.title_l.text)
	for k in [1, 2]:
		g._select_sf(mine[k]["id"])
		g._on_pick_hex(Hex.hexof(ac) * 1000 + 500 + ac.z)
	await create_timer(0.6).timeout
	print("passo ", tut.step, ": ", tut.title_l.text)
	g._provide(g.plot.duplicate(true))
	for w in 60:
		await create_timer(0.5).timeout
		if not is_instance_valid(tut):
			print("tutorial chiuso")
			break
		if g.req.get("type", "") == "alloc":
			print("passo ", tut.step, ": ", tut.title_l.text, " (combattimento)")
			g._alloc_done()
		elif g.req.get("type", "") == "plot":
			print("passo ", tut.step, ": ", tut.title_l.text, " | turno ", g.eng.turn)
			break
	if is_instance_valid(tut):
		print("finale: passo ", tut.step, ": ", tut.title_l.text)
	quit()
