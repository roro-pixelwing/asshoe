# WITNESS — Game Design Document (v0.1, pre-production)

> Working title. A first-person, no-combat survival horror game **inspired by** Outlast's
> design (helpless protagonist, camcorder night vision, hide-and-run). Mechanics and genre are
> free to use; Outlast's story, characters, names, setting, art, audio and UI are not (see §11).

---

## 1. Pillars

1. **You cannot fight.** Your only options are: run, hide, or stay unseen.
2. **The camera is your eyes and your clock.** Night vision lets you see in the dark, but it
   drains batteries. Darkness = safety from being seen, danger from not seeing.
3. **Fear comes from anticipation, not frequency.** Long quiet stretches make the scares land.
4. **Every scary moment teaches something.** Each enemy encounter introduces or tests one rule.

## 2. Pitch & Story

**Setting:** *Saint Agnes Sanatorium*, a closed 1950s tuberculosis hospital in the Oregon
mountains, reopened in secret by the **Halden Institute** as a "sleep research" facility.

**Protagonist:** **Mara Quinn**, a freelance documentary filmmaker. Her younger brother **Eli**
volunteered for a paid sleep study at Saint Agnes and stopped answering calls 3 weeks ago.
She breaks in with a camcorder to find him. (Personal motive > Outlast's journalist motive:
it gives the ending emotional weight.)

**The secret:** Halden is running *Project Lullaby* — subjects are kept from REM sleep for weeks
using an implanted device. Deprived minds begin to "share" one waking nightmare. The patients
call the thing at the centre of it **The Night Nurse**. She isn't a ghost: she is the collective
hallucination given a body by a real person — the study's first subject — who now believes
she's still caring for patients.

**Twist (Act 3):** Eli isn't a victim. He's the study's newest *orderly* — he joined Halden
willingly, recruited the patients, and called Mara here because the study needs an
"outside mind" that hasn't been deprived yet. Every recording Mara makes is being watched.

**Structure (≈2–3 hours, 3 acts, 9 levels):**

| Act | Levels | Beat | New threat |
|-----|--------|------|------------|
| I — Admission | 1 Grounds & entry · 2 Admin wing · 3 Records basement | Find Eli's file; facility is in chaos after a "lights out" event | **The Orderly** (brute, patrols, teaches hiding) |
| II — Ward C | 4 Male ward · 5 Hydrotherapy · 6 Chapel / morgue | Learn about Lullaby; power must be restored | **The Twins** (two stalkers who flank; teach sound) and **Dr. Vos** (scripted pursuer with keys) |
| III — Lullaby | 7 Sleep lab · 8 Rooftop/bell tower · 9 The Nursery | Twist revealed; final escape | **The Night Nurse** (only appears in darkness, teaches light/dark rule) |

**Endings:** (a) Mara uploads her footage and escapes — but her final tape shows her sleeping
in a ward bed. (b) If she found all of Eli's tapes, she can refuse to escape and destroy the
lab, trapping herself. Two endings is enough; more is scope creep.

**Storytelling methods:** documents, Mara's camcorder notes (she narrates in a whisper when
recording key events, like a journal), audio tapes, environmental scenes. No long cutscenes.

## 3. Core mechanics

| System | Rules |
|--------|-------|
| **Movement** | Walk, sprint (stamina-free, but loud), crouch (silent, slow), peek around corners (Q/E), climb/vault low obstacles, squeeze through gaps, look behind while running (hold key). |
| **Camcorder** | Raise/lower (RMB). Zoom. Night vision (F) — green-tinted, noisy, the only way to see in true darkness. Drains batteries (~90 s per battery). Max 4 spare batteries. |
| **Recording** | Filming key moments adds notes to the journal (story progression, collectible). |
| **Hiding** | Lockers, under beds, in barrels. Hold breath (limited) when an enemy searches nearby. Enemies may check a hiding spot if they *saw* you enter it. |
| **Doors** | Can be closed and barricaded (pushing a cabinet) to buy seconds. Enemies break doors in 2–3 hits. |
| **Health** | 3 hits. Regenerates slowly when not in danger. Screen goes red/blurry, heartbeat audio. Third hit = death → checkpoint. |
| **Objectives** | Classic "find 2 fuses / 3 valves / keycard" with enemies patrolling the objective area. Keep each to ≤3 items. |

## 4. Enemy AI (the most important system)

State machine shared by all enemies, tuned per enemy:

```
PATROL → (heard noise) → INVESTIGATE → (saw player) → CHASE
   ↑                          ↓ (nothing)              ↓ (lost sight > N s)
   └────────── RETURN ←── SEARCH (check hiding spots, look around) ←┘
```

- **Perception:** sight cone (distance shortened in darkness, lengthened if player's light/IR
  lamp is visible), hearing radius (sprint > walk > crouch = ~0), memory of last seen position.
- **Chase design:** enemy speed ≈ player sprint speed − 5%, so the player escapes only by
  breaking line of sight, closing doors, vaulting or sliding under things — never by out-running
  in a straight line. Rubber-banding: enemy speeds up slightly if far behind, slows if about to
  catch the player in the first 2 seconds (fairness).
- **Scripted chases** (one per level, the "set pieces"): a hand-built route with guided
  lighting (exits are lit), destructible obstacles, and a scare at the end. These are the
  "scary chase" moments — they're levels, not AI.

| Enemy | Behaviour |
|-------|-----------|
| The Orderly | Slow patrol, fast chase, rips open lockers if he saw you enter. |
| The Twins | Hunt in pairs; one stays at last-known spot while the other searches. Very sensitive hearing, poor sight. |
| Dr. Vos | Never runs. Walks relentlessly, always knows roughly where you are, locks doors behind him. |
| The Night Nurse | Only exists in unlit areas. Visible **only** through night vision. Standing in light makes her vanish. Batteries become life-or-death. |

## 5. Scare design

Rule of thumb: **1 major scare per ~5 minutes, 3–4 minor ones in between, and silence.**

| Type | Example | When |
|------|---------|------|
| Ambient | distant screams, footsteps above, door slams off-screen | constant, randomised |
| False alarm | a rat knocks over a bottle right after a tense corridor | to reset tension |
| Reveal | night vision turns on → a patient standing 1 m from you, just staring | early Act I |
| Jump scare | enemy bursts through a door you were about to open | max once per level |
| Delayed | something grabs you from a locker **while you're hiding** in the next one | after teaching lockers are safe |
| Subversion | a "safe room" isn't; the Nurse is in the lit room and the lights flicker out | Act III |

Implementation: **trigger volumes** + a `ScareDirector` that tracks time since last scare and
player stress (recent chases, health) and can veto a scare if it's too soon.

## 6. Level design method

1. Paper map → 2. graybox in-engine → 3. playtest AI/hiding → 4. lighting pass → 5. art.
Each level has: one *loop* (a circular route so chases don't dead-end), 3+ hiding spots near
every patrol route, one scripted chase, one major scare.

## 7. Audio (half the horror)

- Dynamic music layers: calm → tension (enemy investigating) → chase (stinger + drums).
- Player breathing tied to stress; heartbeat when an enemy is near and you're hiding.
- 3D positional enemy footsteps so the player can *track enemies by ear*.
- Silence is a tool: cut music entirely before a big scare.

## 8. Technology

**Recommended: Godot 4 (C# or GDScript).** Open source (MIT), free, no royalties, good 3D
lighting (SDFGI/volumetric fog), built-in NavigationServer for AI pathfinding, exports to
Windows/Linux/Mac.

Alternatives, honestly compared:
- **Unreal 5** — best visuals for this genre, but heavy, C++/Blueprints, and 5% royalty after
  $1M. Hard for a solo beginner.
- **Unity** — huge tutorial base, not open source, licensing history makes some devs wary.
- **Three.js (browser)** — easiest to share, but you'll build everything yourself; visuals cap lower.

**Open-source/free assets we can legally use:**
- Godot FPS controller templates (e.g. community MIT-licensed controllers) as a starting point.
- Models/textures: Kenney (CC0), Poly Haven (CC0 textures/HDRIs), ambientCG (CC0).
- Sound: Freesound.org (check each file — CC0 / CC-BY need attribution, avoid CC-BY-NC if selling).
- Character models: Mixamo (free animations; usable in games), or MakeHuman (CC0 output).
- We keep an `ASSETS_CREDITS.md` with every source + licence from day one.

**Code architecture (Godot):**
```
/scenes   player, enemies, levels, ui
/scripts
  player/        PlayerController, Camcorder, HidingSpot, Health
  ai/            EnemyBase (state machine), Perception, NoiseEmitter
  director/      ScareDirector, ChaseSequence, MusicDirector
  systems/       Inventory(batteries, keys), Objectives, SaveCheckpoint, Journal
/assets  models, textures, audio (+ ASSETS_CREDITS.md)
```

## 9. Milestones

| # | Milestone | Done when |
|---|-----------|-----------|
| M1 | Vertical slice core | Player moves, crouches, peeks; camcorder with night vision + batteries; one graybox corridor |
| M2 | AI | Orderly patrols/investigates/chases/searches; hiding in lockers works; death + checkpoint |
| M3 | Scare toolkit | Trigger volumes, ScareDirector, dynamic music, 3 scares in the graybox |
| M4 | **Level 1 complete** | Graybox → lit → first playable 15-minute level with one scripted chase. **Playtest here.** |
| M5+ | Remaining levels | One level per milestone; new enemies as introduced |

M1–M4 is the real test of whether the game is fun. Don't build level 2 before level 1 scares people.

## 10. Scope warning

Outlast was made by a ~10-person studio of ex-AAA developers over ~2 years. A solo/hobby
version should aim for **Act I only (3 levels, ~40 minutes)** first. If that's good, continue.

## 11. Legal: why this isn't a "direct copy"

Game mechanics (hiding, camcorder night vision, no combat) are **not copyrightable** — that's why
Amnesia, Outlast, and dozens of others share them. What *is* protected: the name "Outlast",
Mount Massive Asylum, Miles Upshur, Murkoff, Walrider, Chris Walker, its models, textures,
sounds, music and UI. Copying those would make the game impossible to publish (Steam/itch
takedowns) and risks legal action. So this design keeps the *feel* and changes everything
else. If it's purely private practice you'd never release, a clone is fine for learning —
but you'd be throwing away the most valuable part: an original story you can actually ship.

---

## Open decisions for you

1. Engine: Godot 4 (recommended) — or do you prefer Unity/Unreal/browser?
2. Scope: start with Act I vertical slice (recommended) or full game plan?
3. Story: keep *WITNESS / Saint Agnes / Mara & Eli*, or change setting/protagonist?
4. Art style: realistic (harder, needs assets) vs. stylised low-poly/PS1-style (much easier
   solo, and currently popular in indie horror — e.g. Puppet Combo games).
