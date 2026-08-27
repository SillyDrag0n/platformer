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

Supernatural creatures have **always existed** in this world — they aren't a
recent invasion or a twist, just part of how the setting works. Not every
creature needs an explanation. Three rough categories:

- **Weird wildlife:** living cacti, strange animals, small spirits — simply
  part of everyday life, background flavor more than threats.
- **Dangerous creatures:** powerful beings that normally stay in remote
  territories but become a threat when humans disturb their habitat.
- **Legendary beings:** extremely rare creatures tied to old folklore and the
  larger mystery — the ones bounties eventually escalate toward.

## Story & Narrative Arc

**Premise:** The protagonist loses his job and is nearly broke. He starts
taking bounty-hunting jobs because he needs money. At first it's simple: take
jobs → earn money → buy equipment → take harder jobs. His first serious
bounty introduces him to something much bigger.

**Protagonist arc:** He doesn't start as a hero — he's simply trying to
rebuild his life.

> He takes the first bounty because he needs money.
> He keeps going because he's becoming good at it.
> Eventually, he starts caring about the people and strange world he's
> become part of.

**First region — The Plains** establishes the template arc
(investigate → understand → hunt) that later regions can riff on:

- **Level 1 — Investigation.** The player helps a farmer/old man because they
  need the money. Strange creatures are encountered along the way. Eventually
  they discover a much more dangerous creature responsible for the problem.
  The player confronts it but is too weak and escapes.
- **Level 2 — The Shaman.** The player travels across the Plains to a remote
  shaman for information. The shaman explains that the creature has always
  existed, but human expansion is destroying its territory and making it
  aggressive.
- **Level 3 — The Hunt.** The player tracks the creature into its remaining
  territory and defeats it.

**Larger story:** As the player travels to new regions, they discover that
human expansion is increasingly colliding with the supernatural world.
Meanwhile, strange phenomena and fragments of forgotten folklore suggest that
something deeper may be happening — the overarching mystery beyond the
bounty-of-the-week structure.

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
  - ~~Knee bends to the anatomically wrong side partway through the walk
    cycle when facing left~~ — **done 2026-08-25.** Preceded by an
    abandoned attempt at true pixel-perfect mirroring: inserting a plain
    `Node2D` wrapper between `Hip` and each leg's root bone (`LegR`/`LegL`)
    to hold a mirror scale, so the whole posed limb reflects as one rigid
    transform instead of being independently IK-derived. **That crashed
    the engine** — `Skeleton2D` lost track of all 6 leg bones
    (`bones.size()` dropped from 12 to 6) and segfaulted in
    `get_index_in_skeleton` (`skeleton_2d.cpp:409`) the moment a
    non-`Bone2D` node sat between `Hip` and `LegR`/`LegL`, contradicting
    what reading `Bone2D`/`SoupTwoBoneIK` source suggested should work —
    Godot 4.4.1's `Skeleton2D` does not tolerate that specific insertion.
    Fully reverted and confirmed clean (GUT 28/28, clean scene load,
    flip_h fix's own check). **Do not retry via text edits** — not that
    exact form, and not "make the wrapper a real `Bone2D`" either (would
    need renumbering every other `bone_index` reference in the file, and a
    *plain* wrapper already crashed things, so that variant is higher
    risk, not lower). If true pixel-perfect mirroring is wanted later, do
    the restructuring in the Godot editor itself (visual skeleton tools +
    undo + immediate error feedback).
    User then clarified they didn't need pixel-perfect, just "correctly
    orientated" — which pointed at a real, separate, much smaller bug:
    `leg_r_ik.flip_bend_direction`/`leg_l_ik.flip_bend_direction` were
    toggled by `facing` (`facing > 0.0`). Verified headlessly (sampling
    real simulated walking, not just the rest pose) that this toggle was
    wrong: walking right held the knee consistently on one side of the
    hip-foot line for the entire cycle (0 sign flips across 90 samples),
    but walking left crossed to the wrong side 1-3 times per cycle with a
    visible snap each time. Fixed by making `flip_bend_direction` a fixed
    `true` for both legs (no longer toggled by facing at all, set once in
    `_ready()` instead of every frame in `update_facing()`) — since the leg
    bones' own origin sits close to the mirror axis, the same bend choice
    works cleanly in both directions: 0 sign flips in either direction
    across 90 samples each, and the rotation ranges end up nearly identical
    between left/right. (The handful of near-zero-magnitude "flips" seen in
    one earlier run were confirmed to be measurement noise at the moment
    the leg is naturally straight mid-swing, not a real defect — checked
    via the cross-product's magnitude distribution, not just its sign.)
    True pixel-perfect mirroring remains a known, deliberately-not-pursued
    gap (see the crashed-wrapper-attempt note above) — this fix only
    guarantees anatomically correct orientation, which is what was
    actually asked for. GUT suite still 28/28. Not yet confirmed in-editor.
  - ~~Legs look "inside-out" facing left~~ — **done 2026-08-25**, pre-existing
    bug surfaced by the crouch-while-walking work prompting more left-facing
    testing (not something this session's changes caused). `update_facing()`
    was `flip_h`-ing each leg sprite (thigh/shin/foot × 2) whenever facing
    left, on top of the leg bones' own genuine IK-driven rotation toward the
    already-mirrored `FootTarget` (via `leg_targets.scale.x = facing` +
    `SoupTwoBoneIK.flip_bend_direction`). That rotation alone already
    presents the correctly-mirrored leg; flip_h'ing the texture on top of
    it double-mirrors it — reported precisely as "the inside of the legs is
    now outward." Same class of mistake the comment block explicitly
    warned against for arms ("their CCDIK joint constraints... mirroring
    that parent via negative scale would... make the limbs bend wrong") but
    had been applied to legs anyway, contradicting the leg-IK-fix session's
    own original reasoning (see the SoupIK entry below: "the leg sprites
    were **not** re-flipped, on the reasoning that the bend is now a real
    geometric turn... same reason arms are left unflipped" — that reasoning
    was right; a flip_h block existed on the legs anyway by the time this
    session found it). Fixed by removing the leg-sprite `flip_h`/`offset`
    block from `update_facing()` entirely (also removed the now-dead
    `leg_r_sprite`/`shin_r_sprite`/`foot_r_sprite`/`leg_l_sprite`/
    `shin_l_sprite`/`foot_l_sprite` exports and their node-path wiring in
    `player.tscn`, and the `_leg_sprites`/`_leg_sprite_rest_offsets` caches
    in `lower_body_controller.gd`, since nothing else used them) — legs are
    now mirrored purely by the IK rotation, same as arms. Verified
    headlessly that `flip_h` stays `false` and each sprite's `offset` stays
    at its rest value regardless of facing, while `leg_targets.scale.x` and
    `SoupTwoBoneIK.flip_bend_direction` still correctly flip (position
    mirroring untouched). GUT suite still 28/28. Not yet confirmed
    in-editor.
  - ~~Crouch-while-walking fix caused a "spasm," then broke death entirely~~
    — **done 2026-08-25** (regression introduced and fixed within the same
    session as the crouch-while-walking work below). Root cause:
    `apply_crouch_pose()` (`hip.position.y += crouch_hip_drop`) ran in
    `_physics_process`, but `AnimationPlayer` was still on its default
    automatic idle-process callback — so its own per-idle-frame update kept
    re-writing `Hip.position` from the idle/walk curve, racing my
    physics-process write with no defined order between the two.
    Confirmed headlessly (not guessed): `Hip.position.y` visibly
    **alternated** between the crouched and un-crouched value every single
    frame while crouch was held — the reported "spasm." Fixed by setting
    `AnimationPlayer.callback_mode_process = MANUAL` (`player.tscn`) and
    having `lower_body_controller.gd`'s `play_clip()` call
    `animation_player.advance(delta)` itself, once per physics frame, right
    before `apply_crouch_pose()` runs — making this file the sole writer of
    `Hip.position` at a fully deterministic point, with nothing left to
    race. That surfaced a second, previously-latent bug: pushing a
    **non-looping** clip (`death`) past its own length via manual
    `advance()` clears `AnimationPlayer.current_animation` to `""` and
    `is_playing()` to `false` **immediately**, unlike automatic idle-process
    ticking, which just holds the final frame — so `play_clip()`'s old
    guard (`if animation_player.current_animation != clip_name`) saw
    `"" != "death"` the instant the collapse finished and restarted it,
    forever, an infinite replay loop that hadn't existed before (`death`
    was the only non-looping clip, so idle/walk/jump/fall never triggered
    it during earlier testing). Fixed by guarding on a locally-tracked
    `_current_clip_name` instead of the engine's own (now unreliable)
    `current_animation`. Verified headlessly, tick-by-tick, for both:
    crouch holds steady across 60 held-frames (no more alternation), and
    death advances 1→13 over its 0.4s length then holds flat at 13
    indefinitely (confirmed past tick 55, no restart). `speed_scale` was
    separately confirmed to still work correctly under manual `advance()`
    (`advance(0.1)` at `speed_scale=3.0` measured exactly 3× the
    `speed_scale=1.0` distance) before relying on it for dash/walk-speed
    scaling. GUT suite still 28/28. Not yet confirmed in-editor — this fix
    in particular touches core animation plumbing (not just pose numbers),
    so it's worth a real look before trusting it fully.
  - ~~Gun and aim reticle don't move with the rest of the body~~ — **done
    2026-08-25**: same root cause as the Torso fix below, one layer further
    out. `Gun.gd` sets its weapon sprite/muzzle directly from
    `arm_r_target.global_position` (bypassing the bone chain entirely, for
    exact hand alignment), and `AimReticle` anchors to that same muzzle —
    so both transitively depend on `arm_r_target`. But `upper_body_controller
    .gd` computed `arm_r_target`/`arm_l_target`/`head_target` purely from
    fixed origins + aim direction, never accounting for `Hip`'s current
    position — so crouching (or dash/hurt/grapple's Hip lean) moved the
    torso and legs but left the gun, reticle, trajectory line, and off-hand
    floating at standing height. Fixed by giving `upper_body_controller.gd`
    its own `hip` reference and cached rest position (mirroring
    `lower_body_controller.gd`'s pattern), and adding `hip.position -
    hip_rest_position` to all three target positions each frame. Verified
    headlessly: manually offsetting `Hip` by the crouch clip's ~13px and
    re-running both controllers' `_process()` shows `arm_r_target`,
    `head_target`, the gun's `Muzzle`, and `AimReticle` all move by exactly
    that same offset. GUT suite still 28/28. Not yet confirmed in-editor.
  - ~~Torso doesn't move with the rest of the body~~ — **done 2026-08-25**:
    `Body/Torso` is a flat sprite outside the `Bones/Skeleton2D` chain, so
    nothing was ever making it track `Hip`'s own position — true in every
    clip (idle/walk's bob included), just most visible in crouch, whose
    larger Hip drop made the torso staying put obvious. Fixed generally
    (not crouch-specifically) by having `lower_body_controller.gd` set
    `body.position` to `Hip`'s live offset from its cached rest position at
    the end of every `_physics_process`, after whichever branch (clip-based
    or procedural) ran that frame — one place, covers all poses including
    the new procedural ones above. Also bumped the "crouch" clip's Hip drop
    from ~5px to ~13px (`player.tscn`), which was reported as "barely bends
    the knees" — deepens the knee bend for free since `SoupTwoBoneIK` must
    bend more to close a shorter hip-to-foot distance, no new foot keyframes
    needed. Verified headlessly that Body's offset matches Hip's exactly
    for both a procedural pose (Dash) and the crouch clip (driven directly
    via `AnimationPlayer.advance()`), and the crouch Hip drop lands at
    ~13px. GUT suite still 28/28. Not yet confirmed in-editor.
  - ~~Couldn't crouch while walking~~ — **done 2026-08-25**: the dedicated
    "crouch" clip required `direction == 0.0` to even be selected, so
    holding crouch while moving just played "walk" at standing height —
    reported by the project owner wanting to duck under gunfire mid-stride,
    which didn't work at all. Fixed by retiring the "crouch" clip entirely
    (removed from `player.tscn` — dead now that this exists) in favor of
    treating crouch as a Hip-offset **modifier** layered on top of
    whichever base clip (idle or walk) `play_normal_clip()` already picked,
    via a new `apply_crouch_pose()`: `hip.position.y += crouch_hip_drop`
    (`@export`, default 13, replaces the old clip's baked-in value) whenever
    grounded + crouch held, regardless of movement direction. Idle/walk
    keep playing normally underneath — full gait, footsteps, everything —
    just from a lower Hip height, so `SoupTwoBoneIK` bends the knees more
    to close the shorter reach exactly as it already did for the old static
    crouch. `apply_crouch_collision()`'s gate also had the same
    stationary-only restriction removed, so the hitbox now actually shrinks
    while crouch-walking too, not just while standing still — the entire
    point of the feature (a hittable-profile reduction you can use while
    moving). Verified headlessly end-to-end against `test_level.tscn` with
    real simulated input (`Input.action_press("crouch")` +
    `action_press("move_right")`): grounded, `velocity.x` at full run speed
    (300), `walk` clip playing, Hip dropped ~13px, collision shrunk — all
    simultaneously. GUT suite still 28/28. Not yet confirmed in-editor.
  - ~~Player's collision shapes don't crouch~~ — **done 2026-08-25** (found
    while checking the torso fix above, then fixed same session at the
    project owner's request). `lower_body_controller.gd`'s new
    `apply_crouch_collision()` shrinks the body's own `CollisionShape2D`
    (`CapsuleShape2D`, rest radius 8 / height 66) from the top only — bottom
    edge held fixed via a matching position shift, so feet don't sink into
    the floor and crouching can actually fit under something shorter than
    standing height, not just look shorter — by `crouch_collision_shrink`
    (`@export`, default 13, matched to the crouch clip's Hip drop above).
    `Hurtbox/HurtboxCollisionShape2D` only translates by the same amount
    (no resize), since the torso sprite itself doesn't compress when
    crouching, just moves down with the rest of the upper body via the
    Torso-follows-Hip fix — the hittable zone should move the same way, not
    change shape. The capsule's shared `Shape2D` resource is duplicated
    once in `_ready()` before mutating `.height`, so this doesn't leak into
    other instances of the scene. Both shapes are driven by the same
    grounded-and-crouch-input condition `play_normal_clip()` already uses
    to pick the "crouch" clip, so the hitbox and the visible pose can't
    desync. Verified headlessly: crouching shrinks height while keeping the
    capsule's bottom edge at the exact same world position, moves the
    hurtbox down by exactly the shrink amount, and un-crouching restores
    both shapes to their exact original transform. GUT suite still 28/28.
    No level geometry exists yet that would actually require the shorter
    hitbox (no crawl spaces) — this just makes crouching mechanically real
    instead of purely cosmetic, ready for when one does.
  - ~~No dedicated hurt, dash, or grapple(swim/swing) poses~~ — **done
    2026-08-25**: replaced the idle/fall/walk placeholder reuse with
    procedural poses computed live in `lower_body_controller.gd`
    (`apply_dash_pose()`/`apply_hurt_pose()`/`apply_grapple_pose()`), the
    same "compute from physics state every frame, no keyframes" approach
    `upper_body_controller.gd` already used for arm/head aiming — chosen
    because hand-keyframing new clips isn't something the project owner
    feels confident doing. `animation_player.stop()` now runs on entering
    these three states so the procedural code has sole control of
    `Hip`/`FootR Target`/`FootL Target`; a `sin(progress * PI)` ease drives
    each pose from its state's own timer (`dash_state.dash_timer`/
    `dash_duration`, `hurt_state.hurt_timer`/`hurt_duration`) back to the
    rest transforms `lower_body_controller.gd` now caches once in
    `_ready()`. Grapple's swing trail reuses the existing `facing` variable
    (already velocity-derived, see `update_facing()`) rather than
    re-deriving tangent/anchor math grapple_state.gd already owns, and eases
    to a tucked pose when `GameInputEvents.climb_input()` is active. All
    offset/angle amplitudes are `@export` (`Dash Pose`/`Hurt Pose`/`Grapple
    Pose` categories) for Inspector-only tuning, no re-keyframing needed.
    Companion change: `player.gd`'s `take_hit()` now applies a small
    one-time knockback (`HURT_KNOCKBACK_SPEED`, pushing away from whatever
    dealt the damage, or opposite current velocity if no source is
    available) so the hurt stagger has real motion to react to even when
    the player was standing still — previously `take_hit()` applied zero
    velocity change. Verified headlessly (not just static reading): a
    throwaway harness instantiated `player.tscn` and drove each pose
    function directly across progress 0→0.5→1, confirming poses start/end
    exactly at the cached rest transform, move mid-pose, both legs get an
    identical relative offset in Hurt, the Hip offset flips sign with
    `facing`, and Grapple's local foot offset is direction-agnostic by
    design (magnitude-only; left/right mirroring is `leg_targets.scale.x`'s
    job, same as every other pose) while still scaling with swing speed.
    Existing GUT suite (28/28) still passes. Still needs an in-editor/in-game
    look — the headless check only proves the numbers move sensibly on the
    intended curve, not that the poses read right as pixel art; amplitudes
    are first-pass guesses meant to be tuned via the new Inspector sliders.
  - **Walking left reads as "walking backward" — LegL/LegR use distinct,
    non-mirror-symmetric art, and four more fix attempts failed 2026-08-26.**
    This is the "possible the legs still need the sprite-flip treatment
    after all" caveat below being confirmed true. `leg_right.png`/
    `shin_right.png`/`foot_right.png` and the `_left` set are NOT mirror
    images of each other (confirmed via a PowerShell/System.Drawing
    non-transparent-pixel bounding-box scan of all six PNGs) — `leg_right`
    has visibly more shape detail (a boot/knee bulge) than `leg_left`'s
    plainer silhouette. A rotation-only reach (what SoupIK already does,
    see below) can't reflect that asymmetry — only an actual mirror
    transform can. Four approaches tried and reverted, in order:
    1. **Swap which texture+offset sits on the always-on-top `LegR`/`ShinR`/
       `FootR` sprites vs `LegL`/etc based on facing** (near/far art
       swap) — legs visibly collapsed into a bunched clump near the hip.
    2. **Same texture swap, but leave each sprite's `offset` fixed to its
       own node instead of swapping it too** — user reported "legs are
       crossed... feet are also messed up," and clarified the actual want
       was structural: "while walking right, LegR should be in front. The
       same sprite should be in front when moving left but now in the
       position of LegL" — i.e. `LegR`'s texture identity should stay fixed
       and always-on-top, but the IK chain itself should occupy the spatial
       role `LegL` used to.
    3. **Reassign which `FootTarget` node each `SoupTwoBoneIK`'s
       `target_node` points to when facing flips** (`leg_r_ik` → `FootL
       Target` while facing left, instead of always `FootR Target`) — this
       is what attempt 2's clarification actually seemed to ask for, but
       it's geometrically broken: `FootR Target` sits at local `(-18, 30)`
       and `FootL Target` at `(5, 31)` — **not mirror-symmetric** — while
       `LegR`'s own bone anchor is at `(-3, 1)` and `LegL`'s at `(3, 1)`.
       Reassigning `leg_r_ik` (anchored left of hip) to reach for `FootL
       Target` (positioned right of hip) makes it reach across the body's
       centerline. Confirmed via reading the actual rest positions, not
       guessed. User: "still fucked up" (crossed legs again, different
       cause than attempt 2).
    4. **Mirror `LegR`/`LegL`'s own `Bone2D.scale.x` directly**
       (`leg_r_ik.joint_one_bone_node.scale.x = facing`), reverting the
       target/texture swaps from attempts 2-3 entirely. `SoupTwoBoneIK`
       looked purpose-built for this: it derives `scale_orient` from
       `sign(joint_one_bone_node.global_transform.determinant())` and
       threads it through the whole bend/angle formula. Verified headlessly
       (no NaN, plausible non-degenerate positions, determinant genuinely
       flips negative on facing left) and reasoned through the transform
       algebra by hand (see git history of this doc/conversation if
       recovering the derivation matters) — but user tested it in-editor
       and reported "it just doesn't work at all." **Root cause not fully
       confirmed** — the leading theory: `SoupTwoBoneIK.handle_ik()` sets
       `joint_one_bone_node.global_rotation = ...`, and Godot's
       `global_rotation` *setter* re-decomposes/recomposes the local
       transform using its own canonical convention (decomposed scale.x is
       always reported/reconstructed non-negative; a reflection's sign
       always lands on scale.y instead) — so even though `scale_orient`
       correctly sees the reflection for the BEND-ANGLE math, the bone's
       actual rendered basis vectors after that write may not end up as a
       true mirror-across-local-X of the unmirrored case. Unconfirmed
       whether this theory is actually why it looked wrong in-game, since
       it was never visually inspected together with the user (see below).
    **All four attempts fully reverted** (`git checkout -- 
    player/lower_body_controller.gd player/player.tscn`) — the leg-facing
    code is back to exactly what SoupIK migration originally landed (this
    same bullet's parent entry above), GUT 28/28. This TODO item is
    reopened, not done.
    **Process notes for next attempt:** (a) the user explicitly does not
    want Claude launching the game/taking screenshots to self-diagnose this
    — ask for a screenshot or ask them to test in-editor instead, see
    [[feedback_visual_bugs_ask_first]]; (b) given seven total dead ends now
    across two IK-system generations (three CCDIK-era, one SoupIK
    orientation-only fix that stuck, four more SoupIK-era chirality
    attempts today), a purely-code, no-visual-feedback-loop attempt is
    unlikely to succeed on the next try either — worth explicitly proposing
    to the user, before writing more code, either (a) iterating live
    together in-editor (them screenshotting each attempt) rather than
    shipping a full guess, or (b) reconsidering whether `leg_left.png`/
    `leg_right.png` etc. being deliberately *different* (not mirror-image)
    art is worth the ongoing implementation cost vs. simpler
    mirror-symmetric art that a plain `flip_h`/rotation approach (the
    already-working SoupIK baseline) would just handle for free.
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

## Design Philosophy (scope discipline)

Keep the game focused on **action-platforming**, not RPG systems. Concretely:

- **Bounties are the main progression track**; quests are optional — jobs,
  favors, lore, and relationships layered on top, not required to advance.
- **Reuse existing mechanics** rather than constantly adding new ones for each
  new bounty or region.
- **Creatures get variety through behavior and combinations**, not sheer
  headcount — a handful of well-differentiated enemy types combined in new
  ways beats a long roster of one-note enemies.
- **Regions differentiate through setting, atmosphere, creatures, and
  situations** — not by requiring wholly new mechanics per region.

## Open Questions / To Fill In

These aren't derivable from the code — fill in when decided so this doc stays
useful:

- Target platform(s) — PC/Steam only, or consoles too?
- Team size — solo, or collaborators involved?
- Rough timeline / milestones (first playable demo, vertical slice, etc.)?
- Monetization / pricing plan?
- What exactly is the "something deeper" behind the strange phenomena/
  forgotten-folklore thread — is there a concrete overarching antagonist or
  mystery planned yet, beyond the region-by-region human-expansion-vs-
  supernatural pattern?
- Art direction reference points (pixel art style, palette, specific games as
  visual touchstones)?
- Audio direction (music genre references, sound design tone)?
