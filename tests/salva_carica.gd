extends SceneTree
## Un salvataggio ricaricato deve rigiocare la stessa partita: si gioca IA contro IA registrando le
## decisioni, poi si rigioca con le decisioni precaricate e si confrontano le impronte.

func _init() -> void:
	for spec in [[3, "avanzato", {}], [5, "avanzato", {"riserve": true, "faker": true, "fatica": true, "continuita": true, "gatelink": true}], [13, "modificato", {}], [16, "modificato", {}], [18, "modificato", {}], [20, "avanzato", {}], [100, "avanzato", {}], [13, "avanzato", {}]]:
		var scn: int = spec[0]
		var fmt: String = spec[1]
		var seats := []
		for i in SFEngine.D.scenario(scn)["lati"].size():
			seats.append({"name": "", "ai": true, "level": 1})
		var cfg := {"scenario": scn, "mode": fmt, "seed": 99, "max_turns": 25, "seats": seats, "opzioni": spec[2]}
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
