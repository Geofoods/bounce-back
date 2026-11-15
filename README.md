# Balls of Duty

A scrolling arcade game built for the "bounce back" jam theme. You are a
bouncy ball. Hold to charge, release to launch yourself toward the cursor, and
ricochet around a world many screens wide to shatter balls before the timer runs
out.

Everything is drawn in code — no images, fonts, or audio assets.

## Run it

Open the folder in **Godot 4.7** and press F5, or from a terminal:

```
godot --path . 
```

`main.tscn` is set as the main scene.

## Controls

| Input | Action |
| --- | --- |
| Hold left mouse | Charge a launch (time slows down while you aim) |
| Release | Fire toward the cursor; hold longer = more power |
| Space | Same as mouse, for keyboard play |
| Right mouse / F / Space (with gun) | Shoot equipped gun toward cursor (versus duel) - every shot kicks you backwards |
| Customize > MOBILE | Fixed shooting joystick in versus (mouse or touch). Auto-enabled on phone; auto-disabled on desktop. |
| Touch: 1 finger | Same as left mouse — hold to charge, release to fire |
| Touch: gun stick | 2nd finger plants a stick — push to aim, hold to shoot |
| R | Restart (rematch in versus) |
| B | Back to menu (versus game-over) |
| M | Mute |
| Esc | Quit |

## Multiplayer versus

Title → MULTIPLAYER: one player HOSTs, the other JOINs with the host's IP
(port 7777, or `IP:port` for a custom port). Type your display name in
the YOUR NAME box first (blank stays YOU, rivals who skip it show as
FOE) — names ride with the roster and show over fighters, in the
corners, and on the winners screen. Versus is a duel in a sharedarena: every fighter has 100 HP. Breaking a chest instantly equips
one of 4 guns — rapid ASSAULT, 5-pellet BLASTER scatter, piercing LASER bolt, or a siege RAILGUN slug that punches through fighters and crates — no pickup walk-over. Fresh crates drop
into the arena every few seconds.The molten floor burns fighters that touch it (15 damage per second). Shoot the rivals (RMB, F or Space toward the cursor). Any number of fighters share one arena (rivals join freely; the host may also sit out and spectate) — knock everyone
else out to win — only the last fighter standing takes it. If the 60s clock runs out with two or more fighters alive, the round is a draw. Hitting START spins a Fall-Guys-style map roulette: five arenas (OPEN FIELD, PILLARS, CROSSROADS, TWIN GATES, STAR FORT) scroll past and land on a random one — simple polygonic slabs everyone collides with, drawn in neon, with spawns, balls, crates and bullets all playing around them.
If you die while the round goes on, you spectate: the camera follows the
remaining fighters until someone wins. The host can also sit out entirely
with the HOST FIGHTS / HOST SPECTATES toggle in the lobby. Edge arrows point
at off-screen rivals. Pink/green balls also spawn — smashing one
reloads your launch (gold spiky balls need a fast hit — slow
touches burn)
(one bounce per ball smashed). The host just clicks an address in their list
to copy it for the rival (each address shows its adapter, best first -
skip VPN/virtual ones). Both PCs must be on the same network, and the host
must allow the game through the Windows firewall (UDP port 7777).
If joining hangs, it fails after ~12s. Browser players can join too:
the desktop host picks HOST (WEB), clicks the `ws://...` address to
copy it, and the browser rival pastes it on the JOIN screen (browsers
cannot host, and `ws://` needs an `http://` page — `https://` pages
need `wss://` instead). Mid-match the netcode favors staying
in: snapshots are small (fighters + packed bullets 20 Hz, balls 10 Hz,
~550 Kbps) and ENet waits out long WiFi hiccups before dropping anyone.
Green drifters also ship their velocity, so joiners glide them locally
at full frame rate instead of jump-cutting between snapshots.
Your own shots, pickups and chest breaks predict instantly on your
screen (the host verdict lands ~50 ms later), and rival gunfire
flashes its muzzle on arrival.
Inputs send unreliably, so one dropped packet costs one shot instead of
stalling every shot; launches echo twice so a lost packet can't strand
you, and stale out-of-order snapshots are ignored. If your link does degrade, the
client shows CONNECTION UNSTABLE with the current ping instead of freezing
silently; a real drop says HOST DISCONNECTED. If drops keep happening:
use the same WiFi band on both PCs, move closer to the router, or test over
a phone hotspot to rule out the router.

## How it plays

- **Touch smashes plain balls.** Basic, drifter and chaser balls break on any
  contact, fast or slow. Spiked balls still demand speed — a slow touch kills.
- **Charging costs time.** The level clock keeps running in real time, even
  while the world is in slow motion, so lining up a shot is a trade-off.
- **Aim is a straight line only.** The guide shows direction and charge length,
  never where the ball will bounce — reading the bank shot is on you.
- **Bumpers add energy.** Hitting a bumper speeds you up, which is how you
  reach armored targets that need a very fast impact.
- **Combos.** Kills within 2.4s of each other raise your multiplier (up to x4).
- **The world is bigger than the screen.** The camera follows your ball as it
  flies, and the rolling minimap in the corner shows the balls waiting beyond
  the edges of the view. Every kill respawns a ball somewhere off-screen, so
  there is always something new to chase. Each kill adds time.

Ball types:

- **Pink** — basic, breaks at 240+ speed.
- **Gold, dashed ring** — armored, needs a fast hit (900+ and rising as you
  smash more). Its ring turns green when your current charge is enough.
- **Purple arrow** — chaser, slowly homes in on you. Easy to pop, but it gets
  in the way of your shots.
- **Green** — drifter, wanders across the world and bounces off the walls.

## Tuning

All the feel knobs are constants at the top of `scripts/game.gd`:

```gdscript
const WORLD := Rect2(0, 0, 3840, 2560)  # ~9 screens of playfield
const TARGET_POP := 130       # balls alive in the world at once
const CAM_LERP := 4.6         # how tightly the camera chases the ball
const CAM_LOOKAHEAD := 0.26   # how far ahead of the ball it leads
const MIN_POWER := 470.0      # tap launch speed
const MAX_POWER := 1750.0     # full charge launch speed
const CHARGE_TIME := 0.8      # seconds to full charge
const SLOWMO := 0.39          # world speed while aiming (1.3x slower than original 0.30)
const WORLD_SCALE := 1.0 / 1.2  # game speed factor: <1 = slower (1.2x slower)
const WALL_REST := 0.97       # wall bounciness
const BUMPER_REST := 1.06     # >1 means bumpers add speed
const SPEED_RETAIN := 0.87    # fraction of speed kept each second
const KILL_SPEED := 240.0     # basic target break threshold
```

World population and spawning live in `_populate_world()` / `_spawn_target()`;
scoring and respawns live in `_kill_target()`.

## Structure

```
project.godot        main scene + 1280x720 canvas stretch
main.tscn            single Node2D running the game
scripts/game.gd      state, physics, scrolling camera, spawning, drawing, audio synth
```

`boss fight.tscn` and `main menu.tscn` were left untouched.

## Jam stretch goals

- A boss that armor-plates itself and must be hit from behind.
- A "bounce back" mechanic where enemy shots reflect off your ball.
- Screen-space trails / chromatic aberration for max juice.
- Controller support (right stick aims, trigger charges).
