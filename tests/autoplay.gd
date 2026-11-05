extends SceneTree
## Partite automatiche IA contro IA: tutti gli scenari in tutti i formati.
## Uso: godot --headless --path . -s tests/autoplay.gd -- [scenario] [formato] [seme]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var scns := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 38]
	var modes := ["base", "modificato", "avanzato"]
	var seeds := [1, 2]
	if args.size() >= 1:
		scns = [int(args[0])]
	if args.size() >= 2:
		modes = [args[1]]
	if args.size() >= 3:
		seeds = [int(args[2])]
	var tot := 0
	for s in scns:
		for m in modes:
			for sd in seeds:
				var e := SFEngine.new()
				e.headless = true
				e.ai_delay = 0.0
				e.anim = 0.0
				var n: int = 3 if s in [11, 12] else (1 if s == 38 else 2)
				var seats := []
				for i in n:
					seats.append({"name": "IA", "ai": true, "level": 1})
				e.setup({"scenario": s, "mode": m, "seed": sd, "seats": seats, "max_turns": 40})
				root.add_child(e)
				var t0 := Time.get_ticks_msec()
				await e.run()
				var dt := Time.get_ticks_msec() - t0
				var gl: Array = e.gates_lost
				print("SCN %d %s seed %d: turno %d, vincitore %s, %s | porte perse %s | punti %s | %d ms | log %d" % [s, e.mode, sd, e.turn, str(e.result.get("winner", "?")), e.result.get("reason", ""), str(gl), str(e.vp), dt, e.log_lines.size()])
				if OS.get_environment("DUMP") != "":
					for ln in e.log_lines:
						print("   ", ln)
				tot += 1
				e.queue_free()
	print("FINE ", tot)
	quit()
