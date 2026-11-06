extends SceneTree
## Replay con battaglie tattiche e finestra delle tabelle: gioca una partita avanzata fra IA,
## poi apre il replay su una proiezione e salva le schermate (serve xvfb-run).
## godot --path . -s tests/replay_tac.gd -- [scenario] [cartella]

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var scn := int(a[0]) if a.size() > 0 else 1
	var out := a[1] if a.size() > 1 else "/tmp"
	root.size = Vector2i(1920, 1080)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var n: int = SFEngine.D.scenario(scn)["lati"].size()
	var seats := []
	for i in n:
		seats.append({"name": "", "ai": true, "level": 1})
	main.start_game({"scenario": scn, "mode": "avanzato", "seats": seats, "style": "reborn", "anim": 30.0, "ai_delay": 0.0, "seed": 3})
	await process_frame
	var g = main.current
	# tabelle durante la partita
	await create_timer(2.0).timeout
	g.show_tables("spostamenti")
	await create_timer(0.8).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/tab_spost.png")
	for c in g.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("tables_view.gd"):
			c.tab = "tattico"
			c._build()
	await create_timer(0.8).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/tab_tatt.png")
	for c in g.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("tables_view.gd"):
			c.queue_free()
	for w in 900:
		await create_timer(0.2).timeout
		if g.eng.over:
			break
	print("finita: ", g.eng.over, " segmenti ", g.eng.history.size())
	var kinds := {}
	for s in g.eng.history:
		kinds[s["k"]] = int(kinds.get(s["k"], 0)) + 1
	print(kinds)
	await create_timer(1.0).timeout
	g._start_replay()
	await create_timer(0.3).timeout
	g.replay_play = false
	var idx := -1
	for i in g.eng.history.size():
		if g.eng.history[i]["k"] == "tac_cast":
			idx = i
			break
	print("prima proiezione al segmento ", idx)
	if idx >= 0:
		g.replay_i = idx - 1
		var lab = null
		for c in g.act_box.get_children():
			if c is Label and c.text.begins_with("Turno"):
				lab = c
		g._replay_show(idx - 1, g.replay_lab)
		await create_timer(1.0).timeout
		root.get_viewport().get_texture().get_image().save_png(out + "/replay_tac1.png")
		g._replay_show(idx, g.replay_lab)
		await create_timer(0.6).timeout
		root.get_viewport().get_texture().get_image().save_png(out + "/replay_tac2.png")
		print("vista tattica: ", g.board.tactical, " unità ", g.board.tac_units.get_child_count())
	quit()
