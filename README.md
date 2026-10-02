# Swarajya: The Maratha Age - Version 0.1 (vertical slice)

Turn-based grand strategy for Android (portrait, touch). Built with **Godot 4.3+** (GDScript).
One campaign: *The Fort Consolidation of the Pune Highlands, c. 1646-1649*.

> **Status: written but not yet run.** This code was produced without access to a Godot
> editor, so it has never been opened or executed. Expect a few small errors on first
> launch (typos, API details). Paste any error from Godot's Output/Debugger panel back
> to Claude and they can be fixed quickly. See "First run checklist" below.

## Quick start (desktop test)
1. Install Godot 4.3 or newer (standard build, not .NET): https://godotengine.org
2. Unzip, open Godot, **Import** `project.godot`, press **Play** (F5).
3. Run the smoke tests (optional):
   `godot --headless --path . res://tests/test_runner.tscn`
   (first time, open the project once in the editor so Godot imports it.)

Desktop controls: click/drag to pan, mouse wheel to zoom, click territories.
Phone controls: drag to pan, pinch or +/- buttons to zoom, tap territories.

## How to play
- Tap one of your armies' territories to select the army (green rings = can move, red rings = can attack).
- Tap a green territory to move. Tap a red one to open the battle screen (Aggressive / Balanced / Cautious / Besiege).
- Besieging an enemy fort lowers its walls; guns do more. Walls rebuild when not besieged.
- Recruit in territories you hold. Forts and territories next to forts form a **fort network** (10% cheaper recruits, faster movement).
- Supply falls with distance from a fort or core territory (Pune); cut-off armies weaken.
- **Win:** hold Torna, Rajgad, Kondana and Purandar at once. **Lose:** lose Pune and Maval, stability 0, no army and no means to raise one, or 24 turns pass.
- Codex button: historical text with confidence tags, separate from gameplay numbers.

## Build an Android APK
Full steps in `docs/ANDROID_BUILD.md`.

## Project layout
```
project.godot            autoload Game = scripts/core/game.gd
scenes/                  main_menu, era_select, game (one-node scenes; UI is built in code)
scripts/core/            game.gd (data+state), rules.gd (all rules), turn_manager.gd
scripts/combat/          combat_resolver.gd (pure maths)
scripts/ai/              ai_player.gd
scripts/save/            save_system.gd (versioned JSON, backup copy)
scripts/ui/              menus, map_view.gd, game_screen.gd, ui_kit.gd
data/                    terrain, units, factions, commanders, forts, territories, campaigns/
docs/                    SOURCES.md (confidence log), ANDROID_BUILD.md, ARCHITECTURE.md
tests/                   headless smoke tests
```
All content is data-driven: edit `data/*.json` to change forts, numbers or text.

## First run checklist
1. Main menu appears; New Game -> Era 1 -> Begin Campaign.
2. Map shows 10 territories; tapping one fills the info panel.
3. Select Shivaji's army at Maval, tap Torna, choose Besiege, then End Turn.
4. Menu -> Main menu -> Continue restores the same turn.

## Known limitations (v0.1)
- Balance is untested; AI difficulty (Settings) is the main tuning lever.
- No fog of war (AI sees everything), no diplomacy, events or audio.
- Placeholder vector art only. The map is schematic, not geographic.
- Commanders have simple modifiers; no injuries or deaths yet.
- Only one save slot.
