extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var role := str(args[0]) if not args.is_empty() else "host"
	var scene: PackedScene = load("res://main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	if role == "host":
		game._net_host()
		var waited := 0
		while game.multiplayer.get_peers().is_empty() and waited < 600:
			await process_frame
			waited += 1
		var ids := game._duel_roster()
		game.mode = "net"
		game._net_begin(ids)
		game._net_begin.rpc(ids)
		for i in 500:
			await process_frame
			if game.mode == "play":
				break
		for i in 600:
			await process_frame
		var foe: Dictionary = game.duel_foes[0] if not game.duel_foes.is_empty() else {}
		print("NET4 host peers=", game.multiplayer.get_peers().size(), " ids=", game.duel_ids.size(), " fighters=", 1 + game.duel_foes.size(), " targets=", game.targets.size(), " mode=", game.mode, " foe_ready=", foe.get("ready", "?"), " foe_vel=", foe.get("vel", Vector2.ZERO))
		print("NET4 done host")
	else:
		await process_frame
		await process_frame
		game._net_join("127.0.0.1")
		var waited := 0
		while game.mode != "play" and waited < 2000:
			await process_frame
			waited += 1
		for i in 200:
			await process_frame
		print("NET4 client ids=", game.duel_ids.size(), " my=", game.duel_my_id, " foes=", game.duel_foes.size(), " targets=", game.targets.size(), " time=", snappedf(game.time_left, 0.1), " mode=", game.mode)
		# Launch once: host should see slot 1 flip to spent.
		game.charging = true
		game.charge_t = 0.7
		game.mouse_pos = (game.duel_me["pos"] as Vector2) + Vector2(200.0, -100.0)
		game._fire()
		print("NET4 client fired ready=", game.duel_me["ready"])
		for i in 400:
			await process_frame
		print("NET4 done client")
	quit()
