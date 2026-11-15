# Bounce Back

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
| Right mouse / F | Shoot equipped gun toward cursor (versus duel) |
| R | Restart (rematch in versus) |
| B | Back to menu (versus game-over) |
| M | Mute |
| Esc | Quit |

## Multiplayer versus

Title → MULTIPLAYER: one player HOSTs, the other JOINs with the host's IP
(port 7777, or `IP:port` for a custom port). Versus is a duel in a sharedarena: every fighter has 100 HP, slams into chests to break them, grabs
PISTOL then SPREAD pickups, and shoots the rivals (RMB or F toward the
cursor). Up to 4 players (host + 3) share one arena — knock everyone
else out, or hold the most HP when the 60s clock runs out, to win.
Knocked-out fighters spectate while the rest finish. Pink/green balls
also spawn — smashing one heals +6 HP and reloads your launch
(one bounce per ball smashed). If joining hangs, it fails after ~12s: use an address from the host's
list that shares your LAN, and allow the game through the Windows firewall
(UDP port 7777).

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
const SLOWMO := 0.30          # world speed while aiming
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
