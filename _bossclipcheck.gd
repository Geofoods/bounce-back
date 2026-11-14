extends SceneTree
## Temporary check: (1) deep overlap under mercy pushes the ball out instead
## of clipping; (2) marginal hits still wound-and-escape; (3) a passive ball
## is still caught. Deleted after verification.

func _setup(game) -> void:
	game._start_game()
	game.ball_pos = Vector2(1920.0, 1280.0)
	game.ball_vel = Vector2.ZERO
	game.score = 5000
	for i in 5:
		await process_frame
	game.boss.fire_t = 999.0
	game.boss_shots.clear()


func _initialize() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	# 1: deep overlap with mercy up: must be separated, never stuck, no death.
	await _setup(game)
	game.boss.mercy_t = 1.0
	game.ball_pos = game.boss.pos + Vector2(0.0, 30.0)
	game.ball_vel = Vector2.ZERO
	for i in 5:
		await process_frame
	var d1: float = game.ball_pos.distance_to(game.boss.pos)
	print("CLIP separated dist=%.1f (expect >=101) mode=%s" % [d1, game.mode])
	# 2: marginal hit from below wounds and escapes.
	await _setup(game)
	game.ball_pos = game.boss.pos + Vector2(0.0, 100.0)
	game.ball_vel = Vector2(0.0, -950.0)
	for i in 30:
		await process_frame
	print("CLIP marginal mode=%s hp=%d (expect play/5)" % [game.mode, game.boss.hp if game.boss != null else -1])
	# 3: passive ball is still caught by the homing boss.
	await _setup(game)
	game.ball_pos = Vector2(1920.0, 1280.0)
	game.ball_vel = Vector2.ZERO
	game.boss.pos = Vector2(1920.0, 980.0)
	for i in 900:
		await process_frame
		if game.mode != "play":
			break
	print("CLIP passive mode=%s (expect over)" % game.mode)
	print("CLIP done")
	quit()
