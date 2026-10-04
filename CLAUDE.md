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
  `dim_candy.gd` and `dim_glitch.gd` are hand-built. The 50 verses in
  between are recipes in `scripts/verses.gd`, built by `scripts/dim_world.gd`
  (layouts: grid, islands, pillars, rings, stacks, canyon, giants, maze,
  spiral, cake, dominoes). Each has its own colours (`palette`), bots
  (`bot_plan`) and respawn spots. `scripts/gate.gd` is the walk-through
  portal. Story: chapters 1-2 in the city, then dimension 1 Noir, 2 Candy,
  3-52 the verses, 53 Glitch-Verse + Glitch King (chapter = dimension + 2).
  Only the dimension you are in is kept in memory. CONTINUE on the title
  starts at the furthest dimension reached.
- `tools/test/verse_view.tscn -- --from=0 --to=49 --out=DIR` renders every verse.
- Suits, logo, signs and sounds are made by `tools/gen_suits.py`,
  `tools/gen_ui.py` and `tools/gen_audio.py`. Edit those, then re-run them.
- `tools/check.sh` checks every script. `tools/autoplay.gd` plays the game
  by itself for testing: `godot res://scenes/main.tscn -- --autoplay=auto --chapter=2`.

## Crito Mon (second game, in `critomon/`)

A Pokemon-style 3D game. It is its own Godot project: run Godot inside
`critomon/`. Web build goes to `docs/critomon/`.

- `scripts/main.gd` runs the story: title, Prof. Birch's lab, picking a
  starter, the rival's Connect Four, Route 1, the Arena.
- `scripts/world.gd` builds the town and Route 1 in code. `lab.gd` is the
  inside of the lab. `battle_stage.gd` is where battles happen.
- `scripts/dex.gd` has every Crito Mon, move and type. `critter_model.gd`
  builds the Crito Mon out of round shapes.
- `scripts/battle.gd` is Crito Mon battles. `connect4.gd` is Connect Four.
- Trainers are listed in `_make_npcs()` in `main.gd`.
- Outfits, logo and sounds: `tools/gen_skins.py`, `tools/gen_ui.py`,
  `tools/gen_audio.py`. `tools/check.sh` checks every script.
- Test it by itself: `godot res://scenes/main.tscn -- --autoplay --start=route`.

## Cave Cash (web game, in `docs/cave-cash/`)

- A blocky mining game in `docs/cave-cash/`. Ore turns into money.
  Money Ore replaces diamonds. Every upgrade costs double.
- Plain web files with three.js, not Godot. No build step: edit and push.
  Once merged to main it is live at `/cave-cash/` on the Pages site.
- Prices are in `js/data.js`. The Mine, Shop and Money Cave are built in
  `js/town.js`. The land is made in `js/world.js`. Kaian asked to take the
  businesses out, so there are none.
- Like Minecraft: hearts, hunger and food (`js/game.js`), day and night
  (`js/daynight.js`), zombies at night (`js/zombies.js`), TNT, house kits.
  Zombies stay out of town and away from lamps.
- Test: run `python3 -m http.server` in `docs/`, open `/cave-cash/`.
  `window.cave` gives the game to test scripts.
- Games save in the browser: 3 save files, picked on the title screen.
