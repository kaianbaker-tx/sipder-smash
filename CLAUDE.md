# Sipder Smash

Kaian is 10 and uses voice-to-text, so his spelling will be off. Work out
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
- Suits, logo, signs and sounds are made by `tools/gen_suits.py`,
  `tools/gen_ui.py` and `tools/gen_audio.py`. Edit those, then re-run them.
- `tools/check.sh` checks every script. `tools/autoplay.gd` plays the game
  by itself for testing: `godot res://scenes/main.tscn -- --autoplay=auto --chapter=2`.
