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
  - No dedicated death pose — `dead_state.gd` just freezes on whatever frame
    was last playing.
  - The legs don't visually turn to face the movement direction (only the
    walk-cycle IK *targets* mirror, not the leg bones/sprites themselves).
    Two fixes were attempted and reverted: mirroring the leg bones via
    negative scale broke their CCDIK hip/knee constraints (glitched out), and
    flipping the leg sprite textures alone looked wrong without rotation
    compensation. Needs a fresh approach — possibly a proper CCDIK constraint
    re-derivation (like was done for the arm elbow) rather than a quick fix.
  - Arm/head aim-IK is functional but the reach radii/origins in
    `upper_body_controller.gd` are still first-pass, eyeballed values — may
    need further visual tuning.
- **Bandit enemy has no dedicated crouch/reload animation** — reuses a
  squashed, darkened idle pose (`enemies/bandit/state_machine/reload_state.gd`).
- **Respawn doesn't reset the resource/health bar UI** — existing `#TODO` in
  `scripts/managers/respawn_manager.gd`.
- **Checkpoints share a single respawn marker** rather than each having their
  own — whichever checkpoint was most recently triggered overwrites the same
  `RespawnPosition` node's position. Works, but means only "last touched
  checkpoint" is remembered, not a per-checkpoint save.

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
