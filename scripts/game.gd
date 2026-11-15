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
const CAM_MIN_ZOOM := 0.55       # widest the camera pulls back for boss+ball
const TARGET_POP := 130          # live balls streamed around the camera
const BUMPER_POP := 40           # static bumpers spread across the world
const MIN_VISIBLE := 18          # always keep at least this many balls on screen

# Balls are spawned this far outside the screen and unloaded once they are
# further away than STREAM_KEEP, so only nearby balls exist at any time.
const STREAM_MARGIN := 620.0
const STREAM_KEEP := 1100.0
const STREAM_INTERVAL := 0.15
const CULL_MARGIN := 150.0       # skip drawing anything beyond the screen edge

const START_TIME := 32.0         # seconds on the clock at the start
const TIME_PER_KILL := 2.4       # seconds added per ball broken
const TIME_CAP := 48.0           # clock can never exceed this

const GRAVITY := 1150.0          # downward pull on the ball (px/s²)
const LAVA_H := 120.0            # depth of the molten floor at the bottom
const WALL_REST := 0.97          # energy kept when bouncing off a wall
const BUMPER_REST := 1.06        # bumpers add a little energy (pinball feel)
const SPEED_RETAIN := 0.87       # fraction of speed kept each second
const MAX_SPEED := 2600.0
const RICOCHET_LIFT := 560.0     # upward kick each time a ball shatters
const SPIKE_LEN := 14.0          # how far the spiked balls' points poke out
const MIN_POWER := 560.0         # launch speed of a tap
const MAX_POWER := 2050.0        # launch speed of a full charge
const CHARGE_TIME := 0.7         # seconds to reach full charge
const SLOWMO := 0.30             # world speed while charging
const KILL_SPEED := 240.0        # minimum impact speed for basic targets

# Boss: wakes at BOSS_SCORE, lumbers at the ball, spits plasma.
const BOSS_SCORE := 5000         # score that wakes the boss
const BOSS_R := 64.0             # body radius, ~2.5x the biggest balls
const BOSS_HP := 6               # solid hits to bring it down
const BOSS_REQ := 850.0          # impact speed needed to wound it
const BOSS_SPIKE_LEN := 22.0     # reach of the boss spikes
const BOSS_SPEED := 54.0         # slow drift toward the ball (px/s)
const BOSS_FIRE_T := 1.7         # seconds between volleys at full health
const BOSS_SHOT_SPEED := 300.0
const BOSS_SHOT_R := 9.0
const BOSS_SHOT_LIFE := 4.0
const BOSS_MAX_SHOTS := 8
const BOSS_HIT_SCORE := 100
const BOSS_KILL_SCORE := 1500

# Autoaim powerup: a rare star ball hands the ball to an autopilot that
# breaks AUTO_KILLS balls on its own, then gives control back.
const STAR_REQ := 150.0
const STAR_SPEED := 30.0
const STAR_WEIGHT := 6.0
const AUTO_SPEED := 1400.0
const AUTO_KILLS := 20

# Shield powerup: bankable extra hits that tank lethal shots, max SHIELD_MAX.
const SHIELD_BLUE := Color(0.45, 0.85, 1.0)
const SHIELD_REQ := 150.0
const SHIELD_SPEED := 30.0
const SHIELD_WEIGHT := 7.0
const SHIELD_MAX := 5

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
# Customization: ball skins, menu buttons and customize rows.
const BALL_SKINS := [CYAN, PINK, GOLD, GREEN, PURPLE]
const BALL_NAMES := ["CYAN", "PINK", "GOLD", "GREEN", "PURPLE"]
const CUSTOM_LABELS := ["BALL", "TRAIL", "SHAKE", "GLOW", "SOUND"]
const BTN_START := Rect2(490.0, 532.0, 300.0, 56.0)
const BTN_CUSTOM := Rect2(490.0, 596.0, 146.0, 40.0)
const BTN_BACK := Rect2(540.0, 596.0, 200.0, 44.0)
# Online versus (mirrored arenas, Godot ENet, no outside services).
const NET_PORT := 7777
const BTN_NET := Rect2(644.0, 596.0, 146.0, 40.0)
const BTN_NET_HOST := Rect2(440.0, 280.0, 400.0, 56.0)
const BTN_NET_JOIN := Rect2(440.0, 348.0, 400.0, 52.0)
const BTN_NET_ROLE := Rect2(490.0, 510.0, 300.0, 44.0)
const BTN_NET_ROLE2 := Rect2(490.0, 360.0, 300.0, 44.0)
const NET_IP_RECT := Rect2(440.0, 280.0, 400.0, 48.0)
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
	var tame := false   # duel balls never home in; only arena balls hunt
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

class Boss:
	var pos: Vector2
	var hp: int
	var max_hp: int
	var radius: float
	var phase: float = 0.0
	var flash: float = 0.0
	var fire_t: float = 0.0
	var mercy_t: float = 0.0

class BossShot:
	var pos: Vector2
	var vel: Vector2
	var life: float

# ------------------------------------------------------------------ state
var mode: String = "title"          # title | play | over
var died_in_lava: bool = false
var died_on_spikes: bool = false
var kills: int = 0
var score: int = 0
var best: int = 0
var boss: Boss = null            # the 5000-point wake-up; null when none
var boss_defeated: bool = false  # one boss per run
var boss_shots: Array = []
var autoaim := false                # powerup autopilot: homing ball, no input
var auto_left := 0                  # balls left to break before control returns
var shields := 0                    # banked extra hits, max SHIELD_MAX
var hurt_cd := 0.0                  # grace after a shield tanks a hit
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

# post fx
var bloom_level: float = 0.35
var vignette_t: float = 0.2
var glow_env: Environment
var vignette_tex: ImageTexture

var cam: Vector2 = Vector2.ZERO        # world point shown at screen center
var cam_snap: bool = true
var cam_zoom := 1.0              # 1 = normal; <1 pulls back to frame boss+ball
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
var touch_aim_id := -1   # finger holding the charge; -1 when no touch aims
var stick_id := -1        # second finger driving the gun stick; -1 = stowed
var stick_on := false
var stick_base := Vector2.ZERO   # screen-space anchor + knob of the gun stick
var stick_knob := Vector2.ZERO
const STICK_R := 70.0     # gun-stick travel in screen px

# customization (persisted to user://bounce_back.cfg)
var ball_idx := 0
var trail_opt := true
var shake_opt := true
var glow_opt := true

# online versus: off | host | client; screens menu|join|host|ready|countdown
var net_mode := "off"
var net_screen := "menu"
var net_status := ""
var net_count := 0.0
var net_send_t := 0.0
var net_timeout := 0.0
var foe_score := 0
var foe_kills := 0
var join_ip := "127.0.0.1"
var join_focused := false

# duel (versus shooter): host-authoritative shared arena, 100 HP each.
const DUEL_TIME := 60.0
const DUEL_HP := 100
const DUEL_GUN_NAMES := ["FISTS", "PISTOL", "SPREAD"]
const DUEL_BULLET_R := 10.0  # versus bullet body radius: chunky, easier to read and land
const DUEL_SNAP_T := 1.0 / 20.0
const DUEL_CHEST_HP := 25
const DUEL_CHEST_RESPAWN_T := 5.0   # host drops a fresh crate this often
const DUEL_BALLS := 78           # smashable balls scattered around the duel arena
const DUEL_SPIKE_REQ := 700.0    # fighter speed needed to smash a spiky ball
const DUEL_SPIKE_DMG := 10       # damage for a slow touch on spikes
const DUEL_LAVA_DMG := 15        # burn tick for resting on the molten floor
const DUEL_LAVA_GRACE := 1.0      # seconds between lava burn ticks
const DUEL_MAX_PLAYERS := 4      # host + up to 3 joiners in one shared arena
const DUEL_FOE_COLS := [Color(1.0, 0.55, 0.25), Color(0.75, 0.55, 1.0), Color(0.45, 1.0, 0.55)]
var duel_me := {}
var duel_foe := {}              # first rival; alias of duel_foes[0] when present
var duel_foes: Array = []       # every rival fighter dict, roster order excluding me
var duel_foe_goal := Vector2.ZERO
var duel_foe_goals: Array = []  # predicted positions, parallel to duel_foes
var duel_ids: Array = []        # peer ids in fighter order; index 0 is the host
var duel_my_id: int = 0         # my fighter index into duel_ids order
var duel_was_alive := true  # tracks my death so elimination banners once
var duel_host_plays := true  # lobby toggle: host fights, or sits out and spectates
var duel_bullets: Array = []
var duel_chests: Array = []
var duel_chest_t := 0.0
var duel_chest_max := 6
var duel_pickups: Array = []
var duel_snap_t := 0.0
var duel_refill_t := 0.0
var duel_over := false
var duel_winner := -1  # winning fighter index, or -1 for draw/undecided

var bumpers: Array = []
var targets: Array = []
var particles: Array = []
var popups: Array = []
var mote_t: float = 0.0
var charge_mote_t: float = 0.0
var ember_t: float = 0.0

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
	_load_custom()
	_enter_title()


func _setup_fonts() -> void:
	body_font = ThemeDB.fallback_font
	var bv := FontVariation.new()
	bv.base_font = body_font
	bv.variation_embolden = 0.75
	bold_font = bv


## Engine bloom: a glow-enabled environment over the 2D canvas. Colours above
## 1.0 in the palette bleed light, and the intensity is driven below.
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
	if glow_env != null:
		glow_env.glow_enabled = glow_opt
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


func _load_custom() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://bounce_back.cfg") == OK:
		ball_idx = clampi(int(cfg.get_value("custom", "ball", 0)), 0, BALL_SKINS.size() - 1)
		trail_opt = bool(cfg.get_value("custom", "trail", true))
		shake_opt = bool(cfg.get_value("custom", "shake", true))
		glow_opt = bool(cfg.get_value("custom", "glow", true))
		muted = bool(cfg.get_value("custom", "muted", false))


func _save_custom() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://bounce_back.cfg")
	cfg.set_value("custom", "ball", ball_idx)
	cfg.set_value("custom", "trail", trail_opt)
	cfg.set_value("custom", "shake", shake_opt)
	cfg.set_value("custom", "glow", glow_opt)
	cfg.set_value("custom", "muted", muted)
	cfg.save("user://bounce_back.cfg")


func _ball_col() -> Color:
	return BALL_SKINS[clampi(ball_idx, 0, BALL_SKINS.size() - 1)]


func _ball_hot() -> Color:
	var c := _ball_col()
	return Color(minf(c.r * 1.6 + 0.15, 2.2), minf(c.g * 1.6 + 0.15, 2.2), minf(c.b * 1.6 + 0.15, 2.2))


func _custom_row_rect(i: int) -> Rect2:
	return Rect2(380.0, 206.0 + float(i) * 60.0, 520.0, 48.0)


func _custom_on(i: int) -> bool:
	match i:
		1:
			return trail_opt
		2:
			return shake_opt
		3:
			return glow_opt
		4:
			return not muted
	return true


func _custom_value(i: int) -> String:
	return "ON" if _custom_on(i) else "OFF"


func _cycle_custom(i: int) -> void:
	match i:
		0:
			ball_idx = (ball_idx + 1) % BALL_SKINS.size()
		1:
			trail_opt = not trail_opt
		2:
			shake_opt = not shake_opt
		3:
			glow_opt = not glow_opt
		4:
			muted = not muted
			if muted:
				for p in players:
					p.stop()
	_save_custom()
	_sfx("bounce", 0.0, -18.0)


func _custom_click(mp: Vector2) -> void:
	if BTN_BACK.has_point(mp):
		mode = "title"
		return
	for i in 5:
		if _custom_row_rect(i).has_point(mp):
			_cycle_custom(i)
			return


func _connect_net_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_net_peer_connected):
		multiplayer.peer_connected.connect(_on_net_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_net_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_net_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_net_connected_to_server):
		multiplayer.connected_to_server.connect(_on_net_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_net_connection_failed):
		multiplayer.connection_failed.connect(_on_net_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_net_server_disconnected):
		multiplayer.server_disconnected.connect(_on_net_server_disconnected)


func _net_host_ips() -> Array:
	var out: Array = []
	for a in IP.get_local_addresses():
		if a.contains(".") and not a.begins_with("127."):
			out.append(a)
	if out.is_empty():
		out.append("127.0.0.1")
	return out


func _net_host() -> void:
	_net_leave_quiet()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(NET_PORT, DUEL_MAX_PLAYERS) != OK:
		net_status = "HOST FAILED"
		return
	multiplayer.multiplayer_peer = peer
	net_mode = "host"
	net_screen = "host"
	_connect_net_signals()


func _net_join(ip: String) -> void:
	_net_leave_quiet()
	join_ip = ip.strip_edges()
	if join_ip == "":
		net_status = "ENTER AN IP FIRST"
		return
	# Optional :port suffix (one colon only, so IPv6 stays the host).
	var host := join_ip
	var port := NET_PORT
	if join_ip.count(":") == 1:
		var cut := join_ip.rfind(":")
		var maybe_port := join_ip.substr(cut + 1)
		if maybe_port == "" or maybe_port.is_valid_int():
			host = join_ip.substr(0, cut)
			if maybe_port != "":
				port = clampi(maybe_port.to_int(), 1, 65535)
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(host, port) != OK:
		net_status = "JOIN FAILED"
		return
	multiplayer.multiplayer_peer = peer
	net_mode = "client"
	net_screen = "join"
	net_status = "CONNECTING..."
	net_timeout = 12.0
	_connect_net_signals()


func _net_leave_quiet() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	net_mode = "off"
	net_screen = "menu"
	net_status = ""
	join_focused = false
	foe_score = 0
	foe_kills = 0
	net_count = 0.0
	net_timeout = 0.0


func _net_leave() -> void:
	_net_leave_quiet()
	_enter_title()


@rpc("authority", "call_remote", "reliable")
func _net_begin(roster: Array = []) -> void:
	net_count = 3.0
	foe_score = 0
	foe_kills = 0
	net_send_t = 0.0
	mode = "net"
	net_screen = "countdown"
	_duel_reset(roster)
	_banner("3")


## Ordered peer-id roster for the match: host first, then clients ascending.
## Capped at DUEL_MAX_PLAYERS; extra joiners are ignored at start.
func _duel_roster() -> Array:
	# A spectating host stays out of the fighter order; the arena is peers only.
	var ids: Array = []
	if duel_host_plays:
		ids.append(multiplayer.get_unique_id())
	var peers := multiplayer.get_peers()
	peers.sort()
	ids.append_array(peers)
	return ids.slice(0, DUEL_MAX_PLAYERS)


## Every fighter dict in roster order; duel_me is duel_all()[duel_my_id].
## Dictionaries are shared references, so edits through either stick.
func _duel_all() -> Array:
	# A spectating host has no fighter: duel_me is a dead dummy, so the real
	# fighters are just the foes, already in roster order.
	var all: Array = []
	if duel_my_id >= 0:
		all.append(duel_me)
	all.append_array(duel_foes)
	return all


## My fighter index into duel_ids order. Owner tags in bullets match.
func _duel_role() -> int:
	return duel_my_id


## No live fighter of my own: I died mid-round, or the host is sitting out.
## Camera, HUD, minimap and my-ball drawing all key off this.
func _duel_watching() -> bool:
	return net_mode != "off" and mode == "play" and not duel_over and (duel_my_id < 0 or int(duel_me.get("hp", 0)) <= 0)


## First living fighter in arena order for the spectator camera to follow.
func _duel_watch_target() -> Dictionary:
	for f in _duel_all():
		if int((f as Dictionary).get("hp", 0)) > 0:
			return f
	return {}


## Roster slot -> fighter dict. A fighting host owns slot 0 so rivals shift
## by one; a spectating host owns no slot and foes sit in roster order.
func _duel_foe_at(idx: int) -> Dictionary:
	var o := idx if duel_my_id < 0 else idx - 1
	if o < 0 or o >= duel_foes.size():
		return {}
	return duel_foes[o]


func _duel_fighter(pos: Vector2) -> Dictionary:
	return {"pos": pos, "vel": Vector2.ZERO, "hp": DUEL_HP, "gun": 0, "cd": 0.0, "slam": 0.0, "ready": true, "gone": false, "spike": 0.0, "lava": 0.0}


## Roster order decides everything: index 0 is the host, the rest are client
## peer ids ascending. Spawn spots ring the center so 2-4 fighters never
## overlap. duel_me aliases my dict; duel_foes holds every rival in order.
func _duel_reset(roster: Array = []) -> void:
	if roster.is_empty():
		roster = _duel_roster()
	duel_ids = roster
	# find() misses when the host sits out: my_id -1 means spectator, no fighter.
	duel_my_id = duel_ids.find(multiplayer.get_unique_id())
	var n := duel_ids.size()
	var c := WORLD.get_center()
	var all: Array = []
	for i in n:
		var ang := TAU * float(i) / float(maxi(n, 1)) - PI * 0.5
		all.append(_duel_fighter(c + Vector2(cos(ang), sin(ang)) * 650.0))
	if duel_my_id >= 0:
		duel_me = all[duel_my_id]
	else:
		# Spectator dummy: hp 0 keeps it out of sim, snapshots and win checks.
		duel_me = _duel_fighter(c)
		duel_me["hp"] = 0
	duel_foes.clear()
	duel_foe_goals.clear()
	for i in n:
		if i == duel_my_id:
			continue
		duel_foes.append(all[i])
		duel_foe_goals.append(all[i]["pos"])
	duel_foe = duel_foes[0] if not duel_foes.is_empty() else {}
	duel_foe_goal = (duel_foe.get("pos", Vector2.ZERO) as Vector2) if not duel_foe.is_empty() else Vector2.ZERO
	duel_bullets.clear()
	duel_pickups.clear()
	duel_chests.clear()
	stick_on = false
	stick_id = -1
	var offs := [Vector2(-260.0, -160.0), Vector2(260.0, -160.0), Vector2(-260.0, 160.0), Vector2(260.0, 160.0), Vector2(0.0, -340.0), Vector2(0.0, 340.0)]
	for k in (4 if n <= 2 else 6):
		duel_chests.append({"pos": c + offs[k], "hp": DUEL_CHEST_HP})
	duel_chest_max = (4 if n <= 2 else 6) + 2
	duel_chest_t = DUEL_CHEST_RESPAWN_T
	duel_snap_t = 0.0
	duel_over = false
	duel_winner = -1
	duel_was_alive = duel_my_id >= 0
	time_left = DUEL_TIME
	max_time = DUEL_TIME
	score = 0
	kills = 0
	shot_ready = true
	charging = false
	charge_t = 0.0
	ball_pos = duel_me["pos"]
	ball_vel = Vector2.ZERO
	trail.clear()
	particles.clear()
	popups.clear()
	_duel_populate()
	boss = null
	boss_shots.clear()
	autoaim = false
	shields = 0
	hurt_cd = 0.0
	cam = ball_pos
	cam_snap = true
	if duel_my_id >= 0:
		_banner("BREAK CHESTS - GRAB GUNS")
	else:
		_banner("SPECTATING")


@rpc("any_peer", "call_remote", "unreliable")
func _net_score(s: int, k: int) -> void:
	foe_score = s
	foe_kills = k


@rpc("any_peer", "call_remote", "reliable")
func _net_restart_request() -> void:
	if net_mode == "host" and mode == "over":
		var ids := _duel_roster()
		_net_begin(ids)
		_net_begin.rpc(ids)


## Client -> host: my launch impulse. Host owns every client fighter and
## maps the sender id to its roster slot.
@rpc("any_peer", "call_remote", "reliable")
func _duel_launch(v: Vector2) -> void:
	if net_mode != "host" or duel_over or mode != "play":
		return
	var idx := duel_ids.find(multiplayer.get_remote_sender_id())
	var f: Dictionary = _duel_foe_at(idx)
	if f.is_empty():
		return
	if not bool(f.get("ready", true)) or int(f.get("hp", 0)) <= 0 or bool(f.get("gone", false)):
		return
	f["ready"] = false
	f["vel"] = v.limit_length(MAX_SPEED)


## Client -> host: shoot toward a world point. Host validates gun + cooldown.
@rpc("any_peer", "call_remote", "reliable")
func _duel_fire(target: Vector2) -> void:
	if net_mode != "host" or duel_over or mode != "play":
		return
	var idx := duel_ids.find(multiplayer.get_remote_sender_id())
	var f: Dictionary = _duel_foe_at(idx)
	if f.is_empty():
		return
	if int(f.get("hp", 0)) <= 0 or bool(f.get("gone", false)):
		return
	_duel_spawn_shots(f, target, idx)


## Host -> client: full duel snapshot, 20 Hz, unreliable. Fighters ride in
## roster order as [pos, vel, hp, gun, ready] each; I reconcile my slot and
## glide every rival toward its newest sample.
@rpc("authority", "call_remote", "unreliable")
func _net_duel(state: Array) -> void:
	if net_mode != "client" or mode != "play":
		return
	var fighters: Array = state[0]
	for i in range(mini(fighters.size(), duel_ids.size())):
		var fd: Array = fighters[i]
		if fd.size() < 5:
			continue
		if i == duel_my_id:
			var mp: Vector2 = fd[0]
			if mp.distance_to(duel_me["pos"]) < 140.0:
				duel_me["pos"] = (duel_me["pos"] as Vector2).lerp(mp, 0.35)
			else:
				duel_me["pos"] = mp
			duel_me["vel"] = fd[1]
			duel_me["hp"] = fd[2]
			duel_me["gun"] = fd[3]
			duel_me["ready"] = fd[4]
			shot_ready = bool(duel_me["ready"])
		else:
			var o := i if i < duel_my_id else i - 1
			if o < 0 or o >= duel_foes.size():
				continue
			var f: Dictionary = duel_foes[o]
			var new_goal: Vector2 = fd[0]
			if new_goal.distance_to(f["pos"]) > 220.0:
				f["pos"] = new_goal
			duel_foe_goals[o] = new_goal
			f["vel"] = fd[1]
			f["hp"] = fd[2]
			f["gun"] = fd[3]
			f["ready"] = fd[4]
	if not duel_foes.is_empty():
		duel_foe = duel_foes[0]
		duel_foe_goal = duel_foe_goals[0]
	if duel_was_alive and int(duel_me.get("hp", 0)) <= 0:
		duel_was_alive = false
		charging = false
		charge_t = 0.0
		stick_on = false
		_banner("ELIMINATED")
	duel_bullets = state[1]
	duel_chests = state[2]
	duel_pickups = state[3]
	time_left = state[4]
	var flat: Array = state[5]
	targets.clear()
	for i in range(0, flat.size(), 4):
		if i + 3 >= flat.size():
			break
		var tg := Target.new()
		tg.pos = Vector2(float(flat[i]), float(flat[i + 1]))
		tg.radius = float(flat[i + 2])
		tg.tame = true
		# Snapshot balls already exist on the host: full fade-in and a free
		# pulse phase, or every ball would sit near-invisible (age 0).
		tg.age = 1.0
		tg.phase = randf() * TAU
		var dk := int(flat[i + 3])
		if dk == 2:
			tg.kind = "armored"
			tg.color = GOLD
			tg.req = DUEL_SPIKE_REQ
		elif dk == 1:
			tg.kind = "drifter"
			tg.color = GREEN
		else:
			tg.kind = "basic"
			tg.color = PINK
		targets.append(tg)


## Host -> client: the round is decided. Both sides show the verdict.
@rpc("authority", "call_remote", "reliable")
func _duel_end(winner: int) -> void:
	if net_mode == "off":
		return
	duel_over = true
	duel_winner = winner
	mode = "over"
	charging = false
	charge_t = 0.0
	bloom_level = maxf(bloom_level, 1.4)
	_ring(ball_pos, PINK, 18, 320.0)
	shake = maxf(shake, 14.0)
	_sfx("over", 0.0, -4.0)


func _on_net_peer_connected(id: int) -> void:
	if net_mode == "host" and (net_screen == "host" or net_screen == "ready"):
		net_screen = "ready"


func _on_net_connected_to_server() -> void:
	if net_mode == "client":
		net_screen = "ready"
		net_status = ""
		net_timeout = 0.0


func _on_net_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	net_mode = "off"
	net_timeout = 0.0
	net_status = "CONNECTION FAILED - CHECK IP & FIREWALL"


func _on_net_server_disconnected() -> void:
	if net_mode == "client":
		_net_leave()
		_banner("FOE LEFT")


func _on_net_peer_disconnected(id: int) -> void:
	if net_mode != "host":
		return
	# A rival leaving the lobby just shrinks the next roster; mid-match it
	# eliminates their fighter and the rest play on.
	var idx := duel_ids.find(id)
	if idx < 0:
		return
	var allf := _duel_all()
	if idx < allf.size():
		var f: Dictionary = allf[idx]
		f["hp"] = 0
		f["gone"] = true
		_popup((f["pos"] as Vector2) + Vector2(0.0, -30.0), "LEFT", RED, 16)


func _net_click(mp: Vector2) -> void:
	if net_screen == "countdown":
		return
	if BTN_BACK.has_point(mp):
		_net_leave()
		return
	if net_screen == "menu":
		if BTN_NET_HOST.has_point(mp):
			_net_host()
		elif BTN_NET_JOIN.has_point(mp):
			net_screen = "join"
	elif net_screen == "host" and net_mode == "host":
		if BTN_NET_ROLE.has_point(mp):
			duel_host_plays = not duel_host_plays
	elif net_screen == "join":
		if NET_IP_RECT.has_point(mp):
			join_focused = true
		else:
			join_focused = false
			if BTN_NET_JOIN.has_point(mp):
				_net_join(join_ip)
	elif net_screen == "ready" and net_mode == "host":
		if BTN_NET_ROLE2.has_point(mp):
			duel_host_plays = not duel_host_plays
		elif BTN_START.has_point(mp):
			var ids := _duel_roster()
			_net_begin(ids)
			_net_begin.rpc(ids)


func _net_key(code: int) -> void:
	if net_screen != "join" or not join_focused:
		return
	if code >= KEY_0 and code <= KEY_9 and join_ip.length() < 48:
		join_ip += "%c" % code
	elif code == KEY_PERIOD and join_ip.length() < 48:
		join_ip += "."
	elif (code == KEY_COLON or code == KEY_SEMICOLON) and join_ip.length() < 48:
		join_ip += ":"
	elif code == KEY_BACKSPACE and join_ip.length() > 0:
		join_ip = join_ip.substr(0, join_ip.length() - 1)
	elif code == KEY_ENTER or code == KEY_KP_ENTER:
		_net_join(join_ip)


# ------------------------------------------------------------------ input
## Mobile: finger 1 holds/drags to charge and aim, lifting fires — exactly
## like the left mouse button. A second finger anchors a gun stick (versus
## only): push it to aim, hold it to keep shooting. While any touch drives
## the game, emulated mouse events are ignored so nothing jumps/double-fires.
func _touch_pos(ev_position: Vector2) -> Vector2:
	return _screen_to_world(ev_position)


func _unhandled_input(event: InputEvent) -> void:
	var st := event as InputEventScreenTouch
	if st:
		mouse_seen = true
		if st.pressed:
			if touch_aim_id == -1:
				touch_aim_id = st.index
				mouse_pos = _touch_pos(st.position)
				if mode == "play":
					_begin_charge()
			elif not stick_on and mode == "play" and net_mode != "off" and not duel_over and int(duel_me.get("hp", 0)) > 0:
				stick_on = true
				stick_id = st.index
				stick_base = st.position
				stick_knob = st.position
		else:
			if st.index == touch_aim_id:
				touch_aim_id = -1
				if mode == "play":
					_fire()
			elif st.index == stick_id:
				stick_on = false
				stick_id = -1
		return
	var dr := event as InputEventScreenDrag
	if dr:
		if dr.index == touch_aim_id:
			mouse_pos = _touch_pos(dr.position)
			mouse_seen = true
		elif dr.index == stick_id and stick_on:
			stick_knob = dr.position
		return
	if event is InputEventMouseMotion:
		mouse_seen = true
		return

	var mb := event as InputEventMouseButton
	if (touch_aim_id >= 0 or stick_on) and (mb and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT)):
		return
	if mb and mb.button_index == MOUSE_BUTTON_RIGHT:
		if mb.pressed and mode == "play" and net_mode != "off":
			_duel_try_fire(mouse_pos)
		return
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			if mode == "play":
				_begin_charge()
			elif mode == "title":
				if BTN_START.has_point(mb.position):
					_start_game()
				elif BTN_CUSTOM.has_point(mb.position):
					mode = "custom"
				elif BTN_NET.has_point(mb.position):
					mode = "net"
					net_screen = "menu"
					net_status = ""
			elif mode == "custom":
				_custom_click(mb.position)
			elif mode == "net":
				_net_click(mb.position)
			elif mode == "over":
				if net_mode == "off":
					_start_game()
		else:
			_fire()
		return

	var key := event as InputEventKey
	if key and not key.echo:
		if (net_mode != "off" or mode == "net") and key.pressed:
			if key.keycode == KEY_ESCAPE:
				get_tree().quit()
			elif key.keycode == KEY_M:
				muted = not muted
				if muted:
					for p in players:
						p.stop()
				_save_custom()
			elif key.keycode == KEY_B and mode == "over":
				_net_leave()
			elif (key.keycode == KEY_R or key.keycode == KEY_SPACE) and mode == "over":
				if net_mode == "host":
					var ids := _duel_roster()
					_net_begin(ids)
					_net_begin.rpc(ids)
				else:
					_net_restart_request.rpc_id(1)
			elif key.keycode == KEY_F and mode == "play":
				_duel_try_fire(mouse_pos)
			elif mode == "net":
				_net_key(key.keycode)
		return
		if key.keycode == KEY_R and key.pressed:
			_start_game()
		elif key.keycode == KEY_M and key.pressed:
			muted = not muted
			if muted:
				for p in players:
					p.stop()
			_save_custom()
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
	# A crowd of drifting balls gives the title screen motion behind the text.
	for i in 70:
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
	shot_ready = true
	ready_nudge_t = 0.0
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
	boss = null
	boss_defeated = false
	boss_shots.clear()
	autoaim = false
	auto_left = 0
	shields = 0
	hurt_cd = 0.0
	cam = ball_pos
	cam_snap = true
	cam_zoom = 1.0
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
	if autoaim:
		return
	# The launch is spent until the ball hits another ball. In the duel each
	# fighter reloads on its own ball smashes, tracked on the fighter dict.
	var can_shoot := shot_ready
	if mode == "play" and net_mode != "off":
		can_shoot = bool(duel_me.get("ready", true))
		if int(duel_me.get("hp", 0)) <= 0:
			return
	if not can_shoot:
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
	if autoaim:
		charging = false
		charge_t = 0.0
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
	if net_mode != "off" and mode == "play":
		duel_me["vel"] = ball_vel
		duel_me["ready"] = false
		shot_ready = false
		if net_mode == "client":
			_duel_launch.rpc(ball_vel)
	else:
		shot_ready = false
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
	# Basics thin out while spiked balls crowd them out as the kill count climbs.
	var w_basic := 100.0 - 30.0 * d
	var w_drift := 20.0 + 30.0 * d
	var w_armor := 14.0 + 110.0 * d
	var w_chase := 10.0 + 40.0 * d
	# One star at a time, never while the autopilot is already flying.
	var w_star := 0.0
	if not autoaim:
		w_star = STAR_WEIGHT
		for tg in targets:
			if tg.kind == "star":
				w_star = 0.0
				break
	var w_shield := 0.0
	if shields < SHIELD_MAX:
		w_shield = SHIELD_WEIGHT
		for tg in targets:
			if tg.kind == "shield":
				w_shield = 0.0
				break
	var roll := randf() * (w_basic + w_drift + w_armor + w_chase + w_star + w_shield)
	if roll < w_basic:
		return "basic"
	roll -= w_basic
	if roll < w_drift:
		return "drifter"
	roll -= w_drift
	if roll < w_armor:
		return "armored"
	roll -= w_armor
	if roll < w_chase:
		return "chaser"
	roll -= w_chase
	if roll < w_star:
		return "star"
	return "shield"


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
	for i in 8:
		_spawn_target(false, _view_rect().grow(-40.0))
	guard = 0
	while targets.size() < TARGET_POP and guard < 400:
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

	var guard := 0
	while guard < 40:
		guard += 1
		# Always leave something to shoot at; otherwise refill off screen.
		if visible < MIN_VISIBLE:
			if targets.size() >= TARGET_POP:
				_remove_farthest()
			if _spawn_target(false, view.grow(-70.0)):
				visible += 1
				continue
		if targets.size() >= TARGET_POP:
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
			tg.vel = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(45.0, 105.0) * (1.0 + 0.8 * _difficulty())
		"star":
			tg.req = STAR_REQ
			tg.color = WHITE
			tg.vel = Vector2.RIGHT.rotated(randf() * TAU) * STAR_SPEED
		"shield":
			tg.req = SHIELD_REQ
			tg.color = SHIELD_BLUE
			tg.vel = Vector2.RIGHT.rotated(randf() * TAU) * SHIELD_SPEED
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
	if autoaim:
		auto_left -= 1
		_popup(tg.pos + Vector2(0.0, 34.0), "%d LEFT" % maxi(auto_left, 0), GOLD, 18)
		if auto_left <= 0:
			_end_autoaim()
	# Streaming refills the population shortly after the kill.


# ------------------------------------------------------------------ simulation
func _physics_process(delta: float) -> void:
	delta = minf(delta, 1.0 / 30.0)
	t += delta
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 40.0)
	hurt_cd = maxf(0.0, hurt_cd - delta)
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
		"custom":
			_update_title_ball(delta)
			_update_targets(delta)
			_update_particles(delta)
			_update_popups(delta)
		"net":
			_update_title_ball(delta)
			_update_targets(delta)
			_update_particles(delta)
			_update_popups(delta)
			if net_mode == "client" and net_screen == "join" and net_timeout > 0.0:
				net_timeout -= delta
				if net_timeout <= 0.0:
					if multiplayer.multiplayer_peer != null:
						multiplayer.multiplayer_peer.close()
						multiplayer.multiplayer_peer = null
					net_mode = "off"
					net_status = "CONNECTION FAILED - CHECK IP & FIREWALL"
			if net_screen == "countdown":
				var before := int(ceil(net_count))
				net_count -= delta
				if net_count <= 0.0:
					mode = "play"
					net_screen = ""
					if net_mode != "off":
						time_left = DUEL_TIME
						max_time = DUEL_TIME
						_banner("FIGHT!")
						_sfx("wave", 0.0, -6.0)
					else:
						_start_game()
				elif int(ceil(net_count)) != before:
					_banner(str(int(ceil(net_count))))
		"play":
			_update_play(delta)

	_update_ambient(delta)
	_update_post_fx(delta)
	_update_camera(delta)
	if touch_aim_id < 0 and not stick_on:
		mouse_pos = _screen_to_world(get_viewport().get_mouse_position())
	queue_redraw()


# ------------------------------------------------------------------ camera
## Returns the world-space rectangle currently visible on screen.
func _view_rect() -> Rect2:
	var size := VIEW / cam_zoom
	return Rect2(cam - size * 0.5, size)


func _screen_to_world(p: Vector2) -> Vector2:
	return (p - VIEW * 0.5) / cam_zoom + cam


func _clamp_cam(p: Vector2) -> Vector2:
	var half := _view_rect().size * 0.5
	var c := Vector2(
		clampf(p.x, WORLD.position.x + half.x, WORLD.end.x - half.x),
		clampf(p.y, WORLD.position.y + half.y, WORLD.end.y - half.y))
	if WORLD.size.x < half.x * 2.0:
		c.x = WORLD.get_center().x
	if WORLD.size.y < half.y * 2.0:
		c.y = WORLD.get_center().y
	return c


func _update_camera(dt: float) -> void:
	# While the boss is up the camera frames both fighters, pulling back just
	# far enough to keep them on screen together.
	var target := ball_pos + ball_vel * CAM_LOOKAHEAD
	var want_zoom := 1.0
	if boss != null:
		target = (ball_pos + boss.pos) * 0.5
		var need := (ball_pos.distance_to(boss.pos) + 2.0 * BOSS_R + 160.0) / VIEW.y
		want_zoom = clampf(1.0 / maxf(need, 1.0), CAM_MIN_ZOOM, 1.0)
	target = _clamp_cam(target)
	if cam_snap:
		cam = target
		cam_zoom = want_zoom
		cam_snap = false
	else:
		cam = _clamp_cam(cam.lerp(target, 1.0 - exp(-CAM_LERP * dt)))
		cam_zoom = lerpf(cam_zoom, want_zoom, 1.0 - exp(-3.0 * dt))


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
	if net_mode != "off":
		_update_duel(delta)
		return
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

	if autoaim:
		_update_autoaim(wdt)

	_step_ball(wdt)
	if mode != "play":
		return
	_update_targets(wdt)
	_update_streaming(delta)
	if score >= BOSS_SCORE and boss == null and not boss_defeated:
		_spawn_boss()
	if boss != null:
		_update_boss(wdt)
		_update_boss_shots(wdt)
	if net_mode != "off":
		net_send_t -= delta
		if net_send_t <= 0.0:
			net_send_t = 0.5
			_net_score.rpc(score, kills)
	_update_bumpers(delta)
	_update_particles(wdt)
	_update_popups(delta)


# ------------------------------------------------------------------ duel
## Shared-arena versus shooter: both fighters in one world, host simulates,
## client commands launches/shots and predicts its own fighter. 100 HP each,
## breaking a chest instantly equips PISTOL then SPREAD; KO (or more HP at 0s) wins.
func _update_duel(delta: float) -> void:
	ball_pos = duel_me["pos"]
	ball_vel = duel_me["vel"]
	if charging:
		charge_t = minf(charge_t + CHARGE_TIME, CHARGE_TIME)
		_update_charge_motes(delta)
	var wdt := delta * (SLOWMO if charging else 1.0)
	ball_flash = maxf(0.0, ball_flash - wdt * 4.0)
	var allf := _duel_all()
	for f in allf:
		var ff: Dictionary = f
		ff["cd"] = maxf(0.0, float(ff["cd"]) - delta)
		ff["slam"] = maxf(0.0, float(ff["slam"]) - delta)
		ff["spike"] = maxf(0.0, float(ff["spike"]) - delta)
		ff["lava"] = maxf(0.0, float(ff["lava"]) - delta)
	# Held gun stick keeps firing toward its deflection; the gun cooldown
	# inside _duel_try_fire sets the rate on both host and client.
	if stick_on and int(duel_me.get("hp", 0)) > 0:
		var sdir := _stick_dir()
		if sdir.length() > 0.3:
			_duel_try_fire((duel_me["pos"] as Vector2) + sdir * 200.0)
	if net_mode == "host":
		for f in allf:
			var ff2: Dictionary = f
			if int(ff2.get("hp", 0)) > 0 and not bool(ff2.get("gone", false)):
				_duel_step(ff2, wdt, true)
		_duel_fighter_clash()
		_update_targets(wdt)
		duel_refill_t -= delta
		if duel_refill_t <= 0.0:
			duel_refill_t = 0.7
			if targets.size() < DUEL_BALLS:
				_duel_spawn_one()
		_duel_smash_check()
		_duel_update_bullets(wdt, true)
		_duel_update_pickups(true)
		duel_chest_t -= delta
		if duel_chest_t <= 0.0:
			duel_chest_t = DUEL_CHEST_RESPAWN_T
			if duel_chests.size() < duel_chest_max:
				var cp := _duel_chest_spot()
				if cp != Vector2.INF:
					duel_chests.append({"pos": cp, "hp": DUEL_CHEST_HP})
					_ring(cp, GOLD, 10, 200.0)
		if duel_was_alive and int(duel_me.get("hp", 0)) <= 0:
			duel_was_alive = false
			charging = false
			charge_t = 0.0
			stick_on = false
			_banner("ELIMINATED")
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			_duel_finish(_duel_time_winner())
			return
		var alive: Array = []
		for i in allf.size():
			if int((allf[i] as Dictionary).get("hp", 0)) > 0:
				alive.append(i)
		if alive.size() <= 1:
			_duel_finish(alive[0] if alive.size() == 1 else -1)
			return
		duel_snap_t -= delta
		if duel_snap_t <= 0.0:
			duel_snap_t = DUEL_SNAP_T
			var fighters: Array = []
			for f in allf:
				var ff3: Dictionary = f
				fighters.append([ff3["pos"], ff3["vel"], ff3["hp"], ff3["gun"], ff3["ready"]])
			var tg_flat: Array = []
			for tg in targets:
				tg_flat.append(tg.pos.x)
				tg_flat.append(tg.pos.y)
				tg_flat.append(tg.radius)
				tg_flat.append(2 if tg.kind == "armored" else (1 if tg.kind == "drifter" else 0))
			_net_duel.rpc([fighters, duel_bullets, duel_chests, duel_pickups, time_left, tg_flat])
	else:
		if int(duel_me.get("hp", 0)) > 0:
			_duel_step(duel_me, wdt, false)
		# Predict each rival with its last known velocity, then ease toward
		# the newest sample. Kills the stop-and-jump of pure snapshot lerping.
		for o in duel_foes.size():
			var rf: Dictionary = duel_foes[o]
			if int(rf.get("hp", 0)) <= 0:
				continue
			var fpos: Vector2 = rf["pos"]
			fpos += (rf["vel"] as Vector2) * delta
			fpos = fpos.lerp(duel_foe_goals[o] as Vector2, minf(1.0, delta * 8.0))
			rf["pos"] = fpos
		_duel_update_bullets(wdt, false)
		time_left = maxf(0.0, time_left - delta)
	ball_pos = duel_me["pos"]
	ball_vel = duel_me["vel"]
	# No live fighter of my own: ride along with the action instead. The
	# camera, minimap and radar all follow ball_pos, so this alone moves them.
	if _duel_watching():
		var w := _duel_watch_target()
		if not w.is_empty():
			ball_pos = w["pos"]
			ball_vel = w["vel"]
	trail.append(ball_pos)
	if trail.size() > 26:
		trail.pop_front()
	_update_ball_motes(wdt)
	_update_particles(wdt)
	_update_popups(delta)


## Gravity + walls + chest bounce for one fighter. Host also damages chests.
func _duel_step(f: Dictionary, dt: float, authoritative: bool) -> void:
	var v: Vector2 = f["vel"]
	v.y += GRAVITY * dt
	if v.length() > MAX_SPEED:
		v = v.normalized() * MAX_SPEED
	var p: Vector2 = f["pos"] + v * dt
	var min_x := WORLD.position.x + BALL_R
	var max_x := WORLD.end.x - BALL_R
	var min_y := WORLD.position.y + BALL_R
	if p.x < min_x:
		p.x = min_x
		if v.x < 0.0:
			v.x = -v.x * WALL_REST
	elif p.x > max_x:
		p.x = max_x
		if v.x > 0.0:
			v.x = -v.x * WALL_REST
	if p.y < min_y:
		p.y = min_y
		if v.y < 0.0:
			v.y = -v.y * WALL_REST
	# Molten floor: resting on it burns instead of killing outright. The
	# fighter floats on the surface and takes a damage tick per grace
	# window; host owns the hp call and snapshots deliver it.
	var surface := _lava_top() - BALL_R
	if p.y > surface and int(f.get("hp", 0)) > 0:
		p.x = clampf(p.x, min_x, max_x)
		p.y = surface
		if v.y > 0.0:
			v.y = -v.y * WALL_REST
		if float(f.get("lava", 0.0)) <= 0.0:
			f["lava"] = DUEL_LAVA_GRACE
			if authoritative:
				_duel_hurt(f, DUEL_LAVA_DMG)
				_popup(p + Vector2(0.0, -30.0), "-%d LAVA" % DUEL_LAVA_DMG, RED, 20)
			_burst(p, RED, 10, 300.0)
			_burst(p, GOLD, 8, 240.0)
			_sfx("armor", 0.0, -8.0)
	# Chest bounce (host also chips the chest on hard hits).
	for i in duel_chests.size():
		var ch: Dictionary = duel_chests[i]
		var d: Vector2 = p - ch["pos"]
		var rr := 34.0 + BALL_R
		if d.length_squared() < rr * rr:
			var n := d.normalized() if d.length_squared() > 0.0001 else Vector2.RIGHT
			p = ch["pos"] + n * rr
			var vn := v.dot(n)
			if vn < 0.0:
				v -= 1.9 * vn * n
				if authoritative and -vn > 380.0:
					_duel_damage_chest(i, 25, f)
					_sfx("bump", 0.10, -14.0)
					break
	f["pos"] = p
	f["vel"] = v


## Body-slam: hard fighter contact hurts the slower one (host only).
func _duel_fighter_clash() -> void:
	var allf := _duel_all()
	for a in allf.size():
		for b in range(a + 1, allf.size()):
			_duel_clash_pair(allf[a], allf[b])


func _duel_clash_pair(fa: Dictionary, fb: Dictionary) -> void:
	if int(fa.get("hp", 0)) <= 0 or int(fb.get("hp", 0)) <= 0:
		return
	if bool(fa.get("gone", false)) or bool(fb.get("gone", false)):
		return
	var d: Vector2 = (fb["pos"] as Vector2) - (fa["pos"] as Vector2)
	var rr := BALL_R * 2.0 + 4.0
	if d.length_squared() >= rr * rr:
		return
	var n := d.normalized() if d.length_squared() > 0.0001 else Vector2.RIGHT
	fa["pos"] = (fa["pos"] as Vector2) - n * (rr / 2.0)
	fb["pos"] = (fb["pos"] as Vector2) + n * (rr / 2.0)
	var rel: Vector2 = (fa["vel"] as Vector2) - (fb["vel"] as Vector2)
	var closing := -rel.dot(n)
	if closing > 0.0:
		var m: Vector2 = fa["vel"]
		var o: Vector2 = fb["vel"]
		var m_n := m.dot(n)
		var o_n := o.dot(n)
		fa["vel"] = m + (o_n - m_n) * 0.9 * n
		fb["vel"] = o + (m_n - o_n) * 0.9 * n
	if closing > 500.0 and float(fa["slam"]) <= 0.0 and float(fb["slam"]) <= 0.0:
		fa["slam"] = 1.0
		fb["slam"] = 1.0
		var a_slow := (fa["vel"] as Vector2).length() < (fb["vel"] as Vector2).length()
		if a_slow:
			_duel_hurt(fa, 8)
		else:
			_duel_hurt(fb, 8)
		_ring(((fa["pos"] as Vector2) + (fb["pos"] as Vector2)) * 0.5, GOLD, 12, 200.0)
		_sfx("bump", 0.0, -8.0)


## Bullets fly straight, die on walls/expiry, and hit chests + any rival.
func _duel_update_bullets(dt: float, authoritative: bool) -> void:
	var keep: Array = []
	var allf := _duel_all()
	for b in duel_bullets:
		var bp: Vector2 = b["pos"] + (b["vel"] as Vector2) * dt
		var life: float = float(b["life"]) - dt
		var dead := life <= 0.0 or bp.x < WORLD.position.x or bp.x > WORLD.end.x or bp.y < WORLD.position.y or bp.y > _lava_top()
		if not dead and authoritative:
			for i in duel_chests.size():
				var ch: Dictionary = duel_chests[i]
				if bp.distance_to(ch["pos"]) < 34.0:
					var oi := int(b["owner"])
					var bf: Dictionary = allf[oi] if oi >= 0 and oi < allf.size() else {}
					_duel_damage_chest(i, int(b["dmg"]), bf)
					dead = true
					break
		if not dead and authoritative:
			for i in allf.size():
				if i == int(b["owner"]):
					continue
				var foe: Dictionary = allf[i]
				if int(foe.get("hp", 0)) <= 0:
					continue
				if bp.distance_to(foe["pos"]) < BALL_R + DUEL_BULLET_R:
					_duel_hurt(foe, int(b["dmg"]))
					_burst(bp, PINK, 8, 200.0)
					dead = true
					break
		if not dead:
			b["pos"] = bp
			b["life"] = life
			keep.append(b)
	duel_bullets = keep


## Walking over a pickup equips it (host grants, snapshot delivers).
func _duel_update_pickups(authoritative: bool) -> void:
	if not authoritative:
		return
	var keep: Array = []
	for pk in duel_pickups:
		var taken := false
		for f in _duel_all():
			var ff: Dictionary = f
			if int(ff.get("hp", 0)) <= 0:
				continue
			if (ff["pos"] as Vector2).distance_to(pk["pos"]) < 46.0:
				ff["gun"] = maxi(int(ff["gun"]), int(pk["kind"]))
				ff["cd"] = 0.0
				_popup((ff["pos"] as Vector2) + Vector2(0.0, -34.0), DUEL_GUN_NAMES[clampi(int(ff["gun"]), 0, 2)], CYAN, 16)
				_sfx("wave", 0.0, -10.0)
				taken = true
				break
		if not taken:
			keep.append(pk)
	duel_pickups = keep


## Breaking a chest equips its gun on the spot: PISTOL first, then SPREAD
## once armed. No walk-over needed; a pickup only drops when the breaker is
## already out (a stray bullet finishing the job after they died).
func _duel_damage_chest(i: int, dmg: int, breaker: Dictionary) -> void:
	if i < 0 or i >= duel_chests.size():
		return
	var ch: Dictionary = duel_chests[i]
	ch["hp"] = int(ch["hp"]) - dmg
	if int(ch["hp"]) > 0:
		return
	duel_chests.remove_at(i)
	if not breaker.is_empty() and int(breaker.get("hp", 0)) > 0:
		var kind := 2 if int(breaker.get("gun", 0)) > 0 else 1
		breaker["gun"] = kind
		breaker["cd"] = 0.0
		_popup((breaker["pos"] as Vector2) + Vector2(0.0, -34.0), DUEL_GUN_NAMES[clampi(kind, 0, 2)], CYAN, 16)
		_sfx("wave", 0.0, -10.0)
	else:
		duel_pickups.append({"pos": ch["pos"], "kind": 1})
	_burst(ch["pos"], GOLD, 14, 260.0)
	_ring(ch["pos"], GOLD, 12, 240.0)
	_sfx("bump", 0.0, -6.0)


func _duel_hurt(f: Dictionary, dmg: int) -> void:
	f["hp"] = maxi(0, int(f["hp"]) - dmg)


## Duel balls: pink basics, green drifters and gold spikies (no pickups).
## Spikies need a fast hit to smash; slow touches burn. Tame: never homing.
## Both sides scatter some instantly; the host truth wins via snapshots.
func _duel_populate() -> void:
	targets.clear()
	duel_refill_t = 0.0
	for i in DUEL_BALLS:
		_duel_spawn_one()


func _duel_spawn_one() -> void:
	var roll := randf()
	var kind := "armored" if roll < 0.20 else ("drifter" if roll < 0.45 else "basic")
	var r := _radius_for(kind)
	var pos := _duel_free_spot(r)
	if pos == Vector2.INF:
		return
	var tg := Target.new()
	tg.kind = kind
	tg.radius = r
	tg.pos = pos
	tg.tame = true
	tg.phase = randf() * TAU
	tg.spin = randf() * TAU
	if kind == "drifter":
		tg.req = KILL_SPEED * 1.15
		tg.color = GREEN
		tg.vel = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(45.0, 105.0)
	elif kind == "armored":
		tg.req = DUEL_SPIKE_REQ
		tg.color = GOLD
	else:
		tg.req = KILL_SPEED
		tg.color = PINK
	targets.append(tg)


func _duel_free_spot(r: float) -> Vector2:
	var pad := 120.0 + r
	for i in 60:
		var pt := Vector2(
			randf_range(WORLD.position.x + pad, WORLD.end.x - pad),
			randf_range(WORLD.position.y + pad, WORLD.end.y - pad))
		if pt.y > _lava_top() - r:
			continue
		var crowded := false
		for f in _duel_all():
			if pt.distance_to((f as Dictionary).get("pos", WORLD.get_center())) < 220.0 + r:
				crowded = true
				break
		if crowded:
			continue
		var free := true
		for ch in duel_chests:
			if pt.distance_to(ch["pos"]) < 120.0 + r:
				free = false
				break
		if free:
			for o in targets:
				if pt.distance_to(o.pos) < 110.0 + r:
					free = false
					break
		if free:
			return pt
	return Vector2.INF


## Random free arena point for a respawned crate, clear of fighters,
## crates and the world edge so it never drops onto someone's head.
func _duel_chest_spot() -> Vector2:
	var pad := 160.0
	for i in 40:
		var pt := Vector2(
			randf_range(WORLD.position.x + pad, WORLD.end.x - pad),
			randf_range(WORLD.position.y + pad, WORLD.end.y - pad))
		if pt.y > _lava_top() - 60.0:
			continue
		var ok := true
		for f in _duel_all():
			if pt.distance_to((f as Dictionary).get("pos", WORLD.get_center())) < 300.0:
				ok = false
				break
		if ok:
			for ch in duel_chests:
				if pt.distance_to(ch["pos"]) < 220.0:
					ok = false
					break
		if ok:
			return pt
	return Vector2.INF


## Host only: any living fighter touching a ball smashes it, reloading launch.
## Spiky gold balls need a fast hit; a slow touch burns for DUEL_SPIKE_DMG
## with a second of grace so resting contact can't melt a fighter.
func _duel_smash_check() -> void:
	for f in _duel_all():
		if int((f as Dictionary).get("hp", 0)) <= 0 or bool((f as Dictionary).get("gone", false)):
			continue
		var fp: Vector2 = (f as Dictionary)["pos"]
		for i in range(targets.size() - 1, -1, -1):
			var tg = targets[i]
			var rr: float = tg.radius + BALL_R
			var d: Vector2 = fp - tg.pos
			if d.length_squared() >= rr * rr:
				continue
			var n := d.normalized() if d.length_squared() > 0.0001 else Vector2.RIGHT
			f["pos"] = tg.pos + n * rr
			var v: Vector2 = f["vel"]
			var spd := v.length()
			var vn := v.dot(n)
			if vn < 0.0:
				v -= 1.8 * vn * n
			v.y = minf(v.y - RICOCHET_LIFT, -RICOCHET_LIFT * 0.5)
			if v.length() > MAX_SPEED:
				v = v.normalized() * MAX_SPEED
			f["vel"] = v
			if tg.kind == "armored" and spd < float(tg.req):
				if float(f.get("spike", 0.0)) <= 0.0:
					f["spike"] = 1.0
					_duel_hurt(f, DUEL_SPIKE_DMG)
					_popup(tg.pos + Vector2(0.0, -30.0), "-%d SPIKES" % DUEL_SPIKE_DMG, RED, 20)
					_shards(tg.pos, v, RED, 8, 470.0, 0.5)
					_sfx("armor", 0.0, -8.0)
				fp = f["pos"]
				continue
			targets.remove_at(i)
			f["ready"] = true
			_popup(tg.pos + Vector2(0.0, -30.0), "SMASH", GREEN, 20)
			_shards(tg.pos, v, tg.color, 8, 470.0, 0.5)
			_sfx("wave", 0.0, -8.0)
			fp = f["pos"]
	shot_ready = bool(duel_me.get("ready", true))


## Timeout verdict: highest HP takes it; ties share the draw (-1).
func _duel_time_winner() -> int:
	var best_i := -1
	var best_hp := -1
	var tied := false
	var allf := _duel_all()
	for i in mini(duel_ids.size(), allf.size()):
		var h := int((allf[i] as Dictionary).get("hp", 0))
		if h > best_hp:
			best_hp = h
			best_i = i
			tied = false
		elif h == best_hp:
			tied = true
	return -1 if tied else best_i


## Reliable round end, called on host only, then broadcast.
func _duel_finish(winner: int) -> void:
	if duel_over:
		return
	duel_over = true
	duel_winner = winner
	mode = "over"
	charging = false
	charge_t = 0.0
	bloom_level = maxf(bloom_level, 1.4)
	_ring(ball_pos, PINK, 18, 320.0)
	shake = maxf(shake, 14.0)
	_sfx("over", 0.0, -4.0)
	_duel_end.rpc(winner)


## Pistol and 3-pellet spread. Host spawns; no gun = hint only.
func _duel_spawn_shots(f: Dictionary, target: Vector2, owner: int = -1) -> void:
	var gun := int(f["gun"])
	if gun <= 0 or float(f["cd"]) > 0.0 or duel_over:
		return
	if int(f.get("hp", 0)) <= 0:
		return
	if owner < 0:
		owner = _duel_all().find(f)
	var base: Vector2 = target - (f["pos"] as Vector2)
	if base.length_squared() < 1.0:
		base = Vector2.RIGHT
	base = base.normalized()
	if gun == 1:
		f["cd"] = 0.35
		duel_bullets.append({"pos": f["pos"] + base * (BALL_R + 8.0), "vel": base * 1900.0, "owner": owner, "life": 1.6, "dmg": 12})
	else:
		f["cd"] = 0.6
		for a in [-0.14, 0.0, 0.14]:
			duel_bullets.append({"pos": f["pos"] + base * (BALL_R + 8.0), "vel": base.rotated(a) * 1700.0, "owner": owner, "life": 1.6, "dmg": 7})
	_sfx("shoot_low", 0.0, -8.0)


## Gun-stick deflection in screen space, dead-zoned and clamped to unit.
func _stick_dir() -> Vector2:
	if not stick_on:
		return Vector2.ZERO
	var d := (stick_knob - stick_base) / STICK_R
	if d.length() < 0.25:
		return Vector2.ZERO
	return d.limit_length(1.0)


## Local trigger: muzzle flash + host spawn or client command.
func _duel_try_fire(target: Vector2) -> void:
	if duel_over or mode != "play" or net_mode == "off":
		return
	if int(duel_me["gun"]) <= 0:
		if float(duel_me["cd"]) <= 0.0:
			duel_me["cd"] = 0.5
			_popup((duel_me["pos"] as Vector2) + Vector2(0.0, -34.0), "NEED A GUN - BREAK CHESTS", RED, 14)
		return
	if float(duel_me["cd"]) > 0.0:
		return
	_burst((duel_me["pos"] as Vector2) + (target - (duel_me["pos"] as Vector2)).normalized() * (BALL_R + 8.0), GOLD, 6, 160.0)
	if int(duel_me.get("hp", 0)) <= 0 or bool(duel_me.get("gone", false)):
		return
	if net_mode == "host":
		_duel_spawn_shots(duel_me, target, duel_my_id)
	else:
		_duel_me_predict_shot(target)
		_duel_fire.rpc(target)


## Client prediction: pay the cooldown now so holding fire feels right.
func _duel_me_predict_shot(target: Vector2) -> void:
	var gun := int(duel_me["gun"])
	if gun == 1:
		duel_me["cd"] = 0.35
	elif gun == 2:
		duel_me["cd"] = 0.6


func _update_targets(dt: float) -> void:
	var chase_speed := 110.0 + minf(kills * 2.8, 175.0)
	for tg in targets:
		tg.phase += dt * 2.0
		tg.spin += dt * (2.4 if tg.kind == "chaser" else 1.1)
		tg.age += dt
		tg.flash = maxf(0.0, tg.flash - dt * 5.0)
		tg.slow_cd = maxf(0.0, tg.slow_cd - dt)

		if (tg.kind == "chaser" or tg.kind == "armored") and not tg.tame:
			# Spiked balls lumber after the ball as well, heavier than chasers.
			var follow: float = chase_speed * (0.60 if tg.kind == "armored" else 1.0)
			var dir: Vector2 = ball_pos - tg.pos
			if dir.length_squared() > 1.0:
				tg.pos += dir.normalized() * follow * dt
		elif tg.kind == "drifter" or tg.kind == "star" or tg.kind == "shield":
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


# ------------------------------------------------------------------ boss
## Wakes once the score crosses BOSS_SCORE. One boss per run.
func _spawn_boss() -> void:
	var b := Boss.new()
	b.hp = BOSS_HP
	b.max_hp = BOSS_HP
	b.radius = BOSS_R
	b.pos = Vector2(ball_pos.x, maxf(ball_pos.y - 420.0, WORLD.position.y + BOSS_R + 30.0))
	b.fire_t = 2.2
	boss = b
	_banner("BOSS INCOMING")
	shake = maxf(shake, 8.0)
	_ring(boss.pos, RED, 24, 420.0)
	_sfx("wave", 0.0, -4.0)


## Lumbers toward the ball and spits plasma on a timer that quickens as it dies.
func _update_boss(dt: float) -> void:
	if boss == null or mode != "play":
		return
	boss.phase += dt
	boss.flash = maxf(0.0, boss.flash - dt * 4.0)
	boss.mercy_t = maxf(0.0, boss.mercy_t - dt)
	var dir: Vector2 = ball_pos - boss.pos
	var dist := dir.length()
	if boss.mercy_t <= 0.0 and dist > 1.0:
		# Rubber-banded: slow up close, quicker across the map, so the camera
		# can almost always keep both fighters framed. Backs off right after
		# taking a hit so the bounce-back always clears it. The step is
		# clamped so the boss can never land exactly on the ball.
		var spd: float = minf(BOSS_SPEED + dist * 0.12, 260.0)
		boss.pos += dir / dist * minf(spd * dt, dist)
	boss.pos.x = clampf(boss.pos.x, WORLD.position.x + boss.radius, WORLD.end.x - boss.radius)
	boss.pos.y = clampf(boss.pos.y, WORLD.position.y + boss.radius, _lava_top() - boss.radius)
	var contact: float = boss.radius + BALL_R + BOSS_SPIKE_LEN + 1.0
	var gap: Vector2 = ball_pos - boss.pos
	var gap2 := gap.length_squared()
	if boss.mercy_t > 0.0 and gap2 < contact * contact:
		# Shove the ball (never the boss) out to clean contact while hits are
		# forgiven, so the fighters can't interpenetrate or degenerate the
		# hit direction to zero.
		var n2 := gap.normalized() if gap2 > 0.0001 else Vector2.RIGHT
		ball_pos = boss.pos + n2 * contact
	boss.fire_t -= dt
	if boss.fire_t <= 0.0:
		_boss_volley()
		var wrath := 1.0 - float(boss.hp) / float(boss.max_hp)
		boss.fire_t = lerpf(BOSS_FIRE_T, BOSS_FIRE_T * 0.55, wrath)


func _boss_volley() -> void:
	if boss_shots.size() >= BOSS_MAX_SHOTS:
		return
	var dir: Vector2 = ball_pos - boss.pos
	if dir.length_squared() < 1.0:
		dir = Vector2.DOWN
	dir = dir.normalized()
	# Below half health the volley fans out into three bolts.
	var angles := [0.0]
	if boss.hp * 2 <= boss.max_hp:
		angles = [-0.22, 0.0, 0.22]
	for a in angles:
		var s := BossShot.new()
		s.pos = boss.pos + dir * (boss.radius + 6.0)
		s.vel = dir.rotated(float(a)) * BOSS_SHOT_SPEED
		s.life = BOSS_SHOT_LIFE
		boss_shots.append(s)
	_sfx("shoot_low", 0.0, -8.0)


func _update_boss_shots(dt: float) -> void:
	for i in range(boss_shots.size() - 1, -1, -1):
		var s = boss_shots[i]
		s.life -= dt
		s.pos += s.vel * dt
		var dead: bool = s.life <= 0.0
		dead = dead or s.pos.x < WORLD.position.x or s.pos.x > WORLD.end.x
		dead = dead or s.pos.y < WORLD.position.y or s.pos.y > _lava_top()
		if not dead:
			var d: Vector2 = ball_pos - s.pos
			var rr: float = BOSS_SHOT_R + BALL_R
			if d.length_squared() < rr * rr:
				_spike_death()
				return
		if dead:
			boss_shots.remove_at(i)


## The boss is one more spiked ball, only huge and with hit points: fast hits
## wound it and bounce you off, slow touches kill like any other spikes.
func _collide_boss() -> void:
	if mode != "play" or boss == null:
		return
	# A wounding blow knocks you clear; grace covers the bounce-back so the
	# upward kick can't steer you back inside at killing speed.
	if boss.mercy_t > 0.0:
		return
	var speed := ball_vel.length()
	var d: Vector2 = ball_pos - boss.pos
	var rr: float = boss.radius + BALL_R + BOSS_SPIKE_LEN
	var dist2 := d.length_squared()
	if dist2 >= rr * rr:
		return
	var n := d.normalized() if dist2 > 0.0001 else Vector2.RIGHT
	if speed >= BOSS_REQ:
		shot_ready = true
		ball_pos = boss.pos + n * rr
		var vn_hit := ball_vel.dot(n)
		if vn_hit < 0.0:
			ball_vel -= 1.8 * vn_hit * n
		ball_vel.y = minf(ball_vel.y - RICOCHET_LIFT, -RICOCHET_LIFT * 0.5)
		_clamp_speed()
		_hurt_boss(speed)
		if boss != null:
			boss.pos -= n * 24.0
		return
	_spike_death()


func _hurt_boss(speed: float) -> void:
	boss.hp -= 1
	boss.flash = 1.0
	boss.mercy_t = 0.6
	shot_ready = true
	score += BOSS_HIT_SCORE
	_popup(boss.pos + Vector2(0.0, -boss.radius - 16.0), "HIT %d/%d" % [boss.max_hp - boss.hp, boss.max_hp], GOLD, 20)
	_shards(boss.pos, ball_vel, RED, 10, 480.0, 0.5)
	_burst(boss.pos, WHITE, 8, 240.0)
	shake = maxf(shake, 7.0)
	hitstop = 0.045
	_sfx("kill", 0.08, -6.0)
	if boss.hp <= 0:
		_boss_defeated()


func _boss_defeated() -> void:
	var at: Vector2 = boss.pos
	boss = null
	boss_defeated = true
	boss_shots.clear()
	score += BOSS_KILL_SCORE
	time_left = minf(time_left + 4.0, TIME_CAP)
	_popup(at, "+%d BOSS DOWN" % BOSS_KILL_SCORE, GOLD, 30)
	_banner("BOSS DOWN")
	_burst(at, RED, 40, 520.0)
	_burst(at, GOLD, 26, 380.0)
	_burst(at, WHITE, 16, 260.0)
	_ring(at, GOLD, 24, 460.0)
	_ring(at, RED, 18, 340.0)
	shake = maxf(shake, 14.0)
	hitstop = 0.12
	bloom_level = minf(bloom_level + 0.6, 1.8)
	_sfx("kill", 0.1, -2.0)


## Star pickup: any touch collects it and hands the ball to the autopilot.
func _collect_star(idx: int) -> void:
	var tg = targets[idx]
	var at: Vector2 = tg.pos
	targets.remove_at(idx)
	shot_ready = true
	autoaim = true
	auto_left = AUTO_KILLS
	_banner("AUTOAIM!")
	_popup(at, "AUTOAIM x%d" % AUTO_KILLS, GOLD, 26)
	_burst(at, WHITE, 18, 300.0)
	_burst(at, GOLD, 10, 220.0)
	_ring(at, WHITE, 14, 300.0)
	shake = maxf(shake, 6.0)
	charging = false
	charge_t = 0.0
	time_left = minf(time_left + TIME_PER_KILL, TIME_CAP)
	_sfx("kill", 0.08, -6.0)


## Shield pickup: any touch banks one, up to SHIELD_MAX.
func _collect_shield(idx: int) -> void:
	var tg = targets[idx]
	var at: Vector2 = tg.pos
	targets.remove_at(idx)
	shot_ready = true
	if shields >= SHIELD_MAX:
		score += 100
		_popup(at, "+100 MAX", SHIELD_BLUE, 20)
	else:
		shields += 1
		_popup(at, "+SHIELD", SHIELD_BLUE, 22)
	_burst(at, SHIELD_BLUE, 14, 260.0)
	_burst(at, WHITE, 8, 200.0)
	_ring(at, SHIELD_BLUE, 10, 260.0)
	_sfx("armor", 0.0, -8.0)


## Autopilot: home the ball at the nearest ball at smashing speed.
func _update_autoaim(dt: float) -> void:
	if targets.is_empty():
		return
	var best: Target = null
	var best_d := INF
	for tg in targets:
		var d: float = tg.pos.distance_squared_to(ball_pos)
		if d < best_d:
			best_d = d
			best = tg
	if best != null and best_d > 1.0:
		ball_vel = (best.pos - ball_pos).normalized() * AUTO_SPEED


func _end_autoaim() -> void:
	autoaim = false
	auto_left = 0
	shot_ready = true
	_banner("YOUR MOVE")
	_popup(ball_pos + Vector2(0.0, -30.0), "CONTROL BACK", CYAN, 22)
	_ring(ball_pos, CYAN, 12, 280.0)
	_sfx("wave", 0.0, -8.0)


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
		if tg.kind == "star":
			_collect_star(i)
			return
		if tg.kind == "shield":
			_collect_shield(i)
			return
		if tg.kind == "armored" and speed < tg.req:
			# Spikes still demand speed: too slow and they kill.
			ball_pos = tg.pos + n * rr
			_spike_death()
			return
		# Anything else shatters on contact now, fast or slow.
		shot_ready = true
		# Shattering a ball ricochets you off its surface instead of passing
		# through, so a shot keeps chaining around the arena.
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


## The ball touched the molten floor — sizzle out and end the run.
## Grace never protects from lava: only a stacked shield tanks one hit.
func _lava_death() -> void:
	if _try_shield():
		return
	died_in_lava = true
	ball_vel = Vector2.ZERO
	_burst(ball_pos, GOLD, 30, 470.0)
	_burst(ball_pos, Color(1.0, 0.55, 0.15), 22, 360.0)
	_burst(ball_pos, RED, 16, 280.0)
	_sfx("kill", 0.14, -4.0)
	_game_over()


## Ran into a spiked ball without the speed to shatter it.
func _spike_death() -> void:
	if hurt_cd > 0.0:
		return
	if _try_shield():
		return
	died_on_spikes = true
	ball_vel = Vector2.ZERO
	_burst(ball_pos, RED, 28, 430.0)
	_burst(ball_pos, PINK, 14, 310.0)
	_burst(ball_pos, WHITE, 8, 220.0)
	_sfx("kill", 0.10, -4.0)
	_game_over()


## Shield tank: eats one stacked shield instead of dying, pops the ball clear
## and grants brief grace. Returns true when a shield was spent.
func _try_shield() -> bool:
	if shields <= 0:
		return false
	shields -= 1
	hurt_cd = 1.5
	ball_pos.y = minf(ball_pos.y, _lava_top() - BALL_R - 20.0)
	ball_vel = Vector2(ball_vel.x * 0.3, -1000.0)
	ball_flash = 1.0
	_popup(ball_pos + Vector2(0.0, -30.0), "SHIELD!", SHIELD_BLUE, 22)
	_burst(ball_pos, WHITE, 12, 260.0)
	_burst(ball_pos, SHIELD_BLUE, 10, 200.0)
	_ring(ball_pos, SHIELD_BLUE, 12, 300.0)
	shake = maxf(shake, 5.0)
	_sfx("armor", 0.0, -8.0)
	return true


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
	if particles.size() > 700:
		particles = particles.slice(particles.size() - 700)


func _update_particles(dt: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p = particles[i]
		p.vel.y += p.gy * dt
		p.pos += p.vel * dt
		p.vel *= pow(p.drag, dt)
		p.life -= dt
		if p.life <= 0.0:
			particles.remove_at(i)


## Fine sparks streaming off a fast-moving ball.
func _update_ball_motes(dt: float) -> void:
	mote_t -= dt
	if mote_t > 0.0:
		return
	mote_t = 0.026
	var bc := _ball_col()
	var spd := ball_vel.length()
	if spd < 420.0:
		return
	_emit(ball_pos + Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0)),
		-ball_vel * 0.12 + Vector2(randf_range(-26.0, 26.0), randf_range(-26.0, 26.0)),
		Color(bc.r, bc.g, bc.b, 0.70), randf_range(1.2, 2.4), randf_range(0.16, 0.30), 0.05)
	_cap_particles()


## Grains of light pulled into the ball while a shot charges.
func _update_charge_motes(dt: float) -> void:
	charge_mote_t -= dt
	if charge_mote_t > 0.0:
		return
	charge_mote_t = 0.05
	var a := randf() * TAU
	var from := ball_pos + Vector2(cos(a), sin(a)) * randf_range(46.0, 76.0)
	var bc := _ball_col()
	_emit(from, (ball_pos - from) * 1.7, Color(bc.r, bc.g, bc.b, 0.85),
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
	if shake_opt and shake > 0.4:
		off = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	# Everything below is drawn in world space; the camera slides it around.
	var z := Vector2(cam_zoom, cam_zoom)
	draw_set_transform(-cam * cam_zoom + VIEW * 0.5 + off, 0.0, z)

	_draw_world_floor()
	_draw_grid()
	_draw_arena()
	_draw_lava()
	_draw_bumpers()
	_draw_targets()
	if boss != null:
		_draw_boss()
		_draw_boss_shots()
	if charging and mode == "play":
		_draw_aim()
	_draw_particles()
	_draw_ball()
	if net_mode != "off" and (mode == "play" or (mode == "over" and duel_over)):
		_draw_duel_world()
	_draw_popups()
	_draw_reticle()

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_vignette()
	if mode == "play" or mode == "over":
		_draw_hud()
		if mode == "play":
			_draw_minimap()
			if net_mode != "off" and not duel_over:
				_draw_duel_arrows()
				_draw_stick()
			if boss != null:
				_draw_boss_bar()
	if mode == "title":
		_draw_title()
	elif mode == "over":
		_draw_game_over()
	elif mode == "custom":
		_draw_custom()
	elif mode == "net":
		_draw_net()


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


func _hex_points(c: Vector2, r: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 6:
		var a := rot + k * TAU / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


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
		if tg.kind == "star":
			# Collectible star: white core, gold halo, spinning sparkle.
			var tw := 0.75 + 0.25 * sin(t * 5.0 + tg.phase)
			draw_circle(tg.pos, r + 10.0, Color(1.0, 0.85, 0.40, 0.10 * tw * fade))
			draw_circle(tg.pos, r * tw, Color(0.25, 0.22, 0.18, 0.98 * fade))
			draw_circle(tg.pos, r * 0.62 * tw, Color(1.0, 0.95, 0.80, 0.95 * fade))
			for k in 5:
				var sa: float = tg.spin + k * TAU / 5.0
				var tip: Vector2 = tg.pos + Vector2(cos(sa), sin(sa)) * (r + 12.0)
				var base2: Vector2 = tg.pos + Vector2(cos(sa), sin(sa)) * (r * 0.5)
				draw_line(base2, tip, Color(1.0, 0.90, 0.50, 0.8 * fade), 2.0, true)
		if tg.kind == "shield":
			# Bankable shield: blue core with a slowly turning hex shell.
			var sw := 0.8 + 0.2 * sin(t * 4.0 + tg.phase)
			draw_circle(tg.pos, r + 8.0, Color(0.30, 0.70, 1.0, 0.10 * fade))
			draw_circle(tg.pos, r * 0.9, Color(0.10, 0.25, 0.45, 0.98 * fade))
			draw_circle(tg.pos, r * 0.55 * sw, Color(0.45, 0.85, 1.0, 0.9 * fade))
			var hp := _hex_points(tg.pos, (r + 6.0) * sw, -t * 0.6 + tg.phase)
			var hr := hp.duplicate()
			hr.append(hp[0])
			draw_polyline(hr, Color(0.45, 0.85, 1.0, 0.85 * fade), 2.5)

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
					draw_line(root, prong, Color(1.0, 0.95, 0.85, 0.35 * fade), 1.0, true)
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


## Charged-shot preview: a ballistic arc stepped with the same forces the ball
## feels (gravity and speed decay), ending at the first thing it would touch.
func _draw_boss() -> void:
	var vis := _view_rect().grow(CULL_MARGIN)
	if not vis.has_point(boss.pos):
		return
	var f: float = clampf(boss.flash, 0.0, 1.0)
	var r := boss.radius
	# Scorched bulk with a molten rim, ringed by long spikes.
	draw_circle(boss.pos, r + 16.0 + f * 10.0, Color(1.0, 0.30, 0.12, 0.06 + f * 0.10))
	draw_circle(boss.pos, r, Color(0.30, 0.07, 0.10, 0.98))
	draw_circle(boss.pos + Vector2(-r * 0.12, -r * 0.12), r * 0.86, Color(0.55, 0.14, 0.14, 0.95))
	draw_circle(boss.pos + Vector2(-r * 0.26, -r * 0.26), r * 0.34, Color(1.0, 0.75, 0.45, 0.35 + f * 0.5))
	var ring := Color(1.0, 0.38, 0.12, 0.85).lerp(WHITE, f)
	draw_arc(boss.pos, r, 0.0, TAU, 40, ring, 3.0 + f * 4.0, true)
	var spike_spin: float = t * 0.5 + boss.phase
	for k in 12:
		var a: float = spike_spin + k * TAU / 12.0
		var out := Vector2(cos(a), sin(a))
		var tip := boss.pos + out * (r + BOSS_SPIKE_LEN)
		var side_w := out.orthogonal() * (r * 0.10)
		var base_c := boss.pos + out * (r * 0.82)
		draw_colored_polygon(PackedVector2Array([tip, base_c + side_w, base_c - side_w]),
			Color(1.0, 0.45, 0.15, 0.95).lerp(WHITE, f * 0.6))
	var pulse := 1.0 + sin(t * 3.0 + boss.phase) * 0.05
	draw_circle(boss.pos, r * 0.30 * pulse, Color(1.0, 0.55, 0.20, 0.75))
	if f > 0.01:
		draw_circle(boss.pos, r, Color(1.0, 1.0, 1.0, f * 0.45))


func _draw_boss_shots() -> void:
	var vis := _view_rect().grow(CULL_MARGIN)
	for s in boss_shots:
		if not vis.has_point(s.pos):
			continue
		var a := clampf(s.life / 1.0, 0.0, 1.0)
		draw_circle(s.pos, BOSS_SHOT_R + 7.0, Color(1.0, 0.35, 0.10, 0.18))
		draw_circle(s.pos, BOSS_SHOT_R, Color(1.0, 0.45, 0.12, 0.55 + 0.4 * a))
		draw_circle(s.pos, BOSS_SHOT_R * 0.45, WHITE)


## Threat bar pinned under the timer while the boss is up.
func _draw_boss_bar() -> void:
	var bw := 420.0
	var bx := 640.0 - bw * 0.5
	var by := 70.0
	_text_center_at(Vector2(640.0, 66.0), "BOSS", 11, RED)
	draw_rect(Rect2(bx, by, bw, 6.0), Color(0.50, 0.10, 0.12, 0.55))
	var p := clampf(float(boss.hp) / float(max(boss.max_hp, 1)), 0.0, 1.0)
	if p > 0.0:
		draw_rect(Rect2(bx, by, bw * p, 6.0), RED)


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

	# Two dozen dots read the same as ninety, and every draw_circle is its own
	# command, so stride the path rather than emitting one per sample.
	var skip := maxi(1, int(ceil(float(n) / 26.0)))
	var clear2 := (BALL_R + 13.0) * (BALL_R + 13.0)
	for i in range(0, n, skip):
		var pt: Vector2 = path[i]
		var dx: float = pt.x - ball_pos.x
		var dy: float = pt.y - ball_pos.y
		if dx * dx + dy * dy < clear2:
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
	# The step never changes, so the decay and the gravity kick fold into two
	# constants instead of being resolved in all 90 steps.
	var drag_step := pow(SPEED_RETAIN, h)
	var gravity_step := GRAVITY * h
	var surface := _lava_top() - BALL_R
	var min_x := WORLD.position.x + BALL_R
	var max_x := WORLD.end.x - BALL_R
	var min_y := WORLD.position.y + BALL_R
	# Bodies further away than the shot can possibly travel are dropped up front,
	# and the survivors are flattened into typed arrays. The sweep below touches
	# them thousands of times per frame while a shot is charged, and packed float
	# access is far cheaper than untyped Array elements and a method call each.
	var reach := v0.length() * 1.5 + 80.0
	var reach2 := reach * reach
	var bx := PackedFloat32Array()
	var by := PackedFloat32Array()
	var rr := PackedFloat32Array()
	for b in bumpers:
		if b.pos.distance_squared_to(ball_pos) < reach2:
			bx.append(b.pos.x)
			by.append(b.pos.y)
			var bg: float = b.radius + BALL_R
			rr.append(bg * bg)
	for tg in targets:
		if tg.pos.distance_squared_to(ball_pos) < reach2:
			bx.append(tg.pos.x)
			by.append(tg.pos.y)
			var tgap: float = tg.radius + BALL_R + (SPIKE_LEN if tg.kind == "armored" else 0.0)
			rr.append(tgap * tgap)
	if boss != null and boss.pos.distance_squared_to(ball_pos) < reach2:
		bx.append(boss.pos.x)
		by.append(boss.pos.y)
		var br2: float = boss.radius + BALL_R + BOSS_SPIKE_LEN
		rr.append(br2 * br2)
	var count := bx.size()
	for i in 90:
		vel.y += gravity_step
		vel *= drag_step
		pos += vel * h
		pts.append(pos)
		if pos.x < min_x or pos.x > max_x or pos.y < min_y or pos.y > surface:
			break
		var blocked := false
		for k in count:
			var dx: float = pos.x - bx[k]
			var dy: float = pos.y - by[k]
			if dx * dx + dy * dy < rr[k]:
				blocked = true
				break
		if blocked:
			break
	return pts


# ------------------------------------------------------------------ draw actors
func _draw_ball() -> void:
	# Spectators have no ball of their own; the watched fighter is drawn by
	# _draw_duel_world, so skip this or it would double-draw on top of them.
	if _duel_watching():
		return
	var bc := _ball_col()
	var bh := _ball_hot()
	var n := trail.size() if trail_opt else 0
	for i in n:
		var u := float(i + 1) / float(n)
		draw_circle(trail[i], BALL_R * (0.2 + u * 0.8), Color(bc.r, bc.g, bc.b, u * u * 0.16))

	draw_circle(ball_pos, BALL_R + 18.0 + ball_flash * 8.0, Color(bc.r, bc.g, bc.b, 0.05 + ball_flash * 0.04))
	draw_circle(ball_pos, BALL_R + 7.0, Color(minf(bc.r + 0.1, 1.0), minf(bc.g + 0.1, 1.0), minf(bc.b + 0.1, 1.0), 0.12))
	draw_circle(ball_pos, BALL_R, bh)
	draw_circle(ball_pos - Vector2(BALL_R * 0.3, BALL_R * 0.3), BALL_R * 0.45, WHITE_HOT)

	if mode == "play" and shot_ready:
		draw_arc(ball_pos, BALL_R + 12.0, 0.0, TAU, 40, Color(_ball_col().r, _ball_col().g, _ball_col().b, 0.32), 2.0, true)

	if charging:
		var c := clampf(charge_t / CHARGE_TIME, 0.0, 1.0)
		draw_arc(ball_pos, BALL_R + 11.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.10), 5.0, true)
		if c > 0.0:
			var col := Color.from_hsv(lerpf(0.52, 0.86, c), 0.80, 1.0)
			draw_arc(ball_pos, BALL_R + 11.0, -PI * 0.5, -PI * 0.5 + TAU * c, 32, col, 5.0, true)
			draw_circle(ball_pos, BALL_R + 5.0, Color(col.r, col.g, col.b, 0.08))


func _draw_particles() -> void:
	var vis := _view_rect().grow(CULL_MARGIN)
	for p in particles:
		if not vis.has_point(p.pos):
			continue
		var a := clampf(p.life / p.max_life, 0.0, 1.0)
		if a <= 0.0:
			continue
		var s: float = p.size * (0.4 + a * 0.6)
		# Dots under 3 px read the same as squares and cost far less to rasterise.
		if s < 3.0:
			var h: float = s * 0.5
			draw_rect(Rect2(p.pos.x - h, p.pos.y - h, s, s),
				Color(p.color.r, p.color.g, p.color.b, a))
		else:
			draw_circle(p.pos, s, Color(p.color.r, p.color.g, p.color.b, a))


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
	if net_mode != "off" and (mode == "play" or (mode == "over" and duel_over)):
		_draw_duel_corners()
	else:
		_text("SCORE", Vector2(48.0, 28.0), 11, DIM)
		_text(str(score), Vector2(48.0, 56.0), 26, WHITE, true)
	if mode == "play" and net_mode == "off":
		_text("SHOT READY" if shot_ready else "HIT A BALL TO RELOAD", Vector2(48.0, 82.0), 12,
			CYAN if shot_ready else RED)
	if mode == "play" and net_mode == "off" and shields > 0:
		_text("SHIELD", Vector2(48.0, 108.0), 11, DIM)
		for i in shields:
			var cp := Vector2(122.0 + float(i) * 26.0, 104.0)
			var poly := _hex_points(cp, 9.0, t * 0.8)
			draw_colored_polygon(poly, Color(0.10, 0.30, 0.45, 0.85))
			var ringp := poly.duplicate()
			ringp.append(poly[0])
			draw_polyline(ringp, SHIELD_BLUE, 2.0)

	if net_mode == "off":
		_text_right("SMASHED", Vector2(1232.0, 28.0), 11, DIM)
		_text_right(str(kills), Vector2(1232.0, 56.0), 26, WHITE, true)
	if mode == "play" and net_mode != "off" and not duel_over:
		var hint := "RMB / F shoot   ·   chests give guns   ·   smash balls to bounce again"
		if _duel_watching():
			hint = "SPECTATING - the round plays on without you"
		if DisplayServer.is_touchscreen_available():
			hint = "hold + drag to bounce   ·   2nd finger: push stick to shoot"
		_text_center_at(Vector2(640.0, 700.0), hint, 12, Color(0.45, 0.60, 0.80, 0.55))

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
	if autoaim:
		_text_center_at(Vector2(640.0, 100.0), "AUTOAIM %d" % auto_left, 16, GOLD, bold_font)

	if mode == "play" and time_left < 5.0:
		var a := (1.0 - time_left / 5.0) * (0.16 + 0.10 * sin(t * 10.0))
		draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(1.0, 0.2, 0.35, a), false, 26.0)

	if muted:
		_text_right("MUTED", Vector2(1232.0, 700.0), 12, DIM)

	if banner_t > 0.0:
		var a := clampf(banner_t / 0.45, 0.0, 1.0)
		_text_center_at(Vector2(640.0, 300.0), banner, 54,
			Color(0.85, 0.98, 1.0, a), bold_font)


func _duel_foe_name(o: int) -> String:
	return "FOE" if o == 0 else "FOE %d" % (o + 1)


func _duel_foe_col(o: int) -> Color:
	return DUEL_FOE_COLS[o % DUEL_FOE_COLS.size()]


## Duel corners: my health + gun, then every rival stacked top-right.
func _draw_duel_corners() -> void:
	var watching := _duel_watching()
	_text("SPECTATING" if watching else "YOU", Vector2(48.0, 28.0), 11, DIM)
	var w := _duel_watch_target() if watching else {}
	var my_hp := int(w.get("hp", 0)) if watching else int(duel_me.get("hp", DUEL_HP))
	var my_gun := 0 if watching else int(duel_me.get("gun", 0))
	_text(str(my_hp), Vector2(48.0, 56.0), 26, WHITE, true)
	_text(DUEL_GUN_NAMES[clampi(my_gun, 0, 2)], Vector2(48.0, 82.0), 12, CYAN if my_gun > 0 else RED)
	var bw2 := 150.0
	draw_rect(Rect2(48.0, 90.0, bw2, 6.0), Color(0.35, 0.55, 1.0, 0.18))
	draw_rect(Rect2(48.0, 90.0, bw2 * clampf(float(my_hp) / DUEL_HP, 0.0, 1.0), 6.0), CYAN if my_hp > 30 else RED)
	for o in duel_foes.size():
		var f: Dictionary = duel_foes[o]
		var hp := int(f.get("hp", DUEL_HP))
		var y := 28.0 + float(o) * 56.0
		_text_right(_duel_foe_name(o), Vector2(1232.0, y), 11, DIM)
		_text_right(str(hp), Vector2(1232.0, y + 28.0), 26, WHITE, true)
		var col: Color = _duel_foe_col(o)
		draw_rect(Rect2(1232.0 - bw2, y + 36.0, bw2, 6.0), Color(col.r, col.g, col.b, 0.18))
		draw_rect(Rect2(1232.0 - bw2, y + 36.0, bw2 * clampf(float(hp) / DUEL_HP, 0.0, 1.0), 6.0), col)


## Foe fighter, bullets, chests, pickups + floating health bars.
func _draw_duel_world() -> void:
	for ch in duel_chests:
		var p: Vector2 = ch["pos"]
		var r := Rect2(p - Vector2(26.0, 26.0), Vector2(52.0, 52.0))
		draw_rect(r.grow(3.0), Color(0.05, 0.04, 0.02, 0.85))
		draw_rect(r, Color(0.45, 0.30, 0.12, 0.95))
		draw_rect(r, GOLD, false, 2.0)
		draw_line(r.position, r.end, Color(0.25, 0.16, 0.06, 0.9), 3.0)
		draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Color(0.25, 0.16, 0.06, 0.9), 3.0)
		var frac := clampf(float(ch["hp"]) / DUEL_CHEST_HP, 0.0, 1.0)
		draw_rect(Rect2(p - Vector2(26.0, 34.0), Vector2(52.0 * frac, 5.0)), GOLD)
	for pk in duel_pickups:
		var pp: Vector2 = pk["pos"] + Vector2(0.0, sin(t * 3.0) * 4.0)
		var gc: Color = CYAN if int(pk["kind"]) == 1 else GOLD
		draw_circle(pp, 14.0, Color(gc.r, gc.g, gc.b, 0.18))
		draw_rect(Rect2(pp + Vector2(-10.0, -4.0), Vector2(18.0, 8.0)), gc)
		draw_rect(Rect2(pp + Vector2(8.0, -2.0), Vector2(12.0, 4.0)), gc)
	for b in duel_bullets:
		var bc: Color = CYAN if int(b["owner"]) == _duel_role() else Color(1.0, 0.55, 0.30)
		draw_circle(b["pos"], DUEL_BULLET_R + 6.0, Color(bc.r, bc.g, bc.b, 0.25))
		draw_circle(b["pos"], DUEL_BULLET_R, bc)
	# Rival fighters in their own colors, skipped once eliminated.
	for o in duel_foes.size():
		var f: Dictionary = duel_foes[o]
		if int(f.get("hp", 0)) <= 0:
			continue
		var fp: Vector2 = f.get("pos", Vector2.ZERO)
		var col: Color = _duel_foe_col(o)
		if mode == "play" or duel_over:
			draw_circle(fp, BALL_R + 5.0, Color(col.r, col.g, col.b, 0.22))
			draw_circle(fp, BALL_R, col)
			draw_circle(fp, BALL_R * 0.45, WHITE)
			draw_arc(fp, BALL_R + 5.0, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.8), 2.0)
			var fhp := clampf(float(f.get("hp", DUEL_HP)) / DUEL_HP, 0.0, 1.0)
			draw_rect(Rect2(fp + Vector2(-30.0, -34.0), Vector2(60.0, 6.0)), Color(0.0, 0.0, 0.0, 0.55))
			draw_rect(Rect2(fp + Vector2(-29.0, -33.0), Vector2(58.0 * fhp, 4.0)), col)
			_text_center_at(fp + Vector2(0.0, -40.0), _duel_foe_name(o), 11,
				Color(minf(col.r + 0.2, 1.0), minf(col.g + 0.1, 1.0), col.b, 0.9))


## Edge arrows pointing at living rivals who are off-screen. Screen space:
## project each rival through the camera, clamp the ray to a margin box and
## draw their color-coded triangle + name so you always know where they are.
func _draw_duel_arrows() -> void:
	var margin := 46.0
	var box := Rect2(margin, margin, VIEW.x - margin * 2.0, VIEW.y - margin * 2.0)
	var center := VIEW * 0.5
	# Same rect as _draw_minimap: arrows slide left past it instead of
	# piling onto the radar, while keeping their exact bearing.
	var rr := Rect2(VIEW.x - 26.0 - 200.0, VIEW.y - 26.0 - 133.0, 200.0, 133.0).grow(30.0)
	for o in duel_foes.size():
		var f: Dictionary = duel_foes[o]
		if int(f.get("hp", 0)) <= 0:
			continue
		var sp := ((f.get("pos", Vector2.ZERO) as Vector2) - cam) * cam_zoom + center
		if box.has_point(sp):
			continue
		var dir := sp - center
		if dir.length_squared() < 1.0:
			dir = Vector2.RIGHT
		dir = dir.normalized()
		var sx := (box.end.x - center.x) / dir.x if dir.x > 0.0 else ((box.position.x - center.x) / dir.x if dir.x < 0.0 else INF)
		var sy := (box.end.y - center.y) / dir.y if dir.y > 0.0 else ((box.position.y - center.y) / dir.y if dir.y < 0.0 else INF)
		var edge := center + dir * minf(sx, sy)
		if rr.has_point(edge):
			edge.x = maxf(rr.position.x - 18.0, box.position.x)
		var col: Color = _duel_foe_col(o)
		var pulse := 0.70 + 0.30 * sin(t * 5.0 + float(o) * 1.7)
		var tip := edge + dir * 14.0
		var back := edge - dir * 6.0
		var side := dir.orthogonal() * 10.0
		draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]),
			Color(col.r, col.g, col.b, pulse))
		_text_center_at(edge - dir * 22.0, _duel_foe_name(o), 12,
			Color(minf(col.r + 0.2, 1.0), minf(col.g + 0.1, 1.0), col.b, 0.95))


## Gun stick (touch versus): base ring where the second finger landed, knob
## following the drag. Drawn in screen space, only while held.
func _draw_stick() -> void:
	if not stick_on:
		return
	var pulse := 0.55 + 0.15 * sin(t * 4.0)
	draw_arc(stick_base, STICK_R, 0.0, TAU, 40, Color(1.0, 0.80, 0.30, 0.15 + 0.35 * pulse), 3.0, true)
	draw_circle(stick_base, 6.0, Color(1.0, 0.80, 0.30, 0.5))
	var k := stick_base + (stick_knob - stick_base).limit_length(STICK_R)
	draw_line(stick_base, k, Color(1.0, 0.85, 0.45, 0.4), 4.0, true)
	draw_circle(k, 22.0, Color(0.10, 0.16, 0.24, 0.55))
	draw_arc(k, 22.0, 0.0, TAU, 28, Color(1.0, 0.85, 0.45, 0.8), 3.0, true)


## Corner map so you can see the balls waiting beyond the screen edge.
func _draw_minimap() -> void:
	var size := Vector2(200.0, 133.0)
	var mm := Rect2(VIEW.x - 26.0 - size.x, VIEW.y - 26.0 - size.y, size.x, size.y)
	draw_rect(mm.grow(7.0), Color(0.01, 0.02, 0.05, 0.66))
	draw_rect(mm, Color(0.03, 0.06, 0.12, 0.55))
	draw_rect(mm, Color(0.40, 0.72, 1.0, 0.32), false, 1.0)

	var sc := Vector2(mm.size.x / WORLD.size.x, mm.size.y / WORLD.size.y)
	for b in bumpers:
		var bp0: Vector2 = mm.position + (b.pos - WORLD.position) * sc
		draw_rect(Rect2(bp0 - Vector2(1.3, 1.3), Vector2(2.6, 2.6)),
			Color(0.35, 0.62, 1.0, 0.30))
	for tg in targets:
		var tp0: Vector2 = mm.position + (tg.pos - WORLD.position) * sc
		draw_rect(Rect2(tp0 - Vector2(1.8, 1.8), Vector2(3.6, 3.6)),
			Color(tg.color.r, tg.color.g, tg.color.b, 0.85))
	draw_rect(Rect2(mm.position.x, mm.position.y + (_lava_top() - WORLD.position.y) * sc.y,
		mm.size.x, LAVA_H * sc.y), Color(1.0, 0.45, 0.10, 0.55))

	var vw := _view_rect()
	var vr := Rect2(mm.position + (vw.position - WORLD.position) * sc, vw.size * sc)
	draw_rect(vr, Color(0.85, 0.97, 1.0, 0.50), false, 1.0)

	var bp := mm.position + (ball_pos - WORLD.position) * sc
	draw_circle(bp, 4.5, Color(0.40, 0.90, 1.0, 0.22))
	draw_circle(bp, 2.4, CYAN)
	if net_mode != "off" and not duel_chests.is_empty():
		for ch in duel_chests:
			var cp0: Vector2 = mm.position + ((ch["pos"] as Vector2) - WORLD.position) * sc
			draw_rect(Rect2(cp0 - Vector2(1.8, 1.8), Vector2(3.6, 3.6)), Color(1.0, 0.80, 0.30, 0.9))
	if net_mode != "off":
		for o in duel_foes.size():
			var f2: Dictionary = duel_foes[o]
			if int(f2.get("hp", 0)) <= 0:
				continue
			var fp0: Vector2 = mm.position + (((f2["pos"]) as Vector2) - WORLD.position) * sc
			draw_circle(fp0, 2.6, _duel_foe_col(o))

	_text_right("RADAR", Vector2(mm.end.x, mm.position.y - 10.0), 10, DIM)


func _draw_custom() -> void:
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.015, 0.020, 0.045, 0.72))
	var panel := Rect2(340.0, 140.0, 600.0, 440.0)
	draw_rect(panel.grow(6.0), Color(0.02, 0.05, 0.10, 0.85))
	draw_rect(panel, Color(0.03, 0.07, 0.14, 0.92))
	draw_rect(panel, Color(0.40, 0.72, 1.0, 0.35), false, 2.0)
	_text_center_at(Vector2(640.0, 196.0), "CUSTOMIZE", 34, WHITE, bold_font)
	var mp := get_viewport().get_mouse_position()
	for i in 5:
		var r := _custom_row_rect(i)
		var hov := r.has_point(mp)
		draw_rect(r, Color(0.10, 0.22, 0.38, 0.60) if hov else Color(0.06, 0.13, 0.24, 0.60))
		draw_rect(r, Color(0.42, 0.66, 1.0, 0.35) if hov else Color(0.42, 0.66, 1.0, 0.18), false, 1.0)
		_text(CUSTOM_LABELS[i], Vector2(r.position.x + 24.0, r.position.y + 32.0), 20, WHITE if hov else DIM)
		if i == 0:
			var skin: Color = BALL_SKINS[clampi(ball_idx, 0, BALL_SKINS.size() - 1)]
			draw_circle(Vector2(640.0, r.position.y + 24.0), 14.0, skin)
			draw_circle(Vector2(640.0, r.position.y + 24.0), 6.0, WHITE)
			_text_right("<  " + BALL_NAMES[clampi(ball_idx, 0, BALL_NAMES.size() - 1)] + "  >", Vector2(r.end.x - 24.0, r.position.y + 32.0), 20, skin)
		else:
			_text_right("<  " + _custom_value(i) + "  >", Vector2(r.end.x - 24.0, r.position.y + 32.0), 20, CYAN if _custom_on(i) else DIM)
	var hov_b := BTN_BACK.has_point(mp)
	draw_rect(BTN_BACK, Color(0.10, 0.22, 0.30, 0.90) if hov_b else Color(0.05, 0.14, 0.20, 0.90))
	draw_rect(BTN_BACK, CYAN if hov_b else Color(0.42, 0.66, 1.0, 0.55), false, 1.5)
	_text_center_at(BTN_BACK.get_center() + Vector2(0.0, 7.0), "BACK", 20, WHITE if hov_b else DIM, bold_font)
	_text_center_at(Vector2(640.0, 700.0), "click a row to change it   ·   R starts the run", 12, Color(0.45, 0.60, 0.80, 0.55))


func _net_button(r: Rect2, label: String, mp: Vector2) -> void:
	var hov := r.has_point(mp)
	draw_rect(r, Color(0.10, 0.30, 0.38, 0.95) if hov else Color(0.06, 0.18, 0.26, 0.95))
	draw_rect(r, CYAN if hov else Color(0.42, 0.66, 1.0, 0.70), false, 2.0)
	var fs := 22 if r.size.x > 200.0 else 18
	_text_center_at(r.get_center() + Vector2(0.0, 9.0), label, fs, WHITE, bold_font)


func _draw_net() -> void:
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.015, 0.020, 0.045, 0.72))
	var panel := Rect2(340.0, 140.0, 600.0, 440.0)
	draw_rect(panel.grow(6.0), Color(0.02, 0.05, 0.10, 0.85))
	draw_rect(panel, Color(0.03, 0.07, 0.14, 0.92))
	draw_rect(panel, Color(0.40, 0.72, 1.0, 0.35), false, 2.0)
	_text_center_at(Vector2(640.0, 196.0), "MULTIPLAYER", 34, WHITE, bold_font)
	var mp := get_viewport().get_mouse_position()
	if net_screen == "menu":
		_net_button(BTN_NET_HOST, "HOST GAME", mp)
		_net_button(BTN_NET_JOIN, "JOIN GAME", mp)
		_text_center_at(Vector2(640.0, 470.0), "up to 4 players - shared arena - last one standing wins", 14, DIM)
	elif net_screen == "join":
		_text_center_at(Vector2(640.0, 250.0), "ENTER HOST IP", 18, DIM)
		draw_rect(NET_IP_RECT, Color(0.06, 0.13, 0.24, 0.9))
		draw_rect(NET_IP_RECT, CYAN if join_focused else Color(0.42, 0.66, 1.0, 0.5), false, 2.0)
		var caret := "_" if join_focused and int(t * 2.0) % 2 == 0 else ""
		_text_center_at(Vector2(640.0, 312.0), join_ip + caret, 24, WHITE, bold_font)
		_net_button(BTN_NET_JOIN, "JOIN", mp)
		if net_status != "":
			_text_center_at(Vector2(640.0, 460.0), net_status, 16, RED)
	elif net_screen == "host":
		_text_center_at(Vector2(640.0, 260.0), "HOSTING ON - GIVE YOUR RIVAL ONE OF THESE", 16, DIM)
		var ips := _net_host_ips()
		for i in mini(ips.size(), 4):
			var big := i == 0
			_text_center_at(Vector2(640.0, 306.0 + i * 34.0), "%s:%d" % [str(ips[i]), NET_PORT], 26 if big else 19, WHITE if big else DIM, bold_font)
		var rivals := multiplayer.get_peers().size()
		var cap := DUEL_MAX_PLAYERS if not duel_host_plays else DUEL_MAX_PLAYERS - 1
		_text_center_at(Vector2(640.0, 320.0 + mini(ips.size(), 4) * 34.0), "waiting for rivals... (%d/%d)" % [rivals, cap], 18, Color(0.85, 0.97, 1.0, 0.5 + 0.5 * sin(t * 4.0)))
		_net_button(BTN_NET_ROLE, "HOST FIGHTS" if duel_host_plays else "HOST SPECTATES", mp)
	elif net_screen == "ready":
		if net_mode == "host":
			_text_center_at(Vector2(640.0, 300.0), "RIVALS READY: %d" % multiplayer.get_peers().size(), 26, CYAN, bold_font)
			_net_button(BTN_NET_ROLE2, "HOST FIGHTS" if duel_host_plays else "HOST SPECTATES", mp)
			_net_button(BTN_START, "START", mp)
		else:
			_text_center_at(Vector2(640.0, 300.0), "RIVAL FOUND", 26, CYAN, bold_font)
			_text_center_at(Vector2(640.0, 400.0), "waiting for host to start...", 18, DIM)
	elif net_screen == "countdown":
		_text_center_at(Vector2(640.0, 360.0), str(maxi(int(ceil(net_count)), 1)), 96, WHITE, bold_font)
	_net_button(BTN_BACK, "BACK", mp)
	_text_center_at(Vector2(640.0, 700.0), "online versus - R restarts after a match", 12, Color(0.45, 0.60, 0.80, 0.55))


func _draw_title() -> void:
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.015, 0.020, 0.045, 0.58))

	_text_center_at(Vector2(640.0, 252.0), "BOUNCE BACK", 88, Color(0.25, 0.80, 1.0, 0.28), bold_font)
	_text_center_at(Vector2(640.0, 248.0), "BOUNCE BACK", 88, WHITE, bold_font)
	_text_center_at(Vector2(640.0, 290.0), "hold  ·  charge  ·  ricochet", 18, Color(0.55, 0.85, 1.0, 0.75))

	_rule(350.0, "HOLD", "charge your bounce")
	_rule(374.0, "RELEASE", "launch toward the cursor")
	_rule(398.0, "RICOCHET", "touch balls to shatter them")
	_rule(422.0, "EARN SHOTS", "hit a ball to shoot again")
	_rule(446.0, "SPIKES", "they hunt you, slow hits kill")
	_rule(470.0, "EXPLORE", "the world scrolls past the screen")
	_rule(494.0, "LAVA", "the molten floor ends your run")

	var mp := get_viewport().get_mouse_position()
	var hov_s := BTN_START.has_point(mp)
	var hov_c := BTN_CUSTOM.has_point(mp)
	draw_rect(BTN_START, Color(0.10, 0.30, 0.38, 0.95) if hov_s else Color(0.06, 0.18, 0.26, 0.95))
	draw_rect(BTN_START, CYAN if hov_s else Color(0.42, 0.66, 1.0, 0.70), false, 2.0)
	_text_center_at(BTN_START.get_center() + Vector2(0.0, 9.0), "START", 26, WHITE, bold_font)
	var hov_n := BTN_NET.has_point(mp)
	draw_rect(BTN_CUSTOM, Color(0.10, 0.22, 0.30, 0.90) if hov_c else Color(0.05, 0.14, 0.20, 0.90))
	draw_rect(BTN_CUSTOM, CYAN if hov_c else Color(0.42, 0.66, 1.0, 0.55), false, 1.5)
	_text_center_at(BTN_CUSTOM.get_center() + Vector2(0.0, 7.0), "CUSTOMIZE", 16, WHITE if hov_c else DIM, bold_font)
	draw_rect(BTN_NET, Color(0.10, 0.22, 0.30, 0.90) if hov_n else Color(0.05, 0.14, 0.20, 0.90))
	draw_rect(BTN_NET, CYAN if hov_n else Color(0.42, 0.66, 1.0, 0.55), false, 1.5)
	_text_center_at(BTN_NET.get_center() + Vector2(0.0, 7.0), "MULTIPLAYER", 16, WHITE if hov_n else DIM, bold_font)
	if best > 0:
		_text_center_at(Vector2(640.0, 662.0), "BEST  %d" % best, 16, DIM)
	_text_center_at(Vector2(640.0, 700.0), "R restart   ·   M mute", 12, Color(0.45, 0.60, 0.80, 0.55))


func _draw_game_over() -> void:
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.02, 0.015, 0.04, 0.78))
	var headline := "TIME'S UP"
	if net_mode != "off" and not duel_over:
		headline = "YOU WIN" if score > foe_score else ("DRAW" if score == foe_score else "YOU LOSE")
	elif died_on_spikes:
		headline = "IMPALED"
	elif died_in_lava:
		headline = "MELTED"
	if net_mode == "off" or not duel_over:
		_text_center_at(Vector2(640.0, 250.0), headline, 68, PINK, bold_font)
	if net_mode != "off" and duel_over:
		var i_won := duel_winner == duel_my_id
		var dh := "YOU WIN" if i_won else ("DRAW" if duel_winner < 0 else "YOU LOSE")
		var sub := "YOU  %d HP" % int(duel_me.get("hp", 0))
		if duel_my_id < 0:
			sub = "SPECTATED MATCH"
			if duel_winner >= 0:
				dh = "%s WINS" % _duel_foe_name(duel_winner)
		_text_center_at(Vector2(640.0, 250.0), dh, 68, PINK, bold_font)
		_text_center_at(Vector2(640.0, 340.0), sub, 40, WHITE, bold_font)
		var oy := 392.0
		for o in duel_foes.size():
			_text_center_at(Vector2(640.0, oy), "%s  %d HP" % [_duel_foe_name(o), int((duel_foes[o] as Dictionary).get("hp", 0))], 24, CYAN)
			oy += 40.0
		var pulse2 := 0.6 + 0.4 * sin(t * 4.0)
		_text_center_at(Vector2(640.0, 610.0), "R rematch   ·   B menu", 12, Color(0.45, 0.60, 0.80, 0.55 * pulse2 + 0.2))
		return
	_text_center_at(Vector2(640.0, 320.0), "SCORE", 12, DIM)
	_text_center_at(Vector2(640.0, 392.0), str(score), 72, WHITE, bold_font)
	_text_center_at(Vector2(640.0, 442.0), "SMASHED %d" % kills, 20, CYAN)
	if net_mode != "off":
		_text_center_at(Vector2(640.0, 466.0), "FOE  %d" % foe_score, 16, CYAN)
	if new_best:
		_text_center_at(Vector2(640.0, 486.0), "NEW BEST!", 18, GOLD, bold_font)
	elif best > 0:
		_text_center_at(Vector2(640.0, 486.0), "BEST  %d" % best, 16, DIM)
	var pulse := 0.6 + 0.4 * sin(t * 4.0)
	if net_mode == "off":
		_text_center_at(Vector2(640.0, 572.0), "CLICK TO PLAY AGAIN", 20, Color(0.85, 0.97, 1.0, pulse))
	else:
		_text_center_at(Vector2(640.0, 610.0), "R rematch   ·   B menu", 12, Color(0.45, 0.60, 0.80, 0.55))


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
