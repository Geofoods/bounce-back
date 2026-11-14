extends SceneTree

func _initialize() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game._start_game()
	await process_frame
	var view: Rect2 = game._view_rect()
	print("start targets=", game.targets.size(), " bumpers=", game.bumpers.size())
	print("onscreen=", _count(game, view))

	# Teleport the ball to a far corner; streaming should unload old balls.
	game.ball_pos = Vector2(3600.0, 1990.0)
	game.cam = game.ball_pos
	game.stream_t = 0.0
	game._update_streaming(0.5)
	game._update_streaming(0.5)
	var far_view: Rect2 = game._view_rect()
	print("after teleport targets=", game.targets.size(), " onscreen=", _count(game, far_view))
	var outside := 0
	for tg in game.targets:
		if not far_view.grow(1100.0).has_point(tg.pos):
			outside += 1
	print("outside keep box=", outside)

	for i in 40:
		if game.targets.size() > 0:
			game._kill_target(0, 1400.0)
	print("after 40 kills targets=", game.targets.size(), " kills=", game.kills)
	quit()


func _count(game, view: Rect2) -> int:
	var n := 0
	for tg in game.targets:
		if view.has_point(tg.pos):
			n += 1
	return n
