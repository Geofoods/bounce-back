extends SceneTree

func _initialize() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var host = scene.instantiate()
	root.add_child(host)
	await process_frame
	host.net_mode = "host"
	host.mode = "play"
	host._duel_reset([10, 20, 30, 40])
	print("CHECK4 reset n=", host.duel_ids.size(), " my=", host.duel_my_id, " foes=", host.duel_foes.size(), " chests=", host.duel_chests.size(), " balls=", host.targets.size())
	var spread_ok := true
	for i in host.duel_ids.size():
		for j in range(i + 1, host.duel_ids.size()):
			var a: Dictionary = host._duel_all()[i]
			var b: Dictionary = host._duel_all()[j]
			if (a["pos"] as Vector2).distance_to(b["pos"] as Vector2) < 400.0:
				spread_ok = false
	print("CHECK4 spread_ok=", spread_ok)
	# Pairwise clash: per closing convention, the still fighter takes the hit.
	var f0: Dictionary = host._duel_all()[0]
	var f1: Dictionary = host._duel_all()[1]
	f0["pos"] = Vector2(1000.0, 1000.0)
	f1["pos"] = Vector2(1000.0, 1000.0)
	f0["vel"] = Vector2.ZERO
	f1["vel"] = Vector2(900.0, 0.0)
	host._duel_fighter_clash()
	print("CHECK4 clash still_hp=", int(f0["hp"]), " fast_hp=", int(f1["hp"]), " (expect 92 100)")
	# Time winner: top HP wins, ties draw.
	f0["hp"] = 80
	f1["hp"] = 80
	(host._duel_all()[2])["hp"] = 80
	(host._duel_all()[3])["hp"] = 10
	print("CHECK4 time_winner_tie=", host._duel_time_winner(), " (expect -1)")
	f0["hp"] = 85
	print("CHECK4 time_winner=", host._duel_time_winner(), " (expect 0)")
	# Snapshot round-trip into a fake client holding slot 1.
	var cli = scene.instantiate()
	root.add_child(cli)
	await process_frame
	cli.net_mode = "client"
	cli.mode = "play"
	cli._duel_reset([10, 20, 30, 40])
	cli.duel_my_id = 1
	cli.duel_me = cli._duel_all()[1]
	cli.duel_foes = [cli._duel_all()[0], cli._duel_all()[2], cli._duel_all()[3]]
	cli.duel_foe_goals = [(cli.duel_foes[0] as Dictionary)["pos"], (cli.duel_foes[1] as Dictionary)["pos"], (cli.duel_foes[2] as Dictionary)["pos"]]
	var fighters: Array = []
	for f in host._duel_all():
		fighters.append([(f as Dictionary)["pos"], (f as Dictionary)["vel"], (f as Dictionary)["hp"], (f as Dictionary)["gun"], (f as Dictionary)["ready"]])
	cli._net_duel([fighters, [], [], [], 55.0, [1.0, 2.0, 3.0, 1.0]])
	var h1: int = (host._duel_all()[1] as Dictionary)["hp"]
	print("CHECK4 client my_hp=", int(cli.duel_me["hp"]), " host_slot1=", h1, " match=", int(cli.duel_me["hp"]) == h1, " balls=", cli.targets.size(), " time=", cli.time_left)
	# Elimination: two KOs keep the match alive, third KO ends it.
	host.duel_over = false
	(host._duel_all()[2])["hp"] = 0
	(host._duel_all()[3])["hp"] = 0
	for i in 10:
		await process_frame
	print("CHECK4 two_down over=", host.duel_over, " (expect false)")
	f1["hp"] = 0
	for i in 10:
		await process_frame
	print("CHECK4 last_out over=", host.duel_over, " winner=", host.duel_winner, " (expect true 0)")
	# Solo ball density.
	host.mode = "play"
	host.net_mode = "off"
	host._start_game()
	await process_frame
	print("CHECK4 solo balls=", host.targets.size(), " bumpers=", host.bumpers.size())
	print("CHECK4 done")
	quit()
