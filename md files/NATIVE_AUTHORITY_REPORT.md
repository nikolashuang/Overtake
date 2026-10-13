# Native server authority experiment

Branch: `Experimental-Server-Authority`. Reference commit: `8c0cd45`.
Investigation and documentation checked on October 13, 2026.

## Outcome and validation boundary

The experimental movement path uses Roblox native input replication, fixed simulation, predicted attributes, and engine rollback/resimulation. All movement mechanics implemented in the reference source have been routed through that path. This is a runnable Studio prototype build, **not a claim of successful Roblox runtime testing**.

Completed checks: official simulation-access metadata audit; Luau compilation; 20 regression tests executing the actual production module bodies against engine test doubles; Rojo place builds. The doubles test formulas, eligibility, deadlines, state restoration, and replay. They do not test Roblox physics, replication, streaming, animation replication, or engine corrections.

Native server authority is available: Roblox announced its full release on July 9, 2026. The older beta instructions are superseded by the current Workspace setup. [Official full-release announcement](https://devforum.roblox.com/t/full-release-ship-fair-and-competitive-games-with-server-authority/4727993).

## Architecture

`MovementSimulation` binds a shared 60 Hz callback on the server and owning client. The server evaluates every player's movement; each client predicts its own. Other players retain ordinary authoritative replication rather than speculative simulation with unknown inputs.

Server-created `InputContext` objects are parented under each Player. Keyboard/MMB actions and scriptable camera-relative world direction use native Input Actions. The client sends only bounded horizontal direction intent and buttons. The server reads frame inputs and independently computes ray hits, eligibility, cooldowns, costs, collisions, and velocity changes. `ParkourRemote` has no handler. The Studio diagnostics RemoteEvent is outgoing telemetry only; it has no gameplay input handler.

`CharacterClass` retains the existing eligibility/action methods and formulas. A small attribute-backed adapter preserves field names while placing persistent simulation state on two predicted attachments under the root. Each attachment holds at most 32 schema attributes. Attributes cover momentum/ramp, stationary time, velocity history, ability flags, slide direction, wall speed/direction/time, cooldowns, input edges/windows, landing/roll state, deadlines, and presentation event IDs. State defaults are initialized inside simulation, not by a separate client constructor. Temporary ray results are overwritten before use each frame; immutable instance references are lifecycle data.

Sixteen server-created constraints have stable identities for the lifetime of a character. Each ability reuses its own slots, allowing boosts from different abilities to overlap. Left/right extended-climb boosts have separate slots so both can coexist. `Enabled`, targets, and `ExpiresAt` attributes are changed in simulation. Deadline expiry disables constraints in simulation. There are no movement `task.delay`, Debris lifetimes, cached speculative instance handles, or Lua snapshots in the runtime path. If a transient boost is reactivated before its prior slot expires, the shared simulation clones the matching replicated constraint and parents it in that callback. Native instance stitching reconciles the clone; later activations reuse disabled pool slots. Pool instances are resolved from the predicted instance graph on each use.

Native attribute tracking and replay are provided by the engine; the adapter is not a custom prediction framework. [Native simulation guide](https://create.roblox.com/docs/projects/server-authority), [RunService API](https://create.roblox.com/docs/reference/engine/classes/RunService).

Camera and cosmetic animation/UI updates run outside core simulation. Animations are optional and reuse the existing place's `ReplicatedStorage.Animations`. Live tracks are queried through `Animator:GetTrackByAnimationId` rather than cached across rollback. Continuous slide, crawl, wall, ledge, and locomotion effects are reconciled to current state. One-shot cosmetic corrections and visibility to other clients remain Studio verification items. [Animation and predicted-instance guidance](https://create.roblox.com/docs/projects/server-authority/techniques).

## Files

| File | Responsibility |
| --- | --- |
| `default.project.json` | Native engine prerequisites and Scriptable default movement; explicit client source mapping excludes the locally ignored legacy PlayerModule |
| `src/shared/Simulation/MovementInputs.luau` | Player-owned Input Actions, key bindings, validation |
| `src/shared/Simulation/MovementState.luau` | Predicted attribute schema/adapter |
| `src/shared/Simulation/MovementSimulation.luau` | Shared frame ordering, input priority, deadlines, lifecycle |
| `src/shared/Simulation/MovementDiagnostics.luau` | Studio state telemetry, same-tick momentum comparison, rollback/resimulation and correction logging |
| `src/shared/Character/CharacterClass.luau` | Existing mechanics with predicted fields and reusable constraints |
| `src/shared/Parkour/ParkourDetection.luau` | Existing ray geometry/classification without simulation-unsafe visualization/ancestry calls |
| `src/client/main.client.luau` | Input intent and local presentation bootstrap |
| `src/client/Controllers/MovementPresentation.luau` | Animations, original optional UI, debug toggle |
| `src/server/main.server.luau` | Native simulation/profile bootstrap; Studio avoids DataStores |
| `src/server/ExperimentalCourse.server.luau` | Opt-in Studio-only practice geometry |
| `tests/native.project.json` | Standalone practice-place build |
| `tests/run.ps1`, `engine-mock.luau`, `movement.spec.luau` | Production-source regression test harness |

The old ParkourController, InputController, AnimationController, HumanoidController, and UIController remain as behavioral references and are not required by the experimental bootstraps. ParkourConfig, profiles, rank configuration, OVERTAKE_CONTEXT.md, and OVERTAKE_DESIGN.md are unchanged.

## Mechanic status

All rows below mean code migrated and structurally tested where applicable, **not verified in Studio**.

| Mechanic | Preserved implementation |
| --- | --- |
| Basic movement/sprint | Camera-relative WASD; speed 12 + momentum x 0.25 |
| Momentum | 5-to-25 ramp, +12/sec; forward-speed gate; stationary grace/decay; consumption and crawl reset |
| Slide/directional slide/crawl | Shift, 65 minimum, 50/sec drain; direction locked; overhang/clearance checks |
| Lunge | MMB then Space within 0.2 sec; 25 eligibility, 35 cost, +30 forward/+15 upward, 0.75 cooldown |
| Vault/hurdle | Original root-relative ray layers, 2.5-to-8 detection range; velocities, 7.5 tall-vault cost, timings/cooldown |
| Wall run/redirect | Original tangent speed transfer, +20 initial vertical boost, 2 sec window, 33/sec wall-slide decay, side-key redirect powers |
| Wall drift | Existing post-wall-run `nowWallDrifting` behavior migrated; separate high-speed-fall drift remains design-only in the reference |
| Climb/extended climb | Original normal boost, two side-consumption flags, input window, velocity/cooldown values |
| Ledge catch/exit | Original precise top-ray placement, 75% severe-fall cost, align constraints and exit boost |
| Recovery roll | Original -65/-190 bounds, 0.075/0.125 sec windows, 30 imperfect-roll cost, landing delay |

No horizontal speed cap was added. A regression explicitly verifies a 120-stud/sec lunge produces 150-stud/sec forward speed and transfers that speed to wall running. Numbers follow the actual source, which differs from the older context/design notes.

## Documented deviations and limits

- Fixed 60 Hz ordering replaces render/PreSimulation/PostSimulation listeners. Deadlines are quantized to simulation steps. Landing/freefall edges are sampled rather than handled by unsynchronized signals.
- Resetting creates fresh state; cooldowns/input windows no longer survive respawn accidentally.
- A prior boost deadline cannot clear a later wall-run/slide/climb momentum hold. Normal vaults still build momentum; only tall vaults hold it.
- Normal R15 collision settings are restored instead of enabling every body part. MeshParts participate in slide collision switching. The slide collider's world pose is set before welding, avoiding an incorrectly captured weld offset.
- Zero-direction normalization is guarded. Wrong-side wall redirect no longer enables an unexpired zero-velocity constraint. Recovery roll is limited to one success per landing.
- Detection excludes Humanoid models using a lifecycle cache outside simulation. Traversal ray thresholds/classification remain unchanged. Debug Beams are replaced by native visualizer/logs.
- Studio profile loading/saving is skipped; published profile behavior remains the existing service. No ranked/contact/attribute gameplay is invented: these were not implemented in the source and receive no client result endpoint.
- Desktop keyboard/mouse is the supported prototype input surface. A mobile/gamepad binding pass remains future work; existing parkour routing was keyboard/MMB-based.
- AuthorityMode and PlayerScriptsUseInputActionSystem are protected settings in current official metadata. Runtime scripts cannot reliably inspect/set them. Rojo serializes them into the place; verify them in Studio. The bootstrap checks accessible prerequisites and an explicit project marker and fails rather than introducing a fallback. Merely setting the marker is not proof of native authority.
- Original Animation instances and MainGui are not in this repository. The standalone build runs movement without them. Sync into a copy of the existing Overtake place to evaluate its custom presentation. No animation IDs were fabricated.
- Rapid same-ability reactivation uses additional native predicted pool slots to retain overlapping boosts. Verify instance stitching and expiry during rapid wall redirects/re-entry in Studio. Pool growth should stop at the maximum observed concurrency.
- Terrain vault height still inherits the original BasePart Size assumption. Dynamic geometry, skeletal collision behavior, streamed geometry, animation corrections, and native Humanoid timing require actual engine tests.

## Studio setup and test instructions

Use an up-to-date Roblox Studio and a disposable place. Keep the avatar rig R15.

From this branch:

```powershell
rojo build tests/native.project.json --output Overtake-NativeAuthority-Test.rbxlx
# Or sync movement into a COPY of the existing Overtake place:
rojo serve default.project.json
```

Open the generated test place. In Workspace Properties verify:

1. AuthorityMode = Server.
2. NextGenerationReplication = Enabled.
3. PlayerScriptsUseInputActionSystem = Enabled.
4. UseFixedSimulation = Enabled.
5. SignalBehavior = Deferred.
6. StreamingEnabled = true.

In StarterPlayer verify DevComputerMovementMode and DevTouchMovementMode are Scriptable. Leave Roblox's default camera enabled. These settings avoid a competing default movement/jump writer; no PlayerModule path is assumed. [StarterPlayer API](https://create.roblox.com/docs/reference/engine/classes/StarterPlayer).

Start with Test > Server & Clients, two clients. Inspect both server and client Output for simulation-access errors. Enable the server authority visualizer with Ctrl+Shift+F6. Set Workspace's `OvertakeDiagnostics` attribute true in the client context, or use the original Debug button if that UI exists. The server sends read-only state snapshots; client logs distinguish server momentum from its first prediction at the same simulation tick. The optional Misprediction signal prints actual corrected attribute values when available; otherwise use the visualizer. Rollback events and resimulated callback counts remain observable. A missing diagnostic sample is not reported as a matching prediction.

Repeat with Studio network emulation: baseline; roughly 100 ms each direction; roughly 200 ms each direction with jitter; packet loss if your build exposes it. Record the configured units/direction (some controls express round-trip latency). Inspect input accept/drop rates and server simulation FPS. Input drops and ordinary corrections must not cause kicks or penalties. No punitive anticheat is implemented.

## Manual checklist / unresolved engine checks

- [ ] Spawn, WASD/camera-relative movement, ordinary jump, no doubled/default jump.
- [ ] Sprint momentum ramp, stationary one-second grace, decay, crawl reset.
- [ ] Shift at/under eligibility; early release, direction changes, low roof, crawl, stand-up clearance.
- [ ] MMB/Space success and missed timing; repeated lunge cooldown; ordinary Space before MMB.
- [ ] Lunge into each wall side at high speed; retained tangent velocity and momentum; no speed clamping.
- [ ] Hurdle, normal/tall vault, cooldown, jumping restoration; moving or rotated obstacles.
- [ ] Both wall sides, initial boost, free window, drift/decay, W release, contact loss, A/D redirects.
- [ ] Normal climb, A/Space and D/Space once each; repeated-side rejection, landing reset.
- [ ] Falling/jumping ledge catches, severe-fall cost, Space mantle, Shift drop, constraint cleanup.
- [ ] Perfect/imperfect/missed rolls before and after landing; invalid fall speeds; no double roll.
- [ ] Force natural mispredictions using latency, shared moving obstacles, and other-player interactions; verify corrected attributes, resimulation, and bounded constraint count (16 base slots plus reused overlap pools).
- [ ] Reset/die during every traversal and while inputs are held; no old handles, stale timers, or cooldown leakage.
- [ ] On one client attempt to change momentum/velocity/CFrame/WalkSpeed or fire old ParkourRemote; the server state must remain governed by native inputs and simulation.
- [ ] Other-client visibility, custom animation timing after rollback, character collision and camera shift-lock behavior.
- [ ] Chat/text entry, streamed-in obstacles, different frame rates, multiple R15 avatar body sizes.

Passing these engine checks is required before calling the prototype runtime-verified or deciding to adopt it. Use the baseline branch/place to compare feel; retain both builds.

Run the regression suite with the official Luau CLI:

```powershell
./tests/run.ps1 -Luau 'C:\path\to\luau.exe'
```

The harness bundles production source with injected engine doubles into a temporary file; it is not shipped as a runtime prediction component.


