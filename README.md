# Western Bounty Hunter *(working title)*

A story-driven 2D action platformer set in a supernatural Wild West, built in
**Godot 4.4**. You play a broke ex-worker turned bounty hunter, taking contracts
against outlaws, spirits, and monsters pulled from frontier folklore — each one a
handcrafted mini-adventure with its own environment, mechanics, and twist.

> The engine project is still named the generic `platformer` in `project.godot`;
> it will be renamed once a final title is locked in.

**Core loop:** Town hub → pick a bounty → play its levels → hunt the target →
earn rewards → upgrade → take the next contract.

## Status

**Core mechanics / prototyping.** Movement, combat, abilities, quest/dialog/shop
NPCs, save slots, inventory, bounties and audio are largely in place. The first
contract's tutorial leg is playable end to end; the remaining legs are not.
See [PROJECT.md](PROJECT.md) for the design doc, the implementation snapshot,
and the current known issues.

## Getting started

Requires **Godot 4.4.x** (developed against 4.4.1, Forward+ renderer). No C#
or external build step.

1. Clone the repo and import the project folder in the Godot project manager.
2. Press **F5** to run — the main scene is
   [main_menu_screen.tscn](ui/screens/main_menu_screen.tscn), which leads into
   the save-slot screen.
3. [test_level.tscn](levels/test_level.tscn) is the scratch level for trying
   mechanics in isolation.

Two editor plugins ship in [addons/](addons/): **SoupIK** (2D skeleton IK, used
for the player's legs — must stay enabled) and **GUT** (tests, CLI-only).

### Debug menu

Debug builds get a **DEBUG MODE** button in the pause menu
([debug_menu_screen.gd](ui/screens/debug_menu_screen.gd)) for granting money,
abilities, items, and bounty/region unlocks. It is hidden in release exports.

## Controls

Fully rebindable in Settings (keyboard *and* controller). Defaults:

| Action | Key | Action | Key |
| --- | --- | --- | --- |
| Move | `A` / `D` or arrows | Shoot | Left mouse |
| Jump | `Space` | Reload | `R` |
| Climb up | `W` | Swap weapon | `Q` |
| Crouch | `C` | Use utility | `G` |
| Drop through platform | `S` | Cycle utility | `V` |
| Wall cling | `F` | Interact | `E` |
| Dash | `Shift` | Inventory / journal | `I` |
| Grapple | Right mouse | Journal tabs | `[` / `]` |
| Deadeye | Middle mouse | Pause | `Esc` |

## Project structure

| Path | Contents |
| --- | --- |
| [player/](player/) | Player scene, upper/lower body controllers, states, gun, dynamite, grapple, camera, effects |
| [enemies/](enemies/) | Bandit, skeleton, cactus, cactus coyote, hoop snake, bosses, shared `_common` logic |
| [npc/](npc/) | `NPC` base plus dialog, quest, shop, welcome and bounty turn-in archetypes |
| [levels/](levels/) | Boss arena, the prototyping test level, checkpoints, grapple anchors, and the `_common` scaffolding |
| [levels/hub/](levels/hub/) | The town itself: `hub_level.tscn` and the eight building interiors it leads into |
| [levels/regions/](levels/regions/) | Story levels grouped by region — `plains/` holds the tutorial backyard, the shaman camp and the coyote den |
| [scripts/managers/](scripts/managers/) | The autoload singletons (see below) |
| [scripts/bounties/](scripts/bounties/) | `BountyData` / `BountyStageData` / `BountyObjectiveData` / `RegionData` |
| [scripts/](scripts/) | Abilities, items, quests, save data, state machine, shared explosion logic |
| [abilities/](abilities/), [quests/](quests/), [items/](items/) | Data resources: dash/double jump/grapple/deadeye, side quests, weapons, ammo, cosmetics, utilities, key items |
| [ui/](ui/) | Screens, inventory journal, shop, dialogue, notice board, HUD, theme and fonts |
| [tileset/](tileset/) | Desert tilesets, parallax backgrounds, hub building structures, interior room art and props |
| [test/unit/](test/unit/) | GUT test suite |

## Architecture notes

- **Autoload managers.** Most global state lives in singletons registered in
  `project.godot` — Collectible, Game, GameInputEvents, Health, Player, Respawn,
  Scene, Settings, Ui, Inventory, GameState, Ability, Quest, Save,
  ProjectileLayer, Localization, UiNavigationRepeater, UiSoundPlayer, Music and
  AudioBuses.
- **Shared scene bases.** Playable levels extend `Level`
  ([levels/\_common/level.gd](levels/_common/level.gd)) for player/camera/respawn
  wiring and a `music` slot; hub interiors extend `InteriorLevel`; town buildings
  use `HubStructure`; UI grids use `FocusGrid` for keyboard/gamepad focus.
- **Bounties are the progression track**, quests are optional side content. One
  bounty is a contract spanning several levels ("legs"), each with its own
  objective checklist; resuming a part-finished bounty picks up at the right leg.
- **Save system.** Three slots, chosen before anything loads.
  `SaveManager.load_slot()` resets every manager via `reset_progress()` first,
  because managers hold progress in memory for the whole session. One-off story
  beats live in a `story_flags` dictionary.
- **Audio.** `Master` / `Music` / `SFX` / `UI` buses with a volume slider each.
  Players are tagged by *group* rather than by bus name and routed in
  [audio_buses.gd](scripts/managers/audio_buses.gd) — see the engine-traps
  section of [PROJECT.md](PROJECT.md) for why.
- **Localization.** English and German in
  [localization/translations.csv](localization/translations.csv) (in progress).

## Tests

The suite uses [GUT](https://github.com/bitwes/Gut) 9.4.0 and runs headless:

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gexit
```

Settings come from [.gutconfig.json](.gutconfig.json) (`test/unit`, `test_*.gd`).
Run it after any bigger change, not just when asked.

> **Gotcha:** adding a new `class_name` needs a `--import` pass before headless
> tests can see it, otherwise scenes using it load with no script attached and
> fail confusingly.

## Documentation

[PROJECT.md](PROJECT.md) is the living design doc: pitch, setting, story arc,
implementation snapshot, known issues/TODO, design pillars and scope discipline.
Keep it updated as the plan evolves.
