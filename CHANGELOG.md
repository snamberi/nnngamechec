# Changelog

## 0.3 — Fieldhouse

- Rename the game to Courtside Basketball and replace the neon theme with cream, navy, burgundy, and maple.
- Add a generated64-frame player master sheet and six transparent animation sheets with layout metadata and a reproducible exporter.
- Add sprite-frame run, dribble, shot, layup, dunk, pass, and defensive animations with foot alignment and left/right facing.
- Redesign the gym, title screen, scoreboard, results screen, playbook, selection markers, and shadows.
- Add shot-timing/contest feedback, a paused live box score (Tab), team statistics, and sound mute (M).
- Replace beeps with synthesized bounce, pass, rim, swish, and whistle sounds.
- Make rebounds favor the nearest eligible player, order interceptions by first contact, stabilize defensive matchups, and resolve exact body overlaps.
- Reject invalid passes and passes after the buzzer; clear stale state and statistics on rematch.
- Add asset and gameplay-polish regression tests; expand engine input tests for stats and sound controls.

## 0.2 — Handles + Team Play

- Add crossover, spin, step-back, pump fake, move cooldowns, and stamina costs.
- Add acceleration/deceleration and shooting penalties for movement and fatigue.
- Add layups, reverse finishes, floaters, two-hand dunks, and tomahawks.
- Add callable pick-and-rolls, screen contact, basket cuts, give-and-go passes, and transition lanes.
- Add AI passing, lane interceptions, nearest-player matchups, help defense, and Balanced/Pressure/Perimeter opponents.
- Replace small player blocks with articulated procedural pixel sprites and directional/action animation.
- Add hairstyles, uniform details, crowd celebrations, benches, a sideline official, court crest, and play guides.
- Add in-game help, keep the shot clock running during passes, and reject shots after the buzzer.
- Preserve fatigue between possessions and simulate movement at a fixed physics rate.
- Add mechanics and engine-input regression tests.

## 0.1 — First playable

- Original 3v3 court, timed shooting, passing, steals, rebounds, quarters, overtime, and procedural sound.
