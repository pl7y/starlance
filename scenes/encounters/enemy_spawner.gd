## Interface / base class for enemy spawning.
## The EncounterRunner delegates actual instantiation here so it never
## hard-codes enemy behaviour.
##
## Subclass this and override spawn_group() for your game.
## Attach a concrete spawner as a child of EncounterRunner and link
## it via @export var spawner.
extends Node
class_name EnemySpawner

## Reference to the Node that acts as the world root for spawned enemies.
@export var world: Node

## Camera rig, used to compute spawn positions ahead of camera.
@export var camera_rig: CameraRig


## Called by EncounterRunner when a SpawnEvent fires.
## [param event]  — the SpawnEvent resource (read-only data).
## [param offsets] — pre-computed Array[Vector2] from Formation (count entries).
## [param rng]    — the runner's deterministic RandomNumberGenerator.
##
## Override this in your concrete spawner.
func spawn_group(event: SpawnEvent, offsets: Array[Vector2], rng: RandomNumberGenerator) -> void:
  prints("* EnemySpawner.spawn_group() called with event: ", event)
  if world == null:
    push_error("EnemySpawner: world node is not set.")
    return
  if camera_rig == null:
    push_error("EnemySpawner: camera_rig is not set.")
    return
  if event.enemy_scene == null:
    push_warning("SpawnEvent has no enemy_scene — skipping.")
    return

  prints("* Spawning group of ", event.count, " enemies with formation shape ", event.formation.shape)
  for i in offsets.size():
    var offset := offsets[i]

    # Apply per-unit spread jitter
    if event.spread != Vector2.ZERO:
      offset.x += rng.randf_range(-event.spread.x, event.spread.x)
      offset.y += rng.randf_range(-event.spread.y, event.spread.y)

    var enemy := event.enemy_scene.instantiate()

    # Position in world space
    var z: float = camera_rig.camera_world_position.z + event.z_start
    var x: float = event.spawn_origin.x + offset.x
    var y: float = event.spawn_origin.y + offset.y + event.height_offset

    enemy.world_pos = Vector3(x, y, z)
    world.add_child(enemy)
    prints("* Spawned enemy at ", enemy.world_pos)

    # Apply move style  →  map to Enemy.MovePattern integer
    _apply_move_style(enemy, event.move_style)

    # Apply pattern (firing config)
    _apply_pattern(enemy, event.pattern, event.hp)


## Maps a MoveStyle resource onto enemy properties.
## Override if your Enemy API differs.
func _apply_move_style(enemy: Node, style: MoveStyle) -> void:
  if style == null:
    return

  # Map MoveStyle.Type → Enemy.MovePattern enum value (same order by convention).
  if "pattern" in enemy:
    enemy.pattern = style.type as int

  if "speed_z" in enemy:
    enemy.speed_z = style.speed_z
  if "speed_x" in enemy:
    enemy.speed_x = style.speed_x
  if "speed_y" in enemy:
    enemy.speed_y = style.speed_y
  if "amp_x" in enemy:
    enemy.amp_x = style.amplitude.x
  if "amp_y" in enemy:
    enemy.amp_y = style.amplitude.y
  if "freq" in enemy:
    enemy.freq = style.frequency
  if "dive_turn" in enemy:
    enemy.dive_turn = style.dive_turn
  if "orbit_radius" in enemy:
    enemy.orbit_radius = style.orbit_radius
  if "orbit_speed" in enemy:
    enemy.orbit_speed = style.orbit_speed


## Maps a Pattern resource onto enemy firing properties.
## Override if your Enemy API differs.
func _apply_pattern(enemy: Node, pat: Pattern, hp_override: int) -> void:
  if hp_override > 0 and "hp" in enemy:
    enemy.hp = hp_override

  if pat == null:
    return

  if "fire_interval" in enemy:
    enemy.fire_interval = pat.fire_interval
  if "bullet_speed" in enemy:
    enemy.bullet_speed = pat.bullet_speed
  if "aim_lead_y" in enemy:
    enemy.aim_lead_y = pat.aim_lead_y
  if "fire_min_z" in enemy:
    enemy.fire_min_z = pat.fire_min_z
  if "fire_max_z" in enemy:
    enemy.fire_max_z = pat.fire_max_z
