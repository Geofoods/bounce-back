extends SceneTree

func _initialize() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game._start_game()
	for i in 40:
		await process_frame
	game.charging = true
	game.charge_t = 0.6
	game.mouse_seen = true
	await process_frame
	await process_frame
	print("PLAY DRAW OK loaded=", game.targets.size())
	for i in 6:
		if game.targets.size() > 0:
			game._kill_target(0, 1500.0)
	await process_frame
	game._game_over()
	await process_frame
	await process_frame
	print("OVER DRAW OK")
	quit()
