extends SceneTree
## Prova dell'interfaccia dell'Outleap: un giocatore umano simulato accetta le proposte dell'IA.
func _init() -> void:
	root.size = Vector2i(1600, 900)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_game({"scenario": 101, "mode": "base", "seats": [{"name": "", "ai": false, "level": 1}, {"name": "", "ai": true, "level": 1}], "style": "reborn", "anim": 8.0, "ai_delay": 0.0, "seed": 5})
	var g = main.current
	var seen := {}
	for w in 600:
		await create_timer(0.1).timeout
		if g.eng.over:
			break
		var t: String = g.req.get("type", "")
		if t == "":
			continue
		seen[t] = int(seen.get(t, 0)) + 1
		var r = g.eng.ais[g.seat].decide(g.eng, g.seat, g.req)
		if t == "eco_spend" or t == "eco_org":
			g.eco_sel = null
		g._provide(r)
	print("richieste viste: ", seen, " anno ", g.eng.eco.year, " finita ", g.eng.over, " ", g.eng.result)
	quit()
