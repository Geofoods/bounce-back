extends Node2D
## BALLS OF DUTY — hold to charge, release to launch the ball toward the cursor.
## Fast impacts shatter balls, slow ones bounce off. The camera follows the ball
## and leans toward the cursor, through a world several screens wide. Gravity pulls the ball down, and the
## molten floor along the bottom of the world ends the run on contact.
## Everything is drawn in code.
##
## Tuning lives at the top of this file. Nothing else is required to run the game.

# ------------------------------------------------------------------ tuning
const VIEW := Vector2(1280.0, 720.0)
const WORLD := Rect2(0.0, 0.0, 3840.0, 2560.0)   # ~9 screens of playfield
const BALL_R := 15.0
const LIGHT_RADIUS := 720.0  # how far your ball's lamp reaches (world units)
const WORLD_SCALE := 1.0 / 1.2  # game speed factor: <1 = slower

const CAM_LERP := 4.6            # camera follow stiffness (higher = tighter)
const CAM_LOOKAHEAD := 0.26      # how far ahead of the ball the camera leads
const CAM_MOUSE_BIAS := 0.28     # how far the camera leans from ball toward cursor
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
const SLOWMO := 0.39             # world speed while charging (1.3x slower than original 0.30)
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
const BALL_NAMES := ["CYAN", "PINK", "VERITY", "GREEN", "PURPLE"]
# Photo ball skins: circular portraits drawn over the ball.
const BALL_FACE_PATHS := ["res://images (2)-modified.png", "res://Kai_Cenat-modified.png", "res://LacyHimself-modified.png", "res://Rayasianboy_2025-modified.png", "res://OIP (17)-modified.png"]
const BALL_FACE_NAMES := ["MARLON", "KAI", "LACY", "RAY", "RAKAI"]
const HOST_QR_PATH := "res://bing_generated_qrcode (1).png"
const SETTINGS_LABELS := ["MOBILE CONTROLS", "TRAIL", "SHAKE", "GLOW", "SOUND"]
const CUSTOM_ARROW_L := Rect2(36.0, 330.0, 64.0, 64.0)
const CUSTOM_ARROW_R := Rect2(1180.0, 330.0, 64.0, 64.0)
const CUSTOM_GHOST_L := Rect2(398.0, 298.0, 104.0, 104.0)
const CUSTOM_GHOST_R := Rect2(778.0, 298.0, 104.0, 104.0)
const BTN_START := Rect2(490.0, 532.0, 300.0, 56.0)
const BTN_CUSTOM := Rect2(413.0, 596.0, 146.0, 40.0)
const BTN_SETTINGS := Rect2(721.0, 596.0, 146.0, 40.0)
const BTN_BACK := Rect2(540.0, 596.0, 200.0, 44.0)
# Main-menu chrome (BO3-style left column). Versus screens keep BTN_* above.
const TITLE_PLAY := Rect2(110.0, 196.0, 360.0, 62.0)
const TITLE_MULTI := Rect2(110.0, 266.0, 360.0, 62.0)
const TITLE_CUSTOM := Rect2(110.0, 336.0, 360.0, 62.0)
const TITLE_SETTINGS := Rect2(110.0, 406.0, 360.0, 62.0)
const TITLE_QUIT := Rect2(110.0, 476.0, 360.0, 62.0)
const TITLE_HOW := Rect2(110.0, 546.0, 360.0, 62.0)
# Online versus (mirrored arenas, Godot ENet, no outside services).
const NET_PORT := 7777
const BTN_NET := Rect2(567.0, 596.0, 146.0, 40.0)
const BTN_NET_HOST := Rect2(440.0, 280.0, 196.0, 56.0)
const BTN_NET_HOST_WS := Rect2(644.0, 280.0, 196.0, 56.0)
const BTN_NET_JOIN := Rect2(440.0, 348.0, 400.0, 52.0)
const BTN_NET_PROTO := Rect2(490.0, 486.0, 300.0, 30.0)
const BTN_NET_CUSTOM := Rect2(440.0, 522.0, 400.0, 34.0)
const BTN_NET_ROLE := Rect2(490.0, 510.0, 300.0, 44.0)
const BTN_NET_ROLE2 := Rect2(490.0, 470.0, 300.0, 44.0)
const NET_IP_RECT := Rect2(440.0, 280.0, 400.0, 48.0)
const NET_NAME_RECT := Rect2(440.0, 410.0, 400.0, 40.0)
const NET_NAME_RECT_SM := Rect2(490.0, 218.0, 300.0, 36.0)
const GREEN := Color(0.56, 0.97, 0.76)
const RED := Color(1.0, 0.25, 0.42)
const DIM := Color(0.62, 0.76, 0.95, 0.62)
# Shared UI language: one panel fill, one hairline, one text hierarchy.
# Everything menu/HUD draws through _ui_panel() / _ui_btn() below so panels,
# buttons and bars share radius, shadow and border instead of one-off rects.
const UI_PANEL := Color(0.055, 0.095, 0.165, 0.96)
const UI_PANEL_SOFT := Color(0.075, 0.13, 0.21, 0.92)
const UI_LINE := Color(0.42, 0.66, 1.0, 0.22)
const UI_LINE_STRONG := Color(0.42, 0.66, 1.0, 0.45)
const UI_TEXT := Color(0.93, 0.97, 1.0)
const UI_SUB := Color(0.66, 0.76, 0.89, 0.78)
const UI_SHADOW := Color(0.0, 0.0, 0.0, 0.38)

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
var ui_t := 0.0    # seconds since the menu screen last changed; drives entrances
var _ui_key := ""  # mode|net_screen combo ui_t measures
var _ui_styles := {}  # cached StyleBoxFlat per fill/line/radius/border key

# post fx
var bloom_level: float = 0.35
var vignette_t: float = 0.2
var vignette_pulse: float = 0.0
var glow_env: Environment
var vignette_tex: ImageTexture

var cam: Vector2 = Vector2.ZERO        # world point shown at screen center
var draw_org := Vector2.ZERO         # screen origin of the camera transform this frame
var cam_snap: bool = true
var cam_zoom := 1.0              # 1 = normal; <1 pulls back to frame boss+ball
var stream_t: float = 0.0

var ball_pos: Vector2 = Vector2.ZERO
var ball_vel: Vector2 = Vector2.ZERO
var ball_flash: float = 0.0
var trail: Array = []

var ball_faces: Array = []
var ball_face_cols: Array = []    # accent sampled from each photo; tints trail, glow + rings so VFX match the face
var duel_gun_texs: Array = []
var title_last := 0  # last-hovered title button; keeps its highlight off-hover
var custom_slide_dir := 0  # carousel swipe direction while a skin swap animates
var custom_swap_t := -10.0  # t at the last skin change; drives the slide
var custom_from := ""  # "net" when CUSTOMIZE opened from multiplayer: picking returns there
var host_qr_tex: Texture2D

var charging: bool = false
var charge_t: float = 0.0
var shot_ready: bool = true       # one launch per collision: any wall, bumper or ball reloads
var ready_nudge_t: float = 0.0
var mouse_pos: Vector2 = Vector2.ZERO
var mouse_seen: bool = false
var touch_aim_id := -1   # finger holding the charge; -1 when no touch aims
var stick_id := -1        # second finger driving the gun stick; -1 = stowed
var stick_on := false
var stick_base := Vector2.ZERO   # screen-space anchor + knob of the gun stick
var stick_knob := Vector2.ZERO
var stick_mouse := false      # true while the mouse (not a finger) drives the stick
const STICK_R := 70.0     # gun-stick travel in screen px
const STICK_HOME := Vector2(150.0, 570.0)  # fixed joystick spot when mobile controls are on
const STICK_GRAB := 110.0                   # grab radius around the home spot

# customization (persisted to user://bounce_back.cfg)
var ball_idx := 0
var trail_opt := true
var shake_opt := true
var glow_opt := true
var mobile_controls := false  # settings checkbox: fixed shooting joystick in versus

# online versus: off | host | client; screens menu|join|host|ready|countdown
var net_mode := "off"
var net_screen := "menu"
var net_transport := "enet"  # host/join link: enet (desktop) | ws (browser can join)
var net_status := ""
var net_count := 0.0
var net_send_t := 0.0
var net_timeout := 0.0
var net_last_snap := 0.0  # t of the last duel snapshot seen/sent; stale = link trouble
var foe_score := 0
var foe_kills := 0
var join_ip := "127.0.0.1"
var join_focused := false
var duel_my_name := ""    # my versus display name; blank falls back to YOU/FOE labels
var name_focused := false  # typing into the name box (multiplayer menu/join screens)
var name_edit: LineEdit  # real name field floating over the drawn lobby panels
var ip_edit: LineEdit  # real address field floating over the drawn join panel
var duel_peer_names := {}  # host-side: peer id -> cleaned name sent via _net_hello
var net_ip_rects: Array = []  # clickable host-screen address lines ({rect, text})
var net_copied_at := -99.0    # t when an address was last copied to the clipboard

# duel (versus shooter): host-authoritative shared arena, 100 HP each.
const DUEL_TIME := 60.0
const DUEL_HP := 100
const DUEL_GUN_NAMES := ["FISTS", "ASSAULT", "BLASTER", "LASER", "RAILGUN"]
const DUEL_GUN_PATHS := ["", "res://assault rifle.png", "res://blaster.png", "res://laser.png", "res://railgun.png"]
const DUEL_GUN_COLS := [Color(1.0, 1.0, 1.0), Color(0.55, 0.90, 1.0), Color(1.0, 0.60, 0.25), Color(0.50, 1.0, 0.90), Color(1.0, 0.85, 0.30)]
const DUEL_GUN_CD := [0.0, 0.16, 0.7, 0.9, 1.5]          # trigger cooldown per gun
const DUEL_GUN_DMG := [0, 6, 5, 16, 34]                 # damage per round
const DUEL_GUN_SPD := [0.0, 2000.0, 1750.0, 3200.0, 900.0]  # muzzle velocity
const DUEL_GUN_LIFE := [0.0, 1.2, 1.2, 1.0, 2.4]        # round lifetime, seconds
const DUEL_GUN_RECOIL := [0.0, 60.0, 150.0, 120.0, 320.0]   # backward kick, px/s
const DUEL_GUN_PELLETS := [0, 1, 5, 1, 1]               # rounds per pull
const DUEL_GUN_SPREAD := [0.0, 0.0, 0.22, 0.0, 0.0]     # cone half-angle, radians
const DUEL_GUN_KIND := [0, 0, 0, 1, 2]                  # 0 slug, 1 beam bolt, 2 rail slug (pierces foes; crates stop all rounds)
const DUEL_BULLET_R := 10.0  # versus bullet body radius: chunky, easier to read and land

const DUEL_SNAP_T := 1.0 / 20.0
const DUEL_CHEST_HP := 25
const DUEL_CHEST_RESPAWN_T := 5.0   # host drops a fresh crate this often
const DUEL_BALLS := 78           # smashable balls scattered around the duel arena
const DUEL_SPIKE_REQ := 700.0    # fighter speed needed to smash a spiky ball
const DUEL_SPIKE_DMG := 10       # damage for a slow touch on spikes
const DUEL_LAVA_DMG := 15        # burn tick for resting on the molten floor
const DUEL_LAVA_GRACE := 1.0      # seconds between lava burn ticks
const DUEL_SERVER_PEERS := 64    # ENet connection slots; no game-level cap on fighters
const DUEL_FOE_COLS := [Color(1.0, 0.55, 0.25), Color(0.75, 0.55, 1.0), Color(0.45, 1.0, 0.55)]
const ROULETTE_T := 4.5          # fall-guys map spin length, seconds
const ROULETTE_CARDS := 24       # cards up to and including the winner
const ROULETTE_TRAIL := 5        # extra cards past the winner so it stops mid-strip
const ROULETTE_PITCH := 324.0    # card width + gap on the strip
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
var duel_snap_balls := true  # balls ride every 2nd snapshot: full 20 Hz sim, 10 Hz ball list
var duel_snap_seq := 0   # host stamps every snapshot; the client drops stale ones
var duel_last_seq := -1  # newest snapshot seq applied (client); stale = out of order
var duel_map := 0                # selected map index; walls bake from it
var duel_walls: Array = []       # absolute polys (Array of Array of Vector2)
var duel_maps_cache: Array = []  # lazy-built map defs (name + polys + bounds)
var roulette_t := 0.0            # spin time left; 0 when settled
var roulette_win := 0            # map the strip lands on
var roulette_seed := 0           # shared strip shuffle; host picks, rpc delivers
var roulette_strip: Array = []   # map indices scrolling past, winner mid-strip
var roulette_stop := 0           # strip index the spin eases onto (the winner)
var roulette_tick := -1          # centered card, for the tick sound
var duel_balls_synced := false  # client applied one ball snapshot; first adopts silently
var duel_launch_echo := 0  # leftover launch re-sends; one lost packet can't strand us
var duel_launch_vel := Vector2.ZERO  # velocity the echo re-sends
var duel_echo_t := 0.0  # spacing between echo re-sends
var duel_refill_t := 0.0
var duel_over := false
var duel_winner := -1  # winning fighter index, or -1 for draw/undecided

var bumpers: Array = []
var targets: Array = []
var particles: Array = []
var popups: Array = []
var shadow_queue: Array = []   # cast requests deferred past the lamp wash
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
	_setup_ball_faces()
	_setup_duel_guns()
	_setup_host_qr()
	_setup_net_edits()
	_load_best()
	_load_custom()
	_enter_title()


## Host-lobby QR code (res://bing_generated_qrcode.png). Loaded once; the host
## screen simply skips it if the file is missing.
func _setup_host_qr() -> void:
	if ResourceLoader.exists(HOST_QR_PATH):
		host_qr_tex = load(HOST_QR_PATH) as Texture2D


## Real text fields for the net screens. Hand-rolled key handling can't pop
## a mobile keyboard, accept lowercase/paste, or repeat properly, so the
## name + address boxes are LineEdits skinned to match the lobby. They float
## over the drawn panels; _update_net_edits() shows, hides and places them.
func _setup_net_edits() -> void:
	# Real text fields for the net screens. Hand-rolled key handling can't pop
	# a mobile keyboard, accept lowercase/paste, or repeat properly, so the
	# name + address boxes are LineEdits skinned to match the lobby. They float
	# over the drawn panels; _update_net_edits() shows, hides and places them.
	# On phone, mobile_kb grabs focus so the OS text keyboard comes up.
	var on_mobile := OS.has_feature("web") or OS.get_name() == "Android" or OS.get_name() == "iOS"
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "YOU"
	name_edit.max_length = 12
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.context_menu_enabled = true
	name_edit.keyboard_visibility_changed.connect(_on_name_editable)
	name_edit.add_theme_font_override("font", bold_font)
	name_edit.add_theme_color_override("font_color", WHITE)
	name_edit.add_theme_color_override("font_placeholder_color", DIM)
	name_edit.add_theme_color_override("caret_color", CYAN)
	name_edit.node_filter_input = false
	_net_edit_boxes(name_edit)
	name_edit.text_changed.connect(_on_name_changed)
	name_edit.text_submitted.connect(_on_name_submitted)
	name_edit.focus_entered.connect(_on_name_focus.bind(true))
	name_edit.focus_exited.connect(_on_name_focus.bind(false))
	name_edit.visible = false
	add_child(name_edit)
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "HOST ADDRESS"
	ip_edit.max_length = 64
	ip_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	ip_edit.context_menu_enabled = true
	ip_edit.keyboard_visibility_changed.connect(_on_ip_editable)
	ip_edit.add_theme_font_override("font", bold_font)
	ip_edit.add_theme_color_override("font_color", WHITE)
	ip_edit.add_theme_color_override("font_placeholder_color", DIM)
	ip_edit.add_theme_color_override("caret_color", CYAN)
	ip_edit.node_filter_input = false
	_net_edit_boxes(ip_edit)
	ip_edit.text_changed.connect(_on_ip_changed)
	ip_edit.text_submitted.connect(_on_ip_submitted)
	ip_edit.focus_entered.connect(_on_ip_focus.bind(true))
	ip_edit.focus_exited.connect(_on_ip_focus.bind(false))
	ip_edit.visible = false
	add_child(ip_edit)


## Dark lobby styling for a net LineEdit: dim border idle, cyan on focus.
## The focus box applies itself; no per-frame styling needed.
func _net_edit_boxes(edit: LineEdit) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.13, 0.24, 0.9)
	normal.set_border_width_all(2)
	normal.border_color = Color(0.42, 0.66, 1.0, 0.5)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = CYAN
	edit.add_theme_stylebox_override("normal", normal)
	edit.add_theme_stylebox_override("focus", focus)


## Shows/hides the real text fields to match the net screen and keeps them
## in sync with duel_my_name / join_ip. Text is only pushed into a field
## the player isn't editing, so typing never jumps under them.
func _update_net_edits() -> void:
	var want_name := mode == "net" and (net_screen == "menu" or net_screen == "join" or net_screen == "host" or net_screen == "ready")
	var rect := NET_NAME_RECT
	if net_screen == "host" or net_screen == "ready":
		rect = NET_NAME_RECT_SM
	var want_ip := mode == "net" and net_screen == "join"
	if name_edit != null:
		name_edit.visible = want_name
		if want_name:
			name_edit.position = rect.position
			name_edit.size = rect.size
			name_edit.add_theme_font_size_override("font_size", 17 if rect == NET_NAME_RECT_SM else 22)
			if not name_edit.has_focus() and name_edit.text != duel_my_name:
				name_edit.text = duel_my_name
			name_edit.editable = true
		elif name_edit.has_focus():
			name_edit.release_focus()
	if ip_edit != null:
		ip_edit.visible = want_ip
		if want_ip:
			ip_edit.position = NET_IP_RECT.position
			ip_edit.size = NET_IP_RECT.size
			ip_edit.add_theme_font_size_override("font_size", 24)
			if not ip_edit.has_focus() and ip_edit.text != join_ip:
				ip_edit.text = join_ip
			ip_edit.editable = true
		elif ip_edit.has_focus():
			ip_edit.release_focus()


func _on_name_changed(new_text: String) -> void:
	duel_my_name = new_text.left(12)
	if net_status == "ENTER A NAME FIRST" and _net_clean_name(duel_my_name) != "":
		net_status = ""


func _on_name_submitted(_text: String) -> void:
	if name_edit != null:
		name_edit.release_focus()
	_save_custom()


func _on_ip_changed(new_text: String) -> void:
	join_ip = new_text.left(64)


func _on_ip_submitted(text: String) -> void:
	_net_join(text)


func _on_name_focus(on: bool) -> void:
	name_focused = on


func _on_ip_focus(on: bool) -> void:
	join_focused = on


func _on_name_editable(visible: bool) -> void:
	if name_edit != null:
		name_edit.editable = true


func _on_ip_editable(visible: bool) -> void:
	if ip_edit != null:
		ip_edit.editable = true


## Drops focus from both net fields without hiding them (they hide
## themselves next frame if the screen no longer wants them).
func _release_net_edits() -> void:
	name_focused = false
	join_focused = false
	if name_edit != null and name_edit.has_focus():
		name_edit.release_focus()
	if ip_edit != null and ip_edit.has_focus():
		ip_edit.release_focus()


## QR card docked to the right of the host panel. White backing keeps the
## code scannable against the dark lobby background.
func _draw_host_qr() -> void:
	if host_qr_tex == null:
		return
	var card := Rect2(958.0, 250.0, 172.0, 210.0)
	draw_rect(card.grow(4.0), Color(0.02, 0.05, 0.10, 0.85))
	draw_rect(card, Color(0.03, 0.07, 0.14, 0.92))
	draw_rect(card, Color(0.40, 0.72, 1.0, 0.35), false, 2.0)
	var qr := Rect2(973.0, 265.0, 142.0, 142.0)
	draw_rect(qr.grow(6.0), Color.WHITE)
	draw_texture_rect(host_qr_tex, qr, false)
	_text_center_at(Vector2(1044.0, 435.0), "SCAN TO JOIN", 13, DIM)


func _ball_total_skins() -> int:
	return BALL_SKINS.size() + BALL_FACE_PATHS.size()


func _ball_face_index() -> int:
	var i := ball_idx - BALL_SKINS.size()
	if i < 0 or i >= BALL_FACE_PATHS.size():
		return -1
	return i


func _ball_face_tex() -> Texture2D:
	return _skin_face_tex(ball_idx)


## Photo ball skins from res:// (*-modified.png). Loaded once; missing files
## simply leave that skin empty and the ball falls back to its color ring.
func _setup_ball_faces() -> void:
	ball_faces.clear()
	ball_face_cols.clear()
	for p in BALL_FACE_PATHS:
		if ResourceLoader.exists(p):
			var tex: Texture2D = load(p)
			ball_faces.append(tex)
			ball_face_cols.append(_face_accent(tex))
		else:
			ball_faces.append(null)
			ball_face_cols.append(WHITE)


## Accent color of a photo skin: mean opaque color sampled on a coarse grid
## so a 2k portrait costs the same as a thumbnail. Falls back to white.
func _face_accent(tex: Texture2D) -> Color:
	var img := tex.get_image()
	var w := img.get_width()
	var h := img.get_height()
	if w <= 0 or h <= 0:
		return WHITE
	var step := maxi(1, mini(w, h) / 32)
	var r := 0.0
	var gg := 0.0
	var b := 0.0
	var n := 0
	var y := 0
	while y < h:
		var x := 0
		while x < w:
			var c := img.get_pixel(x, y)
			if c.a >= 0.05:
				r += c.r
				gg += c.g
				b += c.b
				n += 1
			x += step
		y += step
	if n <= 0:
		return WHITE
	return Color(r / n, gg / n, b / n)


## Versus gun sprites from res://. Loaded once; a missing file leaves that
## gun's badge empty and the game falls back to colored rounds.
func _setup_duel_guns() -> void:
	duel_gun_texs.clear()
	for p in DUEL_GUN_PATHS:
		if p != "" and ResourceLoader.exists(p):
			var tex: Texture2D = load(p)
			duel_gun_texs.append(tex)
		else:
			duel_gun_texs.append(null)


## Gun badge: sprite scaled to fit a size x size box, centered. Nothing
## draws when the slot has no file, so art is optional, never fatal.
func _draw_gun_icon(gun: int, center: Vector2, size: float) -> void:
	if gun <= 0 or gun >= duel_gun_texs.size():
		return
	var tex: Texture2D = duel_gun_texs[gun]
	if tex == null:
		return
	var s := tex.get_size()
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var sc := size / maxf(s.x, s.y)
	draw_texture_rect(tex, Rect2(center - s * sc * 0.5, s * sc), false)


## Held gun: orbits its carrier, pointing along the aim with a 45-degree
## clockwise offset. The sprite rides at orbit radius and rotates
## with it, so it visibly revolves around the ball as aim moves.
func _draw_gun_orbit(gun: int, carrier: Vector2, aim_pos: Vector2, size: float) -> void:
	if gun <= 0 or gun >= duel_gun_texs.size():
		return
	var tex: Texture2D = duel_gun_texs[gun]
	if tex == null:
		return
	var s := tex.get_size()
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var d := aim_pos - carrier
	var ang := d.angle() if d.length_squared() > 1.0 else 0.0
	ang += PI / 4.0
	var center := carrier + Vector2.RIGHT.rotated(ang) * (BALL_R + 38.0)
	var sc := size / maxf(s.x, s.y)
	draw_set_transform(draw_org + center * cam_zoom, ang, Vector2(sc, sc) * cam_zoom)
	draw_texture(tex, -s * 0.5)
	draw_set_transform(draw_org, 0.0, Vector2(cam_zoom, cam_zoom))


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
	env.glow_hdr_threshold = 0.72
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
## In versus the danger is our own hurt: the lower our hull, the harder the
## frame closes in.
func _danger_level() -> float:
	if mode == "over":
		return 1.0
	if mode != "play":
		return 0.2
	if net_mode != "off" and not duel_me.is_empty():
		if duel_over:
			return 1.0
		return clampf(1.0 - float(duel_me.get("hp", 100)) / 100.0, 0.0, 1.0)
	var near_lava := clampf((ball_pos.y - (_lava_top() - 760.0)) / 760.0, 0.0, 1.0)
	var low_time := 1.0 - clampf(time_left / START_TIME, 0.0, 1.0)
	return clampf(maxf(near_lava, low_time * 0.85), 0.0, 1.0)


## Bloom swells while charging, while chaining, while firing, and while in
## danger; the vignette closes in with the same danger, kicks with every
## bounce, kill and hit, and flares red at the edges.
func _update_post_fx(dt: float) -> void:
	var danger := _danger_level()
	if glow_env != null:
		glow_env.glow_enabled = glow_opt
		var target := 0.5
		if mode == "play":
			target += 0.8 * (clampf(charge_t / CHARGE_TIME, 0.0, 1.0) if charging else 0.0)
			target += 0.08 * minf(combo, 8)
			target += 0.6 * danger
		elif mode == "title":
			target = 0.5 + 0.12 * sin(t * 1.7)
		bloom_level = lerpf(bloom_level, clampf(target, 0.15, 2.2), 1.0 - exp(-6.0 * dt))
		glow_env.glow_intensity = bloom_level
		glow_env.glow_bloom = 0.10 + bloom_level * 0.14
		glow_env.glow_strength = 0.9 + bloom_level * 0.6
	vignette_t = lerpf(vignette_t, danger, 1.0 - exp(-5.0 * dt))
	vignette_pulse = maxf(0.0, vignette_pulse - dt * 1.8)


func _draw_vignette() -> void:
	if vignette_tex == null:
		return
	var charge := clampf(charge_t / CHARGE_TIME, 0.0, 1.0) if charging else 0.0
	# Play runs a heavier frame than the menus so the darkening reads in game.
	var base := 0.66 if mode == "play" else 0.44
	var heat := clampf(vignette_t + vignette_pulse * 0.6, 0.0, 1.0)
	var strength := base + 0.42 * vignette_t + 0.18 * charge + vignette_pulse
	var tint := Color(0.0, 0.0, 0.03).lerp(Color(0.55, 0.06, 0.10), heat)
	draw_texture_rect(vignette_tex, Rect2(Vector2.ZERO, VIEW), false,
		Color(tint.r, tint.g, tint.b, clampf(strength, 0.0, 0.98)))


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
		ball_idx = clampi(int(cfg.get_value("custom", "ball", 0)), 0, _ball_total_skins() - 1)
		trail_opt = bool(cfg.get_value("custom", "trail", true))
		shake_opt = bool(cfg.get_value("custom", "shake", true))
		glow_opt = bool(cfg.get_value("custom", "glow", true))
		muted = bool(cfg.get_value("custom", "muted", false))
		duel_my_name = _net_clean_name(str(cfg.get_value("custom", "name", "")))
	mobile_controls = _is_mobile()
	cfg.set_value("custom", "mobile", mobile_controls)


func _save_custom() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://bounce_back.cfg")
	cfg.set_value("custom", "ball", ball_idx)
	cfg.set_value("custom", "trail", trail_opt)
	cfg.set_value("custom", "shake", shake_opt)
	cfg.set_value("custom", "glow", glow_opt)
	cfg.set_value("custom", "mobile", mobile_controls)
	cfg.set_value("custom", "muted", muted)
	cfg.set_value("custom", "name", duel_my_name)
	cfg.save("user://bounce_back.cfg")


func _is_mobile() -> bool:
	return OS.has_feature("web") or OS.get_name() == "Android" or OS.get_name() == "iOS"


## Skin helpers by index, so the customize carousel can preview neighbours.
func _skin_face_tex(idx: int) -> Texture2D:
	var i := idx - BALL_SKINS.size()
	if i < 0 or i >= ball_faces.size():
		return null
	return ball_faces[i] as Texture2D


func _skin_col(idx: int) -> Color:
	if idx - BALL_SKINS.size() >= 0:
		var i := idx - BALL_SKINS.size()
		if i >= 0 and i < ball_face_cols.size():
			return ball_face_cols[i]
		return WHITE
	return BALL_SKINS[clampi(idx, 0, BALL_SKINS.size() - 1)]


func _skin_name(idx: int) -> String:
	if idx < BALL_SKINS.size():
		return str(BALL_NAMES[clampi(idx, 0, BALL_NAMES.size() - 1)])
	var i := idx - BALL_SKINS.size()
	if i >= 0 and i < BALL_FACE_NAMES.size():
		return str(BALL_FACE_NAMES[i])
	return "?"


func _cycle_ball(dir: int) -> void:
	var n := _ball_total_skins()
	ball_idx = (ball_idx + dir + n) % n
	custom_slide_dir = signi(dir)
	custom_swap_t = t
	_save_custom()
	_sfx("bounce", 0.0, -18.0)


func _ball_col() -> Color:
	return _skin_col(ball_idx)


func _ball_hot() -> Color:
	var c := _ball_col()
	return Color(minf(c.r * 1.6 + 0.15, 2.2), minf(c.g * 1.6 + 0.15, 2.2), minf(c.b * 1.6 + 0.15, 2.2))


## Smiley face drawn over color balls: two eyes plus a smile arc.
## Dark ink so it reads on every skin, including VERITY yellow.
func _draw_smiley(center: Vector2, r: float, alpha: float = 1.0) -> void:
	var ink := Color(0.06, 0.09, 0.16, 0.88 * alpha)
	var er := r * 0.13
	draw_circle(center + Vector2(-r * 0.32, -r * 0.14), er, ink)
	draw_circle(center + Vector2(r * 0.32, -r * 0.14), er, ink)
	draw_arc(center + Vector2(0.0, r * 0.06), r * 0.46, PI * 0.15, PI * 0.85, 24, ink, maxf(2.0, r * 0.09), true)


## Touch tap in a menu: same button as a mouse click, so the whole menu
## stack (including the mobile-controls checkbox) works without a mouse.
func _menu_tap(pos: Vector2) -> void:
	if mode == "title":
		if TITLE_PLAY.has_point(pos):
			_start_game()
		elif TITLE_CUSTOM.has_point(pos):
			custom_from = ""
			mode = "custom"
		elif TITLE_SETTINGS.has_point(pos):
			mode = "settings"
		elif TITLE_MULTI.has_point(pos):
			mode = "net"
			net_screen = "menu"
			net_status = ""
			_release_net_edits()
		elif TITLE_QUIT.has_point(pos):
			if OS.has_feature("web"):
				mode = "how"
			else:
				get_tree().quit()
		elif TITLE_HOW.has_point(pos):
			mode = "how"
	elif mode == "how":
		if BTN_BACK.has_point(pos):
			mode = "title"
	elif mode == "custom":
		_custom_click(pos)
	elif mode == "settings":
		_settings_click(pos)
	elif mode == "net":
		_net_click(pos)
	elif mode == "over":
		if net_mode == "off":
			_start_game()


## Where BACK leaves CUSTOMIZE: the title menu, or the multiplayer join
## screen when CUSTOMIZE was opened from there. Picking a skin on that
## detour also returns straight to multiplayer with the choice saved.
func _custom_back() -> void:
	if custom_from == "net":
		custom_from = ""
		mode = "net"
	else:
		mode = "title"


func _custom_click(mp: Vector2) -> void:
	if BTN_BACK.has_point(mp):
		_custom_back()
		return
	if CUSTOM_ARROW_L.has_point(mp) or CUSTOM_GHOST_L.has_point(mp):
		_cycle_ball(-1)
		if custom_from == "net":
			_custom_back()
		return
	if CUSTOM_ARROW_R.has_point(mp) or CUSTOM_GHOST_R.has_point(mp):
		_cycle_ball(1)
		if custom_from == "net":
			_custom_back()
		return


## Settings screen: main-menu button that opens its own screen. Owns every
## toggle (mobile controls, trail, shake, glow, sound); CUSTOMIZE only
## picks the skin. Touch and mouse users alike find it from the main menu.
func _settings_row_rect(i: int) -> Rect2:
	return Rect2(380.0, 230.0 + float(i) * 60.0, 520.0, 48.0)


func _settings_on(i: int) -> bool:
	match i:
		0:
			return mobile_controls
		1:
			return trail_opt
		2:
			return shake_opt
		3:
			return glow_opt
		4:
			return not muted
	return true


func _settings_toggle(i: int) -> void:
	match i:
		0:
			mobile_controls = not mobile_controls
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


func _settings_click(mp: Vector2) -> void:
	if BTN_BACK.has_point(mp):
		mode = "title"
		return
	for i in SETTINGS_LABELS.size():
		if _settings_row_rect(i).has_point(mp):
			_settings_toggle(i)
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


## Host addresses with adapter names: [{copy, label}]. Virtual, VPN and
## pseudo adapters sort last so the first address is one a rival can reach.
func _net_host_addrs() -> Array:
	var cands: Array = []
	var order := 0
	if IP.has_method("get_local_interfaces"):
		for f in IP.get_local_interfaces():
			if not (f is Dictionary):
				continue
			var nm := str((f as Dictionary).get("friendly", (f as Dictionary).get("name", "")))
			var low := nm.to_lower()
			var bad := false
			for k in ["virtual", "vbox", "vmware", "vmnet", "docker", "wsl", "vethernet", "hyper-v", "vpn", "hamachi", "zerotier", "tailscale", "wireguard", "nordlynx", "tap-", "tun", "loopback", "pseudo", "bluetooth", "isatap", "teredo", "wan miniport", "direct", "ppp", "tunnel"]:
				if low.contains(k):
					bad = true
					break
			for a in (f as Dictionary).get("addresses", []):
				var s := str(a)
				if not s.contains(".") or s.contains(":") or s.begins_with("127."):
					continue
				var rank := 3 if bad else (2 if s.begins_with("169.254.") else (0 if _net_is_private(s) else 1))
				cands.append({"ip": s, "label": nm, "rank": rank, "order": order})
				order += 1
	if cands.is_empty():
		for a in IP.get_local_addresses():
			var s := str(a)
			if s.contains(".") and not s.contains(":") and not s.begins_with("127."):
				cands.append({"ip": s, "label": "", "rank": 0, "order": order})
			order += 1
	var out: Array = []
	var seen := {}
	# Browser rivals join with a ws:// URL; desktop ENet rivals use plain ip:port.
	var ws := net_transport == "ws" and net_mode == "host"
	for r in 4:
		for c in cands:
			if int((c as Dictionary)["rank"]) != r or seen.has(str((c as Dictionary)["ip"])):
				continue
			seen[str((c as Dictionary)["ip"])] = true
			if ws:
				out.append({"copy": "ws://%s:%d" % [str((c as Dictionary)["ip"]), NET_PORT], "label": str((c as Dictionary)["label"])})
			else:
				out.append({"copy": "%s:%d" % [str((c as Dictionary)["ip"]), NET_PORT], "label": str((c as Dictionary)["label"])})
	if out.is_empty():
		if ws:
			out.append({"copy": "ws://127.0.0.1:%d" % NET_PORT, "label": ""})
		else:
			out.append({"copy": "127.0.0.1:%d" % NET_PORT, "label": ""})
	return out


func _net_is_private(s: String) -> bool:
	if s.begins_with("10.") or s.begins_with("192.168."):
		return true
	if s.begins_with("172."):
		var tail := s.get_slice(".", 1)
		if tail.is_valid_int() and int(tail) >= 16 and int(tail) <= 31:
			return true
	return false


## Desktop hosts pick a link: enet (desktop rivals) or ws (websocket lobby
## that browser rivals can join). Browsers cannot listen, so hosting stays
## desktop-only; the websocket server speaks plain ws:// on NET_PORT.
## Name gate: hosting or joining needs a real display name first. Warns
## in the lobby status line and focuses the name box when blank; the caller
## returns without proceeding.
func _net_name_ok() -> bool:
	if _net_clean_name(duel_my_name) != "":
		return true
	net_status = "ENTER A NAME FIRST"
	if name_edit != null:
		name_edit.grab_focus()
	return false


func _net_host(transport: String = "enet") -> void:
	_net_leave_quiet()
	net_transport = "ws" if transport == "ws" else "enet"
	if net_transport == "ws":
		var wpeer := WebSocketMultiplayerPeer.new()
		if wpeer.create_server(NET_PORT) != OK:
			net_status = "HOST FAILED"
			return
		multiplayer.multiplayer_peer = wpeer
	else:
		var peer := ENetMultiplayerPeer.new()
		if peer.create_server(NET_PORT, DUEL_SERVER_PEERS) != OK:
			net_status = "HOST FAILED"
			return
		multiplayer.multiplayer_peer = peer
	net_mode = "host"
	net_screen = "host"
	_save_custom()
	_connect_net_signals()


func _net_join(ip: String) -> void:
	_net_leave_quiet()
	join_ip = ip.strip_edges()
	if join_ip == "":
		net_status = "ENTER AN IP FIRST"
		return
	# Committed: the field is gone, so its focus (and key repeat) ends here.
	join_focused = false
	_save_custom()
	# Websocket join when the field holds a ws:// or wss:// URL, when the
	# game runs in a browser (ENet cannot dial out there), or when the
	# join screen toggle picked ws. Plain "ip" / "ip:port" stay ENet.
	var low := join_ip.to_lower()
	var want_ws := net_transport == "ws" or OS.has_feature("web")
	var scheme := "ws"
	var had_ws_scheme := false
	var rest := join_ip
	if low.begins_with("ws://"):
		want_ws = true
		had_ws_scheme = true
		rest = join_ip.substr(5)
	elif low.begins_with("wss://"):
		want_ws = true
		scheme = "wss"
		had_ws_scheme = true
		rest = join_ip.substr(6)
	if want_ws:
		net_transport = "ws"
		var path := ""
		var cut := rest.length()
		for sep in ["/", "?", "#"]:
			var i := rest.find(sep)
			if i >= 0:
				cut = mini(cut, i)
		var hostport := rest
		if cut < rest.length():
			hostport = rest.substr(0, cut)
			path = rest.substr(cut)
		var whost := hostport
		var wport := NET_PORT
		var has_explicit_wport := false
		if hostport.begins_with("["):
			var close := hostport.find("]")
			if close > 0:
				var tail := hostport.substr(close + 1)
				if tail.begins_with(":"):
					var wmaybe6 := tail.substr(1)
					whost = hostport.substr(0, close + 1)
					if wmaybe6.is_valid_int():
						wport = clampi(wmaybe6.to_int(), 1, 65535)
						has_explicit_wport = true
		if hostport.count(":") == 1:
			var wcut := hostport.rfind(":")
			var wmaybe := hostport.substr(wcut + 1)
			if wmaybe.is_valid_int():
				whost = hostport.substr(0, wcut)
				wport = clampi(wmaybe.to_int(), 1, 65535)
				has_explicit_wport = true
		if whost.strip_edges() == "":
			net_status = "ENTER AN IP FIRST"
			return
		var authority := whost.strip_edges()
		# Keep explicit ports exactly as entered. For full ws:// or wss:// URLs,
		# preserve the scheme's default port unless one was given.
		if has_explicit_wport or not had_ws_scheme:
			authority = "%s:%d" % [authority, wport]
		var url := "%s://%s%s" % [scheme, authority, path]
		var wpeer := WebSocketMultiplayerPeer.new()
		if wpeer.create_client(url) != OK:
			net_status = "JOIN FAILED"
			return
		multiplayer.multiplayer_peer = wpeer
	else:
		net_transport = "enet"
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
	duel_walls = []
	net_status = ""
	_release_net_edits()
	duel_peer_names.clear()
	foe_score = 0
	foe_kills = 0
	net_count = 0.0
	net_timeout = 0.0


func _net_leave() -> void:
	_net_leave_quiet()
	_enter_title()


@rpc("authority", "call_remote", "reliable")
func _net_begin(roster: Array = [], names: Array = [], map_idx: int = -1) -> void:
	net_count = 3.0
	net_last_snap = t
	_net_toughen()
	foe_score = 0
	foe_kills = 0
	net_send_t = 0.0
	mode = "net"
	net_screen = "countdown"
	_duel_reset(roster, names, map_idx)
	_banner("3")


## Host START: spin the Fall-Guys-style map roulette instead of jumping
## straight in. Winner + seed fully determine the strip, so every peer
## animates the identical show from one reliable rpc.
func _net_roulette_start() -> void:
	if net_mode != "host":
		return
	roulette_win = randi() % _duel_map_count()
	roulette_seed = randi()
	_roulette_setup(roulette_win, roulette_seed)
	# Leave the "over" verdict: the roulette spin only ticks while mode is
	# "net", so without this the strip never moves and rematch stalls.
	mode = "net"
	net_screen = "roulette"
	_net_roulette.rpc(roulette_win, roulette_seed)


@rpc("authority", "call_remote", "reliable")
func _net_roulette(win: int, seed: int) -> void:
	if net_mode != "client":
		return
	_roulette_setup(win, seed)
	mode = "net"
	net_screen = "roulette"


func _roulette_setup(win: int, seed: int) -> void:
	var n := _duel_map_count()
	roulette_win = clampi(win, 0, n - 1)
	roulette_seed = seed
	roulette_t = ROULETTE_T
	roulette_tick = -1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	roulette_strip.clear()
	roulette_strip.append(rng.randi() % n)
	for i in ROULETTE_CARDS - 2:
		roulette_strip.append(rng.randi() % n)
	roulette_strip.append(roulette_win)
	roulette_stop = roulette_strip.size() - 1
	# Trail past the winner: the strip stops with maps still ahead of it,
	# so the landing reads as a random halt instead of the end of a list.
	for i in ROULETTE_TRAIL:
		roulette_strip.append(rng.randi() % n)


## Strip offset for the current spin time: fast scroll easing out so the
## winner lands centered with trail cards still ahead. Deterministic.
func _roulette_offset() -> float:
	var pr := clampf(1.0 - roulette_t / ROULETTE_T, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - pr, 3.0)
	return -float(maxi(roulette_stop, 0)) * ROULETTE_PITCH * e


func _roulette_center() -> int:
	if roulette_strip.is_empty():
		return 0
	return clampi(int(round(-_roulette_offset() / ROULETTE_PITCH)), 0, roulette_strip.size() - 1)


## One roulette card: map name over a scaled outline preview.
func _roulette_card(r: Rect2, mi: int, hot: bool) -> void:
	draw_rect(r, Color(0.03, 0.07, 0.14, 0.95))
	draw_rect(r, CYAN if hot else Color(0.42, 0.66, 1.0, 0.45), false, 3.0 if hot else 1.5)
	var maps := _duel_maps()
	var m: Dictionary = maps[clampi(mi, 0, maps.size() - 1)]
	_text_center_at(Vector2(r.get_center().x, r.position.y + 34.0), str(m.get("name", "?")), 20, WHITE if hot else DIM, bold_font)
	var ext: Vector2 = m.get("ext", Vector2(1.0, 1.0))
	var ctr: Vector2 = m.get("ctr", Vector2.ZERO)
	var sc := minf(250.0 / ext.x, 150.0 / ext.y)
	var org := Vector2(r.get_center().x, r.position.y + 200.0)
	for poly in m.get("polys", []):
		var pts := PackedVector2Array()
		for q in (poly as Array):
			pts.append(org + ((q as Vector2) - ctr) * sc)
		if pts.size() < 3:
			continue
		draw_colored_polygon(pts, Color(0.10, 0.22, 0.34, 0.9))
		pts.append(pts[0])
		draw_polyline(pts, Color(0.45, 0.85, 1.0, 0.9), 2.0, true)


## Arcade-cabinet names: short, uppercase, letters/digits/space/_/- only.
func _net_clean_name(s: String) -> String:
	var keep := ""
	var up := s.strip_edges().to_upper()
	for i in up.length():
		var c := up.substr(i, 1)
		if (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == " " or c == "_" or c == "-":
			keep += c
	return keep.strip_edges().left(12)


## Display names parallel to a roster: mine from the name box, rivals from
## their hellos. Blanks stay blank; draw code falls back to YOU/FOE labels.
func _duel_match_names(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		if int(id) == multiplayer.get_unique_id():
			out.append(_net_clean_name(duel_my_name))
		else:
			out.append(_net_clean_name(str(duel_peer_names.get(int(id), ""))))
	return out


## Pre-start lobby roster for the host: every fighter in arena order (host
## first when fighting, then peers ascending) with display names. Peers
## that connected but haven't said hello yet read as JOINING. Caps at
## max_rows with a "+N MORE" tail; redrawn every frame so joins and late
## hellos appear live.
func _draw_lobby_roster(x: float, y0: float, max_rows: int = 5) -> void:
	var ids := _duel_roster()
	var names := _duel_match_names(ids)
	var me := multiplayer.get_unique_id()
	var shown := mini(ids.size(), max_rows)
	for i in shown:
		var mine := int(ids[i]) == me
		var nm := str(names[i])
		if mine:
			nm = (nm if nm != "" else "YOU") + " (HOST)"
		elif nm == "":
			nm = "JOINING..."
		_text_center_at(Vector2(x, y0 + float(i) * 26.0), nm, 20, CYAN if mine else WHITE, bold_font)
	if ids.size() > shown:
		_text_center_at(Vector2(x, y0 + float(shown) * 26.0), "+%d MORE" % (ids.size() - shown), 16, DIM)


## Client -> host: my display name, sent once on connect. The host files it
## by peer id and bakes it into the roster names at match start.
@rpc("any_peer", "call_remote", "reliable")
func _net_hello(nm: String) -> void:
	if net_mode != "host":
		return
	duel_peer_names[multiplayer.get_remote_sender_id()] = _net_clean_name(nm)


## Ordered peer-id roster for the match: host first, then clients ascending.
## Every connected peer fights: host first, then clients ascending. No cap.
func _duel_roster() -> Array:
	# A spectating host stays out of the fighter order; the arena is peers only.
	var ids: Array = []
	if duel_host_plays:
		ids.append(multiplayer.get_unique_id())
	var peers := multiplayer.get_peers()
	peers.sort()
	ids.append_array(peers)
	return ids


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
	return {"pos": pos, "vel": Vector2.ZERO, "hp": DUEL_HP, "gun": 0, "cd": 0.0, "slam": 0.0, "ready": true, "gone": false, "spike": 0.0, "lava": 0.0, "name": ""}


## Roster order decides everything: index 0 is the host, the rest are client
## peer ids ascending. Spawn spots ring the center so 2-4 fighters never
## overlap. duel_me aliases my dict; duel_foes holds every rival in order.
func _duel_reset(roster: Array = [], names: Array = [], map_idx: int = -1) -> void:
	if roster.is_empty():
		roster = _duel_roster()
	if names.size() < roster.size():
		names = _duel_match_names(roster)
	duel_ids = roster
	# find() misses when the host sits out: my_id -1 means spectator, no fighter.
	if map_idx < 0:
		map_idx = randi() % _duel_map_count()
	_duel_build_map(map_idx)
	duel_my_id = duel_ids.find(multiplayer.get_unique_id())
	var n := duel_ids.size()
	var c := WORLD.get_center()
	var all: Array = []
	for i in n:
		var ang := TAU * float(i) / float(maxi(n, 1)) - PI * 0.5
		var nf := _duel_fighter(_duel_clear_spot(c + Vector2(cos(ang), sin(ang)) * 650.0, BALL_R + 12.0))
		nf["name"] = str(names[i]) if i < names.size() else ""
		all.append(nf)
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
	stick_mouse = false
	var offs := [Vector2(-260.0, -160.0), Vector2(260.0, -160.0), Vector2(-260.0, 160.0), Vector2(260.0, 160.0), Vector2(0.0, -340.0), Vector2(0.0, 340.0)]
	for k in (4 if n <= 2 else 6):			duel_chests.append({"pos": _duel_clear_spot(c + offs[k], 70.0), "hp": DUEL_CHEST_HP, "gun": 1 + randi() % 4})
	duel_chest_max = (4 if n <= 2 else 6) + 2
	duel_chest_t = DUEL_CHEST_RESPAWN_T
	duel_snap_t = 0.0
	duel_snap_seq = 0
	duel_last_seq = -1
	duel_balls_synced = false
	duel_launch_echo = 0
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
		_net_roulette_start()


## Client -> host: my launch impulse. Host owns every client fighter and
## maps the sender id to its roster slot. Unreliable on purpose: inputs must
## never stall behind a retransmit. The client echoes each launch twice, and
## the ready-gate below makes repeats free: the first one lands, the rest
## are ignored, so at most one launch ever applies.
@rpc("any_peer", "call_remote", "unreliable")
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
## Unreliable like the launch: the gun refires every 0.35-0.6 s, so a dropped
## packet costs one shot, while a retransmit stall would cost every shot.
@rpc("any_peer", "call_remote", "unreliable")
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
## roster order as [pos, vel, hp, gun, ready] each; bullets/chests/pickups
## ride packed flat (numbers only, no key strings); balls ride every 2nd
## snap with drifter velocities; the trailing seq stamps the order.
## I reconcile my slot, glide every rival toward its sample, and glide
## drifters myself between snaps.
@rpc("authority", "call_remote", "unreliable")
func _net_duel(state: Array) -> void:
	if net_mode != "client" or mode != "play":
		return
	net_last_snap = t
	# Out-of-order snapshot: the newer one already applied, ignore this.
	var seq := int(state[6]) if state.size() > 6 else 0
	if seq <= duel_last_seq:
		return
	duel_last_seq = seq
	var fighters: Array = state[0]
	for i in range(mini(fighters.size(), duel_ids.size())):
		var fd: Array = fighters[i]
		if fd.size() < 5:
			continue
		if i == duel_my_id:
			var old_hp := int(duel_me.get("hp", 0))
			var mp: Vector2 = fd[0]
			# Prediction now mirrors the host sim, so ease gently toward
			# each sample; only a true desync still snaps.
			if mp.distance_to(duel_me["pos"]) > 400.0:
				duel_me["pos"] = mp
			else:
				duel_me["pos"] = (duel_me["pos"] as Vector2).lerp(mp, 0.2)
			duel_me["vel"] = fd[1]
			duel_me["hp"] = fd[2]
			duel_me["gun"] = fd[3]
			duel_me["ready"] = fd[4]
			_duel_client_hurt_fx(duel_me["pos"], old_hp, int(fd[2]), true)
			shot_ready = bool(duel_me["ready"])
			# The host applied our launch: its echo job is done.
			if not bool(duel_me["ready"]):
				duel_launch_echo = 0
		else:
			var o := i if i < duel_my_id else i - 1
			if o < 0 or o >= duel_foes.size():
				continue
			var f: Dictionary = duel_foes[o]
			var f_old := int(f.get("hp", 0))
			var new_goal: Vector2 = fd[0]
			if new_goal.distance_to(f["pos"]) > 220.0:
				f["pos"] = new_goal
			duel_foe_goals[o] = new_goal
			f["vel"] = fd[1]
			f["hp"] = fd[2]
			f["gun"] = fd[3]
			f["ready"] = fd[4]
			_duel_client_hurt_fx(f["pos"], f_old, int(fd[2]), false)
	if not duel_foes.is_empty():
		duel_foe = duel_foes[0]
		duel_foe_goal = duel_foe_goals[0]
	if duel_was_alive and int(duel_me.get("hp", 0)) <= 0:
		duel_was_alive = false
		charging = false
		charge_t = 0.0
		stick_on = false
		stick_mouse = false
		_banner("ELIMINATED")
	# Bullets fly ~1900 px/s, so adopting the 20 Hz snapshot raw would
	# teleport them ~95 px per snap on the joiner's screen. Match each
	# incoming bullet to the one already gliding locally (same owner +
	# velocity; both sides extrapolate with it) and correct only halfway:
	# steady-state drift is ~zero, so the lerp eats network jitter instead
	# of flashing it. Newly spawned bullets have no match and land exact.
	# Unpack the flat bullet wire format back into sim dicts.
	var bf2: Array = state[1]
	var fresh: Array = []
	for i in range(0, bf2.size(), 8):
		if i + 7 >= bf2.size():
			break
		fresh.append({"pos": Vector2(float(bf2[i]), float(bf2[i + 1])), "vel": Vector2(float(bf2[i + 2]), float(bf2[i + 3])), "owner": int(bf2[i + 4]), "life": float(bf2[i + 5]), "dmg": int(bf2[i + 6]), "kind": int(bf2[i + 7]), "hit": []})
	var old_bl: Array = duel_bullets
	var smooth: Array = []
	var used: Array = []
	var new_shots := false
	for nb in fresh:
		var nd: Dictionary = nb
		var found := -1
		for oi in old_bl.size():
			if used.has(oi):
				continue
			var ob: Dictionary = old_bl[oi]
			if int(ob.get("owner", -9)) == int(nd.get("owner", -9)) and int(ob.get("kind", 0)) == int(nd.get("kind", 0)) and (ob["vel"] as Vector2).distance_squared_to(nd["vel"] as Vector2) < 1.0:
				found = oi
				break
		if found < 0:
			# Same-frame aim from a slightly desynced fighter: velocity can
			# miss by a hair while the bullet is clearly ours. Fall back to
			# the nearest same-owner ghost inside 120 px so predicted shots
			# never double up.
			var near := -1
			var near_d2 := 14400.0
			for oi2 in old_bl.size():
				if used.has(oi2):
					continue
				var ob4: Dictionary = old_bl[oi2]
				if int(ob4.get("owner", -9)) != int(nd.get("owner", -9)) or int(ob4.get("kind", 0)) != int(nd.get("kind", 0)):
					continue
				var dd3: float = (ob4["pos"] as Vector2).distance_squared_to(nd["pos"] as Vector2)
				if dd3 < near_d2:
					near_d2 = dd3
					near = oi2
			found = near
		if found >= 0:
			used.append(found)
			var ob2: Dictionary = old_bl[found]
			smooth.append({"pos": (ob2["pos"] as Vector2).lerp(nd["pos"], 0.5), "vel": nd["vel"], "owner": nd["owner"], "life": nd["life"], "dmg": nd["dmg"], "kind": nd.get("kind", 0), "hit": []})
		else:
			# Someone else just pulled the trigger: flash its muzzle the way
			# the shooter's screen does. Our own predicted shots always
			# match above, so they never double-flash here.
			var np: Vector2 = nd["pos"]
			_burst(np, GOLD, 4, 140.0)
			new_shots = true
			smooth.append(nd)
	if new_shots:
		_sfx("shoot_low", 0.0, -10.0)
	# A bullet the host dropped mid-flight with life left hit something.
	# Its burst only shows on the host screen, so replay it here instead.
	for oi in old_bl.size():
		if used.has(oi):
			continue
		var ob3: Dictionary = old_bl[oi]
		var op: Vector2 = ob3["pos"]
		if float(ob3.get("life", 0.0)) > 0.0 and op.x > WORLD.position.x and op.x < WORLD.end.x and op.y > WORLD.position.y and op.y < _lava_top():
			_burst(op, PINK, 8, 200.0)
			_ring(op, PINK, 8, 220.0)
			if op.distance_to(ball_pos) < 700.0:
				shake = maxf(shake, 3.0)
	duel_bullets = smooth
	# Chests never move, so a missing old one broke and a missing new one
	# just dropped in: replay both, same as the host sees in its sim.
	var cf2: Array = state[2]
	var new_chests: Array = []
	for i in range(0, cf2.size(), 4):
		if i + 3 >= cf2.size():
			break
		new_chests.append({"pos": Vector2(float(cf2[i]), float(cf2[i + 1])), "hp": int(cf2[i + 2]), "gun": int(cf2[i + 3])})
	if not duel_chests.is_empty():
		for ch in duel_chests:
			var cp: Vector2 = ch["pos"]
			var gone := true
			for nc in new_chests:
				if ((nc as Dictionary)["pos"] as Vector2).distance_to(cp) < 1.0:
					gone = false
					break
			if gone:
				_burst(cp, GOLD, 14, 260.0)
				_ring(cp, GOLD, 12, 240.0)
				if cp.distance_to(ball_pos) < 700.0:
					shake = maxf(shake, 6.0)
				_sfx("bump", 0.0, -12.0)
		for nc2 in new_chests:
			var np: Vector2 = (nc2 as Dictionary)["pos"]
			var is_new := true
			for ch2 in duel_chests:
				if ((ch2 as Dictionary)["pos"] as Vector2).distance_to(np) < 1.0:
					is_new = false
					break
			if is_new:
				_ring(np, GOLD, 10, 200.0)
	duel_chests = new_chests
	var pf2: Array = state[3]
	var new_pickups: Array = []
	for i in range(0, pf2.size(), 3):
		if i + 2 >= pf2.size():
			break
		new_pickups.append({"pos": Vector2(float(pf2[i]), float(pf2[i + 1])), "kind": int(pf2[i + 2])})
	duel_pickups = new_pickups
	time_left = state[4]
	var flat: Array = state[5]
	if flat.is_empty():
		return
	# Drifters glide client-side now: the host ships their velocities and
	# each snapshot only reconciles - the same ball keeps moving locally
	# and the sample just nudges it, like bullets and rival fighters.
	var slot_vel := {}
	var dv: Array = state[7] if state.size() > 7 else []
	for i in range(0, dv.size(), 3):
		if i + 2 >= dv.size():
			break
		slot_vel[int(dv[i])] = Vector2(float(dv[i + 1]), float(dv[i + 2]))
	# First sync adopts silently: both sides scattered independently,
	# so nothing was actually smashed.
	var first_sync := not duel_balls_synced
	duel_balls_synced = true
	var kept: Array = []
	var used_tg := {}
	var slot := -1
	for i in range(0, flat.size(), 4):
		if i + 3 >= flat.size():
			break
		slot += 1
		var ipos := Vector2(float(flat[i]), float(flat[i + 1]))
		var irad := float(flat[i + 2])
		var ikind := "armored" if int(flat[i + 3]) == 2 else ("drifter" if int(flat[i + 3]) == 1 else "basic")
		var best := -1
		var best_d2 := 1600.0
		for oi in targets.size():
			if used_tg.has(oi):
				continue
			var ot = targets[oi]
			if ot.kind != ikind:
				continue
			var dd2: float = ot.pos.distance_squared_to(ipos)
			if dd2 < best_d2:
				best_d2 = dd2
				best = oi
		if best >= 0:
			used_tg[best] = true
			var et = targets[best]
			if et.pos.distance_to(ipos) > 150.0:
				et.pos = ipos
			else:
				et.pos = et.pos.lerp(ipos, 0.5)
			if slot_vel.has(slot):
				et.vel = slot_vel[slot]
			et.radius = irad
			kept.append(et)
		else:
			var tg := Target.new()
			tg.pos = ipos
			tg.radius = irad
			tg.tame = true
			# New balls fade in like solo spawns; spike rotation stays
			# index-derived so no rotation state is tracked or sent.
			tg.age = 1.0
			tg.phase = fmod(float(slot) * 2.399963, TAU)
			if ikind == "armored":
				tg.kind = "armored"
				tg.color = GOLD
				tg.req = DUEL_SPIKE_REQ
			elif ikind == "drifter":
				tg.kind = "drifter"
				tg.color = GREEN
				tg.vel = slot_vel.get(slot, Vector2.ZERO)
			else:
				tg.kind = "basic"
				tg.color = PINK
			kept.append(tg)
	# A ball the host dropped is a smash: replay it with the same burst +
	# ring solo gets.
	if not first_sync:
		for oi in targets.size():
			if used_tg.has(oi):
				continue
			var ot2 = targets[oi]
			var sp: Vector2 = ot2.pos
			var sc := PINK
			if ot2.kind == "drifter":
				sc = GREEN
			elif ot2.kind == "armored":
				sc = GOLD
			_burst(sp, sc, 12, 280.0)
			_ring(sp, sc, 8, 220.0)
			_shards(sp, Vector2.ZERO, sc, 8, 470.0, 0.5)
			hitstop = maxf(hitstop, 0.04)
			if sp.distance_to(ball_pos) < 700.0:
				shake = maxf(shake, 4.0)
				_sfx("kill", 0.08, -12.0)
	targets = kept


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
	bloom_level = maxf(bloom_level, 1.8)
	vignette_pulse = minf(vignette_pulse + 0.6, 0.9)
	_ring(ball_pos, PINK, 18, 320.0)
	shake = maxf(shake, 14.0)
	_sfx("over", 0.0, -4.0)


func _on_net_peer_connected(id: int) -> void:
	if net_mode == "host" and (net_screen == "host" or net_screen == "ready"):
		net_screen = "ready"
	_net_toughen()


func _on_net_connected_to_server() -> void:
	if net_mode == "client":
		net_screen = "ready"
		net_status = ""
		net_timeout = 0.0
		_net_toughen()
		_net_hello.rpc_id(1, duel_my_name)


## Give ENet room to ride out WiFi hiccups before calling a peer dead:
## same 32-strike limit, but 15s before the backoff gives up (was 5s) and a
## 60s hard cap on any unacked reliable packet (was 30s). Re-applying to an
## already-toughened peer is harmless, so both connect and match start call it.
func _net_toughen() -> void:
	var mp := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if mp == null:
		return
	var host: ENetConnection = mp.get_host()
	if host == null:
		return
	for p in host.get_peers():
		if p is ENetPacketPeer and (p as ENetPacketPeer).is_active():
			(p as ENetPacketPeer).set_timeout(32, 15000, 60000)


## Round-trip ms to the first ENet peer, or -1 when there is no live link.
func _net_rtt_ms() -> int:
	var mp := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if mp == null:
		return -1
	var host: ENetConnection = mp.get_host()
	if host == null:
		return -1
	for p in host.get_peers():
		if p is ENetPacketPeer and (p as ENetPacketPeer).is_active():
			return int((p as ENetPacketPeer).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
	return -1


func _on_net_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	net_mode = "off"
	net_timeout = 0.0
	if OS.has_feature("web") and net_transport == "ws":
		net_status = "CONNECTION FAILED - USE http:// PAGE FOR ws:// LINKS"
	else:
		net_status = "CONNECTION FAILED - CHECK IP & FIREWALL"


func _on_net_server_disconnected() -> void:
	if net_mode == "client":
		_net_leave()
		_banner("HOST DISCONNECTED")


func _on_net_peer_disconnected(id: int) -> void:
	duel_peer_names.erase(id)
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
	if net_screen == "countdown" or net_screen == "roulette":
		return
	if BTN_BACK.has_point(mp):
		_net_leave()
		return
	if net_screen == "menu":
		if name_edit != null and NET_NAME_RECT.has_point(mp):
			name_edit.grab_focus()
			return
		if not OS.has_feature("web") and BTN_NET_HOST.has_point(mp):
			if not _net_name_ok():
				return
			_release_net_edits()
			_net_host("enet")
		elif not OS.has_feature("web") and BTN_NET_HOST_WS.has_point(mp):
			if not _net_name_ok():
				return
			_release_net_edits()
			_net_host("ws")
		elif BTN_NET_JOIN.has_point(mp):
			if not _net_name_ok():
				return
			_release_net_edits()
			net_screen = "join"
			if OS.has_feature("web"):
				net_transport = "ws"
		else:
			name_focused = false
	elif net_screen == "host" and net_mode == "host":
		if name_edit != null and NET_NAME_RECT_SM.has_point(mp):
			name_edit.grab_focus()
			return
		for e in net_ip_rects:
			if (e["rect"] as Rect2).has_point(mp):
				DisplayServer.clipboard_set(str(e.get("copy", e.get("text", ""))))
				net_copied_at = t
				return
		if BTN_NET_ROLE.has_point(mp):
			duel_host_plays = not duel_host_plays
	elif net_screen == "join":
		if name_edit != null and NET_NAME_RECT.has_point(mp):
			name_edit.grab_focus()
			return
		if ip_edit != null and NET_IP_RECT.has_point(mp):
			ip_edit.grab_focus()
			return
		_release_net_edits()
		if BTN_NET_CUSTOM.has_point(mp):
			custom_from = "net"
			mode = "custom"
		elif not OS.has_feature("web") and BTN_NET_PROTO.has_point(mp):
			net_transport = "ws" if net_transport == "enet" else "enet"
		elif BTN_NET_JOIN.has_point(mp):
			if not _net_name_ok():
				return
			_net_join(join_ip)
	elif net_screen == "ready" and net_mode == "host":
		if name_edit != null and NET_NAME_RECT_SM.has_point(mp):
			name_edit.grab_focus()
			return
		if BTN_NET_ROLE2.has_point(mp):
			duel_host_plays = not duel_host_plays
		elif BTN_START.has_point(mp):
			_release_net_edits()
			_net_roulette_start()
	elif net_screen == "ready":
		if name_edit != null and NET_NAME_RECT_SM.has_point(mp):
			name_edit.grab_focus()


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
		if st.pressed and mode != "play":
			_menu_tap(st.position)
			return
		if st.pressed:
			# Fixed joystick owns its zone in versus when mobile controls are on:
			# a press there is stick-only and never starts a bounce charge.
			if mobile_controls and mode == "play" and net_mode != "off" and not duel_over and st.position.distance_to(STICK_HOME) <= STICK_GRAB:
				if int(duel_me.get("hp", 0)) > 0:
					if not stick_on:
						_stick_take(STICK_HOME, st.position, st.index, false)
					elif st.index == stick_id:
						stick_knob = st.position
				# This finger can never be the aim finger: drop it silently
				# so lifting it does not fire a bounce.
				if st.index == touch_aim_id:
					touch_aim_id = -1
				return
			if touch_aim_id == -1:
				touch_aim_id = st.index
				mouse_pos = _touch_pos(st.position)
				if mode == "play":
					_begin_charge()
			elif not stick_on and not mobile_controls and mode == "play" and net_mode != "off" and not duel_over and int(duel_me.get("hp", 0)) > 0:
				stick_on = true
				stick_id = st.index
				stick_mouse = false
				stick_base = st.position
				stick_knob = st.position
		else:
			# Joystick release has priority: it never fires a bounce, even if
				# the same index somehow also matches the aim finger.
			var was_stick := st.index == stick_id
			if was_stick:
				stick_on = false
				stick_id = -1
				stick_mouse = false
			if st.index == touch_aim_id:
				touch_aim_id = -1
				if mode == "play" and not was_stick:
					_fire()
		return
	var dr := event as InputEventScreenDrag
	if dr:
		if dr.index == stick_id and stick_on:
			stick_knob = dr.position
			return
		if dr.index == touch_aim_id:
			mouse_pos = _touch_pos(dr.position)
			mouse_seen = true
		return
	var mm := event as InputEventMouseMotion
	if mm:
		mouse_seen = true
		if stick_mouse and stick_on:
			stick_knob = mm.position
		return

	var mb := event as InputEventMouseButton
	if mb and not mb.pressed and stick_mouse and mb.button_index == MOUSE_BUTTON_LEFT:
		stick_on = false
		stick_id = -1
		stick_mouse = false
		return
	if (touch_aim_id >= 0 or stick_on) and (mb and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT)):
		return
	if mb and mb.button_index == MOUSE_BUTTON_RIGHT:
		if mb.pressed and mode == "play" and net_mode != "off":
			_duel_try_fire(mouse_pos)
		return
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			if mode == "play":
				# Same priority for the mouse: the fixed joystick zone never
				# starts a bounce charge, even while the stick is held.
				if mobile_controls and net_mode != "off" and not duel_over and mb.position.distance_to(STICK_HOME) <= STICK_GRAB:
					if int(duel_me.get("hp", 0)) > 0 and not stick_on:
						_stick_take(STICK_HOME, mb.position, -2, true)
					return
				_begin_charge()
			elif mode == "title":
				if TITLE_PLAY.has_point(mb.position):
					_start_game()
				elif TITLE_CUSTOM.has_point(mb.position):
					custom_from = ""
					mode = "custom"
				elif TITLE_SETTINGS.has_point(mb.position):
					mode = "settings"
				elif TITLE_MULTI.has_point(mb.position):
					mode = "net"
					net_screen = "menu"
					net_status = ""
					# No autofocus: the player taps the name box, which pops
					# the mobile keyboard only when actually wanted.
					_release_net_edits()
				elif TITLE_QUIT.has_point(mb.position):
					if OS.has_feature("web"):
						mode = "how"
					else:
						get_tree().quit()
				elif TITLE_HOW.has_point(mb.position):
					mode = "how"
			elif mode == "how":
				if BTN_BACK.has_point(mb.position):
					mode = "title"
			elif mode == "custom":
				_custom_click(mb.position)
			elif mode == "settings":
				_settings_click(mb.position)
			elif mode == "net":
				_net_click(mb.position)
			elif mode == "over":
				if net_mode == "off":
					_start_game()
		else:
			_fire()
		return
	var key := event as InputEventKey
	# A focused LineEdit eats its keys first, so shortcuts check focus and
	# stay out of the way while typing. Shortcuts never repeat on echo.
	var typing := mode == "net" and ((name_edit != null and name_edit.has_focus()) or (ip_edit != null and ip_edit.has_focus()))
	# Letting go of space releases a held charge, mirroring the mouse.
	if key and not key.pressed and key.keycode == KEY_SPACE and charging and mode == "play":
		_fire()
	if key and key.pressed and (not key.echo or typing):
		if (net_mode != "off" or mode == "net") and key.pressed:
			if key.keycode == KEY_ESCAPE:
				get_tree().quit()
			elif typing:
				pass
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
					_net_roulette_start()
				else:
					_net_restart_request.rpc_id(1)
			elif key.keycode == KEY_F and mode == "play":
				_duel_try_fire(mouse_pos)
		if mode == "play" and key.keycode == KEY_SPACE:
			# Armed in versus: space fires the held gun. Otherwise it
			# charges/releases a launch exactly like the mouse button.
			if net_mode != "off" and int(duel_me.get("gun", 0)) > 0:
				_duel_try_fire(mouse_pos)
			elif not charging:
				_begin_charge()
			else:
				_fire()
		if mode == "custom":
			if key.keycode == KEY_LEFT:
				_cycle_ball(-1)
				if custom_from == "net":
					_custom_back()
			elif key.keycode == KEY_RIGHT:
				_cycle_ball(1)
				if custom_from == "net":
					_custom_back()
		if key.keycode == KEY_H:
			if mode == "title":
				mode = "how"
			elif mode == "how":
				mode = "title"
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
	duel_walls = []
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
	duel_walls = []
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
	bloom_level = maxf(bloom_level, 1.8)
	vignette_pulse = minf(vignette_pulse + 0.6, 0.9)
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
	# The launch is spent until the ball hits something: any wall, bumper
	# or ball reloads it. In the duel each fighter reloads on its own
	# ball smashes, tracked on the fighter dict.
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
	bloom_level = minf(bloom_level + 0.15 + p * 0.25, 2.2)
	vignette_pulse = minf(vignette_pulse + 0.08 + p * 0.12, 0.9)
	if net_mode != "off" and mode == "play":
		duel_me["vel"] = ball_vel
		duel_me["ready"] = false
		shot_ready = false
		if net_mode == "client":
			_duel_launch.rpc(ball_vel)
			# Echo the launch twice, spaced out: ENet may drop one packet,
			# and a lost launch strands the client mid-flight. Same-frame
			# copies would share one datagram's fate, so they go staggered.
			duel_launch_vel = ball_vel
			duel_launch_echo = 2
			duel_echo_t = 0.08
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
	bloom_level = minf(bloom_level + 0.8, 2.2)
	vignette_pulse = minf(vignette_pulse + 0.30, 0.9)
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
	# Fresh screen, fresh entrance: any mode or versus-screen swap restarts
	# the menu animation clock. Gameplay never reads it.
	var key := mode + "|" + net_screen
	if key != _ui_key:
		_ui_key = key
		ui_t = 0.0
	else:
		ui_t += delta
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
		"settings":
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
			if net_screen == "roulette":
				roulette_t = maxf(0.0, roulette_t - delta)
				var rc := _roulette_center()
				if rc != roulette_tick:
					roulette_tick = rc
					_sfx("bounce", 0.0, -16.0)
				if roulette_t <= 0.0 and net_mode == "host" and mode == "net":
					var ids := _duel_roster()
					var nm := _duel_match_names(ids)
					_net_begin(ids, nm, roulette_win)
					_net_begin.rpc(ids, nm, roulette_win)
		"play":
			_update_play(delta)

	_update_ambient(delta)
	_update_post_fx(delta)
	_update_camera(delta)
	_update_net_edits()
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
	# Lean the frame toward the cursor so the space being aimed into stays
	# visible. ball_pos already tracks my fighter in versus, so this covers
	# singleplayer and multiplayer alike (and touch, via the aim finger).
	if mouse_seen:
		target = target.lerp(mouse_pos, CAM_MOUSE_BIAS)
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

	var wdt := delta * WORLD_SCALE * (SLOWMO if charging else 1.0)

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
## breaking a chest instantly equips the gun sealed inside (assault, blaster, laser or railgun); last one standing wins.
## A 0s clock with two or more fighters alive is a draw: nobody wins without
## every rival dead.
func _update_duel(delta: float) -> void:
	# Solo freezes a beat on big hits; the duel shares the same punch.
	if hitstop > 0.0:
		hitstop -= delta
		_update_particles(delta * 0.2)
		return
	ball_pos = duel_me["pos"]
	ball_vel = duel_me["vel"]
	if charging:
		charge_t = minf(charge_t + CHARGE_TIME, CHARGE_TIME)
		_update_charge_motes(delta)
	var wdt := delta * WORLD_SCALE * (SLOWMO if charging else 1.0)
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
					duel_chests.append({"pos": cp, "hp": DUEL_CHEST_HP, "gun": 1 + randi() % 4})
					_ring(cp, GOLD, 10, 200.0)
		if duel_was_alive and int(duel_me.get("hp", 0)) <= 0:
			duel_was_alive = false
			charging = false
			charge_t = 0.0
			stick_on = false
			stick_mouse = false
			_banner("ELIMINATED")
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			# No HP verdict: a win needs every rival dead, so the clock
			# can only end it level. The elimination check below crowns
			# the last fighter standing.
			_duel_finish(-1)
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
			# Balls ride every 2nd snapshot (~10 Hz); fighters, bullets and
			# chests stay 20 Hz. Drifters ship their velocity too, so joiners
			# glide them client-side between snaps instead of jump-cutting.
			# An empty list means "no change", never "arena is empty".
			duel_snap_balls = not duel_snap_balls
			var tg_flat: Array = []
			# [slot, vx, vy] per drifter, slots matching the ball order above.
			# ~20 movers; basics and spikies never move, so they ride free.
			var dv_flat: Array = []
			if duel_snap_balls:
				var slot := 0
				for tg in targets:
					tg_flat.append(tg.pos.x)
					tg_flat.append(tg.pos.y)
					tg_flat.append(tg.radius)
					tg_flat.append(2 if tg.kind == "armored" else (1 if tg.kind == "drifter" else 0))
					if tg.kind == "drifter":
						dv_flat.append(slot)
						dv_flat.append(tg.vel.x)
						dv_flat.append(tg.vel.y)
					slot += 1
			# Dictionaries re-send every key string per entry per snapshot,
			# so bullets/chests/pickups ride packed flat: numbers only.
			var bf: Array = []
			for b in duel_bullets:
				var bd: Dictionary = b
				var bpp: Vector2 = bd["pos"]
				var bvv: Vector2 = bd["vel"]
				bf.append(bpp.x)
				bf.append(bpp.y)
				bf.append(bvv.x)
				bf.append(bvv.y)
				bf.append(bd["owner"])
				bf.append(bd["life"])
				bf.append(bd["dmg"])
				bf.append(int(bd.get("kind", 0)))
			var cf: Array = []
			for ch in duel_chests:
				var chd: Dictionary = ch
				var cpp: Vector2 = chd["pos"]
				cf.append(cpp.x)
				cf.append(cpp.y)
				cf.append(chd["hp"])
				cf.append(int(chd.get("gun", 1)))
			var pf: Array = []
			for pk in duel_pickups:
				var pkd: Dictionary = pk
				var ppp: Vector2 = pkd["pos"]
				pf.append(ppp.x)
				pf.append(ppp.y)
				pf.append(pkd["kind"])
			# Sequence stamp: ENet unreliable can reorder, and an older
				# snapshot must never overwrite a newer one on the client.
			duel_snap_seq += 1
			net_last_snap = t
			_net_duel.rpc([fighters, bf, cf, pf, time_left, tg_flat, duel_snap_seq, dv_flat])
	else:
		# Staggered launch echo: re-send until the host applies it.
		if duel_launch_echo > 0:
			duel_echo_t -= delta
			if duel_echo_t <= 0.0:
				duel_echo_t = 0.08
				duel_launch_echo -= 1
				_duel_launch.rpc(duel_launch_vel)
		if int(duel_me.get("hp", 0)) > 0:
			_duel_step(duel_me, wdt, false)
			# Same contact response the host sim runs, in the same order,
			# so its snapshots confirm prediction instead of rewinding it.
			_duel_clash_me()
			# Drifters glide client-side at full frame rate; snapshots only
			# reconcile them. Same tame-ball motion the host sim runs.
			_update_targets(wdt)
			_duel_smash_check(false)
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
			# dt = 0 integrates nothing, but still runs the world-edge /
			# lava / chest / map-wall resolve, so rivals slide along
			# geometry instead of sinking through it between snapshots.
			# Non-authoritative: no damage, chips, or FX, host owns those.
			_duel_step(rf, 0.0, false)
		_duel_update_bullets(wdt, false)
		_duel_predict_my_bullets()
		_duel_predict_my_pickup()
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
		# Lava always reloads the launch, so touching the floor hands
		# back control for another aimed bounce. Mirrors to shot_ready
		# for the local fighter so the HUD hint clears instantly.
		f["ready"] = true
		if f == duel_me:
			shot_ready = true
		if v.y > 0.0:
			v.y = -v.y * WALL_REST
		if float(f.get("lava", 0.0)) <= 0.0:
			f["lava"] = DUEL_LAVA_GRACE
			if authoritative:
				_duel_hurt(f, DUEL_LAVA_DMG)
				_popup(p + Vector2(0.0, -30.0), "-%d LAVA" % DUEL_LAVA_DMG, RED, 20)
				_burst(p, RED, 10, 300.0)
				_burst(p, GOLD, 8, 240.0)
				shake = maxf(shake, 4.0)
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
	# Map walls slide like the world edge: push out, kill inward speed.
	if not duel_walls.is_empty():
		var shove := _duel_wall_push(p, BALL_R)
		if shove.length_squared() > 0.0001:
			p += shove
		var wn := shove.normalized()
		var wvn := v.dot(wn)
		if wvn < 0.0:
			v -= wvn * wn
	f["pos"] = p
	f["vel"] = v


## Body-slam: hard fighter contact shoves both apart; the host also hurts
## the slower one.
func _duel_fighter_clash() -> void:
	var allf := _duel_all()
	for a in allf.size():
		for b in range(a + 1, allf.size()):
			_duel_clash_pair(allf[a], allf[b])


## Client-side: resolve body contact for my own fighter only, with the same
## response the host pair applies. Damage still arrives via snapshots.
func _duel_clash_me() -> void:
	if duel_my_id < 0:
		return
	if int(duel_me.get("hp", 0)) <= 0 or bool(duel_me.get("gone", false)):
		return
	for foe in duel_foes:
		var ff: Dictionary = foe
		if int(ff.get("hp", 0)) <= 0 or bool(ff.get("gone", false)):
			continue
		_duel_clash_pair(duel_me, ff, false)


func _duel_clash_pair(fa: Dictionary, fb: Dictionary, authoritative := true) -> void:
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
		# Damage stays host-authoritative; the shove above runs on both
		# sides so joiner prediction matches instead of snapping back.
		if authoritative:
			if a_slow:
				_duel_hurt(fa, 8)
			else:
				_duel_hurt(fb, 8)
		var mid := ((fa["pos"] as Vector2) + (fb["pos"] as Vector2)) * 0.5
		_burst(mid, GOLD, 10, 260.0)
		_ring(mid, GOLD, 12, 200.0)
		shake = maxf(shake, 6.0)
		_sfx("bump", 0.0, -8.0)


## Bullets fly straight, die on walls/expiry, and hit chests + any rival.
## Beam bolts and rail slugs pierce fighters (tagged rivals take one hit
## each per pass); every crate absorbs any round, so one shot breaks one
## crate at most.
func _duel_update_bullets(dt: float, authoritative: bool) -> void:
	var keep: Array = []
	var allf := _duel_all()
	for b in duel_bullets:
		var bp: Vector2 = b["pos"] + (b["vel"] as Vector2) * dt
		var life: float = float(b["life"]) - dt
		var kind := int(b.get("kind", 0))
		var dead := life <= 0.0 or bp.x < WORLD.position.x or bp.x > WORLD.end.x or bp.y < WORLD.position.y or bp.y > _lava_top()
		if not dead and authoritative:
			# Backwards: a kill removes the entry mid-loop, which is only
			# safe when later indices are already visited.
			for i in range(duel_chests.size() - 1, -1, -1):
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
					var hitlist: Array = b.get("hit", [])
					if hitlist.has(i):
						continue
					_duel_hurt(foe, int(b["dmg"]))
					_burst(bp, PINK, 8, 200.0)
					_ring(bp, PINK, 10, 260.0)
					shake = maxf(shake, 4.0)
					_sfx("bump", 0.05, -10.0)
					if kind == 1 or kind == 2:
						hitlist.append(i)
						b["hit"] = hitlist
					else:
						dead = true
						break
		if not dead and not duel_walls.is_empty() and _duel_point_blocked(bp, DUEL_BULLET_R + 6.0):
			_burst(bp, CYAN, 6, 160.0)
			_sfx("bump", 0.05, -14.0)
			dead = true
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
				ff["gun"] = clampi(int(pk["kind"]), 1, 4)
				ff["cd"] = 0.0
				_popup((ff["pos"] as Vector2) + Vector2(0.0, -34.0), DUEL_GUN_NAMES[clampi(int(ff["gun"]), 0, 4)], CYAN, 16)
				_sfx("wave", 0.0, -10.0)
				taken = true
				break
		if not taken:
			keep.append(pk)
	duel_pickups = keep


## Breaking a chest equips the gun sealed inside on the spot (each crate
## holds one of the 4 guns, shown on its face). No walk-over needed; a
## pickup only drops when the breaker is already out (a stray bullet
## finishing the job after they died).
func _duel_damage_chest(i: int, dmg: int, breaker: Dictionary) -> void:
	if i < 0 or i >= duel_chests.size():
		return
	var ch: Dictionary = duel_chests[i]
	ch["hp"] = int(ch["hp"]) - dmg
	if int(ch["hp"]) > 0:
		return
	duel_chests.remove_at(i)
	var kind := clampi(int(ch.get("gun", 1)), 1, 4)
	if not breaker.is_empty() and int(breaker.get("hp", 0)) > 0:
		breaker["gun"] = kind
		breaker["cd"] = 0.0
		_popup((breaker["pos"] as Vector2) + Vector2(0.0, -34.0), DUEL_GUN_NAMES[clampi(kind, 0, 4)], CYAN, 16)
		_sfx("wave", 0.0, -10.0)
	else:
		duel_pickups.append({"pos": ch["pos"], "kind": kind})
	_burst(ch["pos"], GOLD, 14, 260.0)
	_ring(ch["pos"], GOLD, 12, 240.0)
	shake = maxf(shake, 8.0)
	hitstop = maxf(hitstop, 0.05)
	bloom_level = minf(bloom_level + 0.5, 2.2)
	vignette_pulse = minf(vignette_pulse + 0.20, 0.9)
	_sfx("bump", 0.0, -6.0)


func _duel_hurt(f: Dictionary, dmg: int) -> void:
	var old := int(f.get("hp", 0))
	if old <= 0:
		return
	f["hp"] = maxi(0, old - dmg)
	if int(f["hp"]) <= 0:
		_duel_death_fx(f["pos"])
	elif is_same(f, duel_me):
		_burst(f["pos"], RED, 8, 260.0)
		shake = maxf(shake, 6.0)
		bloom_level = minf(bloom_level + 0.4, 2.2)
		vignette_pulse = minf(vignette_pulse + 0.4, 0.9)
		_sfx("armor", 0.0, -10.0)


## Shared elimination sendoff, solo-death style. The host spawns it in the
## sim; joiners mirror it from snapshot hp diffs via _duel_client_hurt_fx.
func _duel_death_fx(at: Vector2) -> void:
	_burst(at, GOLD, 24, 420.0)
	_burst(at, WHITE, 12, 260.0)
	_ring(at, GOLD, 16, 320.0)
	_popup(at + Vector2(0.0, -40.0), "ELIMINATED", RED, 22)
	shake = maxf(shake, 12.0)
	hitstop = maxf(hitstop, 0.08)
	bloom_level = minf(bloom_level + 0.9, 2.2)
	vignette_pulse = minf(vignette_pulse + 0.45, 0.9)
	_sfx("kill", 0.08, -6.0)


## Joiner-side hurt mirror: hp lives on the host, so damage is inferred
## from snapshot diffs and the same juice replays locally.
func _duel_client_hurt_fx(pos: Vector2, old_hp: int, new_hp: int, is_me: bool) -> void:
	if new_hp >= old_hp or old_hp <= 0:
		return
	if new_hp <= 0:
		_duel_death_fx(pos)
	else:
		_burst(pos, RED, 6, 220.0)
		if is_me:
			shake = maxf(shake, 5.0)
			bloom_level = minf(bloom_level + 0.4, 2.2)
			vignette_pulse = minf(vignette_pulse + 0.4, 0.9)
			_sfx("armor", 0.0, -10.0)


## Versus maps: simple polygonic slabs inside the world barriers. The open
## field stays empty; the rest are center-anchored boxes plus one octagon,
## all high above the lava line (spawns still resolve out, just in case).
func _duel_map_defs() -> Array:
	var c := WORLD.get_center()
	var maps: Array = []
	maps.append({"name": "OPEN FIELD", "polys": []})
	maps.append({"name": "PILLARS", "polys": [
		_box_at(c, -480.0, -260.0, 150.0, 150.0),
		_box_at(c, 480.0, -260.0, 150.0, 150.0),
		_box_at(c, -480.0, 260.0, 150.0, 150.0),
		_box_at(c, 480.0, 260.0, 150.0, 150.0)]})
	maps.append({"name": "CROSSROADS", "polys": [
		_box_at(c, 0.0, 0.0, 920.0, 140.0),
		_box_at(c, 0.0, 0.0, 140.0, 920.0)]})
	maps.append({"name": "TWIN GATES", "polys": [
		_box_at(c, -350.0, -430.0, 140.0, 560.0),
		_box_at(c, -350.0, 430.0, 140.0, 560.0),
		_box_at(c, 350.0, -430.0, 140.0, 560.0),
		_box_at(c, 350.0, 430.0, 140.0, 560.0)]})
	var oct: Array = []
	for i in 8:
		var a := TAU * float(i) / 8.0 + TAU / 16.0
		oct.append(c + Vector2(cos(a), sin(a)) * 380.0)
	maps.append({"name": "STAR FORT", "polys": [oct]})
	for m in maps:
		var md: Dictionary = m
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for poly in md.get("polys", []):
			for q in (poly as Array):
				var qp: Vector2 = q
				lo.x = minf(lo.x, qp.x)
				lo.y = minf(lo.y, qp.y)
				hi.x = maxf(hi.x, qp.x)
				hi.y = maxf(hi.y, qp.y)
		md["ctr"] = (lo + hi) * 0.5
		md["ext"] = Vector2(maxf(hi.x - lo.x, 1.0), maxf(hi.y - lo.y, 1.0))
	return maps


## Center-anchored box corners for map building.
func _box_at(c: Vector2, x: float, y: float, w: float, h: float) -> Array:
	return [c + Vector2(x - w * 0.5, y - h * 0.5), c + Vector2(x + w * 0.5, y - h * 0.5),
		c + Vector2(x + w * 0.5, y + h * 0.5), c + Vector2(x - w * 0.5, y + h * 0.5)]


func _duel_maps() -> Array:
	if duel_maps_cache.is_empty():
		duel_maps_cache = _duel_map_defs()
	return duel_maps_cache


func _duel_map_count() -> int:
	return _duel_maps().size()


func _duel_map_name(i: int) -> String:
	var maps := _duel_maps()
	return str((maps[clampi(i, 0, maps.size() - 1)] as Dictionary).get("name", "?"))


## Absolute wall polys for this match, from the selected map.
func _duel_build_map(idx: int) -> void:
	var maps := _duel_maps()
	duel_map = clampi(idx, 0, maps.size() - 1)
	duel_walls = ((maps[duel_map] as Dictionary).get("polys", []) as Array).duplicate(true)


## Closest point on segment ab to p.
func _seg_closest(a: Vector2, b: Vector2, p: Vector2) -> Vector2:
	var ab := b - a
	if ab.length_squared() < 0.0001:
		return a
	return a + ab * clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)


## Ray-cast containment for spawn checks.
func _point_in_poly(pt: Vector2, pl: Array) -> bool:
	var inside := false
	var n := pl.size()
	for i in n:
		var a: Vector2 = pl[i]
		var b: Vector2 = pl[(i + 1) % n]
		if (a.y > pt.y) != (b.y > pt.y):
			var x := a.x + (pt.y - a.y) * (b.x - a.x) / (b.y - a.y)
			if pt.x < x:
				inside = not inside
	return inside


## True when a disc of radius pad around pt touches any wall.
func _duel_point_blocked(pt: Vector2, pad: float) -> bool:
	for poly in duel_walls:
		var pl: Array = poly
		if pl.size() < 3:
			continue
		if _point_in_poly(pt, pl):
			return true
		for i in pl.size():
			if pt.distance_to(_seg_closest(pl[i], pl[(i + 1) % pl.size()], pt)) < pad:
				return true
	return false


## Push a disc out of every wall (edges and containment); two passes
## settle corners. Returns the total push so callers can kill or
## reflect the inward velocity component.
func _duel_wall_push(pt: Vector2, r: float) -> Vector2:
	var pos := pt
	for pass_i in 2:
		for poly in duel_walls:
			var pl: Array = poly
			if pl.size() < 3:
				continue
			var best := pos
			var best_d2 := INF
			for i in pl.size():
				var q := _seg_closest(pl[i], pl[(i + 1) % pl.size()], pos)
				var d2 := pos.distance_squared_to(q)
				if d2 < best_d2:
					best_d2 = d2
					best = q
			var d := sqrt(best_d2)
			var n := (pos - best) / maxf(d, 0.001)
			if _point_in_poly(pos, pl):
				pos += n * (d + r)
			elif d < r:
				pos += n * (r - d)
	return pos - pt


## Spawn-safe point: shoved clear of walls (fighters, chests).
func _duel_clear_spot(pt: Vector2, pad: float) -> Vector2:
	if duel_walls.is_empty():
		return pt
	var pos := pt
	for k in 3:
		var push := _duel_wall_push(pos, pad)
		if push.length_squared() < 0.0001:
			break
		pos += push
	return pos


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
		if not duel_walls.is_empty() and _duel_point_blocked(pt, 60.0 + r):
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
		if ok and not duel_walls.is_empty() and _duel_point_blocked(pt, 90.0):
			ok = false
		if ok:
			for ch in duel_chests:
				if pt.distance_to(ch["pos"]) < 220.0:
					ok = false
					break
		if ok:
			return pt
	return Vector2.INF


## Any living fighter touching a ball smashes it, reloading launch. The host
## owns removals, reloads and damage; joiners predict only their own bounce
## so snapshots confirm it instead of teleporting them back. Spiky gold balls
## need a fast hit; a slow touch burns for DUEL_SPIKE_DMG with a second of
## grace so resting contact can't melt a fighter.
func _duel_smash_check(authoritative := true) -> void:
	var allf := _duel_all()
	for fi in allf.size():
		var f: Dictionary = allf[fi]
		if int(f.get("hp", 0)) <= 0 or bool(f.get("gone", false)):
			continue
		# Joiners predict themselves only; rivals ease from snapshots.
		if not authoritative and (duel_my_id < 0 or fi != 0):
			continue
		var fp: Vector2 = f["pos"]
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
					if authoritative:
						_duel_hurt(f, DUEL_SPIKE_DMG)
					_popup(tg.pos + Vector2(0.0, -30.0), "-%d SPIKES" % DUEL_SPIKE_DMG, RED, 20)
					_shards(tg.pos, v, RED, 8, 470.0, 0.5)
					_sfx("armor", 0.0, -8.0)
					if not authoritative:
						_popup(tg.pos + Vector2(0.0, -30.0), "-%d SPIKES" % DUEL_SPIKE_DMG, RED, 20)
						_shards(tg.pos, v, RED, 8, 470.0, 0.5)
						_sfx("armor", 0.0, -8.0)
				fp = f["pos"]
				continue
			if not authoritative:
				# Bounce predicted; the host owns the kill and the joiner
				# replays its juice when the snapshot confirms the smash.
				fp = f["pos"]
				continue
			targets.remove_at(i)
			f["ready"] = true
			_shards(tg.pos, v, tg.color, 8, 470.0, 0.5)
			_burst(tg.pos, tg.color, 14, 300.0)
			_burst(tg.pos, WHITE, 6, 220.0)
			shake = maxf(shake, 6.0)
			hitstop = maxf(hitstop, 0.04)
			bloom_level = minf(bloom_level + 0.5, 2.2)
			vignette_pulse = minf(vignette_pulse + 0.15, 0.9)
			_sfx("wave", 0.0, -8.0)
			fp = f["pos"]
	shot_ready = bool(duel_me.get("ready", true))


## Reliable round end, called on host only, then broadcast.
func _duel_finish(winner: int) -> void:
	if duel_over:
		return
	duel_over = true
	duel_winner = winner
	mode = "over"
	charging = false
	charge_t = 0.0
	bloom_level = maxf(bloom_level, 1.8)
	vignette_pulse = minf(vignette_pulse + 0.6, 0.9)
	_ring(ball_pos, PINK, 18, 320.0)
	shake = maxf(shake, 14.0)
	_sfx("over", 0.0, -4.0)
	_duel_end.rpc(winner)


## Assault sprays, blaster scatters 5 pellets, laser fires a piercing beam
## bolt, railgun lobs a slow siege slug through fighters AND crates. Host
## spawns; no gun = hint only. Every pull kicks the shooter backwards off
## the aim line, so firing has a movement cost. Identical params on host
## and predicting client, so the trigger feels instant with no duplicates.
func _duel_spawn_shots(f: Dictionary, target: Vector2, owner: int = -1) -> void:
	var gun := clampi(int(f.get("gun", 0)), 0, 4)
	if gun <= 0 or float(f.get("cd", 0.0)) > 0.0 or duel_over:
		return
	if int(f.get("hp", 0)) <= 0:
		return
	if owner < 0:
		owner = _duel_all().find(f)
	var base: Vector2 = target - (f["pos"] as Vector2)
	if base.length_squared() < 1.0:
		base = Vector2.RIGHT
	base = base.normalized()
	f["cd"] = float(DUEL_GUN_CD[gun])
	var n := int(DUEL_GUN_PELLETS[gun])
	for i in n:
		var ang := 0.0
		if n > 1:
			ang = lerpf(-float(DUEL_GUN_SPREAD[gun]), float(DUEL_GUN_SPREAD[gun]), float(i) / float(n - 1))
		duel_bullets.append({"pos": f["pos"] + base * (BALL_R + 8.0), "vel": base.rotated(ang) * float(DUEL_GUN_SPD[gun]), "owner": owner, "life": float(DUEL_GUN_LIFE[gun]), "dmg": int(DUEL_GUN_DMG[gun]), "kind": int(DUEL_GUN_KIND[gun]), "hit": []})
	f["vel"] = (f["vel"] as Vector2) - base * float(DUEL_GUN_RECOIL[gun])
	_sfx("shoot_high" if gun >= 3 else "shoot_low", 0.0, -4.0 if gun == 4 else -8.0)
	if is_same(f, duel_me):
		var kick := 0.35 if gun == 4 else (0.2 if gun == 3 else 0.12)
		bloom_level = minf(bloom_level + kick, 2.2)
		vignette_pulse = minf(vignette_pulse + kick * 0.5, 0.9)


## Claim the gun stick if this is a live versus fighter. Mouse claims pin
## to the fixed home spot; touches may grab the home spot or float.
func _stick_take(base: Vector2, knob: Vector2, idx: int, is_mouse: bool) -> bool:
	if stick_on or duel_over or mode != "play" or net_mode == "off":
		return false
	if int(duel_me.get("hp", 0)) <= 0:
		return false
	stick_on = true
	stick_id = idx
	stick_mouse = is_mouse
	stick_base = base
	stick_knob = knob
	return true


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
	if int(duel_me.get("hp", 0)) <= 0:
		return
	if int(duel_me["gun"]) <= 0:
		if float(duel_me["cd"]) <= 0.0:
			duel_me["cd"] = 0.5
			_popup((duel_me["pos"] as Vector2) + Vector2(0.0, -34.0), "NEED A GUN - BREAK CHESTS", RED, 14)
		return
	if float(duel_me["cd"]) > 0.0:
		return
	var mz := (duel_me["pos"] as Vector2) + (target - (duel_me["pos"] as Vector2)).normalized() * (BALL_R + 8.0)
	var mgun := int(duel_me.get("gun", 0))
	var mbig := mgun == 4
	_burst(mz, GOLD, 12 if mbig else (8 if mgun == 3 else 6), 260.0 if mbig else 160.0)
	_ring(mz, GOLD, 10 if mbig else 6, 320.0 if mbig else 200.0)
	if int(duel_me.get("hp", 0)) <= 0 or bool(duel_me.get("gone", false)):
		return
	if net_mode == "host":
		_duel_spawn_shots(duel_me, target, duel_my_id)
	else:
		_duel_me_predict_shot(target)
		_duel_fire.rpc(target)


## Client prediction: spawn our shots locally the same frame we fire, with
## the exact params the host sim uses, so the trigger feels instant. The
## next snapshot matches each ghost by owner + velocity and just eases it,
## so no duplicates; damage itself stays host-side.
func _duel_me_predict_shot(target: Vector2) -> void:
	_duel_spawn_shots(duel_me, target, duel_my_id)


## Client-side: my bullets spark against rivals and chests the same frame
## instead of sailing through until the snapshot. A hit only spends the
## local ghost with a small flash; rival damage still arrives via hp diffs,
## and a lethal chest hit runs the real break so the snapshot confirms it
## silently instead of replaying the burst a second time.
func _duel_predict_my_bullets() -> void:
	if duel_my_id < 0 or duel_over:
		return
	for bi in range(duel_bullets.size() - 1, -1, -1):
		var b: Dictionary = duel_bullets[bi]
		if int(b.get("owner", -9)) != duel_my_id:
			continue
		var bp: Vector2 = b["pos"]
		var bkind := int(b.get("kind", 0))
		var hit := false
		for foe in duel_foes:
			var ff: Dictionary = foe
			if int(ff.get("hp", 0)) <= 0:
				continue
			if bp.distance_to(ff["pos"]) < BALL_R + DUEL_BULLET_R:
				if bkind == 0:
					hit = true
					break
				# Piercing bolts spark through rivals and keep flying.
				_burst(bp, WHITE, 2, 90.0)
		if not hit:
			# Backwards: a predicted kill removes the entry mid-loop.
			# Crates absorb every round including rail slugs, mirroring
			# the host: one ghost breaks one crate, then it is spent.
			for ci in range(duel_chests.size() - 1, -1, -1):
				var ch: Dictionary = duel_chests[ci]
				if bp.distance_to(ch["pos"]) < 34.0:
					if int(ch["hp"]) - int(b["dmg"]) <= 0:
						_duel_damage_chest(ci, int(b["dmg"]), duel_me)
					else:
						_burst(bp, GOLD, 5, 170.0)
						hit = true
						break
		if hit:
			duel_bullets.remove_at(bi)
			_burst(bp, WHITE, 3, 120.0)


## Client-side: walking over a pickup equips it on the spot with the same
## popup + sound the host grant plays. Snapshots then just confirm the gun
## already shown, so a contested pickup quietly corrects itself.
func _duel_predict_my_pickup() -> void:
	if duel_my_id < 0 or duel_over or int(duel_me.get("hp", 0)) <= 0:
		return
	for pi in range(duel_pickups.size() - 1, -1, -1):
		var pk: Dictionary = duel_pickups[pi]
		if (duel_me["pos"] as Vector2).distance_to(pk["pos"]) < 46.0:
			duel_me["gun"] = maxi(int(duel_me["gun"]), int(pk["kind"]))
			duel_me["cd"] = 0.0
			_popup((duel_me["pos"] as Vector2) + Vector2(0.0, -34.0), DUEL_GUN_NAMES[clampi(int(duel_me["gun"]), 0, 4)], CYAN, 16)
			_sfx("wave", 0.0, -10.0)
			duel_pickups.remove_at(pi)



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
		if not duel_walls.is_empty() and (tg.kind == "drifter" or tg.kind == "star" or tg.kind == "shield"):
			var bpush := _duel_wall_push(tg.pos, tg.radius)
			if bpush.length_squared() > 0.0001:
				tg.pos += bpush
				var bn := bpush.normalized()
				var bvn: float = tg.vel.dot(bn)
				if bvn < 0.0:
					tg.vel -= 2.0 * bvn * bn


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
	bloom_level = minf(bloom_level + 0.9, 2.2)
	vignette_pulse = minf(vignette_pulse + 0.40, 0.9)
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

	# The floor is molten but bouncy: touching it kicks the ball back up
	# and reloads the launch via _on_bounce, in play and on title.
	var surface := _lava_top() - BALL_R
	if ball_pos.y > surface:
		ball_pos.y = surface
		# Lava always reloads the launch, even on a graze: touching the
		# floor hands back control for another aimed bounce.
		shot_ready = true
		if ball_vel.y > 0.0:
			ball_vel.y = -ball_vel.y * WALL_REST
			ball_vel.y = minf(ball_vel.y - RICOCHET_LIFT, -RICOCHET_LIFT * 0.5)
			_clamp_speed()
			_on_bounce(Vector2(ball_pos.x, surface), absf(ball_vel.y))
			_burst(Vector2(ball_pos.x, surface), Color(1.0, 0.55, 0.15), 8, 220.0)


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


## Any wall or bumper ricochet reloads the launch, so the ball can bounce
## again as soon as it touches something. Solo only: versus reloads on
## the fighter dict, which this never touches.
func _on_bounce(at: Vector2, strength: float) -> void:
	if net_mode == "off" and mode == "play":
		shot_ready = true
	var s := clampf(strength / 1400.0, 0.0, 1.0)
	ball_flash = maxf(ball_flash, 0.4 + s)
	bloom_level = minf(bloom_level + s * 0.4, 2.2)
	vignette_pulse = minf(vignette_pulse + s * 0.25, 0.9)
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
	draw_org = -cam * cam_zoom + VIEW * 0.5 + off
	draw_set_transform(draw_org, 0.0, z)

	shadow_queue.clear()
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
	_draw_lamp_wash()
	_draw_queued_shadows()
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
	elif mode == "settings":
		_draw_settings()
	elif mode == "how":
		_draw_how()
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

	# Versus map structures, culled to the view. Solo never builds walls.
	if not duel_walls.is_empty():
		var vis2 := _view_rect().grow(80.0)
		var pulse2 := 0.55 + 0.25 * sin(t * 2.4)
		for poly in duel_walls:
			var pl: Array = poly
			if pl.size() < 3:
				continue
			var pts := PackedVector2Array(pl)
			var lo: Vector2 = pts[0]
			var hi: Vector2 = pts[0]
			for q2 in pts:
				var qv: Vector2 = q2
				lo.x = minf(lo.x, qv.x)
				lo.y = minf(lo.y, qv.y)
				hi.x = maxf(hi.x, qv.x)
				hi.y = maxf(hi.y, qv.y)
			if not vis2.intersects(Rect2(lo, hi - lo)):
				continue
			draw_colored_polygon(pts, Color(0.05, 0.10, 0.20, 0.92))
			var ring := PackedVector2Array(pts)
			ring.append(pts[0])
			draw_polyline(ring, Color(0.45, 0.85, 1.0, pulse2), 3.0, true)


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


## The lamp everything is lit by: your ball, or the camera while spectating.
func _light_pos() -> Vector2:
	if _duel_watching():
		return cam
	return ball_pos


## How lit a world point is by the lamp: 1.0 at the lamp, fading to a dim
## ambient floor far away. Used to dim distant bodies so the lamp reads.
func _light_level(pos: Vector2) -> float:
	var dist := pos.distance_to(_light_pos())
	if dist >= LIGHT_RADIUS * 1.6:
		return 0.22
	var u := 1.0 - dist / (LIGHT_RADIUS * 1.6)
	return clampf(0.22 + 0.78 * u, 0.22, 1.0)


## Cartoon stand-in for real 2D lights: a blob shadow on the side away
## from your ball plus a warm kiss of light on the facing side. Strength
## falls off with distance; past LIGHT_RADIUS bodies sit in darkness and
## are dimmed instead of skipped, so shading never disappears.
func _cast_shadow(pos: Vector2, r: float, fade: float = 1.0) -> void:
	# Records only; _draw_queued_shadows() inks them after the lamp wash,
	# which would otherwise paint straight over every blob and erase them.
	var d := pos - _light_pos()
	var dist := d.length()
	if dist < 1.0:
		return
	var dir := d / dist if dist > 0.001 else Vector2.RIGHT
	shadow_queue.append({"pos": pos, "r": r, "dir": dir, "dist": dist, "fade": fade})


## Cartoon stand-in for real 2D lights, inked after the lamp wash so the
## lit floor sits under the shadow instead of bleaching it out: a blob on
## the side away from your ball plus a warm kiss of light on the facing
## side, with a faint cool rim so the shape reads on the near-black floor.
func _draw_queued_shadows() -> void:
	for q in shadow_queue:
		var pos: Vector2 = q["pos"]
		var r: float = q["r"]
		var dir: Vector2 = q["dir"]
		var dist: float = q["dist"]
		var fade: float = q["fade"]
		if dist > LIGHT_RADIUS:
			# Beyond the lamp: settle into ambient darkness, no highlight.
			var lvl := _light_level(pos)
			draw_circle(pos, r * 1.02, Color(0.0, 0.0, 0.0, (1.0 - lvl) * 0.62 * fade))
			continue
		var strength := pow(1.0 - dist / LIGHT_RADIUS, 0.65) * fade
		if strength <= 0.02:
			# Still leave a faint contact shade so far bodies keep depth.
			draw_circle(pos, r * 1.0, Color(0.0, 0.0, 0.0, 0.18 * fade))
			continue
		# Blob pushed well clear of the body so a crescent survives from
		# under it; the lamp-side overlap reads as edge shading, which is
		# exactly what a cast shadow does when it climbs its caster.
		var bc := pos + dir * (r * 1.10 + 12.0)
		draw_circle(bc, r * 1.05, Color(0.0, 0.0, 0.0, 0.70 * strength))
		draw_circle(pos + dir * (r * 0.30 + 3.0), r * 0.96, Color(0.0, 0.0, 0.0, 0.30 * strength))
		draw_arc(bc, r * 1.05, dir.angle() - 1.4, dir.angle() + 1.4, 28, Color(0.60, 0.78, 1.0, 0.30 * strength), 2.5, true)
		draw_circle(pos - dir * r * 0.52, r * 0.42, Color(1.0, 0.95, 0.85, 0.34 * strength))


## Warm pool of light spilled by the lamp onto the floor around it. Drawn
## in world space after the actors so nearby ground and bodies visibly
## brighten while far ground stays dark. Three nested washes approximate
## a smooth falloff without needing a light texture or shader.
func _draw_lamp_wash() -> void:
	if mode != "play" and mode != "title" and mode != "over":
		return
	var lamp := _light_pos()
	var breathe := 1.0 + sin(t * 2.2) * 0.03 + (0.12 if charging else 0.0)
	var r0 := LIGHT_RADIUS * breathe
	# Outer spill first so inner washes stack brighter toward the lamp.
	draw_circle(lamp, r0, Color(1.0, 0.88, 0.70, 0.045))
	draw_circle(lamp, r0 * 0.66, Color(1.0, 0.90, 0.74, 0.055))
	draw_circle(lamp, r0 * 0.40, Color(1.0, 0.93, 0.80, 0.065))


func _draw_bumpers() -> void:
	var vis := _view_rect().grow(CULL_MARGIN)
	for b in bumpers:
		if not vis.has_point(b.pos):
			continue
		_cast_shadow(b.pos, b.radius)
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

		_cast_shadow(tg.pos, r, fade)
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
	_cast_shadow(boss.pos, r)
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

	# Your lamp: a soft halo in your skin color that breathes, and flares
	# while charging so rivals can see the shot winding up.
	var glow := BALL_R * (5.2 + sin(t * 2.2) * 0.3 + (1.6 if charging else 0.0))
	draw_circle(ball_pos, LIGHT_RADIUS * 0.55, Color(bc.r, bc.g, bc.b, 0.030))
	draw_circle(ball_pos, glow, Color(bc.r, bc.g, bc.b, 0.045))
	draw_circle(ball_pos, glow * 0.62, Color(bc.r, bc.g, bc.b, 0.07))
	draw_circle(ball_pos, BALL_R + 18.0 + ball_flash * 8.0, Color(bc.r, bc.g, bc.b, 0.05 + ball_flash * 0.04))
	draw_circle(ball_pos, BALL_R + 7.0, Color(minf(bc.r + 0.1, 1.0), minf(bc.g + 0.1, 1.0), minf(bc.b + 0.1, 1.0), 0.12))
	# Squash and stretch with speed: the body elongates along the velocity
	# and pinches across it, from a whisper at rest to dramatic at full pace.
	# The portrait itself stays upright: spinning the photo with the velocity
	# angle reads as the texture sliding off the trail, so it is drawn
	# axis-aligned and shrunk to fit inside the pinched body.
	var spd := ball_vel.length()
	var samt := 0.0
	if spd > 40.0:
		var sk := clampf(spd / 1800.0, 0.0, 1.0)
		samt = 0.04 + 0.30 * sk
		draw_set_transform(draw_org + ball_pos * cam_zoom, ball_vel.angle(), Vector2(1.0 + samt, 1.0 - samt) * cam_zoom)
	else:
		draw_set_transform(draw_org + ball_pos * cam_zoom, 0.0, Vector2.ONE * cam_zoom)
	var face := _ball_face_tex()
	if face != null:
		draw_circle(Vector2.ZERO, BALL_R, Color(0.0, 0.0, 0.0, 0.55))
		draw_arc(Vector2.ZERO, BALL_R, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.85), 2.0, true)
		var fs := 1.0 - samt
		draw_set_transform(draw_org + ball_pos * cam_zoom, 0.0, Vector2.ONE * fs * cam_zoom)
		draw_texture_rect(face, Rect2(Vector2(-BALL_R, -BALL_R), Vector2(BALL_R * 2.0, BALL_R * 2.0)), false)
		draw_circle(Vector2(-BALL_R * 0.3, -BALL_R * 0.3), BALL_R * 0.22, Color(1.0, 1.0, 1.0, 0.35))
	else:
		draw_circle(Vector2.ZERO, BALL_R, bh)
		draw_circle(Vector2(-BALL_R * 0.3, -BALL_R * 0.3), BALL_R * 0.45, WHITE_HOT)
		_draw_smiley(Vector2.ZERO, BALL_R)
	draw_set_transform(draw_org, 0.0, Vector2(cam_zoom, cam_zoom))

	if mode == "play" and shot_ready:
		draw_arc(ball_pos, BALL_R + 12.0, 0.0, TAU, 40, Color(_ball_col().r, _ball_col().g, _ball_col().b, 0.32), 2.0, true)
	# Versus: my equipped gun orbits the ball, tracking the cursor (or the
	# gun stick while it is deflected). Hidden while spectating, when
	# ball_pos rides the watched rival instead of my own fighter.
	if net_mode != "off" and mode == "play" and not _duel_watching() and int(duel_me.get("gun", 0)) > 0:
		var aim := mouse_pos
		if stick_on:
			var sdir := _stick_dir()
			if sdir.length() > 0.1:
				aim = ball_pos + sdir * 200.0
		_draw_gun_orbit(int(duel_me.get("gun", 0)), ball_pos, aim, 66.0)

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
	# Top scrim anchors the floating score/timer so they read as one bar.
	draw_rect(Rect2(0.0, 0.0, 1280.0, 88.0), Color(0.008, 0.016, 0.036, 0.55))
	draw_line(Vector2(0.0, 88.0), Vector2(1280.0, 88.0), UI_LINE, 1.0)
	if net_mode != "off" and (mode == "play" or (mode == "over" and duel_over)):
		_draw_duel_corners()
	else:
		_text("SCORE", Vector2(48.0, 26.0), 11, UI_SUB)
		_text(str(score), Vector2(48.0, 54.0), 24, UI_TEXT, true)
	if mode == "play" and net_mode == "off":
		_text("SHOT READY" if shot_ready else "HIT A BALL TO RELOAD", Vector2(48.0, 78.0), 11,
			CYAN if shot_ready else UI_SUB)
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
		_text_right("SMASHED", Vector2(1232.0, 26.0), 11, UI_SUB)
		_text_right(str(kills), Vector2(1232.0, 54.0), 24, UI_TEXT, true)
	if mode == "play" and net_mode != "off" and not duel_over:
		var hint := "RMB / F / SPACE shoot   ·   chests give guns   ·   smash balls to bounce again"
		if _duel_watching():
			hint = "SPECTATING - the round plays on without you"
		if DisplayServer.is_touchscreen_available():
			hint = "hold + drag to bounce   ·   2nd finger: push stick to shoot"
		_text_center_at(Vector2(640.0, 700.0), hint, 12, Color(0.45, 0.60, 0.80, 0.55))

	var bw := 320.0
	var bx := 640.0 - bw * 0.5
	var by := 20.0
	draw_rect(Rect2(bx, by, bw, 4.0), Color(0.35, 0.55, 1.0, 0.14))
	var p := clampf(time_left / maxf(max_time, 0.001), 0.0, 1.0)
	if p > 0.0:
		var tc := RED if p < 0.25 else CYAN
		draw_rect(Rect2(bx, by, bw * p, 4.0), tc)
	_text_center_at(Vector2(640.0, 44.0), "%ds" % int(ceil(time_left)), 13, UI_SUB)
	if net_mode != "off" and mode == "play" and not duel_walls.is_empty():
		_text_center_at(Vector2(640.0, 78.0), _duel_map_name(duel_map), 11, Color(0.55, 0.85, 1.0, 0.6))

	if combo > 1:
		_text_center_at(Vector2(640.0, 62.0), "COMBO x%d" % combo, 12, GOLD)
	if autoaim:
		_text_center_at(Vector2(640.0, 100.0), "AUTOAIM %d" % auto_left, 16, GOLD, bold_font)

	# Link health, duel only: a stale snapshot means the other end stopped
	# arriving (WiFi dying), not a silent freeze. RTT shown when known.
	if mode == "play" and not duel_over and net_mode == "client" and t - net_last_snap > 2.0:
		var _rtt := _net_rtt_ms()
		var _msg := "CONNECTION UNSTABLE - holding last snapshot"
		if _rtt >= 0:
			_msg += " (%dms)" % _rtt
		_text_center_at(Vector2(640.0, 62.0), _msg, 13, RED)

	if mode == "play" and time_left < 5.0:
		var a := (1.0 - time_left / 5.0) * (0.16 + 0.10 * sin(t * 10.0))
		draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(1.0, 0.2, 0.35, a), false, 26.0)

	if muted:
		_text_right("MUTED", Vector2(1232.0, 700.0), 12, DIM)

	if banner_t > 0.0:
		var a := clampf(banner_t / 0.45, 0.0, 1.0)
		_text_center_at(Vector2(640.0, 300.0), banner, 42,
			Color(UI_TEXT.r, UI_TEXT.g, UI_TEXT.b, a), bold_font)


func _duel_foe_name(o: int) -> String:
	if o >= 0 and o < duel_foes.size():
		var nm := str((duel_foes[o] as Dictionary).get("name", ""))
		if nm != "":
			return nm
	return "FOE" if o == 0 else "FOE %d" % (o + 1)


## My display name, or the old YOU label when the box was left blank.
func _duel_my_name() -> String:
	var nm := str(duel_me.get("name", ""))
	return nm if nm != "" else "YOU"


## Winner's display name. duel_winner indexes _duel_all() on every peer, so
## this reads the same fighter everywhere (unlike the foe-slot labels).
func _duel_winner_name() -> String:
	var allf := _duel_all()
	if duel_winner >= 0 and duel_winner < allf.size():
		var nm := str((allf[duel_winner] as Dictionary).get("name", ""))
		if nm != "":
			return nm
		if duel_winner == duel_my_id:
			return _duel_my_name()
		var foe_o := duel_winner if duel_my_id < 0 else duel_winner - 1
		return "FOE" if foe_o == 0 else "FOE %d" % (foe_o + 1)
	return "DRAW"


func _duel_foe_col(o: int) -> Color:
	return DUEL_FOE_COLS[o % DUEL_FOE_COLS.size()]


## Duel corners: my health + gun, then every rival stacked top-right.
func _draw_duel_corners() -> void:
	var watching := _duel_watching()
	_text("SPECTATING" if watching else _duel_my_name(), Vector2(48.0, 26.0), 11, UI_SUB)
	var w := _duel_watch_target() if watching else {}
	var my_hp := int(w.get("hp", 0)) if watching else int(duel_me.get("hp", DUEL_HP))
	var my_gun := 0 if watching else int(duel_me.get("gun", 0))
	_text(str(my_hp), Vector2(48.0, 54.0), 24, UI_TEXT, true)
	_text(DUEL_GUN_NAMES[clampi(my_gun, 0, 4)], Vector2(48.0, 78.0), 11, CYAN if my_gun > 0 else UI_SUB)
	if my_gun > 0:
		_draw_gun_icon(my_gun, Vector2(150.0, 76.0), 20.0)
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
		_cast_shadow(p, 30.0)
		var r := Rect2(p - Vector2(26.0, 26.0), Vector2(52.0, 52.0))
		draw_rect(r.grow(3.0), Color(0.05, 0.04, 0.02, 0.85))
		draw_rect(r, Color(0.45, 0.30, 0.12, 0.95))
		draw_rect(r, GOLD, false, 2.0)
		draw_line(r.position, r.end, Color(0.25, 0.16, 0.06, 0.9), 3.0)
		draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Color(0.25, 0.16, 0.06, 0.9), 3.0)
		# Gun sealed inside, so rivals can see what the crate holds.
		_draw_gun_icon(int(ch.get("gun", 1)), p, 26.0)
		var frac := clampf(float(ch["hp"]) / DUEL_CHEST_HP, 0.0, 1.0)
		draw_rect(Rect2(p - Vector2(26.0, 34.0), Vector2(52.0 * frac, 5.0)), GOLD)
	for pk in duel_pickups:
		var pp: Vector2 = pk["pos"] + Vector2(0.0, sin(t * 3.0) * 4.0)
		var gk := clampi(int(pk.get("kind", 1)), 1, 4)
		var gc: Color = DUEL_GUN_COLS[gk]
		draw_circle(pp, 16.0, Color(gc.r, gc.g, gc.b, 0.18))
		draw_arc(pp, 16.0, 0.0, TAU, 24, Color(gc.r, gc.g, gc.b, 0.8), 1.5, true)
		_draw_gun_icon(gk, pp, 22.0)
	for b in duel_bullets:
		var bc: Color = CYAN if int(b["owner"]) == _duel_role() else Color(1.0, 0.55, 0.30)
		var bk := int(b.get("kind", 0))
		var bp2: Vector2 = b["pos"]
		var glow := Color(bc.r, bc.g, bc.b, 0.20)
		var glow_soft := Color(bc.r, bc.g, bc.b, 0.10)
		if bk == 1:
			var bd: Vector2 = (b["vel"] as Vector2).normalized()
			draw_line(bp2 - bd * 28.0, bp2 + bd * 14.0, glow_soft, 18.0, true)
			draw_line(bp2 - bd * 26.0, bp2 + bd * 12.0, Color(bc.r, bc.g, bc.b, 0.5), 10.0, true)
			draw_line(bp2 - bd * 26.0, bp2 + bd * 12.0, Color(1.0, 1.0, 1.0, 0.9), 4.0, true)
			draw_circle(bp2 + bd * 12.0, 8.0, glow)
			draw_circle(bp2 + bd * 12.0, 3.5, Color(1.0, 1.0, 1.0, 0.95))
		elif bk == 2:
			draw_circle(bp2, DUEL_BULLET_R + 18.0, glow_soft)
			draw_circle(bp2, DUEL_BULLET_R + 10.0, Color(bc.r, bc.g, bc.b, 0.30))
			draw_circle(bp2, DUEL_BULLET_R + 4.0, Color(1.0, 1.0, 1.0, 0.95))
			draw_circle(bp2, DUEL_BULLET_R, bc)
			draw_circle(bp2, DUEL_BULLET_R * 0.45, Color(1.0, 1.0, 1.0, 0.95))
		else:
			draw_circle(bp2, DUEL_BULLET_R + 14.0, glow_soft)
			draw_circle(bp2, DUEL_BULLET_R + 6.0, Color(bc.r, bc.g, bc.b, 0.25))
			draw_circle(bp2, DUEL_BULLET_R, bc)
			draw_circle(bp2, DUEL_BULLET_R * 0.5, Color(1.0, 1.0, 1.0, 0.9))
	# Rival fighters in their own colors, skipped once eliminated.
	for o in duel_foes.size():
		var f: Dictionary = duel_foes[o]
		if int(f.get("hp", 0)) <= 0:
			continue
		var fp: Vector2 = f.get("pos", Vector2.ZERO)
		var col: Color = _duel_foe_col(o)
		if mode == "play" or duel_over:
			_cast_shadow(fp, BALL_R)
			draw_circle(fp, BALL_R + 5.0, Color(col.r, col.g, col.b, 0.22))
			draw_circle(fp, BALL_R, col)
			_draw_smiley(fp, BALL_R)
			draw_circle(fp + Vector2(-BALL_R * 0.3, -BALL_R * 0.3), BALL_R * 0.28, Color(1.0, 1.0, 1.0, 0.30))
			draw_arc(fp, BALL_R + 5.0, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.8), 2.0)
			var fhp := clampf(float(f.get("hp", DUEL_HP)) / DUEL_HP, 0.0, 1.0)
			draw_rect(Rect2(fp + Vector2(-30.0, -34.0), Vector2(60.0, 6.0)), Color(0.0, 0.0, 0.0, 0.55))
			draw_rect(Rect2(fp + Vector2(-29.0, -33.0), Vector2(58.0 * fhp, 4.0)), col)
			_text_center_at(fp + Vector2(0.0, -40.0), _duel_foe_name(o), 11,
				Color(minf(col.r + 0.2, 1.0), minf(col.g + 0.1, 1.0), col.b, 0.9))
			if int(f.get("gun", 0)) > 0:
				# Aim at the nearest living rival (usually whoever is
				# watching this screen), so the gun visibly tracks a
				# target instead of freezing along stale velocity.
				var aim_at: Vector2 = fp + (f.get("vel", Vector2.RIGHT) as Vector2)
				var best := INF
				if int(duel_me.get("hp", 0)) > 0:
					best = fp.distance_squared_to(duel_me["pos"])
					aim_at = duel_me["pos"]
				for q in duel_foes.size():
					if q == o:
						continue
					var qf: Dictionary = duel_foes[q]
					if int(qf.get("hp", 0)) <= 0:
						continue
					var dd: float = fp.distance_squared_to(qf["pos"])
					if dd < best:
						best = dd
						aim_at = qf["pos"]
				_draw_gun_orbit(int(f.get("gun", 0)), fp, aim_at, 60.0)


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
	if mobile_controls and not stick_on:
		draw_arc(STICK_HOME, STICK_R, 0.0, TAU, 40, Color(1.0, 0.80, 0.30, 0.28), 2.0, true)
		draw_circle(STICK_HOME, 5.0, Color(1.0, 0.80, 0.30, 0.4))
		_text_center_at(STICK_HOME + Vector2(0.0, -100.0), "SHOOT", 13, Color(1.0, 0.85, 0.45, 0.55))
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
	_ui_panel(mm, 10.0, Color(0.03, 0.06, 0.12, 0.72))

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
	_text_center_at(Vector2(640.0, 46.0), "CUSTOMIZE", 26, UI_TEXT, bold_font)
	_ui_rule(62.0, 520.0, 760.0)
	var mp := get_viewport().get_mouse_position()
	_draw_custom_stage(mp)
	var hov_b := BTN_BACK.has_point(mp)
	var _back_rr := _ui_btn(BTN_BACK, hov_b, 10.0)
	_text_center_at(_back_rr.get_center() + Vector2(0.0, 6.0), "BACK", 18, UI_TEXT if hov_b else UI_SUB, bold_font)

	_menu_fade()


## Skin carousel: a sliding strip of skins eases across the screen on
## every swap, the one nearest center staging large. Arrow buttons, the
## side skins and the arrow keys all cycle.
func _draw_custom_stage(mp: Vector2) -> void:
	var n := _ball_total_skins()
	var p := clampf((t - custom_swap_t) / 0.28, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - p, 3.0)
	var slide := (1.0 - e) * float(custom_slide_dir) * 190.0
	var center_k := int(round(-slide / 190.0))
	for k in range(-3, 4):
		var idx := (ball_idx + k + n * 3) % n
		var x := 640.0 + float(k) * 190.0 + slide
		if x < 140.0 or x > 1140.0:
			continue
		var w := clampf(1.0 - absf(x - 640.0) / 480.0, 0.0, 1.0)
		if w <= 0.01:
			continue
		_draw_stage_skin(Vector2(x, 350.0), 44.0 + 52.0 * w, idx, 0.25 + 0.75 * w)
	var center_idx := (ball_idx + center_k + n * 3) % n
	_text_center_at(Vector2(640.0, 470.0), _skin_name(center_idx), 22, UI_TEXT, bold_font)
	_text_center_at(Vector2(640.0, 492.0), str(center_idx + 1) + " / " + str(n), 13, UI_SUB)
	_custom_arrow(CUSTOM_ARROW_L, "<", mp)
	_custom_arrow(CUSTOM_ARROW_R, ">", mp)


func _draw_stage_skin(c: Vector2, r: float, idx: int, alpha: float) -> void:
	draw_circle(c, r, Color(0.0, 0.0, 0.0, 0.40 * alpha))
	var face := _skin_face_tex(idx)
	if face != null:
		draw_texture_rect(face, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1.0, 1.0, 1.0, alpha))
	else:
		var col: Color = _skin_col(idx)
		draw_circle(c, r, Color(col.r, col.g, col.b, alpha))
		_draw_smiley(c, r, alpha)
	draw_circle(c + Vector2(-0.34, -0.40) * r, 0.31 * r, Color(1.0, 1.0, 1.0, 0.70 * alpha))
	draw_circle(c + Vector2(0.28, 0.40) * r, 0.11 * r, Color(1.0, 1.0, 1.0, 0.45 * alpha))
	draw_arc(c, r, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.90 * alpha), maxf(2.0, r * 0.06), true)
	if r > 55.0:
		draw_arc(c, r + 24.0, t * 0.8, t * 0.8 + PI * 1.4, 40, Color(0.43, 0.90, 1.0, 0.35 * alpha), 4.0, true)
		draw_arc(c, r + 36.0, -t * 0.6, -t * 0.6 + PI * 1.0, 40, Color(1.0, 0.77, 0.30, 0.30 * alpha), 3.0, true)


func _custom_arrow(r: Rect2, label: String, mp: Vector2) -> void:
	var hov := r.has_point(mp)
	var rr := _ui_btn(r, hov, 12.0)
	_text_center_at(rr.get_center() + Vector2(0.0, 8.0), label, 24, UI_TEXT if hov else UI_SUB, bold_font)


func _draw_settings() -> void:
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.015, 0.020, 0.045, 0.72))
	var panel := Rect2(340.0, 140.0, 600.0, 440.0)
	_ui_panel(panel)
	_text_center_at(Vector2(640.0, 188.0), "SETTINGS", 26, UI_TEXT, bold_font)
	_ui_rule(204.0, 400.0, 880.0)
	var mp := get_viewport().get_mouse_position()
	for i in SETTINGS_LABELS.size():
		var r := _settings_row_rect(i)
		var hov := r.has_point(mp)
		# Rows glide in from the right in list order on every arrival.
		r.position.x += (1.0 - _ui_ease_at(0.05 + float(i) * 0.05)) * 50.0
		var _rr := _ui_btn(r, hov, 8.0)
		_text(str(SETTINGS_LABELS[i]), Vector2(_rr.position.x + 20.0, _rr.position.y + 31.0), 18, UI_TEXT if hov else UI_SUB)
		var val := "ON" if _settings_on(i) else "OFF"
		_text_right(val, Vector2(_rr.end.x - 20.0, _rr.position.y + 31.0), 18, CYAN if _settings_on(i) else UI_SUB, true)
	_text_center_at(Vector2(640.0, 552.0), "mobile controls shows a fixed shooting joystick in versus", 13, UI_SUB)
	var hov_b := BTN_BACK.has_point(mp)
	var _back_rr := _ui_btn(BTN_BACK, hov_b, 10.0)
	_text_center_at(_back_rr.get_center() + Vector2(0.0, 6.0), "BACK", 18, UI_TEXT if hov_b else UI_SUB, bold_font)

	_menu_fade()


## Tutorial screen: the real controls for both modes, using the same
## panel + BACK language as CUSTOMIZE and SETTINGS. Reached from the
## HOW TO PLAY slot on the title menu (mouse, touch or H key).
func _draw_how() -> void:
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.015, 0.020, 0.045, 0.72))
	var panel := Rect2(340.0, 110.0, 600.0, 470.0)
	_ui_panel(panel)
	_text_center_at(Vector2(640.0, 160.0), "HOW TO PLAY", 26, UI_TEXT, bold_font)
	_ui_rule(176.0, 400.0, 880.0)
	_text_center_at(Vector2(640.0, 202.0), "SOLO", 13, GOLD, bold_font)
	_rule(230.0, "HOLD CLICK / SPACE", "charge the launch - time slows while you aim")
	_rule(256.0, "RELEASE", "fire toward the cursor - longer hold = more power")
	_rule(282.0, "HIT BALLS FAST", "speed shatters them - slow touches bounce off")
	_text_center_at(Vector2(640.0, 322.0), "VERSUS DUEL", 20, GOLD, bold_font)
	_rule(350.0, "RMB / F / SPACE", "shoot the held gun - every shot kicks you back")
	_rule(376.0, "BREAK CHESTS", "instant gun: assault, blaster, laser, railgun")
	_rule(402.0, "SMASH BALLS", "reloads your launch - spiky gold needs speed")
	_rule(428.0, "LAVA + SPIKES", "molten floor burns (15/s) - 100 HP each")
	_rule(454.0, "R / B", "rematch / back to menu after a match")
	var mp := get_viewport().get_mouse_position()
	var hov_b := BTN_BACK.has_point(mp)
	var _back_rr := _ui_btn(BTN_BACK, hov_b, 10.0)
	_text_center_at(_back_rr.get_center() + Vector2(0.0, 6.0), "BACK", 18, UI_TEXT if hov_b else UI_SUB, bold_font)

	_menu_fade()


func _net_button(r: Rect2, label: String, mp: Vector2) -> void:
	var hov := r.has_point(mp)
	# Lobby buttons glide up in column order on every arrival.
	var e := _ui_ease_at(0.05 + clampf((r.position.y - 232.0) / 120.0, 0.0, 3.0) * 0.06)
	var base := Rect2(r.position + Vector2(0.0, (1.0 - e) * 30.0), r.size)
	var rr := _ui_btn(base, hov, 10.0)
	var fs := 20 if rr.size.x > 200.0 else 17
	_text_center_at(rr.get_center() + Vector2(0.0, 7.0), label, fs, UI_TEXT if hov else UI_SUB, bold_font)


## Editable display-name field. The YOU placeholder lives inside the box
## until you type; the host files the real name at match start and FOE
## labels fill in for rivals who skipped theirs. The big box lives on
## the menu/join screens; the small bare one on the host/ready screens.
func _draw_name_field(rect: Rect2) -> void:
	if name_edit != null and name_edit.visible:
		return  # the real LineEdit is showing; it draws the box + text itself
	draw_style_box(_ui_box(Color(0.06, 0.13, 0.24, 0.9), CYAN if name_focused else UI_LINE, 8.0, 2.0 if name_focused else 1.5), rect)
	var caret := "_" if name_focused and int(t * 2.0) % 2 == 0 else ""
	var big := rect.size.y > 34.0
	var cy := rect.get_center().y + (8.0 if big else 6.0)
	if duel_my_name != "":
		_text_center_at(Vector2(640.0, cy), duel_my_name + caret, 22 if big else 17, WHITE, bold_font)
	else:
		_text_center_at(Vector2(640.0, cy), "YOU" + caret, 22 if big else 17, DIM, bold_font)


func _draw_name_box() -> void:
	_draw_name_field(NET_NAME_RECT)


## Map roulette gets its own full screen, not the lobby panel: no lobby
## chrome, no BACK button, nothing host-menu behind it.
func _draw_roulette(mp: Vector2) -> void:
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.008, 0.012, 0.030, 0.94))
	_text_center_at(Vector2(640.0, 108.0), "MAP ROULETTE", 30, UI_TEXT, bold_font)
	_ui_rule(126.0, 520.0, 760.0)
	var roff := _roulette_offset()
	var rcen := _roulette_center()
	for i in roulette_strip.size():
		var cx := 640.0 + float(i) * ROULETTE_PITCH + roff
		if cx < -220.0 or cx > 1500.0:
			continue
		_roulette_card(Rect2(cx - 150.0, 200.0, 300.0, 280.0), int(roulette_strip[i]), i == rcen)
	for sx in [-1.0, 1.0]:
		var bx: float = 640.0 + (sx as float) * 162.0
		draw_line(Vector2(bx, 190.0), Vector2(bx - sx * 26.0, 190.0), GOLD, 4.0, true)
		draw_line(Vector2(bx, 490.0), Vector2(bx - sx * 26.0, 490.0), GOLD, 4.0, true)
	if roulette_t <= 0.0:
		_text_center_at(Vector2(640.0, 556.0), _duel_map_name(roulette_win), 44, GOLD, bold_font)
		_text_center_at(Vector2(640.0, 602.0), "GET READY!", 18, DIM)
	else:
		_text_center_at(Vector2(640.0, 580.0), "spinning...", 18, DIM)
	_text_center_at(Vector2(640.0, 700.0), "online versus - last fighter standing wins", 12, Color(0.45, 0.60, 0.80, 0.55))


func _draw_net() -> void:
	var mp := get_viewport().get_mouse_position()
	if net_screen == "roulette":
		_draw_roulette(mp)
		return
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.015, 0.020, 0.045, 0.72))
	var panel := Rect2(340.0, 140.0, 600.0, 440.0)
	_ui_panel(panel)
	_text_center_at(Vector2(640.0, 188.0), "MULTIPLAYER", 26, UI_TEXT, bold_font)
	_ui_rule(204.0, 400.0, 880.0)
	if net_screen == "menu":
		if OS.has_feature("web"):
			_text_center_at(Vector2(640.0, 308.0), "HOSTING NEEDS THE DESKTOP BUILD", 18, DIM)
			_net_button(BTN_NET_JOIN, "JOIN GAME", mp)
			_draw_name_box()
			if net_status != "":
				_text_center_at(Vector2(640.0, 470.0), net_status, 15, RED)
			else:
				_text_center_at(Vector2(640.0, 470.0), "paste the ws:// address your desktop host copied", 14, DIM)
		else:
			_net_button(BTN_NET_HOST, "HOST (PC)", mp)
			_net_button(BTN_NET_HOST_WS, "HOST (WEB)", mp)
			_net_button(BTN_NET_JOIN, "JOIN GAME", mp)
			_draw_name_box()
			if net_status != "":
				_text_center_at(Vector2(640.0, 470.0), net_status, 15, RED)
			else:
				_text_center_at(Vector2(640.0, 470.0), "host pc = desktop rivals  ·  host web = browser rivals can join", 14, DIM)
	elif net_screen == "join":
		_text_center_at(Vector2(640.0, 250.0), "ENTER WS ADDRESS" if (net_transport == "ws" or OS.has_feature("web")) else "ENTER HOST IP", 18, DIM)
		if ip_edit == null or not ip_edit.visible:
			draw_rect(NET_IP_RECT, Color(0.06, 0.13, 0.24, 0.9))
			draw_rect(NET_IP_RECT, CYAN if join_focused else Color(0.42, 0.66, 1.0, 0.5), false, 2.0)
			var caret := "_" if join_focused and int(t * 2.0) % 2 == 0 else ""
			_text_center_at(Vector2(640.0, 312.0), join_ip + caret, 24, WHITE, bold_font)
		_net_button(BTN_NET_JOIN, "JOIN" if net_transport == "enet" and not OS.has_feature("web") else "JOIN WEB", mp)
		_draw_name_box()
		# Skin detour: full CUSTOMIZE screen, then straight back here.
		_net_button(BTN_NET_CUSTOM, "CUSTOMIZE", mp)
		if OS.has_feature("web"):
			_text_center_at(Vector2(640.0, 486.0), "websocket link - paste the ws:// address", 13, DIM)
		else:
			_net_button(BTN_NET_PROTO, "LINK: PC" if net_transport == "enet" else "LINK: WEB", mp)
		if net_status != "":
			_text_center_at(Vector2(640.0, 460.0), net_status, 16, RED)
	elif net_screen == "host":
		_draw_name_field(NET_NAME_RECT_SM)
		_text_center_at(Vector2(640.0, 278.0), "HOSTING ON - CLICK AN ADDRESS TO COPY IT", 16, DIM)
		var ips := _net_host_addrs()
		net_ip_rects.clear()
		for i in mini(ips.size(), 4):
			var big := i == 0
			var entry: Dictionary = ips[i]
			var line := str(entry["copy"])
			var shown := line if str(entry["label"]) == "" else "%s  (%s)" % [line, str(entry["label"])]
			var yp := 320.0 + i * 34.0
			_text_center_at(Vector2(640.0, yp), shown, 26 if big else 19, WHITE if big else DIM, bold_font)
			net_ip_rects.append({"rect": Rect2(640.0 - 220.0, yp - 16.0, 440.0, 32.0), "text": shown, "copy": line})
		if t - net_copied_at < 1.5:
			_text_center_at(Vector2(640.0, 344.0 + maxi(0, mini(ips.size(), 4) - 1) * 34.0), "COPIED!", 16, Color(0.5, 1.0, 0.6))
		var rivals := multiplayer.get_peers().size()
		_text_center_at(Vector2(640.0, 334.0 + mini(ips.size(), 4) * 34.0), "waiting for rivals... (%d in lobby)" % rivals, 18, Color(0.85, 0.97, 1.0, 0.5 + 0.5 * sin(t * 4.0)))
		if net_transport == "ws":
			_text_center_at(Vector2(640.0, 364.0 + mini(ips.size(), 4) * 34.0), "RIVAL STUCK? ALLOW TCP 7777 - HTTPS PAGES NEED WSS, USE HTTP OR DESKTOP", 13, DIM)
		else:
			_text_center_at(Vector2(640.0, 364.0 + mini(ips.size(), 4) * 34.0), "RIVAL STUCK ON CONNECTING? ALLOW UDP 7777 IN WINDOWS FIREWALL", 13, DIM)
		_net_button(BTN_NET_ROLE, "HOST FIGHTS" if duel_host_plays else "HOST SPECTATES", mp)
		_draw_host_qr()
	elif net_screen == "ready":
		if net_mode == "host":
			_draw_name_field(NET_NAME_RECT_SM)
			_text_center_at(Vector2(640.0, 290.0), "READY TO PLAY (%d)" % _duel_roster().size(), 26, CYAN, bold_font)
			_draw_lobby_roster(640.0, 320.0)
			_net_button(BTN_NET_ROLE2, "HOST FIGHTS" if duel_host_plays else "HOST SPECTATES", mp)
			_net_button(BTN_START, "START", mp)
		else:
			_draw_name_field(NET_NAME_RECT_SM)
			_text_center_at(Vector2(640.0, 300.0), "RIVAL FOUND", 26, CYAN, bold_font)
			_text_center_at(Vector2(640.0, 400.0), "waiting for host to start...", 18, DIM)
	elif net_screen == "countdown":
		_text_center_at(Vector2(640.0, 360.0), str(maxi(int(ceil(net_count)), 1)), 96, WHITE, bold_font)
	_net_button(BTN_BACK, "BACK", mp)
	_menu_fade()


## 0-to-1 ease-out for menu entrances, with a per-element delay so rows
## and buttons cascade in instead of popping all at once.
func _ui_ease_at(delay: float, dur: float = 0.35) -> float:
	var p := clampf((ui_t - delay) / maxf(dur, 0.01), 0.0, 1.0)
	return 1.0 - pow(1.0 - p, 3.0)


## Full-screen fade that lifts as a fresh menu settles in. Called last so
## every menu shares the same soft landing.
func _menu_fade() -> void:
	var a := (1.0 - _ui_ease_at(0.0, 0.30)) * 0.45
	if a > 0.004:
		draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.0, 0.0, 0.0, a))


## Rounded-box cache: one StyleBoxFlat per fill/line/radius/width combo so
## panels and buttons share geometry without allocating every frame.
func _ui_box(fill: Color, line: Color, radius: float, width: float = 1.5) -> StyleBoxFlat:
	var key := "%s|%s|%.1f|%.1f" % [fill.to_html(), line.to_html(), radius, width]
	if _ui_styles.has(key):
		return _ui_styles[key] as StyleBoxFlat
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(radius))
	sb.set_border_width_all(int(maxi(1, int(round(width)))))
	sb.border_color = line
	sb.shadow_color = UI_SHADOW
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	_ui_styles[key] = sb
	return sb


## Card panel: soft drop shadow + fill + hairline in one call.
func _ui_panel(r: Rect2, radius: float = 14.0, fill: Color = UI_PANEL) -> void:
	draw_style_box(_ui_box(fill, UI_LINE, radius), r)


## Menu button: same card language, brighter fill on hover plus a left
## accent bar when active. Text is drawn by the caller for label control.
func _ui_btn(r: Rect2, hover: bool, radius: float = 10.0, active: bool = false) -> Rect2:
	var rr := r
	if hover:
		rr = r.grow(1.0)
	var fill := UI_PANEL_SOFT if hover else UI_PANEL
	draw_style_box(_ui_box(fill, UI_LINE_STRONG if (hover or active) else UI_LINE, radius, 2.0 if (hover or active) else 1.5), rr)
	if active:
		draw_rect(Rect2(rr.position + Vector2(8.0, 10.0), Vector2(3.0, rr.size.y - 20.0)), CYAN)
	return rr


## Small section label used across menus: uppercase, tracked-out feel via
## spaces is avoided; single size/color keeps hierarchy quiet.
func _ui_label(s: String, pos: Vector2, size: int = 12) -> void:
	_text(s, pos, size, UI_SUB)


## Thin divider line with soft alpha, for separating logo / buttons / bar.
func _ui_rule(y: float, x0: float = 110.0, x1: float = 410.0) -> void:
	draw_line(Vector2(x0, y), Vector2(x1, y), Color(0.42, 0.66, 1.0, 0.22), 1.0)


## BO3-style front end in game theme: logo + vertical menu down the left,
## the bouncy ball as the center character, control bar along the bottom.
## Cartoon read comes from chunky outlines, the gloss shine and the bob.
func _draw_title() -> void:
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.015, 0.020, 0.045, 0.58))
	var mp := get_viewport().get_mouse_position()
	_draw_title_ball()
	# Logo with a soft cyan ghost behind it for the arcade-cabinet glow.
	# It drifts up into place and breathes gently once settled.
	var le := _ui_ease_at(0.0)
	var ly := (1.0 - le) * -26.0 + sin(t * 1.6) * 3.0
	var bw := bold_font.get_string_size("BALLS ", HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
	_text("BALLS ", Vector2(110.0, 156.0 + ly), 64, Color(UI_TEXT.r, UI_TEXT.g, UI_TEXT.b, le), true)
	_text("OF DUTY", Vector2(110.0 + bw, 156.0 + ly), 64, Color(GOLD.r, GOLD.g, GOLD.b, le), true)
	if le > 0.02:
		draw_line(Vector2(112.0, 172.0 + ly), Vector2(408.0, 172.0 + ly), Color(0.42, 0.66, 1.0, 0.25 * le), 1.5)
	# The browser build can't quit the window, so QUIT is dropped and
	# HOW TO PLAY slides up into its slot to keep the column packed.
	var web := OS.has_feature("web")
	var btns: Array = [TITLE_PLAY, TITLE_MULTI, TITLE_CUSTOM, TITLE_SETTINGS, TITLE_QUIT, TITLE_HOW]
	var labels: Array = ["PLAY", "MULTIPLAYER", "CUSTOMIZE", "SETTINGS", "QUIT", "HOW TO PLAY"]
	if web:
		btns = [TITLE_PLAY, TITLE_MULTI, TITLE_CUSTOM, TITLE_SETTINGS, TITLE_QUIT]
		labels = ["PLAY", "MULTIPLAYER", "CUSTOMIZE", "SETTINGS", "HOW TO PLAY"]
	var hov_idx := -1
	for i in btns.size():
		if (btns[i] as Rect2).has_point(mp):
			hov_idx = i
	if hov_idx >= 0:
		title_last = hov_idx
	var sel := hov_idx if hov_idx >= 0 else title_last
	for i in btns.size():
		_title_button(btns[i], labels[i], mp, sel == i)
	_menu_fade()


## Left-column menu row: one card language, quiet idle, clear selected.
func _title_button(r: Rect2, label: String, mp: Vector2, selected: bool) -> void:
	# Buttons sweep in from the left in column order on every arrival.
	var e := _ui_ease_at(clampf((r.position.y - 196.0) / 50.0, 0.0, 4.0) * 0.06)
	var base := Rect2(r.position + Vector2((1.0 - e) * -60.0, 0.0), r.size)
	var on := selected or r.has_point(mp)
	var rr := _ui_btn(base, on, 10.0, selected)
	_text(label, rr.position + Vector2(28.0, 40.0), 24, UI_TEXT if on else UI_SUB, true)


## The bouncy ball as the center character: current skin (photo faces
## included), thick cartoon outline, gloss shine, slow orbiting rings,
## squash-and-stretch idle bob and a cursor-tracking assault rifle held
## proportional to the ball radius.
func _draw_title_ball() -> void:
	# The ball drops in from above, then keeps its idle bob.
	var R := 140.0
	var be := _ui_ease_at(0.0, 0.45)
	var bob := sin(t * 2.0) * 12.0
	var c := Vector2(830.0, 390.0 + bob + (1.0 - be) * 140.0)
	draw_arc(c, R + 42.0, t * 0.7, t * 0.7 + PI * 1.2, 32, Color(0.43, 0.90, 1.0, 0.35), 6.0, true)
	draw_arc(c, R + 70.0, -t * 0.5, -t * 0.5 + PI * 0.9, 32, Color(1.0, 0.77, 0.30, 0.30), 5.0, true)
	# Squash and stretch, synced to the bob: stretched while travelling,
	# round at the top and bottom of each stroke.
	var stretch := cos(t * 2.0) * 0.03
	draw_set_transform(c, 0.0, Vector2(1.0 + stretch, 1.0 - stretch))
	draw_circle(Vector2.ZERO, R, Color(0.0, 0.0, 0.0, 0.45))
	var face := _ball_face_tex()
	if face != null:
		draw_texture_rect(face, Rect2(Vector2(-R, -R), Vector2(R * 2.0, R * 2.0)), false)
	else:
		draw_circle(Vector2.ZERO, R, _ball_col())
		_draw_smiley(Vector2.ZERO, R)
	# Gloss shine breathes with the same idle clock.
	var shine := 0.65 + 0.25 * sin(t * 2.0 + 1.2)
	draw_circle(Vector2(-R * 0.345, -R * 0.40), R * 0.31, Color(1.0, 1.0, 1.0, shine))
	draw_circle(Vector2(R * 0.27, R * 0.40), R * 0.11, Color(1.0, 1.0, 1.0, 0.35 + 0.2 * shine))
	draw_arc(Vector2.ZERO, R, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.9), 7.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_title_gun(c)


## Menu mascot gun: the assault-rifle sprite, uniformly scaled so its
## length stays proportional to the title-ball radius, held off the
## ball edge with a clear gap and aimed at the cursor with a small idle sway.
func _draw_title_gun(c: Vector2) -> void:
	if duel_gun_texs.size() < 2:
		return
	var tex: Texture2D = duel_gun_texs[1]
	if tex == null:
		return
	var ts := tex.get_size()
	if ts.x <= 0.0 or ts.y <= 0.0:
		return
	var mp := get_viewport().get_mouse_position()
	var d := mp - c
	if d.length() < 4.0:
		d = Vector2.RIGHT
	var ang := d.angle() + sin(t * 2.3) * 0.035
	var gun_len := 140.0 * 1.55
	var sc := gun_len / ts.x
	var grip := c + Vector2.from_angle(ang) * 172.0
	var flip := cos(ang) < 0.0
	# The sprite's barrel is baked in 45 deg up-right, so cancel that out
	# (mirrored when flipped) to make the muzzle sit on the aim line.
	var fix := PI / 4.0 if not flip else -PI / 4.0
	draw_set_transform(grip, ang + fix, Vector2(sc, -sc if flip else sc))
	draw_texture(tex, Vector2(-ts.x * 0.30, -ts.y * 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var tip := grip + Vector2.from_angle(ang) * gun_len * 0.70
	var glint := 0.35 + 0.25 * sin(t * 5.0)
	draw_circle(tip, 3.0, Color(1.0, 0.85, 0.4, glint))


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
		_ui_panel(Rect2(380.0, 190.0, 520.0, 330.0), 16.0)
		_text_center_at(Vector2(640.0, 248.0), headline, 40, UI_TEXT, bold_font)
		_ui_rule(266.0, 480.0, 800.0)
	if net_mode != "off" and duel_over:
		var i_won := duel_winner == duel_my_id
		var dh := "YOU WIN" if i_won else ("DRAW" if duel_winner < 0 else "YOU LOSE")
		var sub := "%s  %d HP" % [_duel_my_name(), int(duel_me.get("hp", 0))]
		if duel_my_id < 0:
			sub = "SPECTATED MATCH"
			if duel_winner >= 0:
				dh = "%s WINS" % _duel_winner_name()
		_ui_panel(Rect2(380.0, 190.0, 520.0, 340.0), 16.0)
		_text_center_at(Vector2(640.0, 248.0), dh, 40, UI_TEXT, bold_font)
		_text_center_at(Vector2(640.0, 330.0), sub, 30, UI_TEXT, bold_font)
		var oy := 372.0
		for o in duel_foes.size():
			_text_center_at(Vector2(640.0, oy), "%s  %d HP" % [_duel_foe_name(o), int((duel_foes[o] as Dictionary).get("hp", 0))], 20, CYAN)
			oy += 36.0
		var pulse2 := 0.6 + 0.4 * sin(t * 4.0)
		_text_center_at(Vector2(640.0, 610.0), "R rematch   ·   B menu", 12, Color(UI_SUB.r, UI_SUB.g, UI_SUB.b, 0.55 * pulse2 + 0.2))
		return
	_text_center_at(Vector2(640.0, 300.0), "SCORE", 12, UI_SUB)
	_text_center_at(Vector2(640.0, 368.0), str(score), 56, UI_TEXT, bold_font)
	_text_center_at(Vector2(640.0, 412.0), "SMASHED %d" % kills, 18, CYAN)
	if net_mode != "off":
		_text_center_at(Vector2(640.0, 438.0), "FOE  %d" % foe_score, 15, CYAN)
	if new_best:
		_text_center_at(Vector2(640.0, 466.0), "NEW BEST!", 16, GOLD, bold_font)
	elif best > 0:
		_text_center_at(Vector2(640.0, 466.0), "BEST  %d" % best, 15, UI_SUB)
	var pulse := 0.6 + 0.4 * sin(t * 4.0)
	if net_mode == "off":
		_text_center_at(Vector2(640.0, 560.0), "CLICK TO PLAY AGAIN", 18, Color(UI_TEXT.r, UI_TEXT.g, UI_TEXT.b, pulse))
	else:
		_text_center_at(Vector2(640.0, 610.0), "R rematch   ·   B menu", 12, UI_SUB)


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
	var kw := bold_font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var dw := body_font.get_string_size(desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var total := kw + 20.0 + dw
	var x := 640.0 - total * 0.5
	draw_string(bold_font, Vector2(x, y), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, CYAN)
	draw_string(body_font, Vector2(x + kw + 20.0, y), desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI_SUB)
