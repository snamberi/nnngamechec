# Neon Court — v0.2

Original pixel-style 3-on-3 basketball for **Godot 4.3+**. The Handles + Team Play update adds dribble moves, directional finishes, coordinated team AI, and procedural pixel-player animation. Tested with Godot 4.7.2 on Windows.

## Play

Clone this repository (or run `git pull origin main` in your existing clone), import `project.godot` into Godot, and press **F5**. Press **Enter** to start. On the title screen, press **T** to choose a Balanced, Pressure, or Perimeter opponent.

The teal Night Owls attack right. The pink Sunset Club attacks left. Four 90-second quarters; 24-second possessions; two/three-point scoring; rebounds; 45-second overtime until the tie is broken. Teams keep their baskets throughout the match.

## Controls

| Key | Action |
| --- | --- |
| WASD / arrows | Move; input also aims passes and chooses close finishes |
| Shift | Sprint, spending stamina; hold during a close shot for a dunk |
| Hold Space, release | Shoot; aim for green at 0.7 seconds |
| Tap Space (under 0.16 seconds) / V | Pump fake; a nearby grounded defender bites briefly |
| Z | Crossover: switch hands and burst sideways |
| X | Spin toward input, or toward the basket while stationary |
| C | Step back away from the basket |
| E | Pass toward input / prefer an open teammate; without possession, switch player |
| R | Call a teammate to set a screen, then roll to the rim |
| F | Give-and-go: pass and send the passer on a basket cut; E returns the pass |
| Q | Close steal attempt / early shot block |
| H | Pause and open the full controls guide |
| Escape | Pause / resume; close the controls guide |
| Enter after final | Rematch |
| T on title or final | Change opponent style |

### Handles and finishing

Moves cost stamina and have cooldowns. Crossovers cost 12%, spins 23%, step-backs 18%, and pump fakes 7%. Moves create separation over time, not instant teleports. Momentum and fatigue lower ordinary jump-shot accuracy; stop and find space before shooting. An open perfect release within 245 court units is guaranteed for a jumper.

Inside 49 court units, a normal shot becomes a layup. Hold a direction **away from the hoop** on release for a reverse. Hold Shift with enough stamina for a **two-hand dunk**, or add up/down input for a **tomahawk**. Dunks cost 24% stamina; tired players use layups. Shots between 49 and 95 units use a high-arcing floater. Outside 160 units, baskets count for three. Timing and defensive pressure still matter for close finishes.

### Team play

- **Pick-and-roll:** R calls the nearest teammate to a marked screen spot. The teammate sets their feet, obstructs nearby defenders, and rolls to the basket. Use the opening, then pass to the roller.
- **Give-and-go:** F passes, hands control to the receiver, and sends the passer on a timed cut. Aim and press E for a return pass.
- **Off-ball AI:** wings space out, cutters attack the back door, and teammates run lanes after a steal or defensive rebound.
- **Defense:** nearest defenders take the ball, others rotate onto uncovered players, and weak-side help collapses on drives. Bad passes can be intercepted.
- **Opponent styles:** Balanced drives, passes, and screens; Pressure attempts steals more aggressively and closes tighter; Perimeter seeks outside shots and swings the ball.

### Visual update

Larger pixel players have different hairstyles and skin tones, jersey trim, socks, shoes, wristbands, directional faces, and articulated arms and legs. Separate poses cover dribbling, spins, screening, passes, pump fakes, shots, blocks, layups, and two dunk styles. Movement trails, jump shadows, an original owl court crest, reserves on benches, a sideline official, and celebrating spectators round out the arena. All art is drawn from code; no external asset or plugin downloads are required.

## Tests

Run from the project directory (replace `godot` with your executable if needed):

```sh
godot --headless --path . --script res://tests/match_test.gd
godot --headless --path . --script res://tests/upgrades_test.gd
godot --headless --path . --script res://tests/input_test.gd
```

Match tests cover scoring, rebounds, possession, quarters, overtime, and a five-minute simulation. Upgrade checks cover controls, stamina, move cooldowns, finishes, screens/rolls, cuts, interceptions, defensive assignments, pause, and 100-second simulations for each opponent style. Input checks exercise Godot's real key handling and fixed-step movement.

## Files

- `game.gd`: match state, fixed-step movement, controls, scoring, HUD, sound.
- `tactics.gd`: screens, cuts, matchups, help defense, pass decisions, AI styles.
- `pixel_art.gd`: procedural player animation and arena characters.
- `main.tscn`: entry scene.
- `tests/`: regression and engine-input checks.

## Current scope

Single-player keyboard 3v3 exhibition. No career/franchise mode, online play, controllers, 5v5, substitutions, fouls/free throws, or out-of-bounds rules yet. The sideline official and bench players are visual additions. This is an original arcade basketball game, not an NBA 2K or Hoop Land asset recreation; no licensed teams or assets are included.
