# Neon Court

An original pixel-style 3-on-3 basketball prototype for Godot 4.3 or newer. Inspired by the readable arcade courts of Hoop Land and the timing, spacing, and possession play of basketball sims. No NBA, NBA 2K, or Hoop Land assets are included.

## Play

Import `project.godot` in Godot and press **F6** with `main.tscn` open, or **F5** to run the project. Press **Enter** on the title screen.

| Key | Action |
| --- | --- |
| WASD / arrows | Move the selected Night Owls player |
| Shift | Sprint; uses the stamina bar below your player |
| Hold Space, release | Shoot; release when the marker crosses green (0.7 seconds) |
| E | Pass toward your movement direction; without a direction, favor an open teammate |
| E without possession | Switch to a teammate near the ball / cycle |
| Q | Attempt a close steal or early shot block |
| Escape | Pause / resume |

The teal Night Owls attack the right basket. The pink Sunset Club attacks left. An open perfect release inside reasonable shooting range goes in; distance and defensive pressure affect other attempts. Shots beyond the arc score three. Close shots become dunks. Misses create loose-ball rebounds. Four 90-second quarters, 24-second possessions, 14-second offensive rebound resets, and 45-second overtime periods.

## Included

- Procedurally drawn pixel players, wood court, audience, scoreboard, shot meter, and title screen.
- Directional passes, automatic receiver selection, off-ball spacing, opponent pursuit and shooting.
- Body separation, steal/block cooldown, sprint stamina, rebounds, two/three-point scoring.
- Synthesized sound effects, basket particles, pause and rematch.
- Self-contained project: no downloads, plugins, or external assets required.

## Scope

This is a playable foundation, not a full NBA 2K-scale simulation. Local single-player keyboard play only. No licensed teams, career/franchise mode, online multiplayer, fouls/free throws, out-of-bounds rules, or controller support yet. Teams keep their basket for all quarters. Opponents currently drive and shoot; passing is player-controlled.

## Verify

```sh
godot --headless --path . --script res://tests/match_test.gd
```

The deterministic match tests cover passing, shot timing and scoring, possession, rebounds, shot-clock violations, quarters, overtime, final results, and a five-minute AI simulation with court-bound assertions.

## Project layout

`game.gd` contains game state, input, AI, procedural rendering, and synthesized sound. `main.tscn` is the entry scene. The logical viewport is 640×360, scaled to a 1280×720 window with nearest filtering.
