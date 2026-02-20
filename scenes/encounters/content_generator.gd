## Run this from the editor to generate a full set of encounter resources
## for a demo level.  Attach to a Node, add to scene, run scene once.
##
## Creates:
##   resources/encounters/       — individual encounter .tres files
##   resources/encounters/pool/  — EncounterPool .tres
##   resources/encounters/templates/ — StageTemplate .tres
##   resources/encounters/difficulty/ — DifficultyProfile .tres
##
## After running, remove this node — it's a one-time content bootstrap.
extends Node

const ENEMY_SCENE_PATH := "res://scenes/enemy.tscn"
const OUTPUT_BASE := "res://resources/encounters/"

func _ready() -> void:
  print("═══ Content Generator: starting ═══")

  # Ensure directories exist
  DirAccess.make_dir_recursive_absolute(OUTPUT_BASE + "pool")
  DirAccess.make_dir_recursive_absolute(OUTPUT_BASE + "templates")
  DirAccess.make_dir_recursive_absolute(OUTPUT_BASE + "difficulty")

  var enemy_scene := load(ENEMY_SCENE_PATH) as PackedScene

  # ── 1. Reusable sub-resources ────────────────────────────────────────

  # Formations
  var line_5 := _formation(ShapeFormation.Shape.LINE, Vector2(40.0, 0.0))
  var v_shape := _formation(ShapeFormation.Shape.V, Vector2(35.0, 25.0))
  var grid_3x2 := _formation(ShapeFormation.Shape.GRID, Vector2(40.0, 30.0), 3)
  var circle_6 := _formation(ShapeFormation.Shape.CIRCLE, Vector2.ZERO, 1, 50.0)
  var point := _formation(ShapeFormation.Shape.POINT)

  # Move styles
  var drift_slow := _drift_style(80.0, 0.0)
  var drift_fast := _drift_style(120.0, 0.0)
  var sine_strafe := _sine_strafe_style(60.0, Vector2(50.0, 20.0), 0.8)
  var sine_fast := _sine_strafe_style(90.0, Vector2(60.0, 30.0), 1.2)
  var dive := _dive_style(70.0)
  var swoop := _swoop_style(80.0, Vector2(60.0, 40.0), 0.6)
  var orbit := _orbit_style(30.0)

  # Rush-follow: fly in fast, then orbit the player at close range
  var rush_follow := _rush_follow_style(25.0, 5.0, 8.0, 2.0)
  var rush_follow_tight := _rush_follow_style(18.0, 6.0, 5.0, 2.5)

  # Patterns (firing)
  var slow_fire := _pattern(2.0, 70.0)
  var med_fire := _pattern(1.2, 90.0)
  var fast_fire := _pattern(0.8, 110.0)
  var _no_fire := _pattern(999.0, 0.0) # effectively doesn't shoot

  # Custom AI move styles
  var ai_flanker := _custom_move_style(FlankerMoveLogic.new())
  var ai_mimic := _custom_move_style(MimicMoveLogic.new())

  var ai_ambusher_logic := AmbusherMoveLogic.new()
  ai_ambusher_logic.lurk_time = 2.0
  ai_ambusher_logic.charge_speed = 280.0
  ai_ambusher_logic.loops = true
  var ai_ambusher := _custom_move_style(ai_ambusher_logic)

  var ai_swarm := _custom_move_style(SwarmMoveLogic.new())

  var ai_hitrun_logic := HitAndRunMoveLogic.new()
  ai_hitrun_logic.attack_hold = 1.8
  ai_hitrun_logic.retreat_distance = 50.0
  var ai_hitrun := _custom_move_style(ai_hitrun_logic)

  var ai_helix := _custom_move_style(HelixMoveLogic.new())

  # ── 2. Encounters ───────────────────────────────────────────────────

  # --- Wave 1: Scout Line (opener — easy line of drifters) ---
  var scout_line := _encounter("scout_line", "Scout Line", 120.0,
    ["opener", "easy"], [
      _spawn(enemy_scene, 3, line_5, drift_slow, slow_fire, 0.0, 20,
        Vector3(0, 0, -500.0)),
  ])
  _save(scout_line, OUTPUT_BASE + "scout_line.tres")

  # --- Wave 2: Sine Dancers (sine-strafe enemies in a V) ---
  var sine_dancers := _encounter("sine_dancers", "Sine Dancers", 150.0,
    ["mid", "strafe"], [
      _spawn(enemy_scene, 5, v_shape, sine_strafe, med_fire, 0.0, 25,
        Vector3(0, 10.0, -500.0)),
  ])
  _save(sine_dancers, OUTPUT_BASE + "sine_dancers.tres")

  # --- Wave 3: Grid Assault (grid formation, medium speed) ---
  var grid_assault := _encounter("grid_assault", "Grid Assault", 150.0,
    ["mid", "grid"], [
      _spawn(enemy_scene, 6, grid_3x2, drift_fast, med_fire, 0.0, 30,
        Vector3(0, 20.0, -500.0)),
  ])
  _save(grid_assault, OUTPUT_BASE + "grid_assault.tres")

  # --- Wave 4: Dive Bombers (dive at player in a circle) ---
  var dive_bombers := _encounter("dive_bombers", "Dive Bombers", 180.0,
    ["hard", "dive"], [
      _spawn(enemy_scene, 4, circle_6, dive, fast_fire, 0.0, 40,
        Vector3(0, 0, -500.0)),
  ])
  _save(dive_bombers, OUTPUT_BASE + "dive_bombers.tres")

  # --- Wave 5: Swooping Aces (swoop pattern, trickier) ---
  var swooping_aces := _encounter("swooping_aces", "Swooping Aces", 180.0,
    ["hard", "swoop"], [
      _spawn(enemy_scene, 3, v_shape, swoop, med_fire, 0.0, 35,
        Vector3(0, 15.0, -500.0)),
      _spawn(enemy_scene, 2, point, dive, fast_fire, 60.0, 40,
        Vector3(50.0, 0.0, -500.0)),
  ])
  _save(swooping_aces, OUTPUT_BASE + "swooping_aces.tres")

  # --- Wave 6: Elite Orbit Guard (elite — orbiting enemies) ---
  var elite_orbit := _encounter("elite_orbit", "Elite Orbit Guard", 200.0,
    ["elite", "orbit"], [
      _spawn(enemy_scene, 4, circle_6, orbit, fast_fire, 0.0, 50,
        Vector3(0, 10.0, -500.0)),
      _spawn(enemy_scene, 2, point, dive, fast_fire, 80.0, 60,
        Vector3(0, 0, -500.0)),
  ])
  _save(elite_orbit, OUTPUT_BASE + "elite_orbit.tres")

  # --- Wave 7: Rush Stalkers (rush in and follow the player) ---
  var rush_stalkers := _encounter("rush_stalkers", "Rush Stalkers", 200.0,
    ["hard", "follow"], [
      # First group rushes in from far away and orbits close
      _spawn(enemy_scene, 3, v_shape, rush_follow, med_fire, 0.0, 35,
        Vector3(0, 10.0, -500.0)),
      # Second group arrives later with tighter orbit — more aggressive
      _spawn(enemy_scene, 2, point, rush_follow_tight, fast_fire, 60.0, 40,
        Vector3(40.0, 0.0, -500.0)),
  ])
  _save(rush_stalkers, OUTPUT_BASE + "rush_stalkers.tres")

  # --- Wave 8: Mixed Ambush (two-phase encounter with gate + gate) ---
  var gate_all_dead := GateEvent.new()
  gate_all_dead.time = 50.0
  gate_all_dead.condition = GateEvent.Condition.ALL_ENEMIES_DEAD
  gate_all_dead.label = "Clear this wave!"

  var mixed_ambush := _encounter("mixed_ambush", "Mixed Ambush", 250.0,
    ["mid", "mixed"], [
      _spawn(enemy_scene, 4, line_5, drift_slow, slow_fire, 0.0, 20,
        Vector3(0, 10.0, -500.0)),
      gate_all_dead,
      _spawn(enemy_scene, 3, v_shape, sine_fast, med_fire, 55.0, 30,
        Vector3(0, 0, -500.0)),
  ])
  _save(mixed_ambush, OUTPUT_BASE + "mixed_ambush.tres")

  # --- Boss: Heavy Dreadnought (static boss + drone waves) ---
  var phase1 := PhaseEvent.new()
  phase1.time = 0.0
  phase1.phase_name = "boss_phase_1"

  var phase2 := PhaseEvent.new()
  phase2.time = 150.0
  phase2.phase_name = "boss_phase_2"

  var boss_gate := GateEvent.new()
  boss_gate.time = 5.0
  boss_gate.condition = GateEvent.Condition.ALL_ENEMIES_DEAD
  boss_gate.label = "Defeat the Dreadnought!"

  var boss_encounter := _encounter("boss_dreadnought", "Heavy Dreadnought", 350.0,
    ["boss"], [
      phase1,
      boss_gate,
      _spawn(enemy_scene, 1, point, MovementStyle.new(), slow_fire, 0.0, 200,
        Vector3(0, 20.0, -500.0)),
      _spawn(enemy_scene, 3, line_5, drift_slow, med_fire, 80.0, 25,
        Vector3(0, 0, -500.0)),
      phase2,
      _spawn(enemy_scene, 4, circle_6, sine_fast, fast_fire, 155.0, 30,
        Vector3(0, 10.0, -500.0)),
  ])
  _save(boss_encounter, OUTPUT_BASE + "boss_dreadnought.tres")

  # --- Wave 10: Flanker Pair (AI — circles then cross-screen dive) ---
  var flanker_pair := _encounter("flanker_pair", "Flanker Pair", 200.0,
    ["hard", "ai"], [
      _spawn(enemy_scene, 2, line_5, ai_flanker, med_fire, 0.0, 40,
        Vector3(0, 10.0, -500.0)),
  ])
  _save(flanker_pair, OUTPUT_BASE + "flanker_pair.tres")

  # --- Wave 11: Dark Mirrors (AI — eerie mimics of the player) ---
  var dark_mirrors := _encounter("dark_mirrors", "Dark Mirrors", 220.0,
    ["mid", "ai", "creepy"], [
      _spawn(enemy_scene, 2, line_5, ai_mimic, slow_fire, 0.0, 35,
        Vector3(0, 0, -500.0)),
  ])
  _save(dark_mirrors, OUTPUT_BASE + "dark_mirrors.tres")

  # --- Wave 12: Phantom Ambush (AI — lurkers that charge) ---
  var phantom_ambush := _encounter("phantom_ambush", "Phantom Ambush", 250.0,
    ["hard", "ai", "surprise"], [
      _spawn(enemy_scene, 3, line_5, ai_ambusher, fast_fire, 0.0, 45,
        Vector3(0, 0, -500.0)),
  ])
  _save(phantom_ambush, OUTPUT_BASE + "phantom_ambush.tres")

  # --- Wave 13: Hive Swarm (AI — boid flocking cloud) ---
  var hive_swarm := _encounter("hive_swarm", "Hive Swarm", 200.0,
    ["mid", "ai", "swarm"], [
      _spawn(enemy_scene, 6, circle_6, ai_swarm, slow_fire, 0.0, 20,
        Vector3(0, 10.0, -500.0)),
  ])
  _save(hive_swarm, OUTPUT_BASE + "hive_swarm.tres")

  # --- Wave 14: Gunship Raiders (AI — hit-and-run pressure) ---
  var gunship_raiders := _encounter("gunship_raiders", "Gunship Raiders", 250.0,
    ["hard", "ai"], [
      _spawn(enemy_scene, 3, v_shape, ai_hitrun, fast_fire, 0.0, 50,
        Vector3(0, 5.0, -500.0)),
  ])
  _save(gunship_raiders, OUTPUT_BASE + "gunship_raiders.tres")

  # --- Wave 15: Helix Dancers (AI — mesmerizing corkscrew approach) ---
  var helix_dancers := _encounter("helix_dancers", "Helix Dancers", 200.0,
    ["elite", "ai", "helix"], [
      _spawn(enemy_scene, 4, point, ai_helix, med_fire, 0.0, 40,
        Vector3(0, 10.0, -500.0)),
  ])
  _save(helix_dancers, OUTPUT_BASE + "helix_dancers.tres")

  print("  ✓ 15 encounters saved")

  # ── 3. Encounter Pool ───────────────────────────────────────────────

  var pool := EncounterPool.new()
  pool.display_name = "Demo Level Pool"
  pool.tags = PackedStringArray(["demo"])

  pool.entries = [
    _pool_entry(scout_line, 3.0, 1, ["opener", "easy"]),
    _pool_entry(sine_dancers, 2.0, 2, ["mid"]),
    _pool_entry(grid_assault, 2.0, 2, ["mid"]),
    _pool_entry(mixed_ambush, 1.5, 2, ["mid", "mixed"]),
    _pool_entry(dive_bombers, 1.5, 3, ["hard"]),
    _pool_entry(swooping_aces, 1.0, 3, ["hard"]),
    _pool_entry(rush_stalkers, 1.5, 3, ["hard", "follow"]),
    _pool_entry(flanker_pair, 1.5, 3, ["hard", "ai"]),
    _pool_entry(dark_mirrors, 2.0, 2, ["mid", "ai"]),
    _pool_entry(phantom_ambush, 1.0, 3, ["hard", "ai"]),
    _pool_entry(hive_swarm, 2.0, 2, ["mid", "ai"]),
    _pool_entry(gunship_raiders, 1.0, 3, ["hard", "ai"]),
    _pool_entry(helix_dancers, 1.0, 4, ["elite", "ai"]),
    _pool_entry(elite_orbit, 1.0, 4, ["elite"]),
    _pool_entry(boss_encounter, 1.0, 5, ["boss"]),
  ] as Array[EncounterPoolEntry]

  _save(pool, OUTPUT_BASE + "pool/demo_pool.tres")
  print("  ✓ Pool saved")

  # ── 4. Stage Template ───────────────────────────────────────────────

  var template := StageTemplate.new()
  template.display_name = "Demo Stage — Standard Run"
  template.tags = PackedStringArray(["demo"])

  template.slots = [
    # Opener — easy warm-up
    _slot_combat(["opener"], 0, 1, 1),
    # Brief breather
    _slot_breather(60.0),
    # Mid-game: two combat encounters ramping up
    _slot_combat([], 0, 2, 2),
    _slot_breather(50.0),
    _slot_combat([], 0, 2, 2),
    # Breather before harder stuff
    _slot_breather(40.0),
    # Hard encounter
    _slot_combat([], 0, 3, 3),
    _slot_breather(50.0),
    # Elite encounter
    _slot_combat(["elite"], 0, 4, 4),
    # Long breather before boss
    _slot_breather(80.0),
    # Boss — fixed
    _slot_fixed(boss_encounter),
  ] as Array[SlotDefinition]

  _save(template, OUTPUT_BASE + "templates/demo_template.tres")
  print("  ✓ Template saved")

  # ── 5. Difficulty Profile ───────────────────────────────────────────

  var profile := DifficultyProfile.new()
  profile.display_name = "Normal"

  # HP: 1.0 at start → 1.8 at end
  profile.hp_curve = _linear_curve(1.0, 1.8)

  # Fire rate: 1.0 → 1.4 (enemies shoot faster later)
  profile.fire_rate_curve = _linear_curve(1.0, 1.4)

  # Spawn count: 1.0 → 1.3 (slightly more enemies later)
  profile.spawn_count_curve = _linear_curve(1.0, 1.3)

  # Speed: 1.0 → 1.2 (enemies move faster later)
  profile.speed_curve = _linear_curve(1.0, 1.2)

  # Breather: 1.0 → 0.6 (shorter breathers later in the stage)
  profile.breather_curve = _linear_curve(1.0, 0.6)

  # Intensity: 1.0 → 2.0 (general pressure multiplier)
  profile.intensity_curve = _linear_curve(1.0, 2.0)

  _save(profile, OUTPUT_BASE + "difficulty/normal_profile.tres")
  print("  ✓ Difficulty profile saved")

  print("═══ Content Generator: DONE ═══")
  print("")
  print("Now wire the StageDirector in the Inspector:")
  print("  stage_template  → res://resources/encounters/templates/demo_template.tres")
  print("  encounter_pool  → res://resources/encounters/pool/demo_pool.tres")
  print("  difficulty_profile → res://resources/encounters/difficulty/normal_profile.tres")
  print("")
  print("Remove this ContentGenerator node, then play your level!")


# ── Factory helpers ──────────────────────────────────────────────────────────

func _formation(shape: ShapeFormation.Shape, spacing := Vector2(5.0, 3.0),
    columns: int = 3, radius: float = 6.0) -> ShapeFormation:
  var f := ShapeFormation.new()
  f.shape = shape
  f.spacing = spacing
  f.columns = columns
  f.radius = radius
  return f


func _drift_style(p_speed_z: float = 12.0, p_speed_x: float = 0.0, p_speed_y: float = 0.0) -> DriftMovementStyle:
  var m := DriftMovementStyle.new()
  m.speed_z = p_speed_z
  m.speed_x = p_speed_x
  m.speed_y = p_speed_y
  return m

func _sine_strafe_style(p_speed_z: float = 60.0, amplitude := Vector2(4.0, 2.0), frequency: float = 1.2) -> SineStrafeMovementStyle:
  var m := SineStrafeMovementStyle.new()
  m.speed_z = p_speed_z
  m.amplitude = amplitude
  m.frequency = frequency
  return m

func _dive_style(p_speed_z: float = 70.0, dive_turn: float = 2.5) -> DiveAtPlayerMovementStyle:
  var m := DiveAtPlayerMovementStyle.new()
  m.speed_z = p_speed_z
  m.dive_turn = dive_turn
  return m

func _swoop_style(p_speed_z: float = 80.0, amplitude := Vector2(60.0, 40.0), frequency: float = 0.6) -> SwoopMovementStyle:
  var m := SwoopMovementStyle.new()
  m.speed_z = p_speed_z
  m.amplitude = amplitude
  m.frequency = frequency
  return m

func _orbit_style(p_speed_z: float = 30.0, radius: float = 6.0, speed: float = 1.5) -> OrbitMovementStyle:
  var m := OrbitMovementStyle.new()
  m.speed_z = p_speed_z
  m.orbit_radius = radius
  m.orbit_speed = speed
  return m

func _rush_follow_style(follow_dist: float = 30.0, rush_turn: float = 4.0, radius: float = 6.0, speed: float = 1.5) -> RushFollowMovementStyle:
  var m := RushFollowMovementStyle.new()
  m.follow_distance = follow_dist
  m.rush_turn = rush_turn
  m.orbit_radius = radius
  m.orbit_speed = speed
  return m


func _custom_move_style(logic: MoveLogic) -> CustomMovementStyle:
  var m := CustomMovementStyle.new()
  m.custom_logic = logic
  return m


func _pattern(fire_interval: float = 1.2, bullet_speed: float = 90.0,
    aim_lead_y: float = 0.0) -> Pattern:
  var p := Pattern.new()
  p.fire_interval = fire_interval
  p.bullet_speed = bullet_speed
  p.aim_lead_y = aim_lead_y
  return p


func _volume_formation(spread: Vector2, z_spread: float = 0.0) -> VolumeFormation:
  """Helper to create a VolumeFormation with BoxShape3D from spread values."""
  if spread == Vector2.ZERO and z_spread == 0.0:
    return null
  var vf := VolumeFormation.new()
  var box := BoxShape3D.new()
  box.size = Vector3(spread.x * 2.0, spread.y * 2.0, z_spread * 2.0)
  vf.volume = box
  return vf


func _spawn(scene: PackedScene, count: int, formation: Formation,
    move_style, pattern: Pattern, time: float, hp: int,
    world_pos: Vector3) -> SpawnEvent:
  var ev := SpawnEvent.new()
  ev.enemy_scene = scene
  ev.count = count
  ev.formation = formation
  ev.move_style = move_style
  ev.pattern = pattern
  ev.time = time
  ev.hp = hp
  ev.world_pos = world_pos
  return ev


func _encounter(id: String, display_name: String, duration: float,
    tags: Array, events: Array) -> Encounter:
  var enc := Encounter.new()
  enc.id = id
  enc.display_name = display_name
  enc.duration = duration
  enc.tags = PackedStringArray(tags)
  var typed_events: Array[EncounterEvent] = []
  for ev in events:
    typed_events.append(ev as EncounterEvent)
  enc.events = typed_events
  enc.validate()
  return enc


func _pool_entry(enc: Encounter, weight: float, tier: int,
    extra_tags: Array) -> EncounterPoolEntry:
  var entry := EncounterPoolEntry.new()
  entry.encounter = enc
  entry.weight = weight
  entry.tier = tier
  entry.extra_tags = PackedStringArray(extra_tags)
  return entry


func _slot_combat(required_tags: Array = [], _excluded_min: int = 0,
    min_tier: int = 0, max_tier: int = 0) -> SlotDefinition:
  var slot := SlotDefinition.new()
  slot.role = SlotDefinition.Role.COMBAT
  slot.required_tags = PackedStringArray(required_tags)
  slot.min_tier = min_tier
  slot.max_tier = max_tier
  return slot


func _slot_breather(duration: float = 3.0) -> SlotDefinition:
  var slot := SlotDefinition.new()
  slot.role = SlotDefinition.Role.BREATHER
  slot.breather_duration = duration
  return slot


func _slot_fixed(enc: Encounter) -> SlotDefinition:
  var slot := SlotDefinition.new()
  slot.role = SlotDefinition.Role.FIXED
  slot.fixed_encounter = enc
  return slot


func _linear_curve(start: float, end: float) -> Curve:
  var c := Curve.new()
  c.add_point(Vector2(0.0, start), 0, 0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
  c.add_point(Vector2(1.0, end), 0, 0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
  return c


func _save(resource: Resource, path: String) -> void:
  var err := ResourceSaver.save(resource, path)
  if err != OK:
    push_error("Failed to save %s: %s" % [path, error_string(err)])
  else:
    print("  Saved: %s" % path)
