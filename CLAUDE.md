# Dream Game (working title) by Mallard Industries

Godot 4.7 project (GDScript). The design source of truth is `Master Game Design Document.pdf`.
Read it before making design decisions. Items marked firm stay firm; `[FLAG - OPEN]` items are undecided.

## Layout
- `game/core/`: autoloads `Settings` (options file), `SaveManager` (save slots), `Game` (scene flow,
  fades, play time, autosave, button prompts), plus `Level` (base class for levels) and `SpawnPoint`.
- `game/ui/`: title screen, pause menu, Edit Deck, options, slot picker, HUD, skip prompt, theme.
- `game/world/kit/`: low-poly environment pieces built in code (`Shelf`, `BookCliff`, `Lectern`,
  `ReadingTable`, `FloorLamp`, `Pillar`, `Rug`, `BookPile`) on top of `LowPoly` and `KitPiece`.
- `game/cards/`: `CardData` resources in `library/`, listed in `CardLibrary.CARDS`.
- `game/levels/`, `game/player/`, `game/enemies/`, `game/props/`, `game/fx/`, `game/cutscenes/`.
- `assets/characters/<name>/`: game-ready sprite frames plus the generated `<name>_frames.tres`.
- `art/`: raw source art and rejected experiments. Godot ignores it (`art/.gdignore`).
- `tests/`: test scenes. `tools/`: helper scripts.

## Conventions
- 3D world with 2D billboard sprites. 1 world unit = 32 px (`pixel_size = 0.03125`).
  The game renders at 640x360 and scales up by whole numbers.
- Camera is orthographic, pitched 65 degrees, looking north (-Z). South (+Z) is toward the camera,
  so only top, south, east and west faces are ever seen (`LowPoly.VISIBLE_FACES`).
- Characters face 8 ways, but only south, south-east, east, north-east and north are drawn.
  West-side facings flip the east-side art in game.
- Sprite folders: `idle/<facing>.png` and `<action>/<facing>/<frame>.png`.
  Rebuild the animations with `tools/build_sprite_frames.gd` after adding or removing frames.
- Anything the owl's gust affects implements `take_gust(damage: int, push: Vector3)`.
- Physics layers: 1 world, 2 player, 3 enemies, 4 props (block the owl), 5 debris (owl walks over it).
- Controls are 6 buttons plus Start: `move_up/down/left/right`, `accept`, `decline`, `start`.
  `accept` is the owl's flap. Menus use the `ui_*` actions, which include the same buttons.
- Kit pieces build their mesh in `_ready()` and aren't saved into scenes; scenes store only settings.
- Bookworms do the same: their bead body is built in code. The worm node only moves the head
  (collision layer 0); the owl and the gust hit its `Hitbox` child on the enemies layer, which
  passes `take_gust` on. Each worm under the same parent gets a different colour automatically.
- `FootprintTrail` (`game/fx/`) is a child of the owl that leaves fading footprints as it walks.
  Give any other walking character one by adding it as a child of its `CharacterBody3D`.

## Saving
- Levels extend `Level` and must contain the `Owl` and a `SpawnPoint` (usually named `Start`).
- Anything that should be remembered joins the `persistent` group and implements
  `get_save_state() -> Variant` (null = nothing to save) and `apply_save_state(state)`.
  State is keyed by node path within the level, so renaming a saved node resets it in old saves.
- Call `Game.request_autosave()` after something worth saving happens. `Game` also saves on
  entering a level, every 60 s of play, on Save and quit, and when the window closes.
- Changing the save data's shape: bump `SaveManager.DATA_VERSION` and add a step to `_migrate()`.
- Saves live in `user://saves`; tests use `user://test_saves` and never touch real slots.

## Commands
Set the Godot path, e.g. `GODOT=/Applications/Godot.app/Contents/MacOS/Godot`.
- Run all tests: `GODOT=$GODOT tools/run_tests.sh` (or name tests: `tools/run_tests.sh save_test`)
- Screenshots from a test: `$GODOT --path . --fixed-fps 60 res://tests/smoke_test.tscn -- --shots=<folder>`
- Import assets: `$GODOT --headless --path . --import`
- Rebuild owl animations: `$GODOT --headless --path . --script res://tools/build_sprite_frames.gd -- res://assets/characters/owl`
- Tests are scenes, not `--script` runs, because `--script` can't see autoloads like `Game`.
