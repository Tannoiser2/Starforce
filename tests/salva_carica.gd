extends SceneTree
## Un salvataggio ricaricato deve rigiocare la stessa partita: si gioca IA contro IA registrando le
## decisioni, poi si rigioca con le decisioni precaricate e si confrontano le impronte.

func _init() -> void:
	for scn in [3, 5, 13]:
		var fmt := "modificato" if scn == 13 else "avanzato"
		var cfg := {"scenario": scn, "mode": fmt, "seed": 99, "max_turns": 25,
			"seats": [{"name": "", "ai": true, "level": 1}, {"name": "", "ai": true, "level": 1}]}
		var a := SFEngine.new()
		a.headless = true
		a.anim = 0.0
		a.ai_delay = 0.0
		a.setup(cfg)
		root.add_child(a)
		await a.run()
		var acts = str_to_var(var_to_str(a.rec_acts))
		var b := SFEngine.new()
		b.headless = true
		b.anim = 0.0
		b.ai_delay = 0.0
		b.setup(cfg)
		b.preload_acts = acts
		root.add_child(b)
		await b.run()
		print("SALVA %d: %s  /  %s  %s" % [scn, a.fingerprint(), b.fingerprint(), "UGUALI" if a.fingerprint() == b.fingerprint() else "DIVERSE"])
	quit()
