# Downstar — Encounter & Stage System

> **Phase 1 Architecture Documentation**
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
   - [MoveStyle](#movestyle)
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
│  Owns: actual instantiation logic, applying MoveStyle /     │
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
 ├── MoveStyle                    # Movement descriptor for enemies
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

| Property        | Type          | Default  | Description                                                                |
| --------------- | ------------- | -------- | -------------------------------------------------------------------------- |
| `enemy_scene`   | `PackedScene` | `null`   | The enemy scene to instantiate.                                            |
| `count`         | `int`         | `1`      | Number of enemies to spawn. Range: 1–100.                                  |
| `formation`     | `Formation`   | `null`   | Spatial formation for the group. Null = all at origin.                     |
| `z_start`       | `float`       | `95.0`   | World-Z distance ahead of camera where enemies appear.                     |
| `move_style`    | `MoveStyle`   | `null`   | Movement descriptor applied to each enemy at spawn.                        |
| `pattern`       | `Pattern`     | `null`   | Firing/attack pattern applied to each enemy.                               |
| `hp`            | `int`         | `0`      | HP override per enemy. 0 = use scene default.                              |
| `spawn_space`   | `SpawnSpace`  | `WORLD`  | Whether positions are in world space or screen-normalised coords.          |
| `spawn_origin`  | `Vector2`     | `(0, 0)` | Centre of the spawn group.                                                 |
| `spread`        | `Vector2`     | `(0, 0)` | Per-axis random jitter added to each unit's offset.                        |
| `height_offset` | `float`       | `-30.0`  | Y offset relative to horizon. Matches the old `height_over_horizon` value. |

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

**File:** `scenes/encounters/formation.gd`
**Class:** `Formation extends Resource`

Describes the spatial arrangement of a group of enemies.

| Property  | Type      | Default      | Description              |
| --------- | --------- | ------------ | ------------------------ |
| `shape`   | `Shape`   | `POINT`      | Geometric shape.         |
| `spacing` | `Vector2` | `(5.0, 3.0)` | Spacing on X/Y axes.     |
| `columns` | `int`     | `3`          | Column count for `GRID`. |
| `radius`  | `float`   | `6.0`        | Radius for `CIRCLE`.     |

**Shape enum and offset logic:**

| Shape    | Behaviour                                                                        |
| -------- | -------------------------------------------------------------------------------- |
| `POINT`  | All units at `(0, 0)`.                                                           |
| `LINE`   | Units spread along X axis, centered. Spacing: `spacing.x`.                       |
| `V`      | Alternating left/right, fanning backward. Uses both `spacing.x` and `spacing.y`. |
| `GRID`   | Rows × columns grid, centered. Uses `columns` property.                          |
| `CIRCLE` | Units evenly distributed on a circle of `radius`.                                |
| `RANDOM` | Returns zeroes — caller (spawner) adds jitter via `spread` on the SpawnEvent.    |

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

### MoveStyle

**File:** `scenes/encounters/move_style.gd`
**Class:** `MoveStyle extends Resource`

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

| Signal               | Parameters                                   | When                                       |
| -------------------- | -------------------------------------------- | ------------------------------------------ |
| `encounter_started`  | `(enc: Encounter)`                           | Playback begins.                           |
| `event_fired`        | `(event: EncounterEvent)`                    | Any event fires (generic).                 |
| `encounter_finished` | `(enc: Encounter)`                           | Timeline complete or duration reached.     |
| `encounter_failed`   | `(reason: String)`                           | `fail()` was called.                       |
| `phase_changed`      | `(phase_name: String)`                       | PhaseEvent fires.                          |
| `marker_hit`         | `(marker_name: String, payload: Dictionary)` | MarkerEvent fires.                         |
| `custom_signal`      | `(signal_name: String, argument: String)`    | SignalEvent fires.                         |
| `gate_entered`       | `(gate: GateEvent)`                          | GateEvent reached — progression paused.    |
| `gate_cleared`       | `(gate: GateEvent)`                          | Gate condition met — progression resuming. |

#### Internal flow (`_process`)

```
_process(delta):
  if TIME mode → _progress += delta
  if gated → _update_gate(delta), return
  _advance_events()     # fire all events where event.time <= _progress
  check end condition   # _progress >= duration OR all events fired
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
6. Calls `_apply_move_style()` to map `MoveStyle` → enemy movement properties.
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
ACTIVE   → Shoot, strafe, do your pattern (2–6s based on MoveStyle)
EXIT     → Fly away off-screen (1s), then queue_free()

At any point: if killed → death anim → queue_free()
```

The `MoveStyle` tells the enemy _how_ to behave during ACTIVE. The `Pattern` tells it _how_ to shoot. The enemy doesn't know about encounters — it does its thing for its lifespan.

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
   - Create (or reuse) a `MoveStyle` sub-resource — set `type`, speeds, etc.
   - Create (or reuse) a `Pattern` sub-resource — set `fire_interval`, `bullet_speed`, etc.
   - Adjust `spawn_origin`, `z_start`, `height_offset`, `spread` as needed.

5. **Add to StageDirector:** Drag the `.tres` into the `segments` array on the StageDirector node.

### Reusing sub-resources

`Formation`, `MoveStyle`, and `Pattern` can be saved as standalone `.tres` files and shared across multiple SpawnEvents. This avoids duplicating configuration:

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

| File                  | Class             | Type     | Lines | Purpose                                      |
| --------------------- | ----------------- | -------- | ----- | -------------------------------------------- |
| `encounter.gd`        | `Encounter`       | Resource | 63    | Top-level encounter container                |
| `encounter_event.gd`  | `EncounterEvent`  | Resource | 20    | Base event class                             |
| `spawn_event.gd`      | `SpawnEvent`      | Resource | 38    | Spawn a group of enemies                     |
| `gate_event.gd`       | `GateEvent`       | Resource | 30    | Pause progression until condition met        |
| `phase_event.gd`      | `PhaseEvent`      | Resource | 9     | Named phase boundary                         |
| `marker_event.gd`     | `MarkerEvent`     | Resource | 12    | Named marker with payload                    |
| `signal_event.gd`     | `SignalEvent`     | Resource | 12    | Fire custom signal                           |
| `formation.gd`        | `Formation`       | Resource | 64    | Spatial group arrangement                    |
| `move_style.gd`       | `MoveStyle`       | Resource | 31    | Enemy movement descriptor                    |
| `pattern.gd`          | `Pattern`         | Resource | 20    | Enemy firing config                          |
| `encounter_runner.gd` | `EncounterRunner` | Node     | 360   | Micro layer: plays encounter timeline        |
| `enemy_spawner.gd`    | `EnemySpawner`    | Node     | 111   | Factory: instantiates and configures enemies |
| `stage_director.gd`   | `StageDirector`   | Node     | 268   | Macro layer: stage progression orchestrator  |

Related files outside `encounters/`:

| File              | Class         | Modification                                                  |
| ----------------- | ------------- | ------------------------------------------------------------- |
| `player.gd`       | `Player`      | Added `_distance: float`, `signal distance_changed(distance)` |
| `enemy.gd`        | `Enemy`       | No changes — `MoveStyle`/`Pattern` map to existing exports    |
| `camera_rig.gd`   | `CameraRig`   | No changes — `EnemySpawner` reads `camera_world_position`     |
| `world_object.gd` | `WorldObject` | No changes — base class for Player/Enemy                      |
