extends Node2D
## BOUNCE BACK — hold to charge, release to launch the ball toward the cursor.
## Fast impacts shatter balls, slow ones bounce off. The camera follows the ball
## through a world several screens wide. Everything is drawn in code.
##
## Tuning lives at the top of this file. Nothing else is required to run the game.

# ------------------------------------------------------------------ tuning
const VIEW := Vector2(1280.0, 720.0)
const WORLD := Rect2(0.0, 0.0, 3840.0, 2560.0)   # ~9 screens of playfield
const BALL_R := 15.0

const CAM_LERP := 4.6            # camera follow stiffness (higher = tighter)
const CAM_LOOKAHEAD := 0.26      # how far ahead of the ball the camera leads
const TARGET_POP := 34           # live balls streamed around the camera
const BUMPER_POP := 26           # static bumpers spread across the world

# Balls are spawned this far outside the screen and unloaded once they are
# further away than STREAM_KEEP, so only nearby balls exist at any time.
const STREAM_MARGIN := 620.0
const STREAM_KEEP := 1100.0
const STREAM_INTERVAL := 0.22
const CULL_MARGIN := 150.0       # skip drawing anything beyond the screen edge

const START_TIME := 32.0         # seconds on the clock at the start
const TIME_PER_KILL := 2.4       # seconds added per ball broken
const TIME_CAP := 48.0           # clock can never exceed this

const WALL_REST := 0.97          # energy kept when bouncing off a wall
const BUMPER_REST := 1.06        # bumpers add a little energy (pinball feel)
const SPEED_RETAIN := 0.87       # fraction of speed kept each second
const MAX_SPEED := 2300.0
const MIN_POWER := 470.0         # launch speed of a tap
const MAX_POWER := 1750.0        # launch speed of a full charge
const CHARGE_TIME := 0.8         # seconds to reach full charge
const SLOWMO := 0.30             # world speed while charging
const KILL_SPEED := 240.0        # minimum impact speed for basic targets

# ------------------------------------------------------------------ palette
const BG := Color(0.018, 0.026, 0.052)
const CYAN := Color(0.43, 0.90, 1.0)
const WHITE := Color(0.92, 1.0, 1.0)
const PINK := Color(1.0, 0.30, 0.55)
const GOLD := Color(1.0, 0.77, 0.30)
const PURPLE := Color(0.65, 0.55, 0.98)
const GREEN := Color(0.56, 0.97, 0.76)
const RED := Color(1.0, 0.25, 0.42)
const DIM := Color(0.62, 0.76, 0.95, 0.62)

# ------------------------------------------------------------------ entities
class Bumper:
	var pos: Vector2
	var radius: float
	var flash: float = 0.0
	var phase: float = 0.0

class Target:
	var pos: Vector2
	var vel: Vector2 = Vector2.ZERO
	var radius: float
	var kind: String
	var req: float
	var color: Color
	var phase: float = 0.0
	var flash: float = 0.0
	var slow_cd: float = 0.0
	var spin: float = 0.0

class Particle:
	var pos: Vector2
	var vel: Vector2
	var life: float
	var max_life: float
	var size: float
	var color: Color

class FloatText:
	var pos: Vector2
	var text: String
	var color: Color
	var size: int
	var life: float
	var max_life: float

# ------------------------------------------------------------------ state
var mode: String = "title"          # title | play | over
var kills: int = 0
var score: int = 0
var best: int = 0
var new_best: bool = false
var time_left: float = 0.0
var max_time: float = TIME_CAP
var combo: int = 0
var combo_t: float = 0.0
var shake: float = 0.0
var hitstop: float = 0.0
var banner: String = ""
var banner_t: float = 0.0
var muted: bool = false
var t: float = 0.0

var cam: Vector2 = Vector2.ZERO        # world point shown at screen center
var cam_snap: bool = true
var stream_t: float = 0.0

var ball_pos: Vector2 = Vector2.ZERO
var ball_vel: Vector2 = Vector2.ZERO
var ball_flash: float = 0.0
var trail: Array = []

var charging: bool = false
var charge_t: float = 0.0
var mouse_pos: Vector2 = Vector2.ZERO
var mouse_seen: bool = false

var bumpers: Array = []
var targets: Array = []
var particles: Array = []
var popups: Array = []

var body_font: Font
var bold_font: Font

var streams: Dictionary = {}
var players: Array = []
var sfx_i: int = 0
var last_bounce_ms: int = 0

# ------------------------------------------------------------------ setup
func _ready() -> void:
	randomize()
	_setup_fonts()
	_setup_audio()
	_load_best()
	_enter_title()


func _setup_fonts() -> void:
	body_font = ThemeDB.fallback_font
	var bv := FontVariation.new()
	bv.base_font = body_font
	bv.variation_embolden = 0.75
	bold_font = bv


func _setup_audio() -> void:
	streams["charge"] = _tone(180.0, 330.0, 0.08, "sine", 0.20)
	streams["shoot_low"] = _tone(240.0, 90.0, 0.18, "triangle", 0.28)
	streams["shoot_high"] = _tone(560.0, 150.0, 0.22, "triangle", 0.32)
	streams["bounce"] = _tone(320.0, 190.0, 0.07, "square", 0.10)
	streams["bump"] = _tone(520.0, 760.0, 0.09, "sine", 0.14)
	streams["kill"] = _tone(760.0, 120.0, 0.20, "square", 0.16)
	streams["armor"] = _tone(150.0, 80.0, 0.10, "square", 0.14)
	streams["wave"] = _tone(520.0, 900.0, 0.22, "sine", 0.22)
	streams["over"] = _tone(240.0, 45.0, 0.85, "saw", 0.24)

	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


## Builds a tiny 16-bit mono tone at runtime so the project needs no audio assets.
func _tone(f0: float, f1: float, dur: float, kind: String, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var u := float(i) / float(count)
		phase += TAU * lerpf(f0, f1, u) / float(rate)
		var s := 0.0
		if kind == "sine":
			s = sin(phase)
		elif kind == "triangle":
			s = 2.0 * absf(2.0 * (phase / TAU - floorf(phase / TAU + 0.5))) - 1.0
		elif kind == "square":
			s = 1.0 if sin(phase) >= 0.0 else -1.0
		elif kind == "saw":
			s = 2.0 * (phase / TAU - floorf(phase / TAU + 0.5))
		else:
			s = randf_range(-1.0, 1.0)
		var env := pow(1.0 - u, 1.7)
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _sfx(sound: String, jitter: float = 0.0, vol_db: float = -8.0) -> void:
	if muted or players.is_empty():
		return
	var s: AudioStream = streams.get(sound)
	if s == null:
		return
	var p: AudioStreamPlayer = players[sfx_i]
	sfx_i = (sfx_i + 1) % players.size()
	p.stream = s
	p.pitch_scale = 1.0 + randf_range(-jitter, jitter)
	p.volume_db = vol_db
	p.play()


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://bounce_back.cfg") == OK:
		best = int(cfg.get_value("score", "best", 0))


func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", best)
	cfg.save("user://bounce_back.cfg")


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_seen = true
		return

	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			if mode == "play":
				_begin_charge()
			else:
				_start_game()
		else:
			_fire()
		return

	var key := event as InputEventKey
	if key and not key.echo:
		if key.keycode == KEY_R and key.pressed:
			_start_game()
		elif key.keycode == KEY_M and key.pressed:
			muted = not muted
			if muted:
				for p in players:
					p.stop()
		elif key.keycode == KEY_SPACE:
			if key.pressed:
				if mode == "play":
					if charging:
						_fire()
					else:
						_begin_charge()
				else:
					_start_game()
		elif key.keycode == KEY_ESCAPE and key.pressed:
			get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		charging = false
		charge_t = 0.0


# ------------------------------------------------------------------ flow
func _enter_title() -> void:
	mode = "title"
	ball_pos = WORLD.get_center()
	ball_vel = Vector2.RIGHT.rotated(randf() * TAU) * 300.0
	ball_flash = 0.0
	trail.clear()
	targets.clear()
	bumpers.clear()
	particles.clear()
	popups.clear()
	charging = false
	charge_t = 0.0
	cam = ball_pos
	cam_snap = true
	# A few drifting balls give the title screen some motion behind the text.
	for i in 30:
		var tg := Target.new()
		tg.kind = "drifter"
		tg.radius = randf_range(13.0, 24.0)
		tg.pos = Vector2(
			randf_range(ball_pos.x - 1300.0, ball_pos.x + 1300.0),
			randf_range(ball_pos.y - 900.0, ball_pos.y + 900.0))
		tg.vel = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(18.0, 46.0)
		tg.req = KILL_SPEED
		tg.color = PINK if i % 3 else PURPLE
		tg.phase = randf() * TAU
		tg.spin = randf() * TAU
		targets.append(tg)


func _start_game() -> void:
	mode = "play"
	kills = 0
	score = 0
	new_best = false
	time_left = START_TIME
	max_time = TIME_CAP
	combo = 0
	combo_t = 0.0
	shake = 0.0
	hitstop = 0.0
	banner = ""
	banner_t = 0.0
	charging = false
	charge_t = 0.0
	ball_pos = WORLD.get_center()
	ball_vel = Vector2.RIGHT.rotated(randf() * TAU) * 320.0
	ball_flash = 0.0
	trail.clear()
	particles.clear()
	popups.clear()
	cam = ball_pos
	cam_snap = true
	_populate_world()
	_banner("SMASH THE BALLS")
	_sfx("wave", 0.0, -6.0)


func _game_over() -> void:
	mode = "over"
	charging = false
	charge_t = 0.0
	if score > best:
		best = score
		new_best = true
		_save_best()
	shake = 14.0
	_sfx("over", 0.0, -4.0)


func _banner(text: String) -> void:
	banner = text
	banner_t = 1.3


# ------------------------------------------------------------------ shooting
func _begin_charge() -> void:
	if mode != "play" or charging:
		return
	charging = true
	charge_t = 0.0
	_sfx("charge", 0.0, -14.0)


func _charge_power() -> float:
	var p := clampf(charge_t / CHARGE_TIME, 0.0, 1.0)
	return MIN_POWER + (MAX_POWER - MIN_POWER) * pow(p, 1.35)


func _fire() -> void:
	if not charging:
		return
	charging = false
	if mode != "play":
		charge_t = 0.0
		return
	var p := clampf(charge_t / CHARGE_TIME, 0.0, 1.0)
	var power := _charge_power()
	var dir := mouse_pos - ball_pos
	if dir.length() < 1.0:
		dir = Vector2.RIGHT
	ball_vel = dir.normalized() * power
	trail.clear()
	_burst(ball_pos, CYAN, 14, 240.0)
	shake = maxf(shake, 5.0)
	_sfx("shoot_low" if p < 0.5 else "shoot_high", 0.06, -6.0)
	charge_t = 0.0


# ------------------------------------------------------------------ world
func _difficulty() -> float:
	return clampf(kills / 40.0, 0.0, 1.0)


func _radius_for(kind: String) -> float:
	match kind:
		"armored":
			return randf_range(26.0, 32.0)
		"chaser":
			return randf_range(19.0, 24.0)
		"drifter":
			return randf_range(18.0, 25.0)
		_:
			return randf_range(21.0, 27.0)


func _roll_kind() -> String:
	var d := _difficulty()
	var w_basic := 100.0
	var w_drift := 20.0 + 30.0 * d
	var w_armor := 14.0 + 46.0 * d
	var w_chase := 10.0 + 40.0 * d
	var roll := randf() * (w_basic + w_drift + w_armor + w_chase)
	if roll < w_basic:
		return "basic"
	roll -= w_basic
	if roll < w_drift:
		return "drifter"
	roll -= w_drift
	if roll < w_armor:
		return "armored"
	return "chaser"


## Fills the area around the camera with balls. Only nearby balls stay loaded.
func _populate_world() -> void:
	targets.clear()
	bumpers.clear()

	var guard := 0
	while bumpers.size() < BUMPER_POP and guard < 4000:
		guard += 1
		var br := randf_range(24.0, 46.0)
		var bp := Vector2(
			randf_range(WORLD.position.x + 120.0 + br, WORLD.end.x - 120.0 - br),
			randf_range(WORLD.position.y + 120.0 + br, WORLD.end.y - 120.0 - br))
		if bp.distance_to(ball_pos) < br + BALL_R + 220.0:
			continue
		var free := true
		for b in bumpers:
			if bp.distance_to(b.pos) < b.radius + br + 150.0:
				free = false
				break
		if free:
			var nb := Bumper.new()
			nb.pos = bp
			nb.radius = br
			nb.phase = randf() * TAU
			bumpers.append(nb)

	# A few balls start on screen so there is something to hit immediately;
	# the rest are streamed in just beyond the edges of the view.
	for i in 4:
		_spawn_target(false, _view_rect().grow(-40.0))
	guard = 0
	while targets.size() < TARGET_POP and guard < 80:
		guard += 1
		if not _spawn_target(true, _stream_area()):
			break


## World rectangle in which balls are allowed to spawn while streaming.
func _stream_area() -> Rect2:
	return _view_rect().grow(STREAM_MARGIN).intersection(WORLD.grow(-70.0))


## Unloads balls that are far off screen and refills the ring around the camera.
func _update_streaming(dt: float) -> void:
	stream_t -= dt
	if stream_t > 0.0:
		return
	stream_t = STREAM_INTERVAL

	var keep := _view_rect().grow(STREAM_KEEP)
	for i in range(targets.size() - 1, -1, -1):
		if not keep.has_point(targets[i].pos):
			targets.remove_at(i)

	var guard := 0
	while targets.size() < TARGET_POP and guard < 24:
		guard += 1
		if not _spawn_target(true, _stream_area()):
			break


func _spawn_target(offscreen: bool, area: Rect2) -> bool:
	var kind := _roll_kind()
	var r := _radius_for(kind)
	var pos := Vector2.INF

	if offscreen:
		var view := _view_rect().grow(80.0)
		for i in 5:
			var p := _free_spot(r, area)
			if p != Vector2.INF and not view.has_point(p):
				pos = p
				break
	if pos == Vector2.INF:
		pos = _free_spot(r, area)
	if pos == Vector2.INF:
		return false

	var tg := Target.new()
	tg.kind = kind
	tg.radius = r
	tg.pos = pos
	tg.phase = randf() * TAU
	tg.spin = randf() * TAU
	match kind:
		"armored":
			tg.req = 900.0 + 380.0 * _difficulty()
			tg.color = GOLD
		"chaser":
			tg.req = 150.0
			tg.color = PURPLE
		"drifter":
			tg.req = KILL_SPEED * 1.15
			tg.color = GREEN
			tg.vel = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(38.0, 95.0)
		_:
			tg.req = KILL_SPEED
			tg.color = PINK
	targets.append(tg)
	return true


func _free_spot(r: float, area: Rect2) -> Vector2:
	var pad := 55.0 + r
	for i in 400:
		var pt := Vector2(
			randf_range(area.position.x + pad, area.end.x - pad),
			randf_range(area.position.y + pad, area.end.y - pad))
		if pt.distance_to(ball_pos) < r + BALL_R + 140.0:
			continue
		var free := true
		for b in bumpers:
			if pt.distance_to(b.pos) < b.radius + r + 80.0:
				free = false
				break
		if free:
			for o in targets:
				if pt.distance_to(o.pos) < o.radius + r + 60.0:
					free = false
					break
		if free:
			return pt
	return Vector2.INF


func _kill_target(idx: int, speed: float) -> void:
	var tg = targets[idx]
	targets.remove_at(idx)
	kills += 1
	combo += 1
	combo_t = 2.4
	var mult := minf(1.0 + (combo - 1) * 0.25, 4.0)
	var gain := int(round((80.0 + speed * 0.12) * mult))
	score += gain
	time_left = minf(time_left + TIME_PER_KILL, TIME_CAP)
	_popup(tg.pos, "+%d" % gain, GREEN, 26)
	if combo > 1:
		_popup(tg.pos + Vector2(0.0, -34.0), "x%d" % combo, GOLD, 20)
	_burst(tg.pos, tg.color, 18, 300.0)
	_burst(tg.pos, WHITE, 8, 220.0)
	shake = maxf(shake, 9.0)
	hitstop = 0.055
	_sfx("kill", 0.08, -6.0)
	# Keep the nearby ring stocked, preferring spots you cannot see yet.
	if targets.size() < TARGET_POP:
		_spawn_target(true, _stream_area())


# ------------------------------------------------------------------ simulation
func _physics_process(delta: float) -> void:
	delta = minf(delta, 1.0 / 30.0)
	t += delta
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 40.0)
	if banner_t > 0.0:
		banner_t -= delta

	match mode:
		"title":
			_update_title_ball(delta)
			_update_targets(delta)
			_update_particles(delta)
			_update_popups(delta)
		"over":
			_update_particles(delta)
			_update_popups(delta)
		"play":
			_update_play(delta)

	_update_camera(delta)
	mouse_pos = _screen_to_world(get_viewport().get_mouse_position())
	queue_redraw()


# ------------------------------------------------------------------ camera
## Returns the world-space rectangle currently visible on screen.
func _view_rect() -> Rect2:
	return Rect2(cam - VIEW * 0.5, VIEW)


func _screen_to_world(p: Vector2) -> Vector2:
	return p - VIEW * 0.5 + cam


func _clamp_cam(p: Vector2) -> Vector2:
	var half := VIEW * 0.5
	var c := Vector2(
		clampf(p.x, WORLD.position.x + half.x, WORLD.end.x - half.x),
		clampf(p.y, WORLD.position.y + half.y, WORLD.end.y - half.y))
	if WORLD.size.x < VIEW.x:
		c.x = WORLD.get_center().x
	if WORLD.size.y < VIEW.y:
		c.y = WORLD.get_center().y
	return c


func _update_camera(dt: float) -> void:
	var lead := ball_pos + ball_vel * CAM_LOOKAHEAD
	var target := _clamp_cam(lead)
	if cam_snap:
		cam = target
		cam_snap = false
	else:
		cam = _clamp_cam(cam.lerp(target, 1.0 - exp(-CAM_LERP * dt)))


func _update_title_ball(dt: float) -> void:
	if ball_vel.length() < 80.0:
		ball_vel = Vector2.RIGHT.rotated(randf() * TAU) * 280.0
	ball_pos += ball_vel * dt
	_collide_walls()
	ball_flash = maxf(0.0, ball_flash - dt * 4.0)
	trail.append(ball_pos)
	if trail.size() > 20:
		trail.pop_front()


func _update_play(delta: float) -> void:
	if hitstop > 0.0:
		hitstop -= delta
		_update_particles(delta * 0.2)
		return

	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_game_over()
		return

	if charging:
		charge_t = minf(charge_t + delta, CHARGE_TIME)

	var wdt := delta * (SLOWMO if charging else 1.0)

	if combo_t > 0.0:
		combo_t -= delta
		if combo_t <= 0.0:
			combo = 0

	ball_flash = maxf(0.0, ball_flash - wdt * 4.0)
	ball_vel *= pow(SPEED_RETAIN, wdt)

	_step_ball(wdt)
	_update_targets(wdt)
	_update_streaming(delta)
	_update_bumpers(delta)
	_update_particles(wdt)
	_update_popups(delta)


func _update_targets(dt: float) -> void:
	var chase_speed := 72.0 + minf(kills * 2.2, 110.0)
	for tg in targets:
		tg.phase += dt * 2.0
		tg.spin += dt * (2.4 if tg.kind == "chaser" else 1.1)
		tg.flash = maxf(0.0, tg.flash - dt * 5.0)
		tg.slow_cd = maxf(0.0, tg.slow_cd - dt)

		if tg.kind == "chaser":
			var dir: Vector2 = ball_pos - tg.pos
			if dir.length() > 1.0:
				tg.pos += dir.normalized() * chase_speed * dt
		elif tg.kind == "drifter":
			tg.pos += tg.vel * dt
			if tg.pos.x < WORLD.position.x + tg.radius or tg.pos.x > WORLD.end.x - tg.radius:
				tg.vel.x = -tg.vel.x
			if tg.pos.y < WORLD.position.y + tg.radius or tg.pos.y > WORLD.end.y - tg.radius:
				tg.vel.y = -tg.vel.y

		tg.pos.x = clampf(tg.pos.x, WORLD.position.x + tg.radius, WORLD.end.x - tg.radius)
		tg.pos.y = clampf(tg.pos.y, WORLD.position.y + tg.radius, WORLD.end.y - tg.radius)


func _update_bumpers(dt: float) -> void:
	for b in bumpers:
		b.phase += dt
		b.flash = maxf(0.0, b.flash - dt * 3.0)


func _step_ball(dt: float) -> void:
	var speed := ball_vel.length()
	var steps := clampi(int(ceil(speed * dt / (BALL_R * 0.5))), 1, 12)
	var h := dt / float(steps)
	for i in steps:
		ball_pos += ball_vel * h
		_collide_walls()
		_collide_bumpers()
		_collide_targets()
	trail.append(ball_pos)
	if trail.size() > 26:
		trail.pop_front()


func _collide_walls() -> void:
	var min_x := WORLD.position.x + BALL_R
	var max_x := WORLD.end.x - BALL_R
	var min_y := WORLD.position.y + BALL_R
	var max_y := WORLD.end.y - BALL_R

	if ball_pos.x < min_x:
		ball_pos.x = min_x
		if ball_vel.x < 0.0:
			ball_vel.x = -ball_vel.x * WALL_REST
			_on_bounce(Vector2(min_x, ball_pos.y), absf(ball_vel.x))
	elif ball_pos.x > max_x:
		ball_pos.x = max_x
		if ball_vel.x > 0.0:
			ball_vel.x = -ball_vel.x * WALL_REST
			_on_bounce(Vector2(max_x, ball_pos.y), absf(ball_vel.x))

	if ball_pos.y < min_y:
		ball_pos.y = min_y
		if ball_vel.y < 0.0:
			ball_vel.y = -ball_vel.y * WALL_REST
			_on_bounce(Vector2(ball_pos.x, min_y), absf(ball_vel.y))
	elif ball_pos.y > max_y:
		ball_pos.y = max_y
		if ball_vel.y > 0.0:
			ball_vel.y = -ball_vel.y * WALL_REST
			_on_bounce(Vector2(ball_pos.x, max_y), absf(ball_vel.y))


func _collide_bumpers() -> void:
	for b in bumpers:
		var d: Vector2 = ball_pos - b.pos
		var rr: float = b.radius + BALL_R
		var dist2 := d.length_squared()
		if dist2 >= rr * rr:
			continue
		var n := d.normalized() if dist2 > 0.0001 else Vector2.RIGHT
		ball_pos = b.pos + n * rr
		var vn := ball_vel.dot(n)
		if vn < 0.0:
			ball_vel -= (1.0 + BUMPER_REST) * vn * n
			_clamp_speed()
			b.flash = 1.0
			_on_bounce(b.pos + n * b.radius, absf(vn))
			_sfx("bump", 0.10, -14.0)


func _collide_targets() -> void:
	for i in range(targets.size() - 1, -1, -1):
		var tg = targets[i]
		var d: Vector2 = ball_pos - tg.pos
		var rr: float = tg.radius + BALL_R
		var dist2 := d.length_squared()
		if dist2 >= rr * rr:
			continue
		var n := d.normalized() if dist2 > 0.0001 else Vector2.RIGHT
		var speed := ball_vel.length()
		if speed >= tg.req:
			_kill_target(i, speed)
			return
		# too slow: the target bounces you back
		ball_pos = tg.pos + n * rr
		var vn := ball_vel.dot(n)
		if vn < 0.0:
			ball_vel -= 1.7 * vn * n
		tg.flash = 1.0
		if tg.slow_cd <= 0.0:
			tg.slow_cd = 0.7
			_popup(tg.pos + Vector2(0.0, -tg.radius - 14.0), "TOO SLOW", RED, 16)
			_burst(ball_pos - n * BALL_R, tg.color, 6, 140.0)
			shake = maxf(shake, 3.0)
			_sfx("armor", 0.1, -10.0)
		return


func _on_bounce(at: Vector2, strength: float) -> void:
	var s := clampf(strength / 1400.0, 0.0, 1.0)
	ball_flash = maxf(ball_flash, 0.4 + s)
	_burst(at, CYAN, 2 + int(s * 6.0), 60.0 + s * 240.0)
	shake = maxf(shake, s * 5.0)
	var now := Time.get_ticks_msec()
	if now - last_bounce_ms > 45:
		last_bounce_ms = now
		_sfx("bounce", 0.12, -28.0 + s * 18.0)


func _clamp_speed() -> void:
	var s := ball_vel.length()
	if s > MAX_SPEED:
		ball_vel *= MAX_SPEED / s


# ------------------------------------------------------------------ fx
func _burst(at: Vector2, color: Color, count: int, speed: float) -> void:
	for i in count:
		var p := Particle.new()
		p.pos = at
		var a := randf() * TAU
		p.vel = Vector2(cos(a), sin(a)) * speed * randf_range(0.35, 1.0)
		p.max_life = randf_range(0.25, 0.55)
		p.life = p.max_life
		p.size = randf_range(2.0, 4.5)
		p.color = color
		particles.append(p)
	if particles.size() > 700:
		particles = particles.slice(particles.size() - 700)


func _update_particles(dt: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p = particles[i]
		p.pos += p.vel * dt
		p.vel *= pow(0.02, dt)
		p.life -= dt
		if p.life <= 0.0:
			particles.remove_at(i)


func _popup(at: Vector2, text: String, color: Color, size: int) -> void:
	var p := FloatText.new()
	p.pos = at
	p.text = text
	p.color = color
	p.size = size
	p.max_life = 0.9
	p.life = 0.9
	popups.append(p)


func _update_popups(dt: float) -> void:
	for i in range(popups.size() - 1, -1, -1):
		var p = popups[i]
		p.pos.y -= 44.0 * dt
		p.life -= dt
		if p.life <= 0.0:
			popups.remove_at(i)


# ------------------------------------------------------------------ rendering
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), BG)

	var off := Vector2.ZERO
	if shake > 0.4:
		off = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	# Everything below is drawn in world space; the camera slides it around.
	draw_set_transform(-cam + VIEW * 0.5 + off, 0.0, Vector2.ONE)

	_draw_world_floor()
	_draw_grid()
	_draw_arena()
	_draw_bumpers()
	_draw_targets()
	if charging and mode == "play":
		_draw_aim()
	_draw_particles()
	_draw_ball()
	_draw_popups()
	_draw_reticle()

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if mode != "title":
		_draw_hud()
		if mode == "play":
			_draw_minimap()
	if mode == "title":
		_draw_title()
	elif mode == "over":
		_draw_game_over()


func _draw_world_floor() -> void:
	draw_rect(WORLD, Color(0.024, 0.036, 0.070))


func _draw_grid() -> void:
	var view := _view_rect()
	var top := maxf(view.position.y, WORLD.position.y)
	var bot := minf(view.end.y, WORLD.end.y)
	var left := maxf(view.position.x, WORLD.position.x)
	var right := minf(view.end.x, WORLD.end.x)
	if right <= left or bot <= top:
		return

	var step := 64.0
	var x := floorf(left / step) * step
	while x <= right:
		var major := int(round(x)) % 256 == 0
		draw_line(Vector2(x, top), Vector2(x, bot),
			Color(0.32, 0.52, 1.0, 0.10 if major else 0.045), 1.0)
		x += step
	var y := floorf(top / step) * step
	while y <= bot:
		var major := int(round(y)) % 256 == 0
		draw_line(Vector2(left, y), Vector2(right, y),
			Color(0.32, 0.52, 1.0, 0.10 if major else 0.045), 1.0)
		y += step


func _draw_arena() -> void:
	var pulse := 0.5 + 0.5 * sin(t * 2.0)
	draw_rect(WORLD, Color(0.30, 0.70, 1.0, 0.03 + pulse * 0.02), false, 18.0)
	draw_rect(WORLD, Color(0.45, 0.80, 1.0, 0.30), false, 2.0)

	# Depth ticks make it obvious where the world edge is while scrolling.
	for x in range(0, int(WORLD.size.x) + 1, 256):
		var on_edge := x == 0 or x >= int(WORLD.size.x) - 1
		var c := Color(0.55, 0.90, 1.0, 0.45 if on_edge else 0.16)
		draw_line(Vector2(WORLD.position.x + x, WORLD.position.y),
			Vector2(WORLD.position.x + x, WORLD.position.y + (26.0 if on_edge else 14.0)), c, 2.0, true)
		draw_line(Vector2(WORLD.position.x + x, WORLD.end.y),
			Vector2(WORLD.position.x + x, WORLD.end.y - (26.0 if on_edge else 14.0)), c, 2.0, true)
	for y in range(0, int(WORLD.size.y) + 1, 256):
		var on_edge := y == 0 or y >= int(WORLD.size.y) - 1
		var c := Color(0.55, 0.90, 1.0, 0.45 if on_edge else 0.16)
		draw_line(Vector2(WORLD.position.x, WORLD.position.y + y),
			Vector2(WORLD.position.x + (26.0 if on_edge else 14.0), WORLD.position.y + y), c, 2.0, true)
		draw_line(Vector2(WORLD.end.x, WORLD.position.y + y),
			Vector2(WORLD.end.x - (26.0 if on_edge else 14.0), WORLD.position.y + y), c, 2.0, true)

	var c := Color(0.55, 0.90, 1.0, 0.55)
	var l := 54.0
	var p := WORLD.position
	var e := WORLD.end
	draw_line(p, p + Vector2(l, 0.0), c, 3.0, true)
	draw_line(p, p + Vector2(0.0, l), c, 3.0, true)
	draw_line(Vector2(e.x, p.y), Vector2(e.x - l, p.y), c, 3.0, true)
	draw_line(Vector2(e.x, p.y), Vector2(e.x, p.y + l), c, 3.0, true)
	draw_line(Vector2(p.x, e.y), Vector2(p.x + l, e.y), c, 3.0, true)
	draw_line(Vector2(p.x, e.y), Vector2(p.x, e.y - l), c, 3.0, true)
	draw_line(e, e - Vector2(l, 0.0), c, 3.0, true)
	draw_line(e, e - Vector2(0.0, l), c, 3.0, true)


func _draw_bumpers() -> void:
	var vis := _view_rect().grow(CULL_MARGIN)
	for b in bumpers:
		if not vis.has_point(b.pos):
			continue
		var f: float = clampf(b.flash, 0.0, 1.0)
		var r: float = b.radius
		var spin: float = b.phase + t * 0.4
		draw_circle(b.pos, r + 8.0 + f * 8.0, Color(0.35, 0.62, 1.0, 0.05 + f * 0.10))
		draw_circle(b.pos, r, Color(0.12, 0.20, 0.42, 0.70))
		var ring := Color(0.42, 0.66, 1.0, 0.55).lerp(WHITE, f)
		draw_arc(b.pos, r, 0.0, TAU, 40, ring, 2.0 + f * 3.0, true)
		for k in 6:
			var a := spin + k * TAU / 6.0
			var inner: Vector2 = b.pos + Vector2(cos(a), sin(a)) * (r * 0.58)
			var outer: Vector2 = b.pos + Vector2(cos(a), sin(a)) * (r * 0.86)
			draw_line(inner, outer, Color(0.45, 0.70, 1.0, 0.20 + f * 0.4), 2.0, true)
		draw_circle(b.pos, r * 0.16, Color(0.65, 0.88, 1.0, 0.25 + f * 0.6))
		draw_arc(b.pos, r * 0.62, 0.0, TAU, 28, Color(0.45, 0.70, 1.0, 0.10), 1.0, true)


func _draw_targets() -> void:
	var charged := charging
	var power := _charge_power() if charging else 0.0
	var vis := _view_rect().grow(CULL_MARGIN)
	for tg in targets:
		if not vis.has_point(tg.pos):
			continue
		var pulse := 1.0 + sin(t * 3.0 + tg.phase) * 0.045
		var r: float = tg.radius * pulse
		var base: Color = tg.color
		var f: float = clampf(tg.flash, 0.0, 1.0)

		draw_circle(tg.pos, r + 14.0, Color(base.r, base.g, base.b, 0.045 + f * 0.10))
		# glossy sphere body
		draw_circle(tg.pos, r, Color(base.r * 0.35, base.g * 0.35, base.b * 0.35, 0.98))
		draw_circle(tg.pos + Vector2(-r * 0.10, -r * 0.10), r * 0.86,
			Color(base.r * 0.62, base.g * 0.62, base.b * 0.62, 0.95))
		draw_circle(tg.pos + Vector2(-r * 0.26, -r * 0.26), r * 0.36,
			Color(1.0, 1.0, 1.0, 0.42 + f * 0.4))
		draw_arc(tg.pos, r, 0.0, TAU, 40, Color(base.r, base.g, base.b, 0.9), 2.0 + f * 3.0, true)

		match tg.kind:
			"basic":
				for k in 3:
					var a: float = tg.spin + k * TAU / 3.0
					draw_circle(tg.pos + Vector2(cos(a), sin(a)) * r * 0.55, 2.0,
						Color(1.0, 0.85, 0.95, 0.55))
			"armored":
				var ready: bool = charged and power >= tg.req
				var rc := GREEN if ready else Color(1.0, 0.62, 0.22, 0.60)
				for k in 8:
					var a0 := t * 1.2 + k * TAU / 8.0
					draw_arc(tg.pos, r + 9.0, a0, a0 + 0.30, 6, rc, 3.0, true)
				draw_arc(tg.pos, r * 0.55, 0.0, TAU, 24,
					Color(base.r, base.g, base.b, 0.55), 2.0, true)
			"chaser":
				var dir: Vector2 = (ball_pos - tg.pos).normalized()
				var side: Vector2 = dir.orthogonal() * r * 0.42
				var tip: Vector2 = tg.pos + dir * r * 0.55
				var back: Vector2 = tg.pos - dir * r * 0.34
				draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]),
					Color(1.0, 0.95, 1.0, 0.72))
			"drifter":
				var d: Vector2 = tg.vel.normalized()
				for k in 2:
					draw_circle(tg.pos - d * r * (0.42 + k * 0.34), 1.8,
						Color(1.0, 1.0, 1.0, 0.34 - k * 0.12))


## Straight aim line only — no bounce prediction.
func _draw_aim() -> void:
	var dir := mouse_pos - ball_pos
	if dir.length() < 1.0:
		dir = Vector2.RIGHT
	dir = dir.normalized()

	var p := clampf(charge_t / CHARGE_TIME, 0.0, 1.0)
	var length := lerpf(120.0, 520.0, p)
	var start := BALL_R + 13.0
	var to := ball_pos + dir * length
	var side := dir.orthogonal()

	var seg := 3
	for i in seg:
		var a0 := float(i) / float(seg)
		var a1 := float(i + 1) / float(seg)
		var p0 := ball_pos + dir * lerpf(start, length, a0)
		var p1 := ball_pos + dir * lerpf(start, length, a1)
		draw_line(p0, p1, Color(0.55, 0.95, 1.0, lerpf(0.55, 0.16, a0)), 3.0, true)

	draw_colored_polygon(PackedVector2Array([
		to + dir * 12.0,
		to + side * 7.5 - dir * 1.0,
		to - side * 7.5 - dir * 1.0,
	]), Color(0.85, 1.0, 1.0, 0.85))


# ------------------------------------------------------------------ draw actors
func _draw_ball() -> void:
	var n := trail.size()
	for i in n:
		var u := float(i + 1) / float(n)
		draw_circle(trail[i], BALL_R * (0.2 + u * 0.8), Color(0.40, 0.88, 1.0, u * u * 0.16))

	draw_circle(ball_pos, BALL_R + 18.0 + ball_flash * 8.0, Color(0.40, 0.90, 1.0, 0.05 + ball_flash * 0.04))
	draw_circle(ball_pos, BALL_R + 7.0, Color(0.50, 0.95, 1.0, 0.12))
	draw_circle(ball_pos, BALL_R, CYAN)
	draw_circle(ball_pos - Vector2(BALL_R * 0.3, BALL_R * 0.3), BALL_R * 0.45, WHITE)

	if charging:
		var c := clampf(charge_t / CHARGE_TIME, 0.0, 1.0)
		draw_arc(ball_pos, BALL_R + 11.0, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.10), 5.0, true)
		if c > 0.0:
			var col := Color.from_hsv(lerpf(0.52, 0.86, c), 0.80, 1.0)
			draw_arc(ball_pos, BALL_R + 11.0, -PI * 0.5, -PI * 0.5 + TAU * c, 48, col, 5.0, true)
			draw_circle(ball_pos, BALL_R + 5.0, Color(col.r, col.g, col.b, 0.08))


func _draw_particles() -> void:
	var vis := _view_rect().grow(CULL_MARGIN)
	for p in particles:
		if not vis.has_point(p.pos):
			continue
		var a := clampf(p.life / p.max_life, 0.0, 1.0)
		if a <= 0.0:
			continue
		draw_circle(p.pos, p.size * (0.4 + a * 0.6), Color(p.color.r, p.color.g, p.color.b, a))


func _draw_popups() -> void:
	var vis := _view_rect().grow(80.0)
	for p in popups:
		if not vis.has_point(p.pos):
			continue
		var a := clampf(p.life / 0.35, 0.0, 1.0)
		_text_center_at(p.pos, p.text, p.size, Color(p.color.r, p.color.g, p.color.b, a), bold_font)


func _draw_reticle() -> void:
	if not mouse_seen:
		return
	var col := Color(0.75, 0.95, 1.0, 0.85)
	if charging:
		col = Color(1.0, 0.95, 0.80, 0.95)
	draw_arc(mouse_pos, 9.0, 0.0, TAU, 28, col, 1.5, true)
	draw_circle(mouse_pos, 1.8, col)
	draw_line(mouse_pos + Vector2(-17.0, 0.0), mouse_pos + Vector2(-6.0, 0.0), col, 1.5, true)
	draw_line(mouse_pos + Vector2(6.0, 0.0), mouse_pos + Vector2(17.0, 0.0), col, 1.5, true)
	draw_line(mouse_pos + Vector2(0.0, -17.0), mouse_pos + Vector2(0.0, -6.0), col, 1.5, true)
	draw_line(mouse_pos + Vector2(0.0, 6.0), mouse_pos + Vector2(0.0, 17.0), col, 1.5, true)
	if charging:
		var pct := int(round(clampf(charge_t / CHARGE_TIME, 0.0, 1.0) * 100.0))
		_text("%d%%" % pct, mouse_pos + Vector2(20.0, -14.0), 14, Color(0.85, 0.98, 1.0, 0.95), true)


# ------------------------------------------------------------------ draw UI
func _draw_hud() -> void:
	_text("SCORE", Vector2(48.0, 28.0), 11, DIM)
	_text(str(score), Vector2(48.0, 56.0), 26, WHITE, true)

	_text_right("SMASHED", Vector2(1232.0, 28.0), 11, DIM)
	_text_right(str(kills), Vector2(1232.0, 56.0), 26, WHITE, true)

	var bw := 420.0
	var bx := 640.0 - bw * 0.5
	var by := 14.0
	draw_rect(Rect2(bx, by, bw, 6.0), Color(0.35, 0.55, 1.0, 0.12))
	var p := clampf(time_left / maxf(max_time, 0.001), 0.0, 1.0)
	if p > 0.0:
		var tc := RED if p < 0.25 else CYAN
		draw_rect(Rect2(bx, by, bw * p, 6.0), tc)
	_text_center_at(Vector2(640.0, 40.0), "%ds" % int(ceil(time_left)), 13, Color(0.72, 0.88, 1.0, 0.85))

	if combo > 1:
		_text_center_at(Vector2(640.0, 60.0), "COMBO x%d" % combo, 12, GOLD)

	if mode == "play" and time_left < 5.0:
		var a := (1.0 - time_left / 5.0) * (0.16 + 0.10 * sin(t * 10.0))
		draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(1.0, 0.2, 0.35, a), false, 26.0)

	if muted:
		_text_right("MUTED", Vector2(1232.0, 700.0), 12, DIM)

	if banner_t > 0.0:
		var a := clampf(banner_t / 0.45, 0.0, 1.0)
		_text_center_at(Vector2(640.0, 300.0), banner, 54,
			Color(0.85, 0.98, 1.0, a), bold_font)


## Corner map so you can see the balls waiting beyond the screen edge.
func _draw_minimap() -> void:
	var size := Vector2(200.0, 133.0)
	var mm := Rect2(VIEW.x - 26.0 - size.x, VIEW.y - 26.0 - size.y, size.x, size.y)
	draw_rect(mm.grow(7.0), Color(0.01, 0.02, 0.05, 0.66))
	draw_rect(mm, Color(0.03, 0.06, 0.12, 0.55))
	draw_rect(mm, Color(0.40, 0.72, 1.0, 0.32), false, 1.0)

	var sc := Vector2(mm.size.x / WORLD.size.x, mm.size.y / WORLD.size.y)
	for b in bumpers:
		draw_circle(mm.position + (b.pos - WORLD.position) * sc, 1.3,
			Color(0.35, 0.62, 1.0, 0.30))
	for tg in targets:
		draw_circle(mm.position + (tg.pos - WORLD.position) * sc, 1.8,
			Color(tg.color.r, tg.color.g, tg.color.b, 0.85))

	var vw := _view_rect()
	var vr := Rect2(mm.position + (vw.position - WORLD.position) * sc, vw.size * sc)
	draw_rect(vr, Color(0.85, 0.97, 1.0, 0.50), false, 1.0)

	var bp := mm.position + (ball_pos - WORLD.position) * sc
	draw_circle(bp, 4.5, Color(0.40, 0.90, 1.0, 0.22))
	draw_circle(bp, 2.4, CYAN)

	_text_right("RADAR", Vector2(mm.end.x, mm.position.y - 10.0), 10, DIM)


func _draw_title() -> void:
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.015, 0.020, 0.045, 0.58))

	_text_center_at(Vector2(640.0, 252.0), "BOUNCE BACK", 88, Color(0.25, 0.80, 1.0, 0.28), bold_font)
	_text_center_at(Vector2(640.0, 248.0), "BOUNCE BACK", 88, WHITE, bold_font)
	_text_center_at(Vector2(640.0, 290.0), "hold  ·  charge  ·  ricochet", 18, Color(0.55, 0.85, 1.0, 0.75))

	_rule(380.0, "HOLD", "charge your bounce")
	_rule(414.0, "RELEASE", "launch toward the cursor")
	_rule(448.0, "RICOCHET", "shatter balls at speed")
	_rule(482.0, "EXPLORE", "the world scrolls past the screen")

	var pulse := 0.55 + 0.45 * sin(t * 3.2)
	_text_center_at(Vector2(640.0, 580.0), "CLICK TO START", 22, Color(0.85, 0.97, 1.0, pulse))
	if best > 0:
		_text_center_at(Vector2(640.0, 630.0), "BEST  %d" % best, 16, DIM)
	_text_center_at(Vector2(640.0, 690.0), "R restart   ·   M mute", 12, Color(0.45, 0.60, 0.80, 0.55))


func _draw_game_over() -> void:
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.02, 0.015, 0.04, 0.78))
	_text_center_at(Vector2(640.0, 250.0), "TIME'S UP", 68, PINK, bold_font)
	_text_center_at(Vector2(640.0, 320.0), "SCORE", 12, DIM)
	_text_center_at(Vector2(640.0, 392.0), str(score), 72, WHITE, bold_font)
	_text_center_at(Vector2(640.0, 442.0), "SMASHED %d" % kills, 20, CYAN)
	if new_best:
		_text_center_at(Vector2(640.0, 486.0), "NEW BEST!", 18, GOLD, bold_font)
	elif best > 0:
		_text_center_at(Vector2(640.0, 486.0), "BEST  %d" % best, 16, DIM)
	var pulse := 0.6 + 0.4 * sin(t * 4.0)
	_text_center_at(Vector2(640.0, 572.0), "CLICK TO PLAY AGAIN", 20, Color(0.85, 0.97, 1.0, pulse))


# ------------------------------------------------------------------ text helpers
func _text(s: String, pos: Vector2, size: int, color: Color, bold: bool = false) -> void:
	var f := bold_font if bold else body_font
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_right(s: String, pos: Vector2, size: int, color: Color, bold: bool = false) -> void:
	var f := bold_font if bold else body_font
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(f, Vector2(pos.x - w, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_center_at(pos: Vector2, s: String, size: int, color: Color, f: Font = null) -> void:
	if f == null:
		f = body_font
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(f, Vector2(pos.x - w * 0.5, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _rule(y: float, key: String, desc: String) -> void:
	var kw := bold_font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var dw := body_font.get_string_size(desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var total := kw + 22.0 + dw
	var x := 640.0 - total * 0.5
	draw_string(bold_font, Vector2(x, y), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, CYAN)
	draw_string(body_font, Vector2(x + kw + 22.0, y), desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
		Color(0.70, 0.82, 0.95, 0.80))
