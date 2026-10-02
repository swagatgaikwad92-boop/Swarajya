# Architecture

- **State** is one plain Dictionary (`Game.state`): territories, armies, factions, log, stats.
  It is saved as JSON; `SaveSystem.normalize()` restores ints after loading.
- **Static data** (`data/*.json`) is loaded once into `Game`. Territories list neighbours once; links are made symmetric on load.
- **Rules** (`rules.gd`) are static functions on the state: movement, recruitment, garrisons,
  sieges, battles, economy, supply, end conditions. Actions return `{ok, msg}`.
- **Combat** (`combat_resolver.gd`) is pure maths: power = units x stats x terrain x commander x morale x supply;
  fort walls multiply defence; casualties scale with the power share; a seeded RNG (stored in the save) adds +-8%.
- **AI** (`ai_player.gd`): attack if the power ratio beats a difficulty threshold, siege forts with guns,
  advance toward the nearest enemy territory when odds are plausible, recruit near the front.
- **Turn** (`turn_manager.gd`): AI acts, then economy, wall repair, supply/morale, move reset, end check.
- **UI** is built in code (`ui_kit.gd`); scenes are single nodes holding scripts.
- No cyclic preloads: Rules -> CombatResolver; AIPlayer -> Rules; TurnManager -> Rules, AIPlayer.

## Extending
- New scenario: add a JSON under `data/campaigns/` and point `Game.SCENARIO_PATH` at it.
- New territory/fort: add entries to `territories.json` / `forts.json` and the scenario `start` block.
- Planned: fog of war, diplomacy, events, leader traits, more eras.
