extends SceneTree
## Screenshot di una partita (serve un display: xvfb-run).
## godot --path . -s tests/shot.gd -- scenario formato grafica secondi file.png [umano] [menu]

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var scn := int(a[0]) if a.size() > 0 else 3
	var fmt := a[1] if a.size() > 1 else "avanzato"
	var st := a[2] if a.size() > 2 else "reborn"
	var secs := float(a[3]) if a.size() > 3 else 6.0
	var out := a[4] if a.size() > 4 else "/tmp/shot.png"
	var human := a.size() > 5 and a[5] == "1"
	var menu := a.size() > 6 and a[6] == "menu"
	root.size = Vector2i(1920, 1080)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	if not menu:
		var n: int = SFEngine.D.scenario(scn)["lati"].size()
		var seats := []
		for i in n:
			seats.append({"name": "", "ai": not (human and i == 0), "level": 1})
		main.start_game({"scenario": scn, "mode": fmt, "seats": seats, "style": st, "anim": 2.0, "ai_delay": 0.2, "seed": 7})
	await create_timer(secs).timeout
	if a.size() > 6 and a[6] == "plot":
		var g = main.current
		var mine: Array = g.eng.live(0, "sf")
		g._select_sf(mine[0]["id"])
		g._on_pick_hex(2523 * 1000 + 500 - 10)
		g._select_sf(mine[1]["id"])
		g._on_pick_hex(2427 * 1000 + 500 - 18)
		await create_timer(1.0).timeout
	if a.size() > 6 and a[6] == "top":
		main.current.board.set_top_view(true)
		await create_timer(1.5).timeout
	if a.size() > 6 and a[6] == "tac":
		if main.current.eng.tac != null:
			main.current.board.show_tactical(true)
		await create_timer(1.5).timeout
	if a.size() > 6 and a[6] == "orig":
		var g2 = main.current
		g2.board.set_style("originale")
		await create_timer(1.0).timeout
	if main.current != null and main.current.get("board") != null:
		var b = main.current.board
		print("tac units: ", b.tac_units.get_child_count(), " tactical ", b.tactical, " eng.tac ", main.current.eng.tac != null)
		for c in b.tac_units.get_children():
			print("  ", c.name, " ", c.position, " vis ", c.visible)
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("SALVATO ", out)
	quit()
