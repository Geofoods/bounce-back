extends Node2D
## BOUNCE BACK — hold to charge, release to launch the ball toward the cursor.
## Fast impacts shatter balls, slow ones bounce off. The camera follows the ball
## through a world several screens wide. Gravity pulls the ball down, and the
## molten floor along the bottom of the world ends the run on contact.
## Everything is drawn in code.
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
const MIN_VISIBLE := 5           # always keep at least this many balls on screen

# Balls are spawned this far outside the screen and unloaded once they are
# further away than STREAM_KEEP, so only nearby balls exist at any time.
const STREAM_MARGIN := 620.0
const STREAM_KEEP := 1100.0
const STREAM_INTERVAL := 0.22
const CULL_MARGIN := 150.0       # skip drawing anything beyond the screen edge

const START_TIME := 32.0         # seconds on the clock at the start
const TIME_PER_KILL := 2.4       # seconds added per ball broken
const TIME_CAP := 48.0           # clock can never exceed this

const POWERUP_CHANCE := 0.14     # chance a shattered ball drops a pickup
const POWERUP_LIFE := 11.0       # seconds a pickup lasts before fading
const POWERUP_PICK_R := 18.0     # pickup radius beyond the ball
const POWERUP_TIME_BONUS := 6.0  # seconds added by a clock pickup
const RAPID_TIME := 5.0          # free reload window
const OVERDRIVE_TIME := 6.0      # every hit shatters window

const BOSS_FIRST_SCORE := 3000   # score needed before the first boss appears
const BOSS_NEXT_SCORE := 4500    # extra score needed before each later boss
const BOSS_TARGET_CAP := 10      # normal balls allowed while a boss is alive
const BOSS_HIT_SPEED := 620.0    # impact speed that actually damages the boss
const BOSS_SHOT_SPEED := 210.0   # speed of the boss's ember volley
const BOSS_SHOT_LIFE := 5.0      # seconds before a volley shot burns out
const BOSS_DEFLECT_SPEED := 500.0  # ball speed that knocks volley shots away

const GRAVITY := 1000.0          # downward pull on the ball (px/s²)
const LAVA_H := 120.0            # depth of the molten floor at the bottom
const WALL_REST := 0.97          # energy kept when bouncing off a wall
const BUMPER_REST := 1.06        # bumpers add a little energy (pinball feel)
const SPEED_RETAIN := 0.87       # fraction of speed kept each second
const MAX_SPEED := 2300.0
const RICOCHET_LIFT := 480.0     # upward kick each time a ball shatters
const SPIKE_LEN := 14.0          # how far the spiked balls' points poke out
const MIN_POWER := 470.0         # launch speed of a tap
const MAX_POWER := 1750.0        # launch speed of a full charge
const CHARGE_TIME := 0.8         # seconds to reach full charge
const SLOWMO := 0.30             # world speed while charging
const KILL_SPEED := 240.0        # minimum impact speed for basic targets

# ------------------------------------------------------------------ palette
const BG := Color(0.018, 0.026, 0.052)
const CYAN := Color(0.43, 0.90, 1.0)
const WHITE := Color(0.92, 1.0, 1.0)
# Emissive versions above 1.0 — these are what the glow pass blooms.
const CYAN_HOT := Color(0.55, 1.65, 2.05)
const WHITE_HOT := Color(2.20, 2.45, 2.60)
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
	var age: float = 0.0

class Particle:
	var pos: Vector2
	var vel: Vector2
	var life: float
	var max_life: float
	var size: float
	var color: Color
	var drag: float = 0.02      # speed kept per second
	var gy: float = 0.0         # extra vertical drift (negative = rising)

class FloatText:
	var pos: Vector2
	var text: String
	var color: Color
	var size: int
	var life: float
	var max_life: float

class Powerup:
	var pos: Vector2
	var kind: String        # time | rapid | boost
	var life: float
	var age: float
	var phase: float

class Boss:
	var pos: Vector2
	var radius: float = 62.0
	var hp: int = 6
	var max_hp: int = 6
	var flash: float = 0.0
	var phase: float = 0.0
	var core: float = 0.0
	var shot_cd: float = 2.0
	var slow_cd: float = 0.0

class BossShot:
	var pos: Vector2
	var vel: Vector2
	var radius: float = 13.0
	var life: float = 4.0
	var phase: float = 0.0

# ------------------------------------------------------------------ state
var mode: String = "title"          # title | play | over
var died_in_lava: bool = false
var died_on_spikes: bool = false
var died_by_blast: bool = false
var kills: int = 0
var score: int = 0
var best: int = 0
var new_best: bool = false
var time_left: float = 0.0
var max_time: float = TIME_CAP
var combo: int = 0
var combo_t: float = 0.0
var rapid_t: float = 0.0
var overdrive_t: float = 0.0
var shake: float = 0.0
var hitstop: float = 0.0
var banner: String = ""
var banner_t: float = 0.0
var muted: bool = false
var t: float = 0.0

# post fx
var bloom_level: float = 0.35
var vignette_t: float = 0.2
var glow_env: Environment
var vignette_tex: ImageTexture
var show_stats: bool = false
var fps_avg: float = 60.0
var fx_stripped: bool = false

var cam: Vector2 = Vector2.ZERO        # world point shown at screen center
var cam_snap: bool = true
var stream_t: float = 0.0

var ball_pos: Vector2 = Vector2.ZERO
var ball_vel: Vector2 = Vector2.ZERO
var ball_flash: float = 0.0
var trail: Array = []

var charging: bool = false
var charge_t: float = 0.0
var shot_ready: bool = true       # only one launch per ball hit
var ready_nudge_t: float = 0.0
var mouse_pos: Vector2 = Vector2.ZERO
var mouse_seen: bool = false

var bumpers: Array = []
var targets: Array = []
var powerups: Array = []
var boss: Boss = null
var boss_shots: Array = []
var boss_beaten: int = 0
var boss_next_score: int = BOSS_FIRST_SCORE
var particles: Array = []
var popups: Array = []
var mote_t: float = 0.0
var charge_mote_t: float = 0.0
var ember_t: float = 0.0
var arc_bodies: Array = []      # reused by the aim preview each frame
var arc_radii: Array = []

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
	_setup_post_fx()
	_load_best()
	_enter_title()


func _setup_fonts() -> void:
	body_font = ThemeDB.fallback_font
	var bv := FontVariation.new()
	bv.base_font = body_font
	bv.variation_embolden = 0.75
	bold_font = bv


## Engine bloom: a glow-enabled environment over the 2D canvas. Colours above
## 1.0 in the palette bleed light, and the intensity is driven below.
func _toggle_glow() -> void:
	if glow_env == null:
		return
	glow_env.glow_enabled = not glow_env.glow_enabled


func _setup_post_fx() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = bloom_level
	env.glow_strength = 1.0
	env.glow_bloom = 0.12
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.90
	env.glow_hdr_scale = 2.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	glow_env = env
	vignette_tex = _make_vignette()


## Soft overlay texture: clear in the middle, opaque toward the corners.
func _make_vignette() -> ImageTexture:
	var w := 96
	var h := 54
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c := Vector2(float(w), float(h)) * 0.5
	var norm := 1.0 / sqrt(2.0)
	for y in h:
		for x in w:
			var d := ((Vector2(float(x) + 0.5, float(y) + 0.5) - c) / c).length() * norm
			var a := pow(clampf((d - 0.16) / 0.84, 0.0, 1.0), 1.45)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


## 0 when calm, 1 when the ball is near the lava or the clock is nearly out.
func _danger_level() -> float:
	if mode == "over":
		return 1.0
	if mode != "play":
		return 0.2
	var near_lava := clampf((ball_pos.y - (_lava_top() - 760.0)) / 760.0, 0.0, 1.0)
	var low_time := 1.0 - clampf(time_left / START_TIME, 0.0, 1.0)
	return clampf(maxf(near_lava, low_time * 0.85), 0.0, 1.0)


## Bloom swells while charging, while chaining, and while in danger; the
## vignette closes in with the same danger and flares red at the edges.
func _update_post_fx(dt: float) -> void:
	var danger := _danger_level()
	# Only sample frame rate while the window has focus, so an alt-tabbed window
	# is not mistaken for a machine that cannot afford the glow pass.
	if get_window().has_focus():
		fps_avg = lerpf(fps_avg, float(Engine.get_frames_per_second()), 1.0 - exp(-1.5 * dt))
	if glow_env != null:
		# One-way safety net: if bloom clearly cannot keep up, drop the glow pass
		# for the rest of the session. F2 turns it back on.
		if not fx_stripped and t > 6.0 and fps_avg < 45.0:
			fx_stripped = true
			glow_env.glow_enabled = false
			_banner("PERFORMANCE MODE")
		var target := 0.35
		if mode == "play":
			target += 0.45 * (clampf(charge_t / CHARGE_TIME, 0.0, 1.0) if charging else 0.0)
			target += 0.04 * minf(combo, 8)
			target += 0.30 * danger
		elif mode == "title":
			target = 0.42 + 0.10 * sin(t * 1.7)
		bloom_level = lerpf(bloom_level, clampf(target, 0.15, 1.5), 1.0 - exp(-6.0 * dt))
		glow_env.glow_intensity = bloom_level
		glow_env.glow_bloom = 0.08 + bloom_level * 0.10
		glow_env.glow_strength = 0.85 + bloom_level * 0.5
	vignette_t = lerpf(vignette_t, danger, 1.0 - exp(-5.0 * dt))


func _draw_vignette() -> void:
	if vignette_tex == null:
		return
	var charge := clampf(charge_t / CHARGE_TIME, 0.0, 1.0) if charging else 0.0
	# Play runs a heavier frame than the menus so the darkening reads in game.
	var base := 0.56 if mode == "play" else 0.38
	var strength := base + 0.32 * vignette_t + 0.08 * charge
	var tint := Color(0.0, 0.0, 0.02).lerp(Color(0.34, 0.03, 0.05), vignette_t)
	draw_texture_rect(vignette_tex, Rect2(Vector2.ZERO, VIEW), false,
		Color(tint.r, tint.g, tint.b, clampf(strength, 0.0, 0.95)))


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
		elif key.keycode == KEY_F2 and key.pressed:
			_toggle_glow()
		elif key.keycode == KEY_F3 and key.pressed:
			show_stats = not show_stats
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
	shot_ready = true
	ready_nudge_t = 0.0
	boss = null
	boss_shots.clear()
	boss_next_score = BOSS_FIRST_SCORE
	ball_pos = WORLD.get_center()
	ball_vel = Vector2.RIGHT.rotated(randf() * TAU) * 300.0
	ball_flash = 0.0
	trail.clear()
	targets.clear()
	bumpers.clear()
	powerups.clear()
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
	died_in_lava = false
	died_on_spikes = false
	died_by_blast = false
	shot_ready = true
	ready_nudge_t = 0.0
	boss = null
	boss_shots.clear()
	boss_beaten = 0
	boss_next_score = BOSS_FIRST_SCORE
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
	powerups.clear()
	rapid_t = 0.0
	overdrive_t = 0.0
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
	bloom_level = maxf(bloom_level, 1.4)
	_ring(ball_pos, PINK, 18, 320.0)
	shake = 14.0
	_sfx("over", 0.0, -4.0)


func _banner(text: String) -> void:
	banner = text
	banner_t = 1.3


# ------------------------------------------------------------------ shooting
func _begin_charge() -> void:
	if mode != "play" or charging:
		return
	# The launch is spent until the ball hits another ball.
	if not shot_ready:
		if ready_nudge_t <= 0.0:
			ready_nudge_t = 0.6
			_popup(ball_pos + Vector2(0.0, -BALL_R - 22.0), "HIT A BALL", RED, 16)
			_sfx("armor", 0.1, -16.0)
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
	shot_ready = rapid_t > 0.0     # rapid fire keeps the launcher loaded
	trail.clear()
	_burst(ball_pos, CYAN, 14, 240.0)
	_ring(ball_pos, CYAN, 12, 260.0)
	_shards(ball_pos, -ball_vel, CYAN, 9, 340.0, 0.45)
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
	while bumpers.size() < BUMPER_POP and guard < 800:
		guard += 1
		var br := randf_range(24.0, 46.0)
		var bp := Vector2(
			randf_range(WORLD.position.x + 120.0 + br, WORLD.end.x - 120.0 - br),
			randf_range(WORLD.position.y + 120.0 + br, _lava_top() - 120.0 - br))
		var ball_gap := br + BALL_R + 220.0
		if bp.distance_squared_to(ball_pos) < ball_gap * ball_gap:
			continue
		var free := true
		for b in bumpers:
			var gap: float = b.radius + br + 150.0
			if bp.distance_squared_to(b.pos) < gap * gap:
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
	# Spawns stay above the lava so every ball is actually reachable.
	var dry := Rect2(WORLD.position, Vector2(WORLD.size.x, WORLD.size.y - LAVA_H))
	return _view_rect().grow(STREAM_MARGIN).intersection(dry.grow(-70.0))


## Unloads balls that are far off screen and refills the ring around the camera.
func _update_streaming(dt: float) -> void:
	stream_t -= dt
	if stream_t > 0.0:
		return
	stream_t = STREAM_INTERVAL

	var view := _view_rect()
	var keep := view.grow(STREAM_KEEP)
	for i in range(targets.size() - 1, -1, -1):
		if not keep.has_point(targets[i].pos):
			targets.remove_at(i)

	var visible := 0
	for tg in targets:
		if view.has_point(tg.pos):
			visible += 1

	# Fewer ordinary balls while the boss is up so the fight has room to breathe.
	var cap := BOSS_TARGET_CAP if boss != null else TARGET_POP
	var guard := 0
	while guard < 24:
		guard += 1
		# Always leave something to shoot at; otherwise refill off screen.
		if visible < MIN_VISIBLE:
			if targets.size() >= cap:
				_remove_farthest()
			if _spawn_target(false, view.grow(-70.0)):
				visible += 1
				continue
		if targets.size() >= cap:
			break
		if not _spawn_target(true, _stream_area()):
			break


## Drops the most distant off-screen ball so a new on-screen one can load.
func _remove_farthest() -> void:
	var view := _view_rect()
	var best := -1
	var best_d := -1.0
	for i in targets.size():
		if view.has_point(targets[i].pos):
			continue
		var d: float = targets[i].pos.distance_squared_to(cam)
		if d > best_d:
			best_d = d
			best = i
	if best >= 0:
		targets.remove_at(best)


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
	var ball_gap := r + BALL_R + 140.0
	var ball_gap2 := ball_gap * ball_gap
	var lava_y := _lava_top() - r - 20.0
	# Squared distances only and fewer candidates: placement runs many times per
	# streaming tick, so skipping sqrt pays off here.
	for i in 96:
		var pt := Vector2(
			randf_range(area.position.x + pad, area.end.x - pad),
			randf_range(area.position.y + pad, area.end.y - pad))
		if pt.y > lava_y:
			continue
		if pt.distance_squared_to(ball_pos) < ball_gap2:
			continue
		var free := true
		for b in bumpers:
			var bg: float = b.radius + r + 80.0
			if pt.distance_squared_to(b.pos) < bg * bg:
				free = false
				break
		if free:
			for o in targets:
				var og: float = o.radius + r + 60.0
				if pt.distance_squared_to(o.pos) < og * og:
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
	if combo >= 5 and combo % 5 == 0:
		_ring(ball_pos, GOLD, 16, 350.0)
	_burst(tg.pos, tg.color, 18, 300.0)
	_burst(tg.pos, WHITE, 8, 220.0)
	shake = maxf(shake, 9.0)
	hitstop = 0.055
	bloom_level = minf(bloom_level + 0.5, 1.8)
	_sfx("kill", 0.08, -6.0)
	if boss == null and score >= boss_next_score:
		_spawn_boss()
	if powerups.size() < 3 and randf() < POWERUP_CHANCE:
		_spawn_powerup(tg.pos)
	# Streaming refills the population shortly after the kill.


# ------------------------------------------------------------------ powerups
## Occasionally drops a pickup where a ball shattered.
func _spawn_powerup(at: Vector2) -> void:
	var kinds := ["time", "rapid", "boost"]
	var p := Powerup.new()
	p.kind = kinds[randi() % kinds.size()]
	p.pos = at
	p.life = POWERUP_LIFE
	p.age = 0.0
	p.phase = randf() * TAU
	powerups.append(p)


func _powerup_color(kind: String) -> Color:
	match kind:
		"time":
			return GOLD
		"rapid":
			return CYAN
		_:
			return PINK


## Pickups drift upward, time out, and are collected by touching them.
func _update_powerups(dt: float) -> void:
	var pick := BALL_R + POWERUP_PICK_R
	var pick2 := pick * pick
	for i in range(powerups.size() - 1, -1, -1):
		var p = powerups[i]
		p.age += dt
		p.life -= dt
		p.pos.y -= 20.0 * dt
		p.pos.x += sin(p.age * 2.4 + p.phase) * 14.0 * dt
		p.pos.x = clampf(p.pos.x, WORLD.position.x + 30.0, WORLD.end.x - 30.0)
		p.pos.y = clampf(p.pos.y, WORLD.position.y + 30.0, _lava_top() - 30.0)
		if p.life <= 0.0:
			powerups.remove_at(i)
			continue
		if ball_pos.distance_squared_to(p.pos) < pick2:
			powerups.remove_at(i)
			_apply_powerup(p)


func _apply_powerup(p: Powerup) -> void:
	var c := _powerup_color(p.kind)
	var label := ""
	match p.kind:
		"time":
			time_left = minf(time_left + POWERUP_TIME_BONUS, TIME_CAP)
			label = "+%d SECONDS" % int(POWERUP_TIME_BONUS)
		"rapid":
			rapid_t = RAPID_TIME
			label = "RAPID FIRE"
		_:
			overdrive_t = OVERDRIVE_TIME
			label = "OVERDRIVE"
	_popup(p.pos + Vector2(0.0, -28.0), label, c, 20)
	_banner(label)
	_burst(p.pos, c, 16, 240.0)
	_burst(p.pos, WHITE, 6, 170.0)
	_ring(p.pos, c, 12, 260.0)
	bloom_level = minf(bloom_level + 0.45, 1.8)
	shake = maxf(shake, 4.0)
	_sfx("wave", 0.06, -6.0)


# ------------------------------------------------------------------ boss fight
func _spawn_boss() -> void:
	var b := Boss.new()
	b.max_hp = 6 + boss_beaten * 2
	b.hp = b.max_hp
	b.pos = ball_pos + Vector2(0.0, -380.0)
	b.phase = randf() * TAU
	_clamp_boss_to_view(b)
	boss = b
	boss_shots.clear()
	_banner("THE WARDEN AWAKENS")
	shake = 12.0
	bloom_level = minf(bloom_level + 0.9, 1.8)
	_sfx("over", 0.0, -10.0)


## Keeps the boss framed by the camera, and inside the world above the lava.
func _clamp_boss_to_view(b: Boss) -> void:
	var view := _view_rect()
	var pad := b.radius + 46.0
	b.pos.x = clampf(b.pos.x, maxf(view.position.x + pad, WORLD.position.x + pad),
		minf(view.end.x - pad, WORLD.end.x - pad))
	b.pos.y = clampf(b.pos.y, maxf(view.position.y + pad, WORLD.position.y + pad),
		minf(view.end.y - pad, _lava_top() - pad))


## The boss hovers above the player, bobbing, and lobs volleys at them.
func _update_boss(dt: float) -> void:
	var b: Boss = boss
	if b == null:
		return
	b.phase += dt
	b.core += dt * 2.6
	b.flash = maxf(0.0, b.flash - dt * 3.0)
	b.slow_cd = maxf(0.0, b.slow_cd - dt)
	var want := Vector2(
		clampf(ball_pos.x, WORLD.position.x + 240.0, WORLD.end.x - 240.0),
		clampf(ball_pos.y - 320.0, WORLD.position.y + 220.0, _lava_top() - 240.0))
	want.y += sin(b.phase * 1.3) * 38.0
	b.pos = b.pos.lerp(want, 1.0 - exp(-1.4 * dt))
	_clamp_boss_to_view(b)
	b.shot_cd -= dt
	if b.shot_cd <= 0.0:
		b.shot_cd = 2.3
		_boss_volley(b)


func _boss_volley(b: Boss) -> void:
	var aim: Vector2 = (ball_pos - b.pos).normalized()
	if aim.length_squared() < 0.01:
		aim = Vector2.DOWN
	for k in 3:
		var spread: float = (k - 1) * 0.26
		var s := BossShot.new()
		s.pos = b.pos + aim.rotated(spread) * (b.radius + 10.0)
		s.vel = aim.rotated(spread) * BOSS_SHOT_SPEED
		s.life = BOSS_SHOT_LIFE
		s.phase = randf() * TAU
		boss_shots.append(s)
	_sfx("shoot_low", 0.12, -14.0)


## Volley shots drift at the ball: a fast ball knocks them away, a slow one dies.
func _update_boss_shots(dt: float) -> void:
	var spd := ball_vel.length()
	for i in range(boss_shots.size() - 1, -1, -1):
		var s = boss_shots[i]
		s.pos += s.vel * dt
		s.life -= dt
		s.phase += dt * 5.0
		if s.life <= 0.0:
			boss_shots.remove_at(i)
			continue
		if (s.pos.x < WORLD.position.x + s.radius or s.pos.x > WORLD.end.x - s.radius
				or s.pos.y < WORLD.position.y + s.radius or s.pos.y > _lava_top() - s.radius):
			boss_shots.remove_at(i)
			continue
		var reach: float = BALL_R + s.radius
		if ball_pos.distance_squared_to(s.pos) < reach * reach:
			boss_shots.remove_at(i)
			if spd >= BOSS_DEFLECT_SPEED:
				score += 60
				_popup(s.pos, "DEFLECT", GOLD, 16)
				_burst(s.pos, GOLD, 10, 250.0)
				_shards(s.pos, -s.vel, GOLD, 6, 330.0, 0.5)
				_sfx("bump", 0.1, -8.0)
			else:
				_blast_death()
				return


## Ball vs boss. Only a fast impact hurts it; anything slower just bounces.
func _collide_boss() -> void:
	var b: Boss = boss
	if b == null:
		return
	var d: Vector2 = ball_pos - b.pos
	var rr: float = b.radius + BALL_R
	var dist2 := d.length_squared()
	if dist2 >= rr * rr:
		return
	var n := d.normalized() if dist2 > 0.0001 else Vector2.RIGHT
	ball_pos = b.pos + n * rr
	var speed := ball_vel.length()
	var vn := ball_vel.dot(n)
	if vn < 0.0:
		ball_vel -= 1.85 * vn * n
	ball_vel.y = minf(ball_vel.y - RICOCHET_LIFT * 0.7, -RICOCHET_LIFT * 0.4)
	_clamp_speed()
	shot_ready = true
	if speed < BOSS_HIT_SPEED and overdrive_t <= 0.0:
		if b.slow_cd <= 0.0:
			b.slow_cd = 0.6
			_popup(b.pos + Vector2(0.0, -b.radius - 16.0), "NEED SPEED", RED, 16)
			_burst(ball_pos - n * BALL_R, Color(0.9, 0.35, 0.3), 6, 150.0)
			shake = maxf(shake, 3.0)
			_sfx("armor", 0.1, -10.0)
		return
	b.hp -= 1
	b.flash = 1.0
	score += 350
	time_left = minf(time_left + 1.6, TIME_CAP)
	_burst(b.pos + n * b.radius, GOLD, 16, 330.0)
	_shards(b.pos + n * b.radius, ball_vel, GOLD, 10, 520.0, 0.6)
	_popup(b.pos + Vector2(0.0, -b.radius - 18.0), "HIT", GOLD, 20)
	shake = maxf(shake, 10.0)
	hitstop = 0.06
	bloom_level = minf(bloom_level + 0.5, 1.8)
	_sfx("kill", 0.1, -6.0)
	if b.hp <= 0:
		_boss_defeated()


func _boss_defeated() -> void:
	var at: Vector2 = boss.pos
	boss = null
	boss_shots.clear()
	boss_beaten += 1
	boss_next_score = score + BOSS_NEXT_SCORE + boss_beaten * 1500
	score += 1800
	time_left = minf(time_left + 10.0, TIME_CAP)
	_banner("BOSS DOWN")
	_ring(at, GOLD, 24, 460.0)
	_burst(at, GOLD, 30, 420.0)
	_burst(at, WHITE, 14, 260.0)
	_burst(at, PINK, 18, 340.0)
	shake = 18.0
	hitstop = 0.08
	bloom_level = 1.8
	_sfx("wave", 0.0, -4.0)
	_spawn_powerup(at + Vector2(-60.0, 40.0))
	_spawn_powerup(at + Vector2(60.0, 40.0))


## A volley shot connected with a ball that was not fast enough to deflect it.
func _blast_death() -> void:
	died_by_blast = true
	ball_vel = Vector2.ZERO
	_burst(ball_pos, Color(1.0, 0.55, 0.2), 26, 420.0)
	_burst(ball_pos, RED, 16, 300.0)
	_sfx("kill", 0.12, -4.0)
	_game_over()


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

	_update_ambient(delta)
	_update_post_fx(delta)
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
	ball_vel.y += GRAVITY * dt
	_clamp_speed()
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

	ready_nudge_t = maxf(0.0, ready_nudge_t - delta)
	rapid_t = maxf(0.0, rapid_t - delta)
	overdrive_t = maxf(0.0, overdrive_t - delta)

	if charging:
		charge_t = minf(charge_t + delta, CHARGE_TIME)
		_update_charge_motes(delta)

	var wdt := delta * (SLOWMO if charging else 1.0)

	if combo_t > 0.0:
		combo_t -= delta
		if combo_t <= 0.0:
			combo = 0

	ball_flash = maxf(0.0, ball_flash - wdt * 4.0)
	ball_vel *= pow(SPEED_RETAIN, wdt)

	_step_ball(wdt)
	if mode != "play":
		return
	_update_powerups(wdt)
	_update_boss(wdt)
	_update_boss_shots(wdt)
	if mode != "play":
		return
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
		tg.age += dt
		tg.flash = maxf(0.0, tg.flash - dt * 5.0)
		tg.slow_cd = maxf(0.0, tg.slow_cd - dt)

		if tg.kind == "chaser" or tg.kind == "armored":
			# Spiked balls lumber after the ball as well, heavier than chasers.
			var follow: float = chase_speed * (0.55 if tg.kind == "armored" else 1.0)
			var dir: Vector2 = ball_pos - tg.pos
			if dir.length_squared() > 1.0:
				tg.pos += dir.normalized() * follow * dt
		elif tg.kind == "drifter":
			tg.pos += tg.vel * dt
			if tg.pos.x < WORLD.position.x + tg.radius or tg.pos.x > WORLD.end.x - tg.radius:
				tg.vel.x = -tg.vel.x
			if tg.pos.y < WORLD.position.y + tg.radius or tg.pos.y > _lava_top() - tg.radius:
				tg.vel.y = -tg.vel.y

		tg.pos.x = clampf(tg.pos.x, WORLD.position.x + tg.radius, WORLD.end.x - tg.radius)
		tg.pos.y = clampf(tg.pos.y, WORLD.position.y + tg.radius, _lava_top() - tg.radius)


func _update_bumpers(dt: float) -> void:
	for b in bumpers:
		b.phase += dt
		b.flash = maxf(0.0, b.flash - dt * 3.0)


func _step_ball(dt: float) -> void:
	var speed := ball_vel.length()
	var steps := clampi(int(ceil(speed * dt / (BALL_R * 0.5))), 1, 12)
	var h := dt / float(steps)
	for i in steps:
		ball_vel.y += GRAVITY * h
		_clamp_speed()
		ball_pos += ball_vel * h
		_collide_walls()
		_collide_bumpers()
		_collide_targets()
		_collide_boss()
		if mode != "play":
			return
	_update_ball_motes(dt)
	trail.append(ball_pos)
	if trail.size() > 26:
		trail.pop_front()


## Y coordinate of the molten surface at the bottom of the world.
func _lava_top() -> float:
	return WORLD.end.y - LAVA_H


func _collide_walls() -> void:
	var min_x := WORLD.position.x + BALL_R
	var max_x := WORLD.end.x - BALL_R
	var min_y := WORLD.position.y + BALL_R

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

	# The floor is molten: in play it ends the run, on the title screen it bounces.
	var surface := _lava_top() - BALL_R
	if ball_pos.y > surface:
		ball_pos.y = surface
		if mode == "play":
			_lava_death()
		elif ball_vel.y > 0.0:
			ball_vel.y = -ball_vel.y * WALL_REST
			_on_bounce(Vector2(ball_pos.x, surface), absf(ball_vel.y))


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
	# Any real contact returns below, so measure the speed once for the sweep.
	var speed := ball_vel.length()
	for i in range(targets.size() - 1, -1, -1):
		var tg = targets[i]
		var d: Vector2 = ball_pos - tg.pos
		# Spiked balls collide out at the tip of their points.
		var rr: float = tg.radius + BALL_R + (SPIKE_LEN if tg.kind == "armored" else 0.0)
		var dist2 := d.length_squared()
		if dist2 >= rr * rr:
			continue
		var n := d.normalized() if dist2 > 0.0001 else Vector2.RIGHT
		if overdrive_t > 0.0 or speed >= tg.req:
			shot_ready = true
			# Shattering a ball ricochets you off its surface instead of passing
			# through, so a fast shot keeps chaining around the arena.
			ball_pos = tg.pos + n * rr
			var vn_hit := ball_vel.dot(n)
			if vn_hit < 0.0:
				ball_vel -= 1.8 * vn_hit * n
			# Every ricochet lifts the ball: add the kick, but never leave the
			# ball headed downward, so chains fight the pull of gravity.
			ball_vel.y = minf(ball_vel.y - RICOCHET_LIFT, -RICOCHET_LIFT * 0.5)
			_clamp_speed()
			_kill_target(i, speed)
			_shards(tg.pos, ball_vel, tg.color, 8, 470.0, 0.5)
			return
		# too slow for this one
		ball_pos = tg.pos + n * rr
		if tg.kind == "armored":
			_spike_death()
			return
		# plain balls bounce you back, which still counts as a hit
		shot_ready = true
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


## The ball touched the molten floor — sizzle out and end the run.
func _lava_death() -> void:
	died_in_lava = true
	ball_vel = Vector2.ZERO
	_burst(ball_pos, GOLD, 30, 470.0)
	_burst(ball_pos, Color(1.0, 0.55, 0.15), 22, 360.0)
	_burst(ball_pos, RED, 16, 280.0)
	_sfx("kill", 0.14, -4.0)
	_game_over()


## Ran into a spiked ball without the speed to shatter it.
func _spike_death() -> void:
	died_on_spikes = true
	ball_vel = Vector2.ZERO
	_burst(ball_pos, RED, 28, 430.0)
	_burst(ball_pos, PINK, 14, 310.0)
	_burst(ball_pos, WHITE, 8, 220.0)
	_sfx("kill", 0.10, -4.0)
	_game_over()


func _on_bounce(at: Vector2, strength: float) -> void:
	var s := clampf(strength / 1400.0, 0.0, 1.0)
	ball_flash = maxf(ball_flash, 0.4 + s)
	bloom_level = minf(bloom_level + s * 0.22, 1.8)
	_burst(at, CYAN, 2 + int(s * 6.0), 60.0 + s * 240.0)
	if s > 0.18:
		_shards(at, ball_vel, CYAN, 3 + int(s * 5.0), 150.0 + s * 380.0, 0.5)
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
		var a := randf() * TAU
		_emit(at, Vector2(cos(a), sin(a)) * speed * randf_range(0.35, 1.0),
			color, randf_range(2.0, 4.5), randf_range(0.25, 0.55))
	_cap_particles()


## Sprayed in a cone — shatters, ricochets and launch backblast.
func _shards(at: Vector2, dir: Vector2, color: Color, count: int, speed: float, spread: float) -> void:
	var base := dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT
	for i in count:
		var a := base.rotated(randf_range(-spread, spread))
		_emit(at + base * randf_range(0.0, 10.0), a * speed * randf_range(0.35, 1.0),
			color, randf_range(1.2, 3.2), randf_range(0.18, 0.42))
	_cap_particles()


## Evenly spaced shockwave — combos, launches, game over.
func _ring(at: Vector2, color: Color, count: int, speed: float) -> void:
	for i in count:
		var a := TAU * float(i) / float(count) + randf_range(-0.08, 0.08)
		_emit(at, Vector2(cos(a), sin(a)) * speed * randf_range(0.85, 1.0),
			color, randf_range(1.6, 2.8), randf_range(0.24, 0.42))
	_cap_particles()


## Adds one particle with its own drag and vertical drift.
func _emit(pos: Vector2, vel: Vector2, color: Color, size: float, life: float,
		drag: float = 0.02, gy: float = 0.0) -> void:
	var p := Particle.new()
	p.pos = pos
	p.vel = vel
	p.color = color
	p.size = size
	p.max_life = life
	p.life = life
	p.drag = drag
	p.gy = gy
	particles.append(p)


func _cap_particles() -> void:
	if particles.size() > 320:
		particles = particles.slice(particles.size() - 320)


func _update_particles(dt: float) -> void:
	# Compact in place instead of remove_at (which shifts the tail every time),
	# and resolve the common drag value once rather than once per particle.
	var drag_default := pow(0.02, dt)
	var keep := 0
	for i in particles.size():
		var p = particles[i]
		p.vel.y += p.gy * dt
		p.pos += p.vel * dt
		p.vel *= drag_default if p.drag == 0.02 else pow(p.drag, dt)
		p.life -= dt
		if p.life > 0.0:
			if keep != i:
				particles[keep] = p
			keep += 1
	if keep != particles.size():
		particles.resize(keep)


## Fine sparks streaming off a fast-moving ball.
func _update_ball_motes(dt: float) -> void:
	mote_t -= dt
	if mote_t > 0.0:
		return
	mote_t = 0.026
	var spd := ball_vel.length()
	if spd < 420.0:
		return
	_emit(ball_pos + Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0)),
		-ball_vel * 0.12 + Vector2(randf_range(-26.0, 26.0), randf_range(-26.0, 26.0)),
		Color(0.55, 0.95, 1.0, 0.70), randf_range(1.2, 2.4), randf_range(0.16, 0.30), 0.05)
	_cap_particles()


## Grains of light pulled into the ball while a shot charges.
func _update_charge_motes(dt: float) -> void:
	charge_mote_t -= dt
	if charge_mote_t > 0.0:
		return
	charge_mote_t = 0.05
	var a := randf() * TAU
	var from := ball_pos + Vector2(cos(a), sin(a)) * randf_range(46.0, 76.0)
	_emit(from, (ball_pos - from) * 1.7, Color(0.65, 0.95, 1.0, 0.85),
		randf_range(1.4, 2.6), randf_range(0.20, 0.36))
	_cap_particles()


## Embers rising off the lava wherever the camera can see it.
func _update_ambient(dt: float) -> void:
	ember_t -= dt
	if ember_t > 0.0:
		return
	ember_t = 0.045
	var view := _view_rect()
	var top := _lava_top()
	if view.end.y < top - 30.0:
		return
	var left := maxf(view.position.x, WORLD.position.x)
	var right := minf(view.end.x, WORLD.end.x)
	if right <= left:
		return
	_emit(Vector2(randf_range(left, right), top + randf_range(0.0, 56.0)),
		Vector2(randf_range(-22.0, 22.0), randf_range(-95.0, -45.0)),
		Color(1.0, 0.55, 0.18, 0.85), randf_range(1.2, 2.6), randf_range(0.5, 1.1), 0.6, -40.0)
	_cap_particles()


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
	var keep := 0
	for i in popups.size():
		var p = popups[i]
		p.pos.y -= 44.0 * dt
		p.life -= dt
		if p.life > 0.0:
			if keep != i:
				popups[keep] = p
			keep += 1
	if keep != popups.size():
		popups.resize(keep)


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
	_draw_lava()
	_draw_bumpers()
	_draw_targets()
	_draw_boss()
	_draw_boss_shots()
	if charging and mode == "play":
		_draw_aim()
	_draw_powerups()
	_draw_particles()
	_draw_ball()
	_draw_popups()
	_draw_reticle()

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_vignette()
	if mode != "title":
		_draw_hud()
		if mode == "play":
			_draw_minimap()
	if mode == "title":
		_draw_title()
	elif mode == "over":
		_draw_game_over()
	if show_stats:
		_draw_stats()


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
	# Only the ticks inside the view are emitted, so this scales with the screen
	# instead of the whole 3840 x 2560 world.
	var vis := _view_rect()
	var tick := 256
	var top := WORLD.position.y
	var bot := WORLD.end.y
	var left := WORLD.position.x
	var right := WORLD.end.x
	var show_top := vis.position.y < top + 30.0
	var show_bot := vis.end.y > bot - 30.0
	if show_top or show_bot:
		var x_lo := maxi(int(floorf(vis.position.x / float(tick))) * tick, 0)
		var x_hi := mini(int(ceilf(vis.end.x / float(tick))) * tick, int(WORLD.size.x))
		for x in range(x_lo, x_hi + 1, tick):
			var on_edge := x == 0 or x >= int(WORLD.size.x) - 1
			var c := Color(0.55, 0.90, 1.0, 0.45 if on_edge else 0.16)
			if show_top:
				draw_line(Vector2(left + x, top), Vector2(left + x, top + (26.0 if on_edge else 14.0)),
					c, 2.0, true)
			if show_bot:
				draw_line(Vector2(left + x, bot), Vector2(left + x, bot - (26.0 if on_edge else 14.0)),
					c, 2.0, true)
	var show_left := vis.position.x < left + 30.0
	var show_right := vis.end.x > right - 30.0
	if show_left or show_right:
		var y_lo := maxi(int(floorf(vis.position.y / float(tick))) * tick, 0)
		var y_hi := mini(int(ceilf(vis.end.y / float(tick))) * tick, int(WORLD.size.y))
		for y in range(y_lo, y_hi + 1, tick):
			var on_edge := y == 0 or y >= int(WORLD.size.y) - 1
			var c := Color(0.55, 0.90, 1.0, 0.45 if on_edge else 0.16)
			if show_left:
				draw_line(Vector2(left, top + y), Vector2(left + (26.0 if on_edge else 14.0), top + y),
					c, 2.0, true)
			if show_right:
				draw_line(Vector2(right, top + y), Vector2(right - (26.0 if on_edge else 14.0), top + y),
					c, 2.0, true)

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


## Animated molten band along the bottom of the world.
func _draw_lava() -> void:
	var top := _lava_top()
	var vis := _view_rect().grow(CULL_MARGIN)
	if vis.end.y < top or vis.position.y > WORLD.end.y:
		return
	var left := maxf(vis.position.x, WORLD.position.x)
	var right := minf(vis.end.x, WORLD.end.x)
	if right <= left:
		return

	var pulse := 0.5 + 0.5 * sin(t * 2.4)
	# heat haze rising off the surface
	for i in 3:
		var h := 22.0 + i * 24.0
		draw_rect(Rect2(left, top - h, right - left, h),
			Color(1.0, 0.34, 0.10, 0.05 + 0.03 * pulse))
	# molten body
	draw_rect(Rect2(left, top, right - left, WORLD.end.y - top),
		Color(0.36, 0.05, 0.04, 0.94))
	draw_rect(Rect2(left, top, right - left, 34.0), Color(1.0, 0.40, 0.07, 0.55))
	draw_rect(Rect2(left, WORLD.end.y - 26.0, right - left, 26.0), Color(1.0, 0.30, 0.05, 0.22))

	# churning surface
	var pts := PackedVector2Array()
	var x := left
	while x <= right:
		pts.append(Vector2(x, top + sin(x * 0.020 + t * 3.1) * 6.0 + sin(x * 0.055 - t * 4.7) * 3.0))
		x += 24.0
	if pts.size() >= 2:
		draw_polyline(pts, Color(1.70, 0.85, 0.26, 0.85), 3.0, true)

	# bubbles drifting up through the melt
	var span := WORLD.size.x
	var depth := WORLD.end.y - top - 20.0
	for i in 16:
		var bx := WORLD.position.x + fmod(float(i) * 271.0 + t * 22.0, span)
		if bx < left or bx > right:
			continue
		var by := top + 16.0 + fmod(float(i) * 97.0 + t * 30.0, depth)
		draw_circle(Vector2(bx, by), 1.6 + fmod(float(i), 3.0),
			Color(1.0, 0.66, 0.22, 0.42))


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
		draw_arc(b.pos, r, 0.0, TAU, 28, ring, 2.0 + f * 3.0, true)
		for k in 6:
			var a: float = spin + k * TAU / 6.0
			var inner: Vector2 = b.pos + Vector2(cos(a), sin(a)) * (r * 0.58)
			var outer: Vector2 = b.pos + Vector2(cos(a), sin(a)) * (r * 0.86)
			draw_line(inner, outer, Color(0.45, 0.70, 1.0, 0.20 + f * 0.4), 2.0, true)
		draw_circle(b.pos, r * 0.16, Color(0.65, 0.88, 1.0, 0.25 + f * 0.6))
		draw_arc(b.pos, r * 0.62, 0.0, TAU, 20, Color(0.45, 0.70, 1.0, 0.10), 1.0, true)


func _draw_targets() -> void:
	var charged := charging
	var power := _charge_power() if charging else 0.0
	var vis := _view_rect().grow(CULL_MARGIN)
	for tg in targets:
		if not vis.has_point(tg.pos):
			continue
		var fade := clampf(tg.age / 0.22, 0.0, 1.0)
		var pulse := 1.0 + sin(t * 3.0 + tg.phase) * 0.045
		var r: float = tg.radius * pulse
		var base: Color = tg.color
		var f: float = clampf(tg.flash, 0.0, 1.0)

		draw_circle(tg.pos, r + 14.0, Color(base.r, base.g, base.b, (0.045 + f * 0.10) * fade))
		# glossy sphere body
		draw_circle(tg.pos, r, Color(base.r * 0.35, base.g * 0.35, base.b * 0.35, 0.98 * fade))
		draw_circle(tg.pos + Vector2(-r * 0.10, -r * 0.10), r * 0.86,
			Color(base.r * 0.62, base.g * 0.62, base.b * 0.62, 0.95 * fade))
		draw_circle(tg.pos + Vector2(-r * 0.26, -r * 0.26), r * 0.36,
			Color(1.0, 1.0, 1.0, (0.42 + f * 0.4) * fade))
		draw_arc(tg.pos, r, 0.0, TAU, 24, Color(base.r, base.g, base.b, 0.9 * fade),
			2.0 + f * 3.0, true)

		match tg.kind:
			"basic":
				for k in 3:
					var a: float = tg.spin + k * TAU / 3.0
					draw_circle(tg.pos + Vector2(cos(a), sin(a)) * r * 0.55, 2.0,
						Color(1.0, 0.85, 0.95, 0.55 * fade))
			"armored":
				var ready: bool = charged and power >= tg.req
				var rc := GREEN if ready else Color(1.0, 0.62, 0.22, 0.75)
				rc.a *= fade
				# Points that actually stick out past the shell.
				var spike_spin: float = t * 0.9 + tg.phase
				for k in 10:
					var a: float = spike_spin + k * TAU / 10.0
					var out := Vector2(cos(a), sin(a))
					var side_w := out.orthogonal() * (r * 0.16)
					var root: Vector2 = tg.pos + out * (r * 0.88)
					var prong: Vector2 = tg.pos + out * (r + SPIKE_LEN)
					draw_colored_polygon(PackedVector2Array([prong, root + side_w, root - side_w]), rc)
				draw_arc(tg.pos, r * 0.55, 0.0, TAU, 16,
					Color(base.r, base.g, base.b, 0.55 * fade), 2.0, true)
			"chaser":
				var dir: Vector2 = (ball_pos - tg.pos).normalized()
				var side: Vector2 = dir.orthogonal() * r * 0.42
				var tip: Vector2 = tg.pos + dir * r * 0.55
				var back: Vector2 = tg.pos - dir * r * 0.34
				draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]),
					Color(1.0, 0.95, 1.0, 0.72 * fade))
			"drifter":
				var d: Vector2 = tg.vel.normalized()
				for k in 2:
					draw_circle(tg.pos - d * r * (0.42 + k * 0.34), 1.8,
						Color(1.0, 1.0, 1.0, (0.34 - k * 0.12) * fade))


## Pickups waiting to be grabbed by the ball.
func _draw_powerups() -> void:
	var vis := _view_rect().grow(CULL_MARGIN)
	for p in powerups:
		if not vis.has_point(p.pos):
			continue
		# Blink through the last seconds so the fade is readable.
		if p.life < 3.0 and fmod(p.life, 0.5) < 0.2:
			continue
		var c := _powerup_color(p.kind)
		var pulse := 0.5 + 0.5 * sin(t * 3.4 + p.phase)
		draw_circle(p.pos, 19.0 + pulse * 4.0, Color(c.r, c.g, c.b, 0.09))
		draw_circle(p.pos, 13.0, Color(0.03, 0.05, 0.10, 0.88))
		draw_arc(p.pos, 13.0, 0.0, TAU, 20, Color(c.r, c.g, c.b, 0.9), 2.0, true)
		match p.kind:
			"time":
				draw_arc(p.pos, 7.5, 0.0, TAU, 16, Color(c.r, c.g, c.b, 0.55), 1.5, true)
				draw_line(p.pos, p.pos + Vector2(0.0, -5.5), c, 1.6, true)
				draw_line(p.pos, p.pos + Vector2(4.0, 1.5), c, 1.6, true)
			"rapid":
				for k in 3:
					draw_circle(p.pos + Vector2(0.0, -4.5 + k * 4.5), 2.0, c)
			_:
				var pts := PackedVector2Array()
				for k in 8:
					var a: float = p.phase + k * TAU / 8.0
					var rr := 8.5 if k % 2 == 0 else 3.4
					pts.append(p.pos + Vector2(cos(a), sin(a)) * rr)
				draw_colored_polygon(pts, c)


## The boss: dark armour plates around a molten core, with hp pips on the rim.
func _draw_boss() -> void:
	var b: Boss = boss
	if b == null:
		return
	if not _view_rect().grow(CULL_MARGIN + 120.0).has_point(b.pos):
		return
	var f: float = clampf(b.flash, 0.0, 1.0)
	var r: float = b.radius * (1.0 + sin(t * 2.0) * 0.02)
	draw_circle(b.pos, r + 42.0 + f * 24.0, Color(1.0, 0.22, 0.32, 0.05 + f * 0.08))
	draw_circle(b.pos, r, Color(0.09, 0.05, 0.10, 0.98))
	draw_circle(b.pos, r * 0.88, Color(0.22, 0.08, 0.13, 0.98))
	for k in 6:
		var a: float = b.phase * 0.8 + k * TAU / 6.0
		var out := Vector2(cos(a), sin(a))
		var root: Vector2 = b.pos + out * (r * 0.70)
		var tip: Vector2 = b.pos + out * (r + 12.0 + f * 10.0)
		var side := out.orthogonal() * (r * 0.26)
		var plate := Color(0.62, 0.14, 0.24, 0.95).lerp(WHITE, f)
		draw_colored_polygon(PackedVector2Array([tip, root + side, root - side]), plate)
	draw_circle(b.pos, r * 0.44 + sin(b.core) * 3.0, Color(1.5, 0.45, 0.18, 0.95))
	draw_circle(b.pos, r * 0.24, Color(2.4, 1.5, 0.75, 0.98))
	for k in b.max_hp:
		var a: float = -PI * 0.5 + k * TAU / float(maxi(b.max_hp, 1))
		var at: Vector2 = b.pos + Vector2(cos(a), sin(a)) * (r + 31.0)
		draw_circle(at, 3.4, GOLD if k < b.hp else Color(0.34, 0.10, 0.14, 0.75))


## Ember volleys in flight.
func _draw_boss_shots() -> void:
	var vis := _view_rect().grow(CULL_MARGIN)
	for s in boss_shots:
		if not vis.has_point(s.pos):
			continue
		draw_circle(s.pos, s.radius + 7.0, Color(1.0, 0.32, 0.22, 0.09))
		draw_circle(s.pos, s.radius, Color(0.30, 0.05, 0.05, 0.95))
		draw_circle(s.pos, s.radius * 0.6, Color(1.9, 0.55, 0.2, 0.95))
		draw_arc(s.pos, s.radius + 3.5, s.phase, s.phase + 2.0, 10,
			Color(1.0, 0.55, 0.28, 0.7), 2.0, true)


## Charged-shot preview: a ballistic arc stepped with the same forces the ball
## feels (gravity and speed decay), ending at the first thing it would touch.
func _draw_aim() -> void:
	var dir := mouse_pos - ball_pos
	if dir.length() < 1.0:
		dir = Vector2.RIGHT
	dir = dir.normalized()

	var path := _predict_arc(dir * _charge_power())
	var n := path.size()
	if n < 2:
		return

	var tip: Vector2 = path[n - 1]
	if tip.distance_to(ball_pos) < BALL_R + 12.0:
		return

	for i in n:
		if i % 2 == 1:
			continue
		var pt: Vector2 = path[i]
		if pt.distance_to(ball_pos) < BALL_R + 13.0:
			continue
		var u := float(i) / float(n)
		draw_circle(pt, lerpf(2.8, 1.1, u), Color(0.55, 0.95, 1.0, lerpf(0.52, 0.12, u)))

	var heading: Vector2 = tip - path[n - 2]
	if heading.length() < 0.001:
		heading = dir
	heading = heading.normalized()
	var side := heading.orthogonal()
	# Red arrowhead warns when the shot is about to end in the lava.
	var col := Color(0.85, 1.0, 1.0, 0.85)
	if tip.y >= _lava_top() - BALL_R - 4.0:
		col = Color(1.0, 0.42, 0.30, 0.95)
	draw_colored_polygon(PackedVector2Array([
		tip + heading * 13.0,
		tip + side * 7.5 - heading * 1.0,
		tip - side * 7.5 - heading * 1.0,
	]), col)


## Steps the launch forward in small slices and stops at the first wall, lava
## surface, bumper or ball along the way.
func _predict_arc(v0: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var pos := ball_pos
	var vel := v0
	var h := 1.0 / 60.0
	var surface := _lava_top() - BALL_R
	var min_x := WORLD.position.x + BALL_R
	var max_x := WORLD.end.x - BALL_R
	var min_y := WORLD.position.y + BALL_R
	# Bodies further away than the shot can possibly travel are dropped up front,
	# so the per-step sweep tests a handful of candidates instead of every ball.
	var reach := v0.length() * 1.5 + 80.0
	var reach2 := reach * reach
	arc_bodies.clear()
	arc_radii.clear()
	for b in bumpers:
		if b.pos.distance_squared_to(ball_pos) < reach2:
			arc_bodies.append(b.pos)
			arc_radii.append(b.radius + BALL_R)
	for tg in targets:
		if tg.pos.distance_squared_to(ball_pos) < reach2:
			arc_bodies.append(tg.pos)
			arc_radii.append(tg.radius + BALL_R + (SPIKE_LEN if tg.kind == "armored" else 0.0))
	if boss != null and boss.pos.distance_squared_to(ball_pos) < reach2:
		arc_bodies.append(boss.pos)
		arc_radii.append(boss.radius + BALL_R)
	var drag_step := pow(SPEED_RETAIN, h)
	for i in 90:
		vel.y += GRAVITY * h
		vel *= drag_step
		pos += vel * h
		pts.append(pos)
		if pos.x < min_x or pos.x > max_x or pos.y < min_y or pos.y > surface:
			break
		var blocked := false
		for k in arc_bodies.size():
			var gap: float = arc_radii[k]
			if pos.distance_squared_to(arc_bodies[k]) < gap * gap:
				blocked = true
				break
		if blocked:
			break
	return pts


# ------------------------------------------------------------------ draw actors
func _draw_ball() -> void:
	var n := trail.size()
	for i in n:
		var u := float(i + 1) / float(n)
		draw_circle(trail[i], BALL_R * (0.2 + u * 0.8), Color(0.40, 0.88, 1.0, u * u * 0.16))

	draw_circle(ball_pos, BALL_R + 18.0 + ball_flash * 8.0, Color(0.40, 0.90, 1.0, 0.05 + ball_flash * 0.04))
	draw_circle(ball_pos, BALL_R + 7.0, Color(0.50, 0.95, 1.0, 0.12))
	draw_circle(ball_pos, BALL_R, CYAN_HOT)
	draw_circle(ball_pos - Vector2(BALL_R * 0.3, BALL_R * 0.3), BALL_R * 0.45, WHITE_HOT)

	if mode == "play" and shot_ready:
		draw_arc(ball_pos, BALL_R + 12.0, 0.0, TAU, 40, Color(0.55, 0.95, 1.0, 0.32), 2.0, true)

	if charging:
		var c := clampf(charge_t / CHARGE_TIME, 0.0, 1.0)
		draw_arc(ball_pos, BALL_R + 11.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.10), 5.0, true)
		if c > 0.0:
			var col := Color.from_hsv(lerpf(0.52, 0.86, c), 0.80, 1.0)
			draw_arc(ball_pos, BALL_R + 11.0, -PI * 0.5, -PI * 0.5 + TAU * c, 32, col, 5.0, true)
			draw_circle(ball_pos, BALL_R + 5.0, Color(col.r, col.g, col.b, 0.08))


## Particles are 2-9 px sparks: quads tessellate far cheaper than circle fans.
func _draw_particles() -> void:
	var vis := _view_rect().grow(CULL_MARGIN)
	for p in particles:
		if not vis.has_point(p.pos):
			continue
		var a := clampf(p.life / p.max_life, 0.0, 1.0)
		if a <= 0.0:
			continue
		var sz: float = p.size * (0.4 + a * 0.6)
		draw_rect(Rect2(p.pos - Vector2(sz, sz), Vector2(sz, sz) * 2.0),
			Color(p.color.r, p.color.g, p.color.b, a))


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
	elif not shot_ready:
		col = Color(0.85, 0.45, 0.55, 0.55)
	draw_arc(mouse_pos, 9.0, 0.0, TAU, 20, col, 1.5, true)
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
	if mode == "play":
		var sy := 82.0
		_text("SHOT READY" if shot_ready else "HIT A BALL TO RELOAD", Vector2(48.0, sy), 12,
			CYAN if shot_ready else RED)
		if rapid_t > 0.0:
			sy += 20.0
			_text("RAPID  %.1fs" % rapid_t, Vector2(48.0, sy), 12, CYAN)
		if overdrive_t > 0.0:
			sy += 20.0
			_text("OVERDRIVE  %.1fs" % overdrive_t, Vector2(48.0, sy), 12, PINK)

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

	if mode == "play" and boss != null:
		_draw_boss_bar()


func _draw_boss_bar() -> void:
	var b: Boss = boss
	if b == null:
		return
	var bw := 520.0
	var bx := 640.0 - bw * 0.5
	var by := 84.0
	_text_center_at(Vector2(640.0, by - 8.0), "THE WARDEN", 14, GOLD, bold_font)
	draw_rect(Rect2(bx - 3.0, by, bw + 6.0, 12.0), Color(0.02, 0.03, 0.06, 0.75))
	var p := clampf(float(b.hp) / float(maxi(b.max_hp, 1)), 0.0, 1.0)
	if p > 0.0:
		draw_rect(Rect2(bx, by + 3.0, bw * p, 6.0), Color(1.0, 0.28, 0.34).lerp(GOLD, p))


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
	for p in powerups:
		var pc := _powerup_color(p.kind)
		draw_circle(mm.position + (p.pos - WORLD.position) * sc, 2.4,
			Color(pc.r, pc.g, pc.b, 0.95))
	if boss != null:
		var bpos: Vector2 = mm.position + (boss.pos - WORLD.position) * sc
		draw_circle(bpos, 5.0, Color(1.0, 0.30, 0.30, 0.95))
		draw_arc(bpos, 7.5, 0.0, TAU, 14, Color(1.0, 0.45, 0.45, 0.7), 1.5, true)
	draw_rect(Rect2(mm.position.x, mm.position.y + (_lava_top() - WORLD.position.y) * sc.y,
		mm.size.x, LAVA_H * sc.y), Color(1.0, 0.45, 0.10, 0.55))

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

	_rule(366.0, "HOLD", "charge your bounce")
	_rule(394.0, "RELEASE", "launch toward the cursor")
	_rule(422.0, "RICOCHET", "shatter balls at speed")
	_rule(450.0, "EARN SHOTS", "hit a ball to shoot again")
	_rule(478.0, "SPIKES", "they hunt you, slow hits kill")
	_rule(506.0, "EXPLORE", "the world scrolls past the screen")
	_rule(534.0, "LAVA", "the molten floor ends your run")

	var pulse := 0.55 + 0.45 * sin(t * 3.2)
	_text_center_at(Vector2(640.0, 580.0), "CLICK TO START", 22, Color(0.85, 0.97, 1.0, pulse))
	if best > 0:
		_text_center_at(Vector2(640.0, 630.0), "BEST  %d" % best, 16, DIM)
	_text_center_at(Vector2(640.0, 690.0), "R restart   ·   M mute", 12, Color(0.45, 0.60, 0.80, 0.55))


func _draw_game_over() -> void:
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.02, 0.015, 0.04, 0.78))
	var headline := "TIME'S UP"
	if died_on_spikes:
		headline = "IMPALED"
	elif died_by_blast:
		headline = "BLASTED"
	elif died_in_lava:
		headline = "MELTED"
	_text_center_at(Vector2(640.0, 250.0), headline, 68, PINK, bold_font)
	_text_center_at(Vector2(640.0, 320.0), "SCORE", 12, DIM)
	_text_center_at(Vector2(640.0, 392.0), str(score), 72, WHITE, bold_font)
	_text_center_at(Vector2(640.0, 442.0), "SMASHED %d" % kills, 20, CYAN)
	if new_best:
		_text_center_at(Vector2(640.0, 486.0), "NEW BEST!", 18, GOLD, bold_font)
	elif best > 0:
		_text_center_at(Vector2(640.0, 486.0), "BEST  %d" % best, 16, DIM)
	var pulse := 0.6 + 0.4 * sin(t * 4.0)
	_text_center_at(Vector2(640.0, 572.0), "CLICK TO PLAY AGAIN", 20, Color(0.85, 0.97, 1.0, pulse))


## F3 overlay: frame rate, renderer workload and script time.
func _draw_stats() -> void:
	var win := DisplayServer.window_get_size()
	var lines := [
		"FPS %d" % Engine.get_frames_per_second(),
		"draws %d" % int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"prims %d" % int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"proc %.1f ms" % (Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0),
		"phys %.1f ms" % (Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0),
		"particles %d" % particles.size(),
		"glow %s" % ("on" if glow_env != null and glow_env.glow_enabled else "off"),
		"window %dx%d" % [win.x, win.y],
	]
	var y := 134.0
	for s in lines:
		_text(s, Vector2(48.0, y), 12, GREEN)
		y += 16.0


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
