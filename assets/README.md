# Player animation sheets

`players.png` is the generated master image: eight animation rows, eight frames per row. Its magenta background is a chroma key, removed by `sprite_atlas.gd` when loading. Keep this master when editing or rebuilding the art.

`player_01.png` through `player_06.png` are ready-to-use **transparent 640 × 640 PNG animation sheets**, exported from exactly the same cleaned and palette-adjusted frames used by the game. Players 01–03 wear home uniforms; players 04–06 wear away uniforms. Each frame is **80 × 80** with a floor-contact pivot at **(40, 70)**. Use nearest-neighbor filtering.

Rows, top to bottom: **idle, run, dribble, shot, layup, dunk, pass, defend**. Read frames left to right. `animations.json` specifies row indices, frame durations, palette variants, and gameplay action mappings. Movement cycles are distance-driven in the game; listed run timing is nominal.

Rebuild the sheets after changing the master or runtime palette:

```sh
godot --headless --path . --script res://tools/export_sheets.gd
```

The exporter removes chroma-key residue, keeps the connected player silhouette, applies a common scale across animations, aligns each frame to the foot pivot, and writes the six PNGs plus metadata. The runtime continues using the master and its own cache; the exported sheets are reusable artifacts for editors and other tools.
