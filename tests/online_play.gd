extends SceneTree
## Prova del gioco online: due istanze giocano una partita intera sul finto Firebase
## (tests/firebase_mock.py) con le decisioni prese dall'IA.
## SF_ROLE=host|guest, SF_CODEFILE=file per il codice della stanza, SF_SCN=scenario, SF_FMT=formato.
## Alla fine ognuno stampa l'impronta della partita: devono coincidere.

var main
var t0 := 0
var ai := SFAI.new(1)

func _init() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	t0 = Time.get_ticks_msec()
	_run()

func _wait(s: float) -> void:
	await create_timer(s).timeout

func _run() -> void:
	await _wait(0.5)
	var role := OS.get_environment("SF_ROLE")
	var cf := OS.get_environment("SF_CODEFILE")
	var menu = main.current
	menu.speed = 20.0
	menu.scen_id = int(OS.get_environment("SF_SCN")) if OS.get_environment("SF_SCN") != "" else 2
	menu.fmt = OS.get_environment("SF_FMT") if OS.get_environment("SF_FMT") != "" else "base"
	menu._refresh()
	menu._online_panel()
	menu.on_name.text = "Host" if role == "host" else "Ospite"
	if role == "host":
		menu.host_side = 0
		await menu._online_create()
		var code: String = main.lobby.get("code", "")
		print("SFTEST stanza ", code)
		var f := FileAccess.open(cf, FileAccess.WRITE)
		f.store_string(code)
		f.close()
		while true:
			var room: Dictionary = await main.net.room(code)
			if Net._as_dict(room.get("seats", {})).size() >= 2:
				break
			await _wait(0.5)
		await menu._online_start()
	else:
		var code := ""
		while code == "":
			if FileAccess.file_exists(cf):
				code = FileAccess.get_file_as_string(cf).strip_edges()
			await _wait(0.3)
		print("SFTEST ospite entra in ", code)
		menu.on_code.text = code
		await menu._online_join()
		print("SFTEST ospite: ", menu.on_lbl.text)
	while true:
		await process_frame
		if Time.get_ticks_msec() - t0 > 900000:
			print("SFTEST tempo scaduto")
			quit(2)
			return
		var view = main.current
		if view == null or not ("eng" in view) or view.eng == null:
			continue
		var e: SFEngine = view.eng
		var req: Dictionary = view.req
		if not req.is_empty() and view.online != null and view.online._pending_mine:
			view._provide(ai.decide(e, int(req["seat"]), req))
		if e.phase == "over":
			await _wait(0.5)
			var lf := FileAccess.open("/tmp/sflog_%s.txt" % OS.get_environment("SF_ROLE"), FileAccess.WRITE)
			lf.store_string("\n".join(e.log_lines))
			lf.close()
			print("SFTEST impronta ", view.online.n, " | ", e.fingerprint(), " | ", e.result.get("reason", ""))
			quit(0)
			return
