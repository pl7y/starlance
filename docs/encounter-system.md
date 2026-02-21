# Downstar — Encounter & Stage System

> **Architecture Documentation**
> Last updated: 2026-02-16

---

## Table of Contents

1. [Overview & Philosophy](#overview--philosophy)
2. [Two-Layer Architecture](#two-layer-architecture)
3. [Resource Class Hierarchy](#resource-class-hierarchy)
4. [Encounter Resource (`Encounter`)](#encounter-resource)
5. [Event Resources](#event-resources)
   - [EncounterEvent (base)](#encounterevent-base)
   - [SpawnEvent](#spawnevent)
   - [GateEvent](#gateevent)
   - [PhaseEvent](#phaseevent)
   - [MarkerEvent](#markerevent)
   - [SignalEvent](#signalevent)
6. [Payload Resources](#payload-resources)
   - [Formation](#formation)
   - [MovementStyle](#movestyle)
   - [Pattern](#pattern)
7. [Runtime Nodes](#runtime-nodes)
   - [EncounterRunner](#encounterrunner)
   - [EnemySpawner](#enemyspawner)
   - [StageDirector](#stagedirector)
8. [Clock Modes: Time vs Distance](#clock-modes-time-vs-distance)
9. [Gate System](#gate-system)
10. [Signal Contract](#signal-contract)
11. [Scene Tree Wiring](#scene-tree-wiring)
12. [Pacing & Level Design Philosophy](#pacing--level-design-philosophy)
13. [Roguelite Integration Points](#roguelite-integration-points)
14. [Authoring an Encounter (.tres)](#authoring-an-encounter-tres)
15. [Example: Full Stage Plan](#example-full-stage-plan)
16. [File Manifest](#file-manifest)
17. [Procedural Generation Pipeline](#procedural-generation-pipeline)
    - [StageTemplate](#stagetemplate)
    - [SlotDefinition](#slotdefinition)
    - [EncounterPool & EncounterPoolEntry](#encounterpool--encounterpoolentry)
    - [EncounterDeck](#encounterdeck)
    - [DifficultyProfile](#difficultyprofile)
    - [RhythmSpacer](#rhythmspacer)
    - [StageBuilder](#stagebuilder)
    - [StageDirector Integration](#stagedirector-integration)

---

## Overview & Philosophy

The encounter system is built on three core principles:

1. **Declarative, not imperative.** Encounter data describes _what_ to spawn and _when_, never _how_ to run logic. Events are pure Godot `Resource` subclasses with exported fields — no code in timeline data.

2. **Deterministic-friendly.** Given the same `Encounter` + `seed` + progress input, the system produces identical spawns every time. This enables replays, ghost systems, and controlled procedural generation.

3. **Decoupled via injection.** The `EncounterRunner` never instantiates enemies itself — it delegates to an injected `EnemySpawner` node. The `StageDirector` never reads enemy state — it reacts to runner signals. Each layer has strict boundaries.

---

## Two-Layer Architecture

The system is split into two layers that communicate via signals:

```
┌─────────────────────────────────────────────────────────────┐
│                     StageDirector (MACRO)                    │
│                                                              │
│  Owns: segment sequence, run seed, corruption, modifiers,   │
│        rail speed, transitions                               │
│                                                              │
│  Does: picks encounters, starts/stops runner, pauses rail,  │
│        reacts to gates, triggers rewards/cutscenes           │
│                                                              │
│  Does NOT: spawn enemies, read encounter timelines           │
└──────────────────────────┬──────────────────────────────────┘
                           │ start() / stop() / pause()
                           │ signals ↑↑↑
┌──────────────────────────▼──────────────────────────────────┐
│                   EncounterRunner (MICRO)                     │
│                                                              │
│  Owns: current encounter timeline, progress clock,          │
│        gate state, deterministic RNG                         │
│                                                              │
│  Does: advances progress, fires events at thresholds,       │
│        manages gates, calls EnemySpawner                     │
│                                                              │
│  Does NOT: decide which encounter is next, control rail     │
│            speed, know about corruption/modifiers            │
└──────────────────────────┬──────────────────────────────────┘
                           │ spawn_group()
┌──────────────────────────▼──────────────────────────────────┐
│                     EnemySpawner (FACTORY)                    │
│                                                              │
│  Owns: actual instantiation logic, applying MovementStyle /     │
│        Pattern / HP to enemy nodes                           │
│                                                              │
│  Does: instantiates PackedScenes, sets world_pos,           │
│        configures enemy properties                           │
│                                                              │
│  Does NOT: decide when to spawn, manage timelines           │
└─────────────────────────────────────────────────────────────┘
```

### Why this split matters for Downstar

Downstar is a roguelite. The `StageDirector` is where run-specific state lives:

- **Planet modifiers** ("High Gravity", "Solar Flare") are stored as `modifiers: PackedStringArray`
- **Corruption scaling** (extra elites, faster bullets) is stored as `corruption: float`
- **Faction swaps** (AI constructs vs parasites) affect which encounter pool to draw from

The `EncounterRunner` stays dumb and deterministic: given encounter + seed + progress source, it always produces the same spawns. This makes balancing easier, replay/ghost systems possible, and procedural generation controllable.

---

## Resource Class Hierarchy

```
Resource
 ├── Encounter                    # Top-level container
 ├── EncounterEvent (base)        # Abstract base for all events
 │    ├── SpawnEvent              # Spawn a group of enemies
 │    ├── GateEvent               # Pause progression until condition met
 │    ├── PhaseEvent              # Mark a named phase boundary
 │    ├── MarkerEvent             # Named marker with payload
 │    └── SignalEvent             # Fire a custom signal
 ├── Formation                    # Spatial arrangement of a group
 ├── MovementStyle                    # Movement descriptor for enemies
 └── Pattern                      # Firing / attack config for enemies
```

All resource classes use `@tool` so they validate in the editor, and `class_name` so they appear in Godot's "New Resource" menu.

---

## Encounter Resource

**File:** `scenes/encounters/encounter.gd`
**Class:** `Encounter extends Resource`

The top-level container for an encounter timeline. One `.tres` file = one encounter.

### Exported Properties

| Property       | Type                    | Default | Description                                                                                                                |
| -------------- | ----------------------- | ------- | -------------------------------------------------------------------------------------------------------------------------- |
| `id`           | `String`                | `""`    | Unique identifier for save/progression system                                                                              |
| `display_name` | `String`                | `""`    | Human-readable name shown in debug/UI                                                                                      |
| `duration`     | `float`                 | `30.0`  | Total duration (seconds or distance units). Clamped ≥ 0.1. Runner stops when progress reaches this, even if events remain. |
| `events`       | `Array[EncounterEvent]` | `[]`    | Ordered list of events. Sorted by `time` on `validate()`.                                                                  |
| `tags`         | `PackedStringArray`     | `[]`    | Freeform tags for biome filtering, difficulty tiers, etc.                                                                  |
| `seed_hint`    | `int`                   | `0`     | Recommended seed. 0 = let the runner pick one.                                                                             |

### Methods

| Method                 | Returns                 | Description                                                                                             |
| ---------------------- | ----------------------- | ------------------------------------------------------------------------------------------------------- |
| `validate()`           | `void`                  | Clamps negative event times to 0, sorts events by time ascending. Call at load-time or from the editor. |
| `events_with_tag(tag)` | `Array[EncounterEvent]` | Returns only events carrying the given tag. Useful for mutation queries.                                |
| `last_event_time()`    | `float`                 | Returns the time of the latest event. Useful for auto-setting duration.                                 |

### Usage Notes

- `duration` is in **the same units as the runner's clock mode**. If the runner is in `DISTANCE` mode, duration is distance units; if `TIME` mode, it's seconds. Author accordingly.
- Events at times beyond `duration` will never fire — they are effectively disabled.
- `validate()` is called automatically when assigned to a runner via the setter.

---

## Event Resources

### EncounterEvent (base)

**File:** `scenes/encounters/encounter_event.gd`
**Class:** `EncounterEvent extends Resource`

Abstract base class. Never used directly — always subclass.

| Property  | Type                | Default | Description                                                                               |
| --------- | ------------------- | ------- | ----------------------------------------------------------------------------------------- |
| `time`    | `float`             | `0.0`   | When this event fires (seconds or distance, depending on runner clock mode). Clamped ≥ 0. |
| `enabled` | `bool`              | `true`  | If false, the runner skips this event entirely. Useful for testing or mutation.           |
| `tags`    | `PackedStringArray` | `[]`    | Freeform tags for roguelite mutation/filtering (e.g. `"elite"`, `"biome:ice"`).           |

| Method         | Returns | Description                                |
| -------------- | ------- | ------------------------------------------ |
| `has_tag(tag)` | `bool`  | Checks if the event carries the given tag. |

### Design rationale: `time` field naming

The field is called `time` even in distance mode. This is intentional — it represents "progress at which to fire", and renaming it per mode would complicate the common base class. Think of it as "timeline position" regardless of what drives the timeline.

---

### SpawnEvent

**File:** `scenes/encounters/spawn_event.gd`
**Class:** `SpawnEvent extends EncounterEvent`

The primary event type. Declares a group of enemies to spawn.

| Property        | Type            | Default  | Description                                                                |
| --------------- | --------------- | -------- | -------------------------------------------------------------------------- |
| `enemy_scene`   | `PackedScene`   | `null`   | The enemy scene to instantiate.                                            |
| `count`         | `int`           | `1`      | Number of enemies to spawn. Range: 1–100.                                  |
| `formation`     | `Formation`     | `null`   | Spatial formation for the group. Null = all at origin.                     |
| `z_start`       | `float`         | `95.0`   | World-Z distance ahead of camera where enemies appear.                     |
| `move_style`    | `MovementStyle` | `null`   | Movement descriptor applied to each enemy at spawn.                        |
| `pattern`       | `Pattern`       | `null`   | Firing/attack pattern applied to each enemy.                               |
| `hp`            | `int`           | `0`      | HP override per enemy. 0 = use scene default.                              |
| `spawn_space`   | `SpawnSpace`    | `WORLD`  | Whether positions are in world space or screen-normalised coords.          |
| `spawn_origin`  | `Vector2`       | `(0, 0)` | Centre of the spawn group.                                                 |
| `spread`        | `Vector2`       | `(0, 0)` | Per-axis random jitter added to each unit's offset.                        |
| `height_offset` | `float`         | `-30.0`  | Y offset relative to horizon. Matches the old `height_over_horizon` value. |

**SpawnSpace enum:**

- `WORLD` — positions are in world units.
- `SCREEN` — positions are screen-normalised (not yet implemented in spawner; reserved for future use).

### How spawning works (data flow)

```
SpawnEvent (data)
    │
    ▼
EncounterRunner._handle_spawn()
    │  reads formation → get_offsets(count)
    │  passes event + offsets + RNG to:
    ▼
EnemySpawner.spawn_group()
    │  for each offset:
    │    1. instantiate enemy_scene
    │    2. apply spread jitter (using runner's RNG)
    │    3. set world_pos = camera_pos + z_start + origin + offset + height_offset
    │    4. add to world node
    │    5. apply move_style → enemy movement properties
    │    6. apply pattern → enemy firing properties
    │    7. apply hp override
    ▼
Enemy node is alive in the scene tree, fully configured
```

---

### GateEvent

**File:** `scenes/encounters/gate_event.gd`
**Class:** `GateEvent extends EncounterEvent`

Pauses encounter progression until a condition is met. Gates are rare and dramatic — used for miniboss arenas, story beats, and boss transitions.

| Property     | Type        | Default            | Description                                                            |
| ------------ | ----------- | ------------------ | ---------------------------------------------------------------------- |
| `condition`  | `Condition` | `ALL_ENEMIES_DEAD` | Which condition clears this gate.                                      |
| `hold_time`  | `float`     | `3.0`              | For `TIMER` condition — how many seconds to hold.                      |
| `custom_key` | `String`    | `""`               | For `CUSTOM` condition — the key checked via `runner.set_gate_flag()`. |
| `label`      | `String`    | `""`               | Optional label for debug/HUD (e.g. "Clear this wave!").                |

**Condition enum:**

| Value               | Clears when…                                                          |
| ------------------- | --------------------------------------------------------------------- |
| `ALL_ENEMIES_DEAD`  | No nodes remain in the `"enemies"` group.                             |
| `WAVE_ENEMIES_DEAD` | All enemies in the `"enemies"` group are dead (same check currently). |
| `TIMER`             | `hold_time` seconds have elapsed since gate entry.                    |
| `CUSTOM`            | `runner.set_gate_flag(custom_key)` is called externally.              |

### Gate behaviour in detail

1. Runner reaches a `GateEvent` in the timeline → `_enter_gate()`.
2. Runner emits `gate_entered(gate)` signal.
3. `StageDirector` receives `gate_entered` → calls `pause_rail()`:
   - Saves current rail speed.
   - Sets player speed to 0 (rail stops).
   - Calls `runner.pause()` (progress freezes).
4. Runner internally checks the gate condition each frame in `_update_gate()`.
5. When condition is met → `_clear_gate()` → emits `gate_cleared(gate)`.
6. `StageDirector` receives `gate_cleared` → calls `resume_rail()`:
   - Restores saved rail speed.
   - Calls `runner.resume()`.
7. Runner resumes advancing events from the next event after the gate.

This is **Pattern A+B combined**:

- **Pattern A:** Runner emits gate state, director pauses rail.
- **Pattern B:** Runner's progress is pulled from rail distance, so if rail stops, progress naturally stops.

---

### PhaseEvent

**File:** `scenes/encounters/phase_event.gd`
**Class:** `PhaseEvent extends EncounterEvent`

Marks the beginning of a named phase. Downstream systems react to phase changes (music, camera, HUD).

| Property     | Type     | Default | Description                                           |
| ------------ | -------- | ------- | ----------------------------------------------------- |
| `phase_name` | `String` | `""`    | e.g. `"approach"`, `"assault"`, `"retreat"`, `"boss"` |

The runner emits `phase_changed(phase_name)` when this event fires.

---

### MarkerEvent

**File:** `scenes/encounters/marker_event.gd`
**Class:** `MarkerEvent extends EncounterEvent`

A named marker with an optional key-value payload. Used for UI cues, audio triggers, or anything that doesn't spawn enemies or change phases.

| Property      | Type         | Default | Description                                                |
| ------------- | ------------ | ------- | ---------------------------------------------------------- |
| `marker_name` | `String`     | `""`    | e.g. `"warning_flash"`, `"music_shift"`, `"pickup_health"` |
| `payload`     | `Dictionary` | `{}`    | Arbitrary data for listeners to parse.                     |

The runner emits `marker_hit(marker_name, payload)` when this event fires.

---

### SignalEvent

**File:** `scenes/encounters/signal_event.gd`
**Class:** `SignalEvent extends EncounterEvent`

Fires a custom signal through the runner, allowing the encounter timeline to trigger game-specific hooks without the DSL knowing about them.

| Property      | Type     | Default | Description                |
| ------------- | -------- | ------- | -------------------------- |
| `signal_name` | `String` | `""`    | Identifier for the signal. |
| `argument`    | `String` | `""`    | Optional string argument.  |

The runner emits `custom_signal(signal_name, argument)` when this event fires.

---

## Payload Resources

These are sub-resources embedded inside `SpawnEvent` — they describe _how_ enemies behave, not _when_ they appear.

### Formation

**File:** `scenes/encounters/formation.resource.gd`
**Class:** `Formation extends Resource`

Describes the spatial arrangement of a group of enemies.

Use one of these concrete subclasses:

| Class             | File                                             | Shape behaviour                            |
| ----------------- | ------------------------------------------------ | ------------------------------------------ |
| `PointFormation`  | `scenes/encounters/point_formation.resource.gd`  | All units at `(0, 0)`                      |
| `LineFormation`   | `scenes/encounters/line_formation.resource.gd`   | Units spread on X axis, centered           |
| `VFormation`      | `scenes/encounters/v_formation.resource.gd`      | Alternating left/right, fanning backward   |
| `GridFormation`   | `scenes/encounters/grid_formation.resource.gd`   | Rows × columns grid, centered              |
| `CircleFormation` | `scenes/encounters/circle_formation.resource.gd` | Units evenly distributed on a circle       |
| `VolumeFormation` | `scenes/encounters/volume_formation.resource.gd` | Random distribution in a sampled 3D volume |

`ShapeFormation` (`scenes/encounters/shape_formation.resource.gd`) remains as a legacy adapter for backward compatibility.

**Key method:** `get_offsets(count: int) -> Array[Vector2]`
Returns an array of local (X, Y) offsets, one per unit. These are in world space relative to the spawn origin.

### Visual examples

```
LINE (5 units, spacing.x=4):         V (5 units):
  •  •  •  •  •                           •
 -8 -4  0  4  8                        •     •
                                     •         •

GRID (6 units, 3 cols):              CIRCLE (6 units, radius=5):
  •  •  •                                •
  •  •  •                             •     •
                                      •     •
                                         •
```

---

### MovementStyle

**File:** `scenes/encounters/move_style.gd`
**Class:** `MovementStyle extends Resource`

Concrete movement style resources live in `scenes/encounters/movement_styles/` and each one creates a runtime strategy in `scenes/movement/`.

All movement styles share base property `z_lock`:

- `NONE`: movement in absolute world coordinates.
- `PLAYER`: compensates player/camera forward run so movement behaves as if the player were not advancing in Z.

#### PolylineMovementStyle

**File:** `scenes/encounters/movement_styles/polyline_movement_style.gd`
**Class:** `PolylineMovementStyle extends MovementStyle`

Moves an enemy along a `PackedVector3Array` of waypoints from first to last.
Points are interpreted as local offsets from spawn position.

| Property | Type                 | Default | Description                                                                                |
| -------- | -------------------- | ------- | ------------------------------------------------------------------------------------------ |
| `points` | `PackedVector3Array` | `[]`    | Polyline waypoints (local offsets from spawn).                                             |
| `close`  | `bool`               | `false` | Appends first point at end (returns to start).                                             |
| `cycle`  | `Cycle`              | `NONE`  | End-of-path behaviour: `NONE`, `LOOP`, `PING_PONG`.                                        |
| `speed`  | `float`              | `40.0`  | Units per second along the path.                                                           |
| `z_lock` | `ZLock`              | `NONE`  | Inherited from `MovementStyle` (`NONE` absolute world Z, `PLAYER` compensates player run). |

#### BounceMovementStyle

**File:** `scenes/encounters/movement_styles/bounce_movement_style.gd`
**Class:** `BounceMovementStyle extends MovementStyle`

Moves an enemy while oscillating up/down. Travel direction comes from target mode.

| Property           | Type      | Default   | Description                                    |
| ------------------ | --------- | --------- | ---------------------------------------------- |
| `target`           | `Target`  | `PLAYER`  | Movement target mode: `PLAYER` or `DIRECTION`. |
| `speed`            | `float`   | `18.0`    | Travel speed along selected target direction.  |
| `bounce_amplitude` | `float`   | `4.0`     | Vertical bounce amplitude.                     |
| `bounce_duration`  | `float`   | `0.83`    | Duration of one bounce arc in seconds.         |
| `pause`            | `float`   | `0.0`     | Seconds spent on ground between bounces.       |
| `direction`        | `Vector3` | `(0,0,1)` | Axis used when `target = DIRECTION`.           |
| `z_lock`           | `ZLock`   | `NONE`    | Inherited from `MovementStyle`.                |

Data-only descriptor for enemy movement. Read by `EnemySpawner` at spawn time and mapped onto `Enemy` properties.

| Property       | Type      | Default      | Description                                                                 |
| -------------- | --------- | ------------ | --------------------------------------------------------------------------- |
| `type`         | `Type`    | `STATIC`     | Movement type. Maps to `Enemy.MovePattern` by convention (same enum order). |
| `speed_z`      | `float`   | `12.0`       | Forward speed. Positive = away from camera in Downstar.                     |
| `speed_x`      | `float`   | `0.0`        | Lateral X speed (used by DRIFT).                                            |
| `speed_y`      | `float`   | `0.0`        | Lateral Y speed (used by DRIFT).                                            |
| `amplitude`    | `Vector2` | `(4.0, 2.0)` | Sine/curve amplitude for X and Y.                                           |
| `frequency`    | `float`   | `1.2`        | Sine frequency.                                                             |
| `dive_turn`    | `float`   | `2.5`        | Homing strength for DIVE_AT_PLAYER.                                         |
| `orbit_radius` | `float`   | `6.0`        | Orbit radius.                                                               |
| `orbit_speed`  | `float`   | `1.5`        | Orbit angular speed.                                                        |

**Type enum:** `STATIC`, `DRIFT`, `SINE_STRAFE`, `DIVE_AT_PLAYER`, `SWOOP`, `ORBIT`

Must be kept in sync with `Enemy.MovePattern` — the `EnemySpawner` casts `style.type as int` to set `enemy.pattern`.

---

### Pattern

**File:** `scenes/encounters/pattern.gd`
**Class:** `Pattern extends Resource`

Data-only descriptor for enemy firing behaviour.

| Property        | Type    | Default | Description                                     |
| --------------- | ------- | ------- | ----------------------------------------------- |
| `fire_interval` | `float` | `1.2`   | Seconds between shots.                          |
| `bullet_speed`  | `float` | `90.0`  | Bullet travel speed.                            |
| `aim_lead_y`    | `float` | `0.0`   | Vertical prediction offset.                     |
| `fire_min_z`    | `float` | `18.0`  | Minimum depth at which the enemy starts firing. |
| `fire_max_z`    | `float` | `95.0`  | Maximum depth (stop firing beyond this).        |

---

## Runtime Nodes

### EncounterRunner

**File:** `scenes/encounters/encounter_runner.gd`
**Class:** `EncounterRunner extends Node`

The micro layer. Plays a single `Encounter` resource over time or distance.

#### Exports

| Property     | Type           | Default    | Description                      |
| ------------ | -------------- | ---------- | -------------------------------- |
| `encounter`  | `Encounter`    | `null`     | Auto-validates on set.           |
| `autostart`  | `bool`         | `false`    | Start on `_ready()`.             |
| `spawner`    | `EnemySpawner` | `null`     | Injected spawner node reference. |
| `seed`       | `int`          | `0`        | 0 = auto.                        |
| `clock_mode` | `ClockMode`    | `DISTANCE` | Default clock mode.              |

#### ClockMode Enum

| Value      | Progress advances by…                   | Use case                       |
| ---------- | --------------------------------------- | ------------------------------ |
| `TIME`     | Elapsed seconds (`_process(delta)`)     | Boss fights, arenas, cutscenes |
| `DISTANCE` | External distance feed from player/rail | Normal rail segments           |

#### Public API

| Method             | Signature                     | Description                                                                |
| ------------------ | ----------------------------- | -------------------------------------------------------------------------- |
| `start()`          | `(enc?, run_seed?, mode?)`    | Begin playback. All params optional — defaults to exports.                 |
| `set_distance()`   | `(absolute_distance: float)`  | Feed distance from rail/player. Only advances progress in `DISTANCE` mode. |
| `pause()`          | `()`                          | Freeze progress and event firing.                                          |
| `resume()`         | `()`                          | Unfreeze.                                                                  |
| `stop()`           | `()`                          | Hard stop. Does NOT emit `encounter_finished`.                             |
| `restart()`        | `()`                          | `stop()` + `start()`.                                                      |
| `fail()`           | `(reason?)`                   | Abort — emits `encounter_failed`.                                          |
| `load_encounter()` | `(enc, auto?)`                | Load a new Encounter; optionally auto-start.                               |
| `set_gate_flag()`  | `(key: String)`               | Set a custom flag; clears CUSTOM gates matching this key.                  |
| `apply_mutators()` | `(mutators: Array[Callable])` | Apply mutation functions to the encounter.                                 |
| `is_running()`     | `-> bool`                     | True while playing (includes paused/gated).                                |
| `is_paused()`      | `-> bool`                     | True while paused.                                                         |
| `is_gated()`       | `-> bool`                     | True while a gate blocks progression.                                      |
| `progress()`       | `-> float`                    | Current progress value.                                                    |

#### Signals

| Signal               | Parameters                                   | When                                                     |
| -------------------- | -------------------------------------------- | -------------------------------------------------------- |
| `encounter_started`  | `(enc: Encounter)`                           | Playback begins.                                         |
| `event_fired`        | `(event: EncounterEvent)`                    | Any event fires (generic).                               |
| `encounter_finished` | `(enc: Encounter)`                           | Duration reached, or early finish via `finish_on_clear`. |
| `encounter_failed`   | `(reason: String)`                           | `fail()` was called.                                     |
| `phase_changed`      | `(phase_name: String)`                       | PhaseEvent fires.                                        |
| `marker_hit`         | `(marker_name: String, payload: Dictionary)` | MarkerEvent fires.                                       |
| `custom_signal`      | `(signal_name: String, argument: String)`    | SignalEvent fires.                                       |
| `gate_entered`       | `(gate: GateEvent)`                          | GateEvent reached — progression paused.                  |
| `gate_cleared`       | `(gate: GateEvent)`                          | Gate condition met — progression resuming.               |

#### Internal flow (`_process`)

```
_process(delta):
  if TIME mode → _progress += delta
  if gated → _update_gate(delta), return
  _advance_events()     # fire all events where event.time <= _progress
	check end condition   # _progress >= duration (or early clear if enabled)
```

---

### EnemySpawner

**File:** `scenes/encounters/enemy_spawner.gd`
**Class:** `EnemySpawner extends Node`

Factory that actually instantiates enemies. The runner never touches `Enemy` directly.

#### Exports

| Property     | Type        | Description                                       |
| ------------ | ----------- | ------------------------------------------------- |
| `world`      | `Node`      | Container node where enemies are `add_child()`'d. |
| `camera_rig` | `CameraRig` | Used to compute spawn Z position ahead of camera. |

#### Key Method: `spawn_group()`

```gdscript
func spawn_group(event: SpawnEvent, offsets: Array[Vector2], rng: RandomNumberGenerator) -> void
```

For each offset in the array:

1. Applies spread jitter using the runner's deterministic RNG.
2. Instantiates `event.enemy_scene`.
3. Computes world position: `camera_z + z_start` for depth, `origin + offset + height_offset` for X/Y.
4. Sets `enemy.world_pos`.
5. Adds enemy to `world` node.
6. Calls `_apply_move_style()` to map `MovementStyle` → enemy movement properties.
7. Calls `_apply_pattern()` to map `Pattern` → enemy firing properties + HP override.

#### Mapping details

`_apply_move_style()` uses duck-typing (`"property" in enemy`) to set enemy properties:

- `pattern` ← `style.type as int`
- `speed_z`, `speed_x`, `speed_y` ← direct map
- `amp_x`, `amp_y` ← `style.amplitude.x/y`
- `freq` ← `style.frequency`
- `dive_turn`, `orbit_radius`, `orbit_speed` ← direct map

`_apply_pattern()` maps:

- `fire_interval`, `bullet_speed`, `aim_lead_y`, `fire_min_z`, `fire_max_z` ← direct map
- `hp` ← from `SpawnEvent.hp` (if > 0)

#### Subclassing

Override `spawn_group()` for custom behaviour (e.g., pooling, VFX on spawn, faction-specific setup). The base implementation is fully functional for standard `Enemy` nodes.

---

### StageDirector

**File:** `scenes/encounters/stage_director.gd`
**Class:** `StageDirector extends Node`

The macro layer. Owns the sequence of encounters and orchestrates the entire stage.

#### Exports

| Property        | Type                | Default    | Description                                                      |
| --------------- | ------------------- | ---------- | ---------------------------------------------------------------- |
| `runner`        | `EncounterRunner`   | `null`     | The runner this director drives.                                 |
| `player`        | `Player`            | `null`     | Player node for distance feed and rail speed control.            |
| `segments`      | `Array[Encounter]`  | `[]`       | Ordered encounter segments for this stage.                       |
| `run_seed`      | `int`               | `0`        | Master seed for the entire run. 0 = randomize.                   |
| `rail_speed`    | `float`             | `1.0`      | Base rail speed (world-units/second). Written to `player.speed`. |
| `corruption`    | `float`             | `1.0`      | Difficulty multiplier. Range: 0.0–10.0.                          |
| `modifiers`     | `PackedStringArray` | `[]`       | Freeform run modifiers.                                          |
| `autostart`     | `bool`              | `false`    | Start on `_ready()`.                                             |
| `default_clock` | `ClockMode`         | `DISTANCE` | Clock mode passed to runner for segments.                        |

#### Public API

| Method                    | Signature               | Description                                                            |
| ------------------------- | ----------------------- | ---------------------------------------------------------------------- |
| `start_stage()`           | `(seed_override?: int)` | Start from segment 0. Seeds RNG, sets rail speed, plays first segment. |
| `skip_segment()`          | `()`                    | Stop current encounter, advance to next segment.                       |
| `stop_stage()`            | `()`                    | Hard stop everything.                                                  |
| `fail_stage()`            | `(reason?)`             | Abort — emits `stage_failed`.                                          |
| `pause_rail()`            | `()`                    | Save speed, set player speed to 0, pause runner.                       |
| `resume_rail()`           | `()`                    | Restore speed, resume runner.                                          |
| `set_rail_speed()`        | `(spd: float)`          | Change rail speed at runtime.                                          |
| `get_corruption()`        | `-> float`              | Read current corruption level.                                         |
| `has_modifier()`          | `(mod: String) -> bool` | Check if a run modifier is active.                                     |
| `current_segment_index()` | `-> int`                | -1 if not started.                                                     |
| `is_running()`            | `-> bool`               | Is the stage active?                                                   |

#### Signals

| Signal             | Parameters                     | When                                |
| ------------------ | ------------------------------ | ----------------------------------- |
| `stage_started`    | `()`                           | `start_stage()` called.             |
| `segment_started`  | `(index: int, enc: Encounter)` | A new segment begins.               |
| `segment_finished` | `(index: int, enc: Encounter)` | A segment's encounter completed.    |
| `stage_finished`   | `()`                           | All segments done.                  |
| `rail_paused`      | `()`                           | Rail speed set to 0 (gate entered). |
| `rail_resumed`     | `()`                           | Rail speed restored (gate cleared). |
| `stage_failed`     | `(reason: String)`             | Abort/failure.                      |

#### Automatic wiring in `_ready()`

The director auto-connects signals in `_ready()`:

```
runner.encounter_finished → _on_encounter_finished → play next segment
runner.encounter_failed   → _on_encounter_failed   → fail_stage()
runner.gate_entered       → _on_gate_entered        → pause_rail()
runner.gate_cleared       → _on_gate_cleared        → resume_rail()
runner.phase_changed      → _on_phase_changed       → (override hook)
player.distance_changed   → runner._on_distance_changed  (distance feed)
```

#### Segment sequencing flow

```
start_stage()
  │
  ├── seed RNG
  ├── set rail speed
  ├── emit stage_started
  └── _play_next_segment()
        │
        ├── segment_index++
        ├── derive per-segment seed from run RNG
        ├── emit segment_started
        └── runner.start(encounter, seed, clock_mode)
              │
              └── [...encounter plays...]
                    │
                    runner.encounter_finished
                    │
                    ├── emit segment_finished
                    └── _play_next_segment()
                          │
                          ├── (more segments) → repeat
                          └── (no more) → _finish_stage()
                                            └── emit stage_finished
```

---

## Clock Modes: Time vs Distance

The `EncounterRunner` supports two progress sources:

### Distance Mode (default — normal rail segments)

```
Player._process():
  step = speed * delta
  world_pos.z -= step
  _distance += abs(step)
  distance_changed.emit(_distance)        ← signal
                │
                ▼
StageDirector auto-wires to:
  runner._on_distance_changed(distance)
    │
    ▼
  runner.set_distance(absolute_distance)
    _progress = absolute_distance - _distance_origin
```

- `_distance_origin` is captured when `start()` is called, so progress is always relative to encounter start.
- If the rail stops (player speed = 0), distance stops increasing, progress freezes naturally.
- Event `time` values represent **distance in world units**, not seconds.

### Time Mode (bosses, arenas)

```
runner._process(delta):
  _progress += delta    ← direct time accumulation
```

- Works independently of rail movement.
- Rail speed can be 0 (boss arena) while events still fire.
- Event `time` values represent **seconds**.

### Switching modes

The `StageDirector` can use different modes for different segments:

```gdscript
# Normal segment — distance driven
runner.start(approach_encounter, seed, EncounterRunner.ClockMode.DISTANCE)

# Boss segment — time driven
runner.start(boss_encounter, seed, EncounterRunner.ClockMode.TIME)
```

---

## Gate System

### Implementation: Pattern A + B Combined

**Pattern A (signal-driven):**

- Runner detects gate → emits `gate_entered`
- Director receives → pauses rail
- Gate clears → runner emits `gate_cleared`
- Director receives → resumes rail

**Pattern B (pull-driven):**

- Runner's progress comes from rail distance
- If rail stops moving, progress naturally stops
- Gate = "don't let rail move until cleared"

**Combined:** Both patterns work simultaneously. The director explicitly pauses the rail (Pattern A), and since the runner pulls progress from distance, everything syncs automatically (Pattern B). Belt and suspenders.

### Gate timing within the timeline

A gate fires like any other event — when progress reaches `gate.time`. All events _before_ the gate in the timeline have already fired. Events _after_ the gate are blocked until the gate clears.

Multiple spawn events can fire before a gate to set up the "clear this wave" challenge:

```
time=50  SpawnEvent: 4x Gunner
time=55  SpawnEvent: 2x ShieldDrone
time=60  GateEvent: ALL_ENEMIES_DEAD    ← won't advance past here until cleared
time=70  SpawnEvent: next wave...       ← fires after gate clears
```

---

## Signal Contract

### StageDirector → EncounterRunner (method calls)

| Call                                        | When                         |
| ------------------------------------------- | ---------------------------- |
| `runner.start(encounter, seed, clock_mode)` | New segment begins           |
| `runner.stop()`                             | Skip segment or stop stage   |
| `runner.pause()`                            | Gate entered (rail pausing)  |
| `runner.resume()`                           | Gate cleared (rail resuming) |

### EncounterRunner → StageDirector (signals)

| Signal                     | Director response                           |
| -------------------------- | ------------------------------------------- |
| `encounter_started(enc)`   | (no action needed)                          |
| `event_fired(event)`       | (optional logging/debug)                    |
| `encounter_finished(enc)`  | `segment_finished` → `_play_next_segment()` |
| `encounter_failed(reason)` | `fail_stage(reason)`                        |
| `gate_entered(gate)`       | `pause_rail()`                              |
| `gate_cleared(gate)`       | `resume_rail()`                             |
| `phase_changed(name)`      | Override hook for music/camera/UI           |

### Player → EncounterRunner (signal)

| Signal                       | Runner response                                         |
| ---------------------------- | ------------------------------------------------------- |
| `distance_changed(distance)` | `set_distance()` → updates `_progress` in DISTANCE mode |

---

## Scene Tree Wiring

### Required scene tree structure

```
GameplayScreen (root)
 ├── World                          ← Node where enemies are added
 ├── CameraRig                      ← must be in group "camera_rig"
 ├── Player                         ← emits distance_changed
 └── StageDirector                  ← stage_director.gd
      └── EncounterRunner           ← encounter_runner.gd
           └── EnemySpawner         ← enemy_spawner.gd
```

### Inspector wiring (drag references)

| Node              | Export       | Points to                          |
| ----------------- | ------------ | ---------------------------------- |
| `StageDirector`   | `runner`     | → EncounterRunner                  |
| `StageDirector`   | `player`     | → Player                           |
| `StageDirector`   | `segments`   | → Array of Encounter `.tres` files |
| `EncounterRunner` | `spawner`    | → EnemySpawner                     |
| `EnemySpawner`    | `world`      | → World node                       |
| `EnemySpawner`    | `camera_rig` | → CameraRig node                   |

### Automatic connections (done in `_ready()`)

The following signals are connected automatically by `StageDirector._ready()`:

- `runner.encounter_finished` → `_on_encounter_finished`
- `runner.encounter_failed` → `_on_encounter_failed`
- `runner.gate_entered` → `_on_gate_entered`
- `runner.gate_cleared` → `_on_gate_cleared`
- `runner.phase_changed` → `_on_phase_changed`
- `player.distance_changed` → `runner._on_distance_changed`

No manual signal wiring required in the editor.

---

## Pacing & Level Design Philosophy

### The Golden Rule: The Rail Never Stops (almost)

In Space Harrier, you are always moving forward. Enemies arrive, fly past, and you deal with them or you don't. Downstar preserves this: the rail runs continuously. Enemies are spawned by distance, fly in, attack, and leave (or die). You don't "clear a room" — you survive a gauntlet.

### Enemy lifecycle (self-contained)

Each enemy owns its own lifecycle independently of the encounter system:

```
ENTER    → Fly to formation position (0.5–1s)
ACTIVE   → Shoot, strafe, do your pattern (2–6s based on MovementStyle)
EXIT     → Fly away off-screen (1s), then queue_free()

At any point: if killed → death anim → queue_free()
```

The `MovementStyle` tells the enemy _how_ to behave during ACTIVE. The `Pattern` tells it _how_ to shoot. The enemy doesn't know about encounters — it does its thing for its lifespan.

**Consequence:** EncounterRunner places enemies into the world. Enemies run themselves. EncounterRunner doesn't track them (except for gate conditions where it checks a group count).

### Stage structure

Think of a stage as a music track — verses, choruses, bridge:

```
INTRO ──► WAVE ──► BREATHER ──► WAVE ──► WAVE ──► BREATHER ──► ELITE ──► GATE ──► BOSS
 5s        8s        3s          6s        6s        4s          10s        *         30s
```

| Section        | What happens                                                | Rail                  |
| -------------- | ----------------------------------------------------------- | --------------------- |
| **Intro**      | Scenery, maybe a title card. Zero enemies.                  | Normal                |
| **Wave**       | 1–3 SpawnEvents in quick succession. Enemies in formations. | Normal / accelerating |
| **Breather**   | No spawns. Pickups drift in.                                | Normal                |
| **Elite wave** | Tougher enemies, denser formations, overlapping timings.    | Maybe faster          |
| **Gate**       | Rail pauses. Miniboss or "clear all" moment.                | **Paused**            |
| **Boss**       | Arena. Time-driven patterns. Phases.                        | Stopped / orbiting    |

### Enemies don't wait to be cleared (in normal flow)

In normal waves, enemies spawn at fixed distances and have their own lifecycle. If you kill them — great, points and drops. If you don't — they leave. The rail doesn't care.

```
Distance:  0m ──────── 100m ──────── 200m ──────── 300m ────►
            │            │             │             │
         [Wave A]    [Wave B]     [Wave A exits]  [Wave C]
         spawns in   spawns in    survivors leave  spawns in
```

Wave A and B can **overlap** — that's how you build intensity. The runner supports this since events fire by distance threshold, not sequentially.

### Breathers are just gaps

No special resource needed. A breather is simply empty space in the timeline where no events are placed:

```
time=50  SpawnEvent (last of wave 2)
         ← 20 units of nothing = breather →
time=70  SpawnEvent (start of wave 3)
```

### When to gate

| Use a gate                               | Don't gate                            |
| ---------------------------------------- | ------------------------------------- |
| Miniboss: "Destroy the shield generator" | Normal enemy waves                    |
| Story beat: NPC transmission mid-combat  | Between every wave                    |
| Boss arena entrance                      | Waiting for all normal enemies to die |
| Branching path choice                    | Pickup collection                     |

Gates should feel like the game saying "pay attention, this matters" — not like a loading screen.

---

## Roguelite Integration Points

### Where mutation happens

| System                     | What it mutates                                                                       | How                                                           |
| -------------------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| `StageDirector.corruption` | Accessed by spawner/mutators to scale HP, fire rate, speed                            | Read via `director.get_corruption()`                          |
| `StageDirector.modifiers`  | Freeform strings like `"high_gravity"`, `"double_fire"`                               | Check via `director.has_modifier(mod)`                        |
| `EncounterEvent.tags`      | Per-event tags like `"elite"`, `"biome:ice"`                                          | Filter via `encounter.events_with_tag()` or `event.has_tag()` |
| `Encounter.tags`           | Per-encounter tags for pool filtering                                                 | Filter when selecting segments                                |
| `runner.apply_mutators()`  | Array of `Callable(encounter, rng)` that modify the encounter in-place before playing | See below                                                     |

### Mutator pattern

Mutators are plain functions that modify an `Encounter` resource before the runner plays it:

```gdscript
# Example mutator: double all enemy HP
func mutator_double_hp(enc: Encounter, rng: RandomNumberGenerator) -> void:
    for ev in enc.events:
        if ev is SpawnEvent:
            ev.hp = maxi(ev.hp, 1) * 2

# Example mutator: add random extra spawn
func mutator_extra_wave(enc: Encounter, rng: RandomNumberGenerator) -> void:
    var extra := SpawnEvent.new()
    extra.time = rng.randf_range(0.0, enc.duration * 0.8)
    extra.enemy_scene = preload("res://scenes/enemy.tscn")
    extra.count = rng.randi_range(2, 5)
    enc.events.append(extra)

# Apply before starting:
runner.apply_mutators([mutator_double_hp, mutator_extra_wave])
```

`apply_mutators()` calls `encounter.validate()` afterward to re-sort events.

### Determinism guarantee

The runner's RNG is seeded from:

1. `run_seed` passed by the director (per-segment, derived from master seed)
2. Fallback: `runner.seed` export
3. Fallback: `encounter.seed_hint`
4. Final fallback: `rng.randomize()` (non-deterministic)

For replay/ghost systems, store the `run_seed` and the `segments` array — the same inputs will produce identical spawns.

---

## Authoring an Encounter (.tres)

### Step-by-step in the Godot editor

1. **Create the Encounter:** In the FileSystem dock, right-click → New Resource → `Encounter`. Save as e.g. `verdant_approach_01.tres`.

2. **Set metadata:** In the Inspector, set `id`, `display_name`, `duration`, `tags`.

3. **Add events to the array:** Click the `events` array → Add Element → choose the event subtype (SpawnEvent, GateEvent, etc.).

4. **Configure each SpawnEvent:**
   - Set `time` (distance in world units for DISTANCE mode).
   - Drag an enemy PackedScene to `enemy_scene`.
   - Set `count`.
   - Create (or reuse) a `Formation` sub-resource — set `shape`, `spacing`, etc.
   - Create (or reuse) a `MovementStyle` sub-resource — set `type`, speeds, etc.
   - Create (or reuse) a `Pattern` sub-resource — set `fire_interval`, `bullet_speed`, etc.
   - Adjust `spawn_origin`, `z_start`, `height_offset`, `spread` as needed.

5. **Add to StageDirector:** Drag the `.tres` into the `segments` array on the StageDirector node.

### Reusing sub-resources

`Formation`, `MovementStyle`, and `Pattern` can be saved as standalone `.tres` files and shared across multiple SpawnEvents. This avoids duplicating configuration:

```
res://encounters/formations/v_formation_5.tres
res://encounters/styles/sine_strafe_fast.tres
res://encounters/patterns/sniper_slow.tres
```

Reference them in SpawnEvents by dragging the `.tres` file into the Inspector field.

---

## Example: Full Stage Plan

```
StageDirector
  run_seed: 42
  rail_speed: 1.0
  corruption: 1.0
  segments:
    [0] verdant_approach_01.tres    (DISTANCE, duration=200)
    [1] verdant_boss.tres           (TIME, duration=60)
    [2] reward_transition.tres      (TIME, duration=5)
```

### verdant_approach_01.tres

```
id: "verdant_approach_01"
duration: 200 (distance units)

Events:
  0    PhaseEvent("intro")
  10   SpawnEvent: 3× Scout, LINE, straight
  25   SpawnEvent: 5× Scout, V, sine_strafe
  40   MarkerEvent("pickup_health")
  50   PhaseEvent("escalation")
  55   SpawnEvent: 4× Gunner, GRID(2×2), aimed shots
  65   SpawnEvent: 3× Scout + 2× Gunner (two separate SpawnEvents)
  80   (breather — 20 units of silence)
  100  PhaseEvent("elite")
  100  SpawnEvent: 1× ShieldDrone, POINT, orbit
  105  SpawnEvent: 4× Scout, CIRCLE, support
  130  GateEvent: ALL_ENEMIES_DEAD
  130  MarkerEvent("gate_cleared_reward")
  140  PhaseEvent("boss_approach")
  160  SpawnEvent: decorative debris (no shooting — atmosphere)
  180  PhaseEvent("boss")
  180  GateEvent: CUSTOM("boss_defeated")
```

### verdant_boss.tres

```
id: "verdant_boss"
duration: 60 (seconds — TIME mode)

Events:
  0    PhaseEvent("phase_1")
  0    SpawnEvent: 1× Boss, POINT
  15   PhaseEvent("phase_2")
  15   SpawnEvent: 4× Drone, CIRCLE, support
  30   PhaseEvent("phase_3_enrage")
  45   MarkerEvent("warning_desperation")
```

---

## File Manifest

All encounter system files live in `scenes/encounters/`:

| File                      | Class                | Type       | Purpose                                      |
| ------------------------- | -------------------- | ---------- | -------------------------------------------- |
| `encounter.gd`            | `Encounter`          | Resource   | Top-level encounter container                |
| `encounter_event.gd`      | `EncounterEvent`     | Resource   | Base event class                             |
| `spawn_event.gd`          | `SpawnEvent`         | Resource   | Spawn a group of enemies                     |
| `gate_event.gd`           | `GateEvent`          | Resource   | Pause progression until condition met        |
| `phase_event.gd`          | `PhaseEvent`         | Resource   | Named phase boundary                         |
| `marker_event.gd`         | `MarkerEvent`        | Resource   | Named marker with payload                    |
| `signal_event.gd`         | `SignalEvent`        | Resource   | Fire custom signal                           |
| `formation.gd`            | `Formation`          | Resource   | Spatial group arrangement                    |
| `move_style.gd`           | `MovementStyle`      | Resource   | Enemy movement descriptor                    |
| `pattern.gd`              | `Pattern`            | Resource   | Enemy firing config                          |
| `encounter_runner.gd`     | `EncounterRunner`    | Node       | Micro layer: plays encounter timeline        |
| `enemy_spawner.gd`        | `EnemySpawner`       | Node       | Factory: instantiates and configures enemies |
| `stage_director.gd`       | `StageDirector`      | Node       | Macro layer: stage progression orchestrator  |
| `slot_definition.gd`      | `SlotDefinition`     | Resource   | One slot in a stage template                 |
| `stage_template.gd`       | `StageTemplate`      | Resource   | Macro skeleton for procedural stage building |
| `encounter_pool.gd`       | `EncounterPool`      | Resource   | Weighted collection of encounter entries     |
| `encounter_pool_entry.gd` | `EncounterPoolEntry` | Resource   | One weighted entry in a pool                 |
| `encounter_deck.gd`       | `EncounterDeck`      | RefCounted | Weighted bag-without-replacement draw system |
| `difficulty_profile.gd`   | `DifficultyProfile`  | Resource   | Curve-based difficulty scaling               |
| `rhythm_spacer.gd`        | `RhythmSpacer`       | RefCounted | Auto-inserts breather gaps between combat    |
| `stage_builder.gd`        | `StageBuilder`       | RefCounted | Orchestrates procedural stage generation     |

Related files outside `encounters/`:

| File              | Class         | Modification                                                   |
| ----------------- | ------------- | -------------------------------------------------------------- |
| `player.gd`       | `Player`      | Added `_distance: float`, `signal distance_changed(distance)`  |
| `enemy.gd`        | `Enemy`       | No changes — `MovementStyle`/`Pattern` map to existing exports |
| `camera_rig.gd`   | `CameraRig`   | No changes — `EnemySpawner` reads `camera_world_position`      |
| `world_object.gd` | `WorldObject` | No changes — base class for Player/Enemy                       |

---

## Procedural Generation Pipeline

> **Phase 2 addition** — seven new classes that let `StageDirector` build
> encounter sequences procedurally instead of requiring hand-authored
> `segments` arrays.

### Architecture Overview

```
StageTemplate (skeleton)  ─┐
EncounterPool (content)   ─┤── StageBuilder.build() ──▸ Array[Encounter]
DifficultyProfile (curves) ─┤                               │
Seeded RNG                 ─┘                               ▼
                                                    StageDirector.segments
```

When `StageDirector.stage_template` and `StageDirector.encounter_pool` are
both set, `start_stage()` invokes `StageBuilder` to fill the `segments`
array automatically. Manual segments still work — leave both null to use
the original hand-authored workflow.

### StageTemplate

A `Resource` that defines the **macro skeleton** of a stage as an ordered
list of `SlotDefinition` entries.

**Exports:**

- `display_name: String` — human-readable label
- `slots: Array[SlotDefinition]` — ordered slot sequence
- `tags: PackedStringArray` — biome / modifier filtering
- `target_distance: float` — total distance budget (0 = sum of slots)

**Helpers:** `combat_slot_count()`, `breather_slot_count()`, `all_required_tags()`

### SlotDefinition

Each slot describes **what kind of content** goes into that position:

| Export              | Type                | Default  | Description                                   |
| ------------------- | ------------------- | -------- | --------------------------------------------- |
| `role`              | `Role` enum         | `COMBAT` | `COMBAT`, `BREATHER`, or `FIXED`              |
| `required_tags`     | `PackedStringArray` | `[]`     | Encounter must have ALL of these              |
| `excluded_tags`     | `PackedStringArray` | `[]`     | Encounter must have NONE of these             |
| `min_tier`          | `int`               | `0`      | Minimum difficulty tier (0 = any)             |
| `max_tier`          | `int`               | `0`      | Maximum difficulty tier (0 = any)             |
| `duration_override` | `float`             | `0.0`    | Override encounter duration (0 = use default) |
| `fixed_encounter`   | `Encounter`         | `null`   | Used when role = FIXED                        |
| `optional`          | `bool`              | `false`  | Skip silently if no match                     |
| `allow_repeat`      | `bool`              | `false`  | Allow recently-used encounters                |
| `breather_duration` | `float`             | `3.0`    | Gap length when role = BREATHER               |

### EncounterPool & EncounterPoolEntry

**EncounterPoolEntry** wraps a single `Encounter` with selection metadata:

- `encounter: Encounter` — the encounter resource
- `weight: float` — selection weight (higher = more likely)
- `tier: int` — difficulty tier for filtering
- `extra_tags: PackedStringArray` — supplemental tags

**EncounterPool** aggregates entries and provides `query()`:

```gdscript
pool.query(required_tags, excluded_tags, min_tier, max_tier, exclude_ids)
# → Array[EncounterPoolEntry] matching all constraints
```

### EncounterDeck

Weighted **bag-without-replacement** — draws encounters from the pool,
removing them from the bag. Only refills when the bag is empty, preventing
the same encounter from appearing back-to-back within a cycle.

```gdscript
var deck := EncounterDeck.new(pool, rng, history_limit)
deck.refill()
var enc := deck.draw(required_tags, excluded_tags, min_tier, max_tier)
```

If no match exists after refill, relaxes repeat constraints as a last resort.

### DifficultyProfile

Curve-based difficulty scaling. Each `Curve` resource maps normalised
stage progress `[0.0 → 1.0]` to a multiplier:

| Parameter     | Curve export        | Fallback scalar      | What it scales            |
| ------------- | ------------------- | -------------------- | ------------------------- |
| `hp`          | `hp_curve`          | `hp_scalar`          | Enemy hit points          |
| `fire_rate`   | `fire_rate_curve`   | `fire_rate_scalar`   | Fire interval (inverse)   |
| `spawn_count` | `spawn_count_curve` | `spawn_count_scalar` | Enemies per wave          |
| `speed`       | `speed_curve`       | `speed_scalar`       | Enemy movement speed      |
| `breather`    | `breather_curve`    | `breather_scalar`    | Breather gap duration     |
| `intensity`   | `intensity_curve`   | `intensity_scalar`   | General pressure (custom) |

```gdscript
profile.sample(&"hp", 0.5)        # → curve value at halfway
profile.sample_all(0.75)           # → Dictionary of all params at 75%
```

### RhythmSpacer

Post-processes the built segment list, inserting **breather encounters**
(empty, no events) between adjacent combat encounters:

- Gap duration scales with `DifficultyProfile.breather` curve
- Adds ±15% random jitter for organic feel
- Works backwards through the list so insertions don't shift indices

### StageBuilder

The **orchestrator** that ties everything together:

```gdscript
var builder := StageBuilder.new(template, pool, profile, rng)
builder.min_gap = 2.0
builder.max_gap = 6.0
builder.auto_breathers = true
var result := builder.build(run_seed)
# result.segments      → Array[Encounter] ready for StageDirector
# result.slots_filled   → how many slots were filled
# result.slots_skipped  → how many slots had no match
# result.breathers_inserted → auto-breathers added by RhythmSpacer
```

**Pipeline steps:**

1. Walk template slots sequentially
2. COMBAT slots → draw from `EncounterDeck` matching slot constraints
3. FIXED slots → use `slot.fixed_encounter` directly
4. BREATHER slots → generate empty gap encounters
5. **Mutate** combat encounters based on difficulty curves at their position
6. **RhythmSpacer** inserts auto-breathers between adjacent combat slots
7. Return `BuildResult` with segments + stats

**Difficulty mutations** (applied per `SpawnEvent`):

- HP scaled by `hp` curve
- Spawn count scaled by `spawn_count` curve
- Move style speeds scaled by `speed` curve
- Fire interval divided by `fire_rate` curve (faster = shorter interval)
- Sub-resources (MovementStyle, Pattern) are duplicated before mutation

### StageDirector Integration

`StageDirector` gained new exports for procedural generation:

```gdscript
@export var stage_template: StageTemplate
@export var encounter_pool: EncounterPool
@export var difficulty_profile: DifficultyProfile
@export var min_breather_gap: float = 2.0
@export var max_breather_gap: float = 6.0
@export var auto_breathers: bool = true
```

**Behaviour:** When both `stage_template` and `encounter_pool` are set,
`start_stage()` runs `StageBuilder.build()` and writes the result into
`segments` before playing. This is **fully backwards-compatible** — leave
both null and the original manual `segments` workflow is unchanged.

New public API:

- `is_procedural() → bool` — true if last run was built procedurally
- `last_build_result() → StageBuilder.BuildResult` — build stats

### Example: Procedural Stage Setup

```
StageTemplate "forest_standard":
  Slot 0: COMBAT   required_tags=["opener"]  tier=1
  Slot 1: BREATHER duration=3.0
  Slot 2: COMBAT   tier=1-2
  Slot 3: COMBAT   tier=2
  Slot 4: BREATHER duration=2.5
  Slot 5: COMBAT   required_tags=["elite"]  tier=3
  Slot 6: FIXED    fixed_encounter=forest_boss

EncounterPool "forest_all":
  Entry: wave_scouts      w=3.0  tier=1  tags=[opener]
  Entry: wave_drones       w=2.0  tier=1
  Entry: wave_bombers      w=1.5  tier=2
  Entry: wave_mixed_v      w=2.0  tier=2
  Entry: wave_elite_squad  w=1.0  tier=3  tags=[elite]

DifficultyProfile "normal":
  hp_curve:         1.0 → 1.8 (linear)
  fire_rate_curve:  1.0 → 1.5
  spawn_count_curve: 1.0 → 1.3
  breather_curve:   1.0 → 0.6 (shorter breathers later)
```

---

## Source Code: Procedural Generation Pipeline

Full implementation of all seven procedural generation classes.

### slot_definition.gd

```gdscript
## Describes one slot in a StageTemplate.
## Each slot pulls an encounter from the pool that matches its constraints.
@tool
extends Resource
class_name SlotDefinition

## ── Slot role ────────────────────────────────────────────────────────────────

## What kind of content this slot expects.
enum Role {
	## A combat encounter pulled from the pool.
	COMBAT,
	## An empty breather gap (auto-generated, no pool query).
	BREATHER,
	## A fixed encounter — always uses `fixed_encounter`.
	FIXED,
}

## Role of this slot in the stage rhythm.
@export var role: Role = Role.COMBAT

## ── Pool query constraints ──────────────────────────────────────────────────

## Tags the encounter MUST have (all must match).
@export var required_tags: PackedStringArray = PackedStringArray()

## Tags the encounter must NOT have.
@export var excluded_tags: PackedStringArray = PackedStringArray()

## Minimum difficulty tier (inclusive).  0 = any.
@export var min_tier: int = 0

## Maximum difficulty tier (inclusive).  0 = any.
@export var max_tier: int = 0

## ── Overrides ───────────────────────────────────────────────────────────────

## Duration override for the encounter placed here.  0 = use encounter default.
@export var duration_override: float = 0.0

## For FIXED role — the specific encounter to place.
@export var fixed_encounter: Encounter

## If true and no pool match is found, the builder skips the slot silently.
## If false and no match is found, the builder logs a warning and skips.
@export var optional: bool = false

## Allow the same encounter to appear again even if it was recently used.
@export var allow_repeat: bool = false

## ── Breather settings ───────────────────────────────────────────────────────

## Duration of the breather gap (only used when role == BREATHER).
@export var breather_duration: float = 3.0
```

### stage_template.gd

```gdscript
## Defines the macro-structure of a stage as a sequence of slots.
## Each slot is a SlotDefinition that the StageBuilder fills from an
## EncounterPool + EncounterDeck.
##
## Author several templates per biome / planet type, then let the
## StageBuilder pick encounters to fill them procedurally.
@tool
extends Resource
class_name StageTemplate

## Human-readable name for this template (e.g. "Forest — Standard Run").
@export var display_name: String = ""

## Ordered list of slots that define the stage skeleton.
@export var slots: Array[SlotDefinition] = []

## Tags for biome filtering / run modifier selection.
@export var tags: PackedStringArray = PackedStringArray()

## Target total distance budget for the stage.  0 = sum of slot durations.
@export var target_distance: float = 0.0


## Returns the number of combat slots in this template.
func combat_slot_count() -> int:
	var n := 0
	for s in slots:
		if s != null and s.role == SlotDefinition.Role.COMBAT:
			n += 1
	return n


## Returns the number of breather slots.
func breather_slot_count() -> int:
	var n := 0
	for s in slots:
		if s != null and s.role == SlotDefinition.Role.BREATHER:
			n += 1
	return n


## Returns all unique required tags across every combat slot.
func all_required_tags() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for s in slots:
		if s == null or s.role != SlotDefinition.Role.COMBAT:
			continue
		for t in s.required_tags:
			if not result.has(t):
				result.append(t)
	return result
```

### encounter_pool_entry.gd

```gdscript
## One weighted entry in an EncounterPool.
## Wraps an Encounter resource with selection metadata.
@tool
extends Resource
class_name EncounterPoolEntry

## The encounter this entry refers to.
@export var encounter: Encounter

## Base selection weight (higher = more likely to be drawn).
@export_range(0.1, 100.0) var weight: float = 1.0

## Difficulty tier.  Used by SlotDefinition min/max_tier constraints.
@export_range(0, 10) var tier: int = 1

## Tags for pool queries (in addition to the encounter's own tags).
## Pool-level tags let you override/supplement encounter tags without
## editing the encounter resource itself.
@export var extra_tags: PackedStringArray = PackedStringArray()


## Returns true if this entry's effective tags contain `tag`.
func has_tag(tag: String) -> bool:
	if extra_tags.has(tag):
		return true
	if encounter != null and encounter.tags.has(tag):
		return true
	return false


## Returns the combined tag set (encounter tags + extra_tags).
func effective_tags() -> PackedStringArray:
	var result := PackedStringArray()
	if encounter != null:
		result.append_array(encounter.tags)
	for t in extra_tags:
		if not result.has(t):
			result.append(t)
	return result
```

### encounter_pool.gd

```gdscript
## A curated pool of encounter entries with weighted selection.
## Used by EncounterDeck / StageBuilder to draw encounters that match
## slot constraints.
@tool
extends Resource
class_name EncounterPool

## Human-readable pool name (e.g. "Forest — All Encounters").
@export var display_name: String = ""

## All available encounters with their weights and metadata.
@export var entries: Array[EncounterPoolEntry] = []

## Tags applied to the entire pool (biome, difficulty bracket, etc.).
@export var tags: PackedStringArray = PackedStringArray()


## Query the pool for entries matching the given constraints.
## Returns a filtered Array[EncounterPoolEntry].
##
## [param required_tags]  — entry must have ALL of these.
## [param excluded_tags]  — entry must have NONE of these.
## [param min_tier]       — minimum tier (0 = no lower bound).
## [param max_tier]       — maximum tier (0 = no upper bound).
## [param exclude_ids]    — encounter IDs to skip (for repeat prevention).
func query(
	required_tags: PackedStringArray = PackedStringArray(),
	excluded_tags: PackedStringArray = PackedStringArray(),
	min_tier: int = 0,
	max_tier: int = 0,
	exclude_ids: PackedStringArray = PackedStringArray()
) -> Array[EncounterPoolEntry]:
	var result: Array[EncounterPoolEntry] = []

	for entry in entries:
		if entry == null or entry.encounter == null:
			continue

		# Tier filter
		if min_tier > 0 and entry.tier < min_tier:
			continue
		if max_tier > 0 and entry.tier > max_tier:
			continue

		# Required tags — entry must have ALL
		var tags_ok := true
		for tag in required_tags:
			if not entry.has_tag(tag):
				tags_ok = false
				break
		if not tags_ok:
			continue

		# Excluded tags — entry must have NONE
		var excluded := false
		for tag in excluded_tags:
			if entry.has_tag(tag):
				excluded = true
				break
		if excluded:
			continue

		# Repeat prevention
		if exclude_ids.has(entry.encounter.id):
			continue

		result.append(entry)

	return result


## Convenience: get all unique encounter IDs in the pool.
func all_encounter_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for entry in entries:
		if entry != null and entry.encounter != null:
			if not ids.has(entry.encounter.id):
				ids.append(entry.encounter.id)
	return ids


## Total number of valid (non-null) entries.
func valid_count() -> int:
	var n := 0
	for entry in entries:
		if entry != null and entry.encounter != null:
			n += 1
	return n
```

### encounter_deck.gd

```gdscript
## Weighted bag-without-replacement for encounter selection.
## Draws encounters from a pool, only refilling the bag when empty.
## Prevents repeats within a cycle while still respecting weights.
##
## This is a runtime helper — not a Resource.  StageBuilder creates one
## per pool when building a stage.
class_name EncounterDeck

var _pool: EncounterPool
var _rng: RandomNumberGenerator
var _bag: Array[EncounterPoolEntry] = []
var _history: PackedStringArray = PackedStringArray()
var _history_limit: int = 3


func _init(pool: EncounterPool, rng: RandomNumberGenerator, history_limit: int = 3) -> void:
	_pool = pool
	_rng = rng
	_history_limit = history_limit


## Draw an encounter matching the given constraints.
## Returns null if no match exists even after a refill attempt.
func draw(
	required_tags: PackedStringArray = PackedStringArray(),
	excluded_tags: PackedStringArray = PackedStringArray(),
	min_tier: int = 0,
	max_tier: int = 0,
	allow_repeat: bool = false
) -> Encounter:
	# Build exclude list from recent history (unless repeats allowed)
	var exclude_ids := PackedStringArray()
	if not allow_repeat:
		exclude_ids = _history.duplicate()

	# Try drawing from the current bag first
	var result := _try_draw_from_bag(required_tags, excluded_tags, min_tier, max_tier, exclude_ids)
	if result != null:
		_record(result)
		return result.encounter

	# Bag exhausted — refill and try once more
	_refill()
	result = _try_draw_from_bag(required_tags, excluded_tags, min_tier, max_tier, exclude_ids)
	if result != null:
		_record(result)
		return result.encounter

	# Still nothing — relax repeat constraint as last resort
	if not allow_repeat and not exclude_ids.is_empty():
		_refill()
		result = _try_draw_from_bag(required_tags, excluded_tags, min_tier, max_tier, PackedStringArray())
		if result != null:
			_record(result)
			return result.encounter

	return null


## Peek at how many entries remain in the current bag.
func remaining() -> int:
	return _bag.size()


## Force a refill of the bag from the pool.
func refill() -> void:
	_refill()


## Clear draw history (e.g. between stage phases).
func reset_history() -> void:
	_history.resize(0)


# ── Internal ─────────────────────────────────────────────────────────────────

func _refill() -> void:
	_bag.clear()
	for entry in _pool.entries:
		if entry != null and entry.encounter != null:
			_bag.append(entry)


func _try_draw_from_bag(
	required_tags: PackedStringArray,
	excluded_tags: PackedStringArray,
	min_tier: int,
	max_tier: int,
	exclude_ids: PackedStringArray
) -> EncounterPoolEntry:
	# Filter bag to candidates
	var candidates: Array[EncounterPoolEntry] = []
	var candidate_indices: Array[int] = []

	for i in _bag.size():
		var entry := _bag[i]
		if _matches(entry, required_tags, excluded_tags, min_tier, max_tier, exclude_ids):
			candidates.append(entry)
			candidate_indices.append(i)

	if candidates.is_empty():
		return null

	# Weighted random selection
	var total_weight := 0.0
	for c in candidates:
		total_weight += c.weight

	var roll := _rng.randf() * total_weight
	var cumulative := 0.0

	for idx in candidates.size():
		cumulative += candidates[idx].weight
		if roll <= cumulative:
			# Remove from bag (no replacement within cycle)
			var bag_idx := candidate_indices[idx]
			_bag.remove_at(bag_idx)
			return candidates[idx]

	# Fallback (floating-point edge case)
	var last_bag_idx := candidate_indices[candidates.size() - 1]
	_bag.remove_at(last_bag_idx)
	return candidates[candidates.size() - 1]


func _matches(
	entry: EncounterPoolEntry,
	required_tags: PackedStringArray,
	excluded_tags: PackedStringArray,
	min_tier: int,
	max_tier: int,
	exclude_ids: PackedStringArray
) -> bool:
	if entry == null or entry.encounter == null:
		return false

	if min_tier > 0 and entry.tier < min_tier:
		return false
	if max_tier > 0 and entry.tier > max_tier:
		return false

	for tag in required_tags:
		if not entry.has_tag(tag):
			return false

	for tag in excluded_tags:
		if entry.has_tag(tag):
			return false

	if exclude_ids.has(entry.encounter.id):
		return false

	return true


func _record(entry: EncounterPoolEntry) -> void:
	if entry.encounter == null:
		return
	_history.append(entry.encounter.id)
	while _history.size() > _history_limit:
		_history.remove_at(0)
```

### difficulty_profile.gd

```gdscript
## Curve-based difficulty scaling profile.
## Maps normalised stage progress (0.0 → 1.0) to multipliers for various
## gameplay parameters.  StageBuilder reads these when mutating encounters
## to fit their position in the stage.
@tool
extends Resource
class_name DifficultyProfile

## Human-readable name (e.g. "Normal", "Nightmare").
@export var display_name: String = ""

## ── Curve exports ───────────────────────────────────────────────────────────
## Each Curve maps X = normalised progress [0..1] → Y = multiplier.
## Leave null to use the fallback scalar instead.

## Enemy HP multiplier over the stage.
@export var hp_curve: Curve

## Enemy fire-rate multiplier over the stage.
@export var fire_rate_curve: Curve

## Spawn count multiplier (rounds to int).
@export var spawn_count_curve: Curve

## Enemy speed multiplier.
@export var speed_curve: Curve

## Breather duration multiplier (lower = shorter breathers later).
@export var breather_curve: Curve

## Overall intensity / pressure value for custom systems.
@export var intensity_curve: Curve

## ── Fallback scalars ────────────────────────────────────────────────────────
## Used when the corresponding curve is null.

@export var hp_scalar: float = 1.0
@export var fire_rate_scalar: float = 1.0
@export var spawn_count_scalar: float = 1.0
@export var speed_scalar: float = 1.0
@export var breather_scalar: float = 1.0
@export var intensity_scalar: float = 1.0


## Sample a named parameter at the given normalised progress.
## Returns the curve value if the curve exists, otherwise the scalar fallback.
func sample(param: StringName, progress: float) -> float:
	progress = clampf(progress, 0.0, 1.0)
	match param:
		&"hp":
			return hp_curve.sample(progress) if hp_curve != null else hp_scalar
		&"fire_rate":
			return fire_rate_curve.sample(progress) if fire_rate_curve != null else fire_rate_scalar
		&"spawn_count":
			return spawn_count_curve.sample(progress) if spawn_count_curve != null else spawn_count_scalar
		&"speed":
			return speed_curve.sample(progress) if speed_curve != null else speed_scalar
		&"breather":
			return breather_curve.sample(progress) if breather_curve != null else breather_scalar
		&"intensity":
			return intensity_curve.sample(progress) if intensity_curve != null else intensity_scalar
		_:
			push_warning("DifficultyProfile: unknown param '%s'" % param)
			return 1.0


## Convenience: sample all params at once into a Dictionary.
func sample_all(progress: float) -> Dictionary:
	return {
		&"hp": sample(&"hp", progress),
		&"fire_rate": sample(&"fire_rate", progress),
		&"spawn_count": sample(&"spawn_count", progress),
		&"speed": sample(&"speed", progress),
		&"breather": sample(&"breather", progress),
		&"intensity": sample(&"intensity", progress),
	}
```

### rhythm_spacer.gd

```gdscript
## Inserts breather gaps between combat encounters based on difficulty curves
## and rhythm rules.
##
## The spacer operates on an already-built segment list, inserting empty
## breather Encounters (no events, just duration) where needed.
## This is a runtime helper, not a Resource.
class_name RhythmSpacer

## ── Configuration ───────────────────────────────────────────────────────────

## Minimum gap duration (seconds / distance units) between combat encounters.
var min_gap: float = 2.0

## Maximum gap duration before the difficulty profile scales it down.
var max_gap: float = 6.0

## If true, always insert a breather after encounter slots even if the
## template already has explicit BREATHER slots.
var force_breathers: bool = false

var _rng: RandomNumberGenerator
var _profile: DifficultyProfile


func _init(rng: RandomNumberGenerator, profile: DifficultyProfile = null,
		p_min_gap: float = 2.0, p_max_gap: float = 6.0) -> void:
	_rng = rng
	_profile = profile
	min_gap = p_min_gap
	max_gap = p_max_gap


## Process a flat list of segments and insert breather encounters where
## two combat encounters sit back-to-back.
##
## [param segments]        — the built segment list (mutated in place).
## [param total_slots]     — total slot count (used for progress normalisation).
## [param combat_indices]  — indices in `segments` that are combat encounters.
func insert_breathers(
	segments: Array[Encounter],
	total_slots: int,
	combat_indices: Array[int]
) -> void:
	if combat_indices.size() < 2:
		return

	# Work backwards so insertions don't shift indices
	var insert_count := 0
	for i in range(combat_indices.size() - 1, 0, -1):
		var current_idx := combat_indices[i] + insert_count
		var prev_idx := combat_indices[i - 1] + insert_count

		# Check if there's already a breather between these two combat slots
		if current_idx - prev_idx > 1:
			continue

		# Calculate progress at this point in the stage
		var progress := float(i) / float(maxi(total_slots, 1))

		# Calculate gap duration
		var gap := _calculate_gap(progress)

		# Create breather encounter
		var breather := _make_breather(gap)

		# Insert after the previous combat encounter
		segments.insert(prev_idx + 1, breather)
		insert_count += 1


## Calculate gap duration scaled by difficulty profile and jitter.
func _calculate_gap(progress: float) -> float:
	var base_gap := lerpf(max_gap, min_gap, progress)

	# Apply difficulty curve scaling if available
	if _profile != null:
		var breather_mult := _profile.sample(&"breather", progress)
		base_gap *= breather_mult

	# Add small random jitter (±15%)
	var jitter := _rng.randf_range(-0.15, 0.15)
	base_gap *= (1.0 + jitter)

	return clampf(base_gap, min_gap, max_gap)


## Create an empty encounter that acts as a breather gap.
func _make_breather(duration: float) -> Encounter:
	var enc := Encounter.new()
	enc.id = "breather_%d" % _rng.randi()
	enc.display_name = "Breather"
	enc.duration = duration
	enc.tags = PackedStringArray(["breather", "auto_generated"])
	# No events — just empty time / distance for the player to breathe
	return enc
```

### stage_builder.gd

```gdscript
## Orchestrates procedural stage generation.
##
## Takes a StageTemplate (skeleton), an EncounterPool (content), and a
## DifficultyProfile (curves), then outputs an Array[Encounter] ready to
## be fed into StageDirector.segments.
##
## Pipeline:
##   1. Walk template slots
##   2. For each COMBAT slot → draw from EncounterDeck matching constraints
##   3. For each FIXED slot  → use the slot's fixed_encounter directly
##   4. For each BREATHER slot → generate an empty breather encounter
##   5. Apply difficulty mutations based on slot position + curves
##   6. Run RhythmSpacer to insert auto-breathers between adjacent combat slots
##   7. Return the final segment array
##
## This is a runtime utility class — not a Node or Resource.
class_name StageBuilder

# ── Build result ─────────────────────────────────────────────────────────────

## Returned by build() with the segment array and metadata.
class BuildResult:
	var segments: Array[Encounter] = []
	var seed_used: int = 0
	var slots_filled: int = 0
	var slots_skipped: int = 0
	var breathers_inserted: int = 0

# ── Configuration ────────────────────────────────────────────────────────────

var template: StageTemplate
var pool: EncounterPool
var profile: DifficultyProfile

## Minimum breather gap between adjacent combat encounters (distance/seconds).
var min_gap: float = 2.0
## Maximum breather gap.
var max_gap: float = 6.0
## If true, the spacer inserts breathers between adjacent combat encounters
## even if the template doesn't have explicit BREATHER slots between them.
var auto_breathers: bool = true
## How many recent draws to remember for repeat prevention.
var history_limit: int = 3

var _rng: RandomNumberGenerator
var _deck: EncounterDeck


func _init(
	p_template: StageTemplate,
	p_pool: EncounterPool,
	p_profile: DifficultyProfile = null,
	p_rng: RandomNumberGenerator = null
) -> void:
	template = p_template
	pool = p_pool
	profile = p_profile
	_rng = p_rng if p_rng != null else RandomNumberGenerator.new()


## Build the stage segments from the template + pool.
## Returns a BuildResult with the segments array and stats.
func build(run_seed: int = 0) -> BuildResult:
	var result := BuildResult.new()

	# Seed
	if run_seed != 0:
		_rng.seed = run_seed
	else:
		_rng.randomize()
	result.seed_used = _rng.seed

	# Create deck from pool
	_deck = EncounterDeck.new(pool, _rng, history_limit)
	_deck.refill()

	var segments: Array[Encounter] = []
	var combat_indices: Array[int] = [] # track where combat encounters land
	var total_slots := template.slots.size()

	# ── Walk slots ───────────────────────────────────────────────────────
	for slot_idx in total_slots:
		var slot := template.slots[slot_idx]
		if slot == null:
			continue

		var progress := float(slot_idx) / float(maxi(total_slots - 1, 1))

		match slot.role:
			SlotDefinition.Role.COMBAT:
				var enc := _fill_combat_slot(slot, progress)
				if enc != null:
					combat_indices.append(segments.size())
					segments.append(enc)
					result.slots_filled += 1
				else:
					result.slots_skipped += 1

			SlotDefinition.Role.FIXED:
				var enc := _fill_fixed_slot(slot)
				if enc != null:
					segments.append(enc)
					result.slots_filled += 1
				else:
					result.slots_skipped += 1

			SlotDefinition.Role.BREATHER:
				var enc := _fill_breather_slot(slot, progress)
				segments.append(enc)
				result.slots_filled += 1

	# ── Auto-breathers ───────────────────────────────────────────────────
	if auto_breathers and combat_indices.size() > 1:
		var spacer := RhythmSpacer.new(_rng, profile, min_gap, max_gap)
		var before := segments.size()
		spacer.insert_breathers(segments, total_slots, combat_indices)
		result.breathers_inserted = segments.size() - before

	result.segments = segments
	return result


# ── Slot filling ─────────────────────────────────────────────────────────────

func _fill_combat_slot(slot: SlotDefinition, progress: float) -> Encounter:
	var enc := _deck.draw(
		slot.required_tags,
		slot.excluded_tags,
		slot.min_tier,
		slot.max_tier,
		slot.allow_repeat
	)

	if enc == null:
		if not slot.optional:
			push_warning("StageBuilder: no match for combat slot (tags=%s, tier=%d-%d)" % [
				str(slot.required_tags), slot.min_tier, slot.max_tier])
		return null

	# Deep-duplicate so mutations don't affect the pool's originals
	enc = enc.duplicate(true)

	# Apply duration override
	if slot.duration_override > 0.0:
		enc.duration = slot.duration_override

	# Apply difficulty mutations
	if profile != null:
		_mutate_encounter(enc, progress)

	return enc


func _fill_fixed_slot(slot: SlotDefinition) -> Encounter:
	if slot.fixed_encounter == null:
		push_warning("StageBuilder: FIXED slot has no fixed_encounter set.")
		return null
	# Duplicate so runtime mutations don't affect the authored resource
	var enc := slot.fixed_encounter.duplicate(true) as Encounter
	if slot.duration_override > 0.0:
		enc.duration = slot.duration_override
	return enc


func _fill_breather_slot(slot: SlotDefinition, progress: float) -> Encounter:
	var duration := slot.breather_duration
	if profile != null:
		duration *= profile.sample(&"breather", progress)
	duration = maxf(duration, 1.0)

	var enc := Encounter.new()
	enc.id = "breather_%d" % _rng.randi()
	enc.display_name = "Breather"
	enc.duration = duration
	enc.tags = PackedStringArray(["breather"])
	return enc


# ── Difficulty mutations ─────────────────────────────────────────────────────

## Mutate an encounter's SpawnEvents based on the difficulty profile at the
## given progress point.
func _mutate_encounter(enc: Encounter, progress: float) -> void:
	var scales := profile.sample_all(progress)

	for ev in enc.events:
		if ev == null:
			continue
		if ev is SpawnEvent:
			_mutate_spawn_event(ev as SpawnEvent, scales)


func _mutate_spawn_event(ev: SpawnEvent, scales: Dictionary) -> void:
	# Scale HP
	if ev.hp > 0:
		ev.hp = maxi(roundi(float(ev.hp) * scales[&"hp"]), 1)

	# Scale spawn count
	var count_mult: float = scales[&"spawn_count"]
	if count_mult != 1.0:
		ev.count = maxi(roundi(float(ev.count) * count_mult), 1)

	# Scale move style speed
	if ev.move_style != null:
		ev.move_style = ev.move_style.duplicate() as MovementStyle
		ev.move_style.speed_x *= scales[&"speed"]
		ev.move_style.speed_z *= scales[&"speed"]

	# Scale pattern fire rate
	if ev.pattern != null:
		ev.pattern = ev.pattern.duplicate() as Pattern
		var fr: float = scales[&"fire_rate"]
		if fr > 0.0:
			ev.pattern.fire_interval = maxf(ev.pattern.fire_interval / fr, 0.1)
```

### StageDirector changes (stage_director.gd)

New exports added to `StageDirector`:

```gdscript
# ── Procedural generation (optional) ────────────────────────────────────────

@export var stage_template: StageTemplate
@export var encounter_pool: EncounterPool
@export var difficulty_profile: DifficultyProfile
@export var min_breather_gap: float = 2.0
@export var max_breather_gap: float = 6.0
@export var auto_breathers: bool = true
```

New internal state:

```gdscript
var _last_build_result: StageBuilder.BuildResult = null
```

Modified `start_stage()` — procedural build block:

```gdscript
func start_stage(seed_override: int = 0) -> void:
  # ... seed setup ...

  # ── Procedural build (if template + pool are set) ────────────────────
  if stage_template != null and encounter_pool != null:
    var builder := StageBuilder.new(stage_template, encounter_pool, difficulty_profile, _rng)
    builder.min_gap = min_breather_gap
    builder.max_gap = max_breather_gap
    builder.auto_breathers = auto_breathers
    _last_build_result = builder.build(run_seed)
    segments = _last_build_result.segments

  # ... rest unchanged ...
```

New public API:

```gdscript
## Returns true if segments were built procedurally (template + pool).
func is_procedural() -> bool:
  return _last_build_result != null

## Returns the last StageBuilder.BuildResult (null if manual segments).
func last_build_result() -> StageBuilder.BuildResult:
  return _last_build_result
```
