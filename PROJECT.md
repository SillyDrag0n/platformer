# Western Bounty Hunter (working title)

> This is a living design doc. Update it as the plan evolves — it exists so anyone
> (including future-you, or an AI assistant picking up the project cold) can get
> oriented quickly. Engine project name is currently the generic `platformer`
> (see `project.godot`); rename once a final title is locked in.

## Elevator Pitch

A level-based 2D action-platformer set in a supernatural Wild West where folklore
and legends are real. You're a bounty hunter taking contracts against outlaws,
spirits, and monsters pulled from frontier folklore — each one a handcrafted
mini-adventure with its own environment, mechanics, and twist.

## Genre & Core Loop

**Genre:** Story-driven action platformer (bounty-of-the-week structure), Weird
West setting.

**Core loop:**

```
Town Hub → Choose a bounty → Enter a level → Explore, platform, fight
   → Hunt down the target → Earn rewards → Upgrade → Choose the next bounty
```

The town is the persistent hub: pick bounties, talk to NPCs, buy upgrades, gear
up for the next job. Progression unlocks new regions, levels, weapons,
abilities, and tougher supernatural targets.

## Setting & Tone

Stylized Weird West: familiar frontier trappings (saloons, sheriffs, bandits,
deserts) mixed with folklore, mysterious creatures, and supernatural events.
Each level is meant to read like its own small story, not just a combat arena —
enemies should have distinctive behaviors/mechanics tied to their folklore
identity (e.g. a living cactus enemy that only attacks when you get too close).

## Current Stage

**Core mechanics / prototyping.** Foundational systems (movement, combat,
abilities, quest/dialog/shop NPCs, save/inventory) are being built out before
committing to a large content push.

## Ambition / Scope

Aiming for a **full commercial release** (e.g. Steam). Not scoped as a small
hobby demo — plan accordingly for systems that need to scale (content
pipeline, save compatibility, localization already in progress).

## What Exists Today (implementation snapshot)

This section reflects what's in the repo as of 2026-08-22 — treat it as a
snapshot, not a source of truth; re-check the code for current state.

- **Player systems:** upper/lower body controllers, state machine
  (`normal`, `dash`, `grapple`, `hurt`, `dead`), gun + aim reticle, dynamite,
  grapple hook, hit-flash shader, death effect, cosmetics.
  - Upper body (arms/head) uses CCDIK to continuously aim at the mouse/stick,
    independent of the lower body's keyframed walk cycle. Muzzle position and
    the aim reticle/trajectory line both track the hand's actual IK target
    rather than a separately-tuned fixed point, so they stay visually aligned
    with where shots actually originate.
- **Abilities (unlockable):** dash, double jump, grapple hook, deadeye.
- **Enemies:** bandit, skeleton, cactus (unique "only attacks when approached"
  behavior), boss enemies, shared `_common` enemy base logic.
- **NPCs:** dialog NPC, quest NPC, shop NPC.
- **Quests:** early quest content (e.g. "kill 5 bandits").
- **Items:** ammo, cosmetics, key items, quest items, utility items, weapons.
- **Levels/hub:** hub level (town) plus interiors — arms dealer, bank, post
  office, saloon, sheriff's office — and a boss arena, checkpoints, a
  grapple-anchor system, and a test level for prototyping.
- **UI:** bounty board (notice board of available contracts, keyboard/gamepad
  focus + click selection with a visible highlight on the selected posting).
- **Managers (autoloads):** Collectible, Game, GameInputEvents, Health, Player,
  Respawn, Scene, Settings, UI, Inventory, GameState, Ability, Quest, Save.
- **Localization:** in progress (`localization/` folder, translations added).
- **Testing:** GUT unit test framework (`addons/gut/`, CLI-only, see
  `test/unit/`) covering the pure-logic autoload managers (Inventory, Health,
  Quest). Run via
  `"D:\Godot\Godot_v4.4.1-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gexit`.
  Run this after any bigger change, not just when someone asks.

## Known Issues / TODO

Gaps found while working in the code — not exhaustive, just what's been
noticed so far. Remove items once actually fixed instead of leaving them
stale.

- **Player animations are largely placeholder/incomplete:**
  - No dedicated hurt, dash, or grapple(swim/swing) poses — hurt reuses idle,
    grapple reuses fall, dash reuses walk sped up
    (`player/lower_body_controller.gd`).
  - ~~No dedicated death pose~~ — **done 2026-08-23**: added a "death" clip
    (`player.tscn`, keyframes `Hip`/`FootR Target`/`FootL Target` over 0.4s
    into a collapsed pose) that `lower_body_controller.gd` now plays on
    entering "Dead". `player.gd`'s `player_death()` delays the poof
    effect/removal by 0.5s (`DEATH_POSE_DURATION`) so the collapse is
    actually visible first; verified via a headless harness that the player
    stays alive/in-tree through the delay and `player_died` fires exactly
    once, not duplicated by a second hit landing mid-collapse (the state
    machine's same-state guard already prevents that). Upper body
    (arms/head) still just freezes on last pose, since
    `upper_body_controller.gd` already skips updating them in "Dead" - not
    touched. Pose values are first-pass/eyeballed like other IK tuning in
    this project; check it in-editor to confirm it reads as "collapsing" and
    not anatomically odd, since it was authored blind.
  - ~~The legs don't visually turn to face the movement direction~~ **Fixed**
    by replacing CCDIK on the leg chain with the third-party **SoupIK**
    addon (`addons/soupik/`, vendored from
    `ZedManul/souperior-2d-skeleton-modifications`, MIT). Three earlier
    fixes (negative-scale mirror with original constraint; the same with a
    correctly re-derived constraint; sprite `flip_h` alone) all failed
    because Godot's built-in `SkeletonModification2DCCDIK` rewrites its
    owned bones' entire local transform every frame from
    `get_global_scale()`, which discards a mirror's negative sign — a
    real, unresolved Godot 4 engine limitation
    ([godotengine/godot#86868](https://github.com/godotengine/godot/issues/86868)),
    not a tuning mistake. SoupIK's `SoupTwoBoneIK` avoids this by reading
    `sign(bone.global_transform.determinant())` directly and setting
    `global_rotation` instead of reconstructing local transform from scale,
    plus exposing a `flip_bend_direction` toggle for picking the correct
    knee-bend solution. `LegR`/`LegL` now use `SoupTwoBoneIK` nodes
    (`Animation/SoupIK/LegR IK`, `LegL IK` in `player.tscn`), driven by
    `lower_body_controller.gd`'s existing `facing` value; the foot `LookAt`
    modifications and all arm/head CCDIK stayed on the built-in system
    (single-bone or unmirrored, not affected by this bug). The addon's
    `main` branch (no tagged releases) needed three `@export_custom(
    PROPERTY_HINT_GROUP_ENABLE, ...)` calls patched to plain `@export`
    since that hint isn't available in this project's pinned Godot 4.4.1 —
    same "don't blindly trust a stated version range" lesson learned from
    pinning GUT to 9.4.0 (see Testing, above). Verified headlessly (bone rotations/positions
    genuinely change and the knee's angle *relative to the thigh* stays
    consistent across facing flips, as a correct mirror should — see
    `git log` for the harness used) and the leg sprites were **not**
    re-flipped, on the reasoning that the bend is now a real geometric turn
    toward an already-mirrored target rather than a texture-space
    reflection (same reason arms are left unflipped). Still needs a look in
    the actual editor/game to confirm it *reads* right — the headless check
    only proves the numbers move sensibly, not that the pixel art looks
    anatomically correct; it's possible the legs still need the sprite-flip
    treatment after all.
  - Arm/head aim-IK is functional but the reach radii/origins in
    `upper_body_controller.gd` are still first-pass, eyeballed values — may
    need further visual tuning.
- **Bandit enemy has no dedicated crouch/reload animation** — reuses a
  squashed, darkened idle pose (`enemies/bandit/state_machine/reload_state.gd`).

## Design Pillars (draft — refine as needed)

1. **Every bounty tells a small story** — not just a level skin, but a target
   with a gimmick, a reason, a bit of folklore behind it.
2. **Movement and gunplay stay tight** — platforming (dash/grapple/double
   jump) and combat are the moment-to-moment draw, story is the wrapper.
3. **The town is a real hub, not a menu** — NPCs, shops, and quest-givers make
   it feel lived-in between jobs.
4. **Creatures behave, not just spawn** — enemies get distinct AI/mechanics
   tied to their folklore identity rather than reskinned generic enemies.

## Open Questions / To Fill In

These aren't derivable from the code — fill in when decided so this doc stays
useful:

- Target platform(s) — PC/Steam only, or consoles too?
- Team size — solo, or collaborators involved?
- Rough timeline / milestones (first playable demo, vertical slice, etc.)?
- Monetization / pricing plan?
- Story/narrative arc beyond the bounty-of-the-week structure — is there an
  overarching plot or antagonist?
- Art direction reference points (pixel art style, palette, specific games as
  visual touchstones)?
- Audio direction (music genre references, sound design tone)?
