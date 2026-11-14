extends SceneTree
## Temporary profiler harness (deleted after the optimization pass).
## Samples the engine Performance monitors — the same data the editor's
## Debugger > Monitors tab shows — across fixed scenarios, then
## microbenchmarks the suspect functions with microsecond timing.

var game: Node


func _noop() -> void:
	pass


func _hold_full_charge() -> void:
	game.charging = true
	game.charge_t = 99.0
	game.mouse_seen = true


func _hold_storm() -> void:
	_hold_full_charge()
	if Engine.get_physics_frames() % 15 == 0:
		game._burst(game.ball_pos, Color.WHITE, 120, 420.0)


func _make_storm(n: int) -> void:
	_hold_full_charge()
	if game.get("particles") != null:
		game.set("particles", [])
	if n > 0:
		game._burst(game.ball_pos, Color.WHITE, n, 420.0)
		var arr: Array = game.get("particles")
		for p in arr:
			p.life = 9999.0
			p.max_life = 9999.0


func _run(tag: String, frames: int, hold: Callable) -> void:
	var fps := 0.0
	var proc := 0.0
	var phys := 0.0
	var nodes := 0.0
	var dc := 0.0
	var prims := 0.0
	for i in frames:
		hold.call()
		await process_frame
		fps += Performance.get_monitor(Performance.TIME_FPS)
		proc += Performance.get_monitor(Performance.TIME_PROCESS)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		nodes += Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var n := float(frames)
	print("SCEN %s fps=%.1f process_ms=%.3f physics_ms=%.3f nodes=%d drawcalls=%.0f prims=%.0f" % [
		tag, fps / n, proc / n * 1000.0, phys / n * 1000.0,
		int(nodes / n), dc / n, prims / n])


func _bench_predict() -> void:
	game.charging = true
	for c in [0.0, 0.4, 0.8]:
		game.charge_t = c
		var v0: Vector2 = Vector2.RIGHT * game._charge_power()
		var t0 := Time.get_ticks_usec()
		for i in 300:
			game._predict_arc(v0)
		var dt := Time.get_ticks_usec() - t0
		print("BENCH predict charge_t=%.1f power=%.0f total_ms=%.2f per_call_us=%.1f path_len=%d" % [
			c, v0.length(), dt / 1000.0, float(dt) / 300.0, game._predict_arc(v0).size()])
	game.charge_t = 0.0
	game.charging = false


func _bench_particles() -> void:
	for target in [0, 350, 700]:
		if game.get("particles") != null:
			game.set("particles", [])
		if target > 0:
			game._burst(game.ball_pos, Color.WHITE, target, 420.0)
		var t0 := Time.get_ticks_usec()
		for i in 100:
			game._update_particles(1.0 / 60.0)
		var dt := Time.get_ticks_usec() - t0
		var final := -1
		if game.get("particles") != null:
			final = (game.get("particles") as Array).size()
		print("BENCH particles target=%d final=%d total_ms=%.2f per_call_us=%.1f" % [
			target, final, dt / 1000.0, float(dt) / 100.0])


func _initialize() -> void:
	print("PROFILER os=", OS.get_name(), " display=", DisplayServer.get_name())
	var scene: PackedScene = load("res://main.tscn")
	game = scene.instantiate()
	root.add_child(game)
	for i in 60:
		await process_frame
	await _run("title", 120, _noop)
	game._start_game()
	for i in 60:
		await process_frame
	await _run("idle", 120, _noop)
	await _run("charge", 120, _hold_full_charge)
	_make_storm(700)
	await _run("storm700", 120, _hold_full_charge)
	game.visible = false
	await _run("storm700_hidden", 120, _hold_full_charge)
	game.visible = true
	_make_storm(200)
	await _run("storm200", 120, _hold_full_charge)
	_make_storm(0)
	await _run("charge2", 120, _hold_full_charge)
	game.charging = false
	game.charge_t = 0.0
	await _run("idle2", 120, _noop)
	print("PROFILER done")
	quit()
