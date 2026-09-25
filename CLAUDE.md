# Sipder Smash

The game is called **Spideys of the Multiverse** (the repo keeps its old
name). Kaian is 10 and uses voice-to-text, so his spelling will be off. Work out
what he meant. Short sentences, one idea at a time.

- Godot 4.7, web build goes to `docs/`, published on GitHub Pages.
- Find art with `kenney-find <word>`, copy it with `--grab`.
- Publish with `share-game`.
- Keep `thread_support=false` or the web page goes black.

## Project map

- `scenes/main.tscn` runs `scripts/main.gd`: title, chapters, boss, win.
- The whole city is built in code (`scripts/city.gd`), not in scenes.
- Look: `shaders/toon.gdshader` (cel shading, dots) and
  `shaders/post.gdshader` (ink lines, red/blue misprint). Colors live in
  `[shader_globals]` in `project.godot`.
- Hero: `scripts/player.gd` (moves) and `scripts/hero_model.gd` (poses).
- Dimensions: `scripts/dimension.gd` is the base; `dim_noir.gd`,
  `dim_candy.gd` and `dim_glitch.gd` build them far from the city. Each has
  its own colours (`palette`), bots (`bot_plan`) and respawn spots.
  `scripts/gate.gd` is the walk-through portal. Story: chapters 1-2 in the
  city, 3 Noir-Verse, 4 Candy-Verse, 5 Glitch-Verse + Glitch King.
- Suits, logo, signs and sounds are made by `tools/gen_suits.py`,
  `tools/gen_ui.py` and `tools/gen_audio.py`. Edit those, then re-run them.
- `tools/check.sh` checks every script. `tools/autoplay.gd` plays the game
  by itself for testing: `godot res://scenes/main.tscn -- --autoplay=auto --chapter=2`.
