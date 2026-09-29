# OVERTAKE_CONTEXT.md

> **DO NOT CHANGE ANY CODE while creating, maintaining, or refreshing this context document unless the user explicitly asks for code changes.**
>
> This file is the canonical cross-chat context for the Overtake project. When this file conflicts with an older chat, prefer this file and the current repository state.
>
> Keep this file compact. Record architectural decisions, current behavior, important conventions, unresolved problems, and implementation status. Do not turn it into a full design document; broader design belongs in `OVERTAKE_DESIGN.md`.

## Project Identity

- **Project:** Overtake
- **Platform:** Roblox
- **Language:** Luau
- **Repo:** `nikolashuang/Overtake`
- **Default branch:** `master`
- **Project sync/build:** Rojo
- Core direction: competitive parkour/racing built around movement mastery, Momentum, route choice, execution, shortcuts, recovery, and light contact mechanics rather than traditional combat.
- All gameplay measurements in the design notes are expressed in **studs** unless otherwise stated.

## Repository Layout / Responsibilities

### `src/shared/Character/CharacterClass.luau`
Shared Character object used by both client and server.

Current responsibilities:
- Holds runtime character references: Player, Character, Humanoid, RootPart.
- Holds movement state such as Momentum, RisingMomentum, Stationary, Staggered, Fatigue.
- Owns current movement actions and eligibility checks.
- Binds an Attachment named `MovementAttachment` to the HumanoidRootPart.
- Updates Momentum and WalkSpeed.
- Updates cached vault/hurdle detection state.
- Executes Vault/Hurdle and Lunge movement.
- Contains placeholders for mantle, slide, wall run, recovery roll, and ledge catch.

Important convention:
- Prefer the CharacterClass as the character-facing API for movement actions.
- Keep raw environment/detection calculations in shared physics/config modules where practical.
- `CanX()` answers whether an action may happen.
- `X()` performs the action.
- Avoid introducing extra `TryX()` wrappers unless there is a concrete reason.

### `src/shared/Parkour/ParkourPhysics.luau`
Shared world/detection helpers.

Current behavior:
- `DetectObstacle(character, vaultDistance)` casts forward rays from stable RootPart-relative offsets.
- Three forward checks currently exist: head, waist/root, and knee.
- Character models containing a Humanoid are filtered from obstacle results.
- Any head hit rejects the obstacle.
- Waist hit with no head hit => `"Vault"`.
- Knee hit with no waist/head hit => `"Hurdle"`.
- Includes debug Beam visualization state.

### `src/shared/Parkour/ParkourConfig.luau`
Canonical numeric configuration for implemented parkour systems.

Current values:
- Vault max height design/config: 4
- Vault distance: 4–15, interpolated from Momentum
- Minimum vault speed: 25
- Vault duration: 0.3 s
- Tall vault Momentum cost: 7.5
- Base movement speed: 12
- Momentum range: 0–100
- Max RisingMomentum: 35
- Startup Momentum threshold: 15
- Lunge/Power Jump input window: 0.2 s
- Lunge height: 5.5
- Lunge power: 30
- Lunge cooldown: 0.75 s
- Lunge Momentum cost: 20

Numbers are balance values and may change. Prefer the config module over duplicating values in logic.

### `src/client/Controllers/ParkourController.luau`
Client input-to-action routing for parkour.

Current behavior:
- MouseButton3/MMB records a timestamp.
- Space runs the current movement priority:
  1. Lunge/Power Jump if `CanLunge()` and Space occurs within the MMB timing window.
  2. Vault/Hurdle if `CanVault()`.
  3. Otherwise Roblox's normal jump behavior is not explicitly suppressed by this controller.
- Successful local Vault or Lunge execution is followed by a `ParkourRemote` server event.

Terminology note:
- The current code calls the max-speed-style jump action **Lunge**.
- The design notes call the mechanic **Power Jumping**.
- Until renamed in code, treat Lunge as the current implementation name for the Power Jump mechanic.

### `src/client/Controllers/AnimationController.luau`
Loads and controls client animation tracks.

Current groups:
- Movement: Lunge, Startup, Sprint, FullSprint.
- Parkour: VaultVariant1, Hurdle.

### `src/client/main.client.luau`
Client bootstrap and frame loops.

Current responsibilities:
- Creates the client CharacterClass.
- Initializes ParkourController and AnimationController.
- Rebinds on CharacterAdded.
- Routes InputBegan.
- Runs `UpdateVaultObject()` every `PreRender`.
- Selects/adjusts running animations every `PreRender`.
- Runs `UpdateMomentum(deltaTime)` every `PostSimulation`.

### `src/server/main.server.luau`
Server player/profile/character bootstrap and parkour remote endpoint.

Current state:
- Loads player profiles.
- Creates one server CharacterClass per Player.
- Binds CharacterAdded.
- Stores CharacterClass objects in `Characters[player]`.
- Receives `ParkourRemote` traversal requests.
- **Server-side parkour validation/execution is not implemented yet.**
- A server `PostSimulation` Momentum update loop exists only as commented-out code.

### `src/server/PlayerProfile/ProfileService.luau`
DataStore profile loading/saving and template reconciliation.

Current behavior:
- Uses DataStore `PlayerProfiles`.
- Creates missing fields from `ProfileTemplate` recursively.
- Uses `UpdateAsync` when saving.
- Keeps active profile objects in a server-side table.

### `src/server/PlayerProfile/ProfileTemplate.luau`
Current saved-data shape:
- Level
- XP
- Wins
- Losses
- CurrentRank
- VisibleRankRating
- Currency
- Inventory
- Gadgets
- Settings

### `src/shared/RankedElosConfig.luau`
Current rank rating thresholds:
- Unranked: 0
- Bronze: 50
- Silver: 350
- Gold: 650
- Diamond: 950
- Apex: 1250
- Defiant: 1550
- Unbound: 1950

The top-rank leaderboard-gate design in `OVERTAKE_DESIGN.md` is not implemented by this config yet.

## Client / Server Movement Model

### Current implementation
The client currently owns the responsive movement simulation:
- Momentum is updated on the client.
- Vault/Hurdle detection is continuously cached on the client.
- Vault/Hurdle and Lunge are executed locally first.
- The client informs the server afterward through `ParkourRemote`.

### Intended direction
- Preserve immediate client responsiveness for movement.
- The server must independently validate movement actions rather than trusting traversal strings or client-reported Momentum blindly.
- Server validation should check plausible state/timing/position/cooldowns before accepting movement-related consequences.
- Persistent/ranked/contact outcomes must be server authoritative.
- Do not make every movement action wait for a server round trip before the local player moves.

### Current server gaps
- The `"Vaulting"` remote branch is empty.
- There is currently no `"Lunging"` branch in the server handler.
- Server Momentum simulation is not active.
- No strike/exploit-validation system exists in the current repository.
- Contact mechanics are not implemented.

## Momentum System — Current Implementation

Momentum is the central movement resource.

Current code behavior:
- Starts at 0.
- Base `RisingMomentum` starts at 5.
- While moving, Momentum rises by `RisingMomentum * deltaTime`.
- RisingMomentum itself increases over time up to 35.
- When stationary, a 3-second grace period occurs before decay.
- After the grace period, Momentum decays at 50 per second until 0.
- Stopping resets RisingMomentum to 5 once decay begins.
- WalkSpeed is recalculated as base 12 + `MomentumUnit * 0.3`.
- At 100 Momentum this currently yields WalkSpeed 42.
- Vault detection distance scales linearly from 4 to 15 based on Momentum percentage.

Design intent:
- Momentum affects speed and movement power.
- Different traversal moves preserve, consume, lose, or build Momentum.
- Flow State may temporarily create Momentum beyond the normal cap; this is design-only today.

## Vaulting / Hurdling — Current Implementation

### Detection
- Detection runs every client `PreRender` while the player is moving.
- Vault distance scales with Momentum.
- Head hit => obstacle rejected.
- Waist hit => Vault.
- Knee-only hit => Hurdle.
- Player/Humanoid models are ignored as vault geometry.

### Execution
Vault:
- Uses `LinearVelocity` + `AlignOrientation`.
- Preserves at least a minimum forward speed.
- Adds forward and upward velocity.
- Plays `VaultVariant1`.
- If the detected object's `Size.Y` is at least the configured max vault height, the code uses a stronger upward velocity and consumes 7.5 Momentum.

Hurdle:
- Uses forward velocity plus a small vertical component.
- Plays `HurdleAnim`.
- Does not currently consume Momentum.

### Design thresholds
- Under 2.5 studs: hurdle.
- 2.5–4 studs: standard vault range.
- Taller/mantle-like traversal is intended to cost Momentum.

### Known mismatch
The current ray logic does not directly calculate obstacle top height against the character. The execution code uses the hit Instance's full `Size.Y`, so the code does not yet perfectly express the design's 2.5/4 stud thresholds or true world-space obstacle height.

## Power Jump / Lunge — Current Implementation

Input:
- Press MMB.
- Press Space within 0.2 seconds.

Current `CanLunge()` requirements:
- At least 25 Momentum.
- Not Staggered.
- 0.75-second cooldown elapsed.
- Not currently in Freefall.

Current action:
- Adds forward velocity + vertical velocity.
- Consumes 20 Momentum.
- Plays Lunge animation.

Design direction:
- This mechanic is called Power Jumping in the design.
- It is intended to reward high movement speed / Momentum and produce a significantly longer jump.
- Current code does **not** require max Momentum/max movement speed yet.

## Space / Input Priority

Current implemented Space priority:
1. MMB -> Space Lunge/Power Jump combo.
2. Vault/Hurdle if currently detected and allowed.
3. Normal jump otherwise.

Current MMB behavior:
- Tap, not hold.
- Stores the press time for the short combo window.

Sliding is intended to use **Shift**, not Space.

As more Space-based actions are added, keep the priority centralized rather than scattering mutually competing Space handlers across multiple connections.

## Animation State

Current locomotion selection:
- Momentum below `STARTUP_MOMENTUM` => StartupAnim.
- Above startup threshold => SprintAnim.
- Animation speed is adjusted based on Momentum.
- Movement animations stop while stationary, jumping, or freefalling.

`FullSprintAnim` is loaded but not currently selected by the locomotion state logic.

## Ranked / Saved Progress State

The repository currently contains:
- Rank names and simple RequiredRating thresholds.
- Saved VisibleRankRating.
- Saved CurrentRank.
- Wins/Losses.
- General inventory/currency/gadget/settings containers.

Not yet implemented in the repo:
- Ranked matchmaking.
- Rating gain/loss calculation.
- Top-player dynamic gates for Defiant/Unbound.
- Hardcore race agreement/rules.
- Leaderboard promotion/demotion logic.

## Mechanics Status

### Implemented / actively being built
- Momentum buildup/decay and Momentum-based WalkSpeed.
- Momentum-scaled vault detection distance.
- Vaulting.
- Hurdling.
- MMB -> Space Lunge/Power Jump prototype.
- Movement/vault/hurdle animations.
- Basic player profile persistence.
- Static rank threshold config.

### Stubbed in CharacterClass
- Ledge Boost.
- Sliding.
- Wall Run.
- Recovery Roll eligibility.
- Ledge Catch eligibility.

### Design-only / not implemented
- Wall hop/boosting.
- Wall Redirect.
- Full ledge catching behavior.
- Contact mechanics: slide trip, shove, dropkick.
- Attributes.
- Flow State / Uncapped Flow.
- Overdrive/Fatigue behavior.
- Gadgets.
- Ranked matchmaking and high-rank ladder gates.
- Casual modes, Gauntlet, rotating modes, challenge/practice/time trials.

## Known Issues / Risks / Unfinished Work

- Server traversal validation is unfinished.
- Client and server do not yet maintain a verified synchronized Momentum model.
- Server CharacterClass construction currently passes `profile` directly where `CharacterClass.new` expects a system-like table containing fields such as `Profile` and `AnimationController`. Treat server-side CharacterClass dependencies as unfinished.
- Server CharacterClass has no AnimationController, while movement methods currently call `self.AnimationController.PlayAnimation(...)`; server-side execution of those same methods would require separation/guarding of client-only presentation concerns.
- Vault height classification is based on ray layers plus Instance `Size.Y`, not an actual measured obstacle top height.
- Debug ray Beams are created by shared parkour physics and are currently part of normal runtime behavior.
- `mb3` starts as nil; current Space handling performs `time() - mb3`, so Space before any MMB press is a potential runtime error.
- `CanLunge()` currently prints debug output.
- Lunge creates an `AlignOrientation` but only parents the `LinearVelocity`; the orientation object is scheduled with Debris but is not currently parented in `Lunge()`.
- The client bootstrap stores the initial `character` variable and rebinds `characterObject` on respawn; any future logic that uses the old local `character` directly should be checked for stale references.
- Profile saving is simple DataStore code and does not yet show session locking, retry queues, shutdown handling, or conflict protection expected for a production competitive game.
- Contact/ranked anti-exploit validation remains a future requirement.

These are context notes, **not permission to change code automatically**.

## Established Conventions / Decisions

- Shared CharacterClass is intentional so client and server can share character rules/state APIs where appropriate.
- Do not blindly duplicate entire movement implementations into separate client/server classes.
- Client responsiveness and server authority should coexist: local execution for feel, server validation for trust.
- CharacterClass should expose direct eligibility/action methods such as `CanVault()` and `VaultOrHurdle()`.
- Detection helpers belong outside input code.
- Important tunable numbers belong in config modules.
- Prefer a centralized input priority for overlapping actions.
- Sliding is on Shift.
- MMB is currently the setup input for the Power Jump/Lunge combo.
- Use `time()`/elapsed seconds for input combo windows rather than treating `tick()` as a frame counter.
- Do not trust arbitrary traversal names, Momentum values, contact hits, ratings, or persistent outcomes sent by the client.
- This is a movement/contact-sport game, not a fighting game.

## Current Work Focus

Current repository work is centered on the movement foundation:
1. Momentum.
2. Vault/Hurdle detection and execution.
3. Power Jump/Lunge input behavior.
4. Client/server CharacterClass architecture.
5. Future server validation.

When a major implementation or architecture decision changes, update this file. Do not add every transient debugging experiment.

## Context Maintenance Rule

When asked to "update Overtake context":
1. **DO NOT CHANGE ANY CODE unless the user separately and explicitly asks for code changes.**
2. Read the current repository state.
3. Read this file.
4. Reconcile new explicit decisions from the current conversation.
5. Update only documentation unless code changes were explicitly requested.
6. Mark speculative ideas as undecided/design-only rather than canonical implementation.
