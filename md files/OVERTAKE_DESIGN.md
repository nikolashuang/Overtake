# OVERTAKE_DESIGN.md

> **DO NOT CHANGE ANY CODE while creating, maintaining, or refreshing this design document unless the user explicitly asks for code changes.**
>
> This document holds broader gameplay/design direction. `OVERTAKE_CONTEXT.md` is the canonical source for current architecture, implementation state, conventions, and known technical issues.
>
> **ALL MEASUREMENT UNITS ARE RECORDED IN STUDS unless otherwise stated.**

# Core Direction

Overtake is a competitive parkour/racing game built around:
- Movement mastery.
- Momentum management.
- Route choice.
- Execution and timing.
- Shortcuts and recovery.
- Light contact mechanics that interfere with opponents without turning the game into a traditional fighting game.

Momentum is the central movement resource. Movement techniques can preserve, consume, lose, or build it.

# Parkour Mechanics

## Vaulting and Vault Boosting
- Standard vaulting is primarily a way to clear slightly tall obstacles while retaining Momentum.
- Taller obstacles become more mantle-like and consume Momentum.
- Timing a jump onto/over shorter vaultable objects can produce a small forward boost at a small Momentum cost.
- The boost is situational; ordinary vaulting may be better when extra distance/height is unnecessary.

### Vaulting Heights
- Max Vault Height: 4
- Min Vault Height: 2.5
- Anything below 2.5 is considered a hurdle.

### Vaulting Feel
- Waist-level vault: fast and smooth; favor stable forward velocity.
- Head-only / taller traversal: mantle-like, with more upward movement and a Momentum cost.

## Climbing / Extended Climbing
- Climbing helps gain limited height while scaling a wall.
- Normal climbing provides controlled upward movement before the player begins to lose their grip.
- Extended Climbing can be mechanically input while climbing to gain a considerable upward boost.
- Players can Extended Climb up to twice before being forced off the wall.
- After an Extended Climb, the player returns to normal climbing.
- Correctly timing Extended Climbs can considerably increase the total height reached.

Exact timing and exploit-resistant implementation are undecided.

## Wall Run
- Allows traversal along walls when there is not perfect footing below.
- Gain a small upward boost when the Wall Run begins.
- The player gets a free 1.5-second Wall Run window.
- After the free window expires, the player enters **Wall Sliding**.
- Wall Sliding eats into the player's momentum at 33 per second while active
- This allows players to continue moving forward at a descended rate if they couldn't reach their desired destination

## Wall Drift (Only active after Wall Run) (Deprecated, now Wall Sliding)
- The player begins sliding downward along the wall.
- Consumes Momentum at 33 per second while active.

## Wall Drift (Updated Idea)
- Separate mechanic from Wall Run.
- Intended as a recovery mechanic for high-speed falls.
- If the player is falling faster than a set downward-speed threshold and is close enough to a wall, they can enter Wall Drift.
- Wall Drift lets the player scrape/slide down the wall to reduce the severity of the fall.
- Intended to help salvage bad falls without completely removing the consequences of poor route choice.
- Exact downward-speed requirement, input, Momentum cost, and fall-speed reduction are undecided.

## Edge Boosting
- If the player uses **Lunge** while on the edge of an object, greatly increase the power output.
- **Status: under review.**

## Sliding
- Uses **Shift**.
- Lets the player traverse beneath low geometry / heights below the character.
- Retains most Momentum during a useful slide.
- Staying in the slide for the full bar/duration should eventually slow the player significantly and lose Momentum.

## Recovery Roll
- Uses **Shift**.
- Recovery Roll timing determines how much Momentum is preserved after a hard landing.
- Within 0.3 seconds: retain most Momentum.
- Within 0.5 seconds: lose some Momentum.
- No successful roll: lose almost all Momentum and receive a small stagger.
- Hard landings should still consume some Momentum even with a successful Recovery Roll.
- Momentum loss should scale with fall severity rather than being completely negated by rolling.
- Vertical fall distance is the current preferred value for calculating landing severity.
- Downward velocity may be used to determine whether the fall is severe enough to trigger Recovery Roll behavior.
- Exact fall-distance thresholds and Momentum-loss scaling are undecided.

## Wall Redirect
- Lets the player bounce/redirect onto adjacent walls.
- Good timing should enable efficient scaling of tight spaces.
- Mistiming can cause a slip.
- Builds a small amount of Momentum.

## Ledge Catching
- If the player narrowly misses a ledge while falling, ledge catching can prevent the fall.
- A defensive catch costs almost all Momentum.
- Catching a ledge during a jump can transition into an upward vault and can grant a small amount of Momentum.

## Lunge
Current design name: **Power Jumping**.
Current implementation name in code: **Lunge**.
Input direction:
- Tap Middle Mouse Button, then Space shortly afterward.
- MMB is a setup/timing input, not intended as a hold.

Design intent:
- At/near max movement speed, jumps become significantly longer.
- Consumes Momentum.
- Has a cooldown to prevent repeated use.

## Trip
- If the player runs into an obstacle without vaulting or attempting to jump over it, they trip on the obstacle.
- The player loses some Momentum.
- Exact Momentum loss is undecided.

## Wall Crash
- If the player runs into a wall without sliding, climbing, or otherwise avoiding it, they crash into the wall.
- The player loses more Momentum than they would from a Trip.
- Exact Momentum loss is undecided.


# Momentum

- Momentum is the central movement resource.
- Momentum contributes directly to movement speed.
- Simply running builds Momentum over time.
- Correct parkour can preserve/build Momentum.
- Mistakes, inactivity, inefficient movement, some traversal techniques, and contact mechanics can consume Momentum.
- Normal implementation currently targets 0–100 Momentum.
- `RisingMomentum` ramps from 5 toward 25 at approximately 12 units per second.
- RisingMomentum buildup uses `deltaTime` and should remain frame-rate independent.
- 60 FPS is used only as a feel-testing/reference baseline.
- Mechanics that intentionally consume Momentum may temporarily halt normal Momentum gain so regeneration does not fight the mechanic's drain.

## Uncapped Flow
- Flow State can temporarily add Momentum beyond the normal cap.
- Normal Momentum bar: intended blue.
- Extra Flow-generated amount: orange.
- Orange portion is **Uncapped Flow**.

# Contact Mechanics

Contact is intended as race interference / contact-sport mechanics, not traditional combat.

## Sliding / Tripping
- While sliding, create two small hitboxes around the player's feet.
- If they connect with another player's legs, briefly trip the victim and push them slightly sideways.
- Attacker consumes 10% Momentum on a successful hit.
- Victim loses 25% Momentum.
- Sliding itself also continuously consumes Momentum, so the successful-hit cost is in addition to the normal sliding drain.

## Shove
- Players can run into/shoulder bump another player.
- Attacker consumes 45% Momentum.
- Victim loses 70% Momentum.
- These values are provisional and should be adjusted after playtesting against the current Momentum recovery rate.

## Dropkick
- While falling, create two small hitboxes around the player's feet.
- If the hitboxes connect with another player's body, both players immediately stagger onto the floor.
- Both players lose all Momentum.
- The victim's `RisingMomentum` is temporarily capped around 10, slowing their Momentum buildup after the hit.
- The duration and exact implementation of the RisingMomentum cap are still undecided.

# Attributes

Normal players can equip up to **two** attributes.

## Anchored Footing
- More resistant to stagger from Slides and Shoves.
- Retains some Momentum when affected.
- No special protection against Dropkick.
- Larger Recovery Roll timing window.

## Swift Feet
- Slightly longer Wall Runs.
- Wall Runs consume less Momentum.
- Sliding retains more Momentum.

## Heavy Landing
- Dropkick staggers the opponent longer.
- Shoves are slightly stronger.
- Retains some Momentum when using contact abilities.

## Flow State
- Correct movement gradually builds Flow stacks.
- Significant mistakes clear Flow.
- Maximum stacks grant **Flow State High**.
- Flow State High temporarily grants additional Momentum beyond the normal cap.
- Extra Momentum should be highlighted in orange and treated as Uncapped Flow.

## Quick Recovery
- Reduces Momentum penalties associated with Ledge Catching.
- Improves Recovery Roll protection against Momentum loss.

## Max Adrenaline
Activation:
- Available at Max Momentum.
- Player consumes 100% of normal Momentum for temporary additive benefits.

Intended temporary benefits:
- Burst of speed for X seconds.
- Contact immunity for X seconds.

Afterward:
- Player becomes fatigued for 10 seconds.
- Fatigue reduces Momentum gained from movement/parkour.
- During fatigue, effective Momentum is capped at 75% of normal maximum.

## I Don't Need Assistance
- Automatically granted when the player has no **Attributes** equipped.
- Provides no gameplay benefits.
- Exists purely as a prestige/flex option to show opponents that the player is competing without Attribute bonuses.

# Gadgets — Future Scope

Players may equip only one gadget.

## Angle Hooker
- Lets the player hook around buildings.
- Builds a small amount of Momentum.

## Body Crasher
- Player crashes into the ground and creates a small shockwave.
- Nearby opponents are slowed.
- User is also slowed, but less severely.
- Single-use.

# Ranked

## Base Rank Progression
- Everyone begins **Unranked**.
- 50 Elo/rating points are required to reach Bronze.
- Once Bronze is reached, the player should not fall below Bronze.
- Unranked acts like a provisional period before normal ranked progression.

Target progression:
- Bronze
- Silver
- Gold
- Diamond

Current repository thresholds:
- Unranked: 0
- Bronze: 50
- Silver: 350
- Gold: 650
- Diamond: 950
- Apex: 1250
- Defiant: 1550
- Unbound: 1950

## Apex
- Unlimited players may reach Apex.

## Defiant
- After roughly 30 players reach Defiant, the entry gate becomes the current 30th player's Elo.
- Dropping below the qualifying top group demotes the player to Apex.
- Exact player count is undecided.

## Unbound
- After roughly 15 players reach Unbound, the entry gate becomes the current 15th player's Elo.
- Dropping below the qualifying top group demotes the player to Defiant.
- Exact player count is undecided.

## Hardcore Ranked Modifier
- Both players must accept before the race.
- Increased rating stakes.
- Falling off course = disqualification.
- Otherwise uses the same race mechanics.

# Menu / Modes

## Multiplayer

### Ranked
- Ranked 1s.
- Ranked 2s is a possible future option and not confirmed.

### Casual

#### Multiplayer Racing
- Similar core race format to Ranked.
- Multiple players in one server.
- Maps rotate.
- Players compete for first place.
- More chaotic and lower-stakes than Ranked.

#### Gauntlet
- 20 players.
- 10 different maps.
- Each player starts at 100 HP.
- Players face different opponents in 1v1 rounds.
- Winning keeps the player safe.
- Losing removes HP based on round depth.
- Last player standing wins.
- Every 2 rounds, players can select a new Attribute up to a maximum of 4.
- Later selection points can allow keeping or swapping Attributes.

### Rotating / Event Modes
Possible:
- Storm Chase.
- Tower Climb / Flood Escape.

## Singleplayer

### Challenge
- Multiple challenges/levels for practicing and improving.
- Challenges can alter normal rules to create specific movement tests.

### Practice Tool
- Choose from available maps.
- Freeform movement/flying around the map to revisit sections and practice mistakes.

### Time Trials
- Race any map against the clock.
- Per-map fastest-time leaderboards.

# Inventory / Shop
- Inventory.
- Shop.
- Robux cosmetic/content assets.
- Current noted product idea: 12 FPS animation pack.
- Avoid pay-to-win movement advantages in competitive/ranked play.

# Settings
A Settings area is planned.
The profile template already reserves a `Settings` table.

# Scope Notes
- Movement feel and the race loop are the priority.
- Ranked, contact mechanics, attributes, anti-exploit validation, matchmaking, and content production are each large systems.
- Gadgets and rotating modes should remain future scope until the core race experience is strong.
- Do not treat every brainstormed mechanic as launch scope.

# Design Decisions Needing Confirmation
- Keep or remove Edge Boosting.
- Final Power Jump requirement: max Momentum vs high Momentum vs fixed minimum.
- Ranked 2s.
- Defiant qualifying player count.
- Unbound qualifying player count.
- Hardcore unlock requirement and rating stakes.
- Exact contact Momentum percentages after playtesting.
- Exact Overdrive duration/stat bonuses.
- Exact Wall Hop camera/timing rules.
- Which rotating modes belong in initial release.

# Documentation Maintenance Rule
When asked to update this design document:
1. **DO NOT CHANGE ANY CODE unless the user explicitly asks for code changes.**
2. Preserve confirmed mechanics and clearly mark uncertain ideas.
3. Put implementation/architecture facts in `OVERTAKE_CONTEXT.md`.
4. Put broad gameplay intentions, balance targets, modes, progression, and future concepts here.
5. Do not silently promote brainstorms into confirmed decisions.
