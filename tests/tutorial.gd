extends SceneTree
## Prova dei tutorial: simula i clic del giocatore e controlla che i passi avanzino.
## godot --path . -s tests/tutorial.gd -- lezione [file.png]

var g
var tut

func _log() -> void:
	if is_instance_valid(tut):
		print("  [", tut.step, "] ", tut.title_l.text, "  req=", g.req.get("type", ""), " turno=", g.eng.turn, " tt=", g.eng.tac.tt if g.eng.tac != null else 0)

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var n := int(a[0]) if a.size() > 0 else 1
	root.size = Vector2i(1920, 1080)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var cfg: Dictionary = load("res://scripts/ui/tutorial.gd").game_config(n)
	cfg["anim"] = 6.0
	cfg["ai_delay"] = 0.05
	main.start_game(cfg)
	await create_timer(1.0).timeout
	g = main.current
	for c in g.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("tutorial.gd"):
			tut = c
	print("lezione ", n, " passi ", tut.steps.size())
	var shot_done := false
	for w in 400:
		await create_timer(0.3).timeout
		if not is_instance_valid(tut):
			print("tutorial finito")
			break
		var s: Dictionary = tut.steps[tut.step]
		var wt := str(s.get("wait", ""))
		_log()
		if a.size() > 1 and not shot_done and wt in ["move", "dest_ei"]:
			shot_done = true
			await create_timer(0.6).timeout
			root.get_viewport().get_texture().get_image().save_png(a[1])
		var r: String = g.req.get("type", "")
		if wt == "":
			tut._next()
			continue
		if r == "plot":
			var mine: Array = g.eng.live(0, "sf")
			var target = tut._star_lz(1821) if n != 3 else tut._star_lz(2523)
			match wt:
				"sel":
					g._select_sf(mine[0]["id"])
				"dest1", "dest_ei":
					g._select_sf(mine[0]["id"])
					g._on_pick_hex(Hex.hexof(target) * 1000 + 500 + target.z)
				"dest3", "dest_ei2":
					for k in (3 if wt == "dest3" else 2):
						g._select_sf(mine[k]["id"])
						g._on_pick_hex(Hex.hexof(target) * 1000 + 500 + target.z)
				"enhance":
					g.plot[mine[3]["id"]] = {"c": "E", "to": mine[3]["lz"]}
				_:
					g._provide(g.plot.duplicate(true))
		elif r == "alloc":
			g._alloc_done()
		elif r == "tdeploy":
			g._provide(g.dep.duplicate(true))
		elif r == "tplot":
			var ai: Dictionary = g.eng.ais[g.seat].tplot(g.eng, g.seat, g.req)
			if wt == "mode":
				for id in g.tplan:
					if g.tplan[id].has("a1"):
						g.tplan[id]["a1"] = {"k": "M"}
			elif wt in ["move", "cast"]:
				for id in ai:
					if g.tplan.has(id):
						g.tplan[id] = ai[id]
				for id in g.tplan:
					if g.tplan[id].has("a2") and str(g.tplan[id]["a2"].get("k", "")) != "C":
						g.tplan[id]["a2"] = {"k": "C", "p": 16, "cl": 3, "zs": 1}
				if wt == "move":
					print("    piano IA: ", g.tplan)
			else:
				g._provide(g.tplan.duplicate(true))
		elif r == "xsign":
			g._provide(1)
	_log()
	quit()
