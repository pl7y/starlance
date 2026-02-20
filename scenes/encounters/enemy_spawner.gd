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
  if world == null:
    push_error("EnemySpawner: world node is not set.")
    return
  if camera_rig == null:
    push_error("EnemySpawner: camera_rig is not set.")
    return
  if event.enemy_scene == null:
    push_warning("SpawnEvent has no enemy_scene — skipping.")
    return

  if event.formation != null and event.spawn_shape != null:
    push_warning("SpawnEvent has both formation and spawn_shape set. These conflict - using formation only.")

  for i in offsets.size():
    var offset := offsets[i]

    var enemy := event.enemy_scene.instantiate()

    # Start with the base world position
    var spawn_pos := event.world_pos
    
    # Add formation offset (offset is 2D, apply to X and Y)
    spawn_pos.x += offset.x
    spawn_pos.y += offset.y
    
    # If a spawn shape is defined, sample a random point within it
    if event.spawn_shape != null:
      var random_point := _sample_point_in_shape(event.spawn_shape, rng)
      spawn_pos += random_point

    enemy.world_pos = spawn_pos
    world.add_child(enemy)

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
  if "follow_distance" in enemy:
    enemy.follow_distance = style.follow_distance
  if "rush_turn" in enemy:
    enemy.rush_turn = style.rush_turn

  # Custom AI logic — duplicate so each enemy gets its own state
  if style.type == MoveStyle.Type.CUSTOM and style.custom_logic != null:
    if "custom_move_logic" in enemy:
      enemy.custom_move_logic = style.custom_logic.duplicate()


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


## Sample a random point within a Shape3D.
## Supports common shapes: BoxShape3D, SphereShape3D, CapsuleShape3D, CylinderShape3D.
func _sample_point_in_shape(shape: Shape3D, rng: RandomNumberGenerator) -> Vector3:
  if shape is BoxShape3D:
    var box := shape as BoxShape3D
    var size := box.size
    return Vector3(
      rng.randf_range(-size.x * 0.5, size.x * 0.5),
      rng.randf_range(-size.y * 0.5, size.y * 0.5),
      rng.randf_range(-size.z * 0.5, size.z * 0.5)
    )
  
  elif shape is SphereShape3D:
    var sphere := shape as SphereShape3D
    var radius := sphere.radius
    # Uniform sampling within a sphere using rejection sampling
    var point := Vector3.ZERO
    var max_attempts := 100
    for attempt in max_attempts:
      point = Vector3(
        rng.randf_range(-1.0, 1.0),
        rng.randf_range(-1.0, 1.0),
        rng.randf_range(-1.0, 1.0)
      )
      if point.length_squared() <= 1.0:
        break
    return point.normalized() * rng.randf_range(0.0, radius)
  
  elif shape is CapsuleShape3D:
    var capsule := shape as CapsuleShape3D
    var radius := capsule.radius
    var height := capsule.height
    # Sample within cylinder part + hemisphere caps
    var cylinder_height := height - 2.0 * radius
    if cylinder_height > 0:
      # Randomly choose cylinder or caps
      var total_volume := PI * radius * radius * cylinder_height + (4.0 / 3.0) * PI * radius * radius * radius
      if rng.randf() < (PI * radius * radius * cylinder_height) / total_volume:
        # Cylinder part
        var angle := rng.randf() * TAU
        var r := sqrt(rng.randf()) * radius
        var y := rng.randf_range(-cylinder_height * 0.5, cylinder_height * 0.5)
        return Vector3(r * cos(angle), y, r * sin(angle))
      else:
        # Hemisphere caps - simplified: sample sphere and offset
        var point := Vector3.ZERO
        for attempt in 100:
          point = Vector3(
            rng.randf_range(-1.0, 1.0),
            rng.randf_range(-1.0, 1.0),
            rng.randf_range(-1.0, 1.0)
          )
          if point.length_squared() <= 1.0:
            break
        point = point.normalized() * rng.randf_range(0.0, radius)
        point.y += cylinder_height * 0.5 if point.y > 0 else -cylinder_height * 0.5
        return point
    else:
      # Degenerate: just a sphere
      return _sample_point_in_shape(SphereShape3D.new(), rng) * radius
  
  elif shape is CylinderShape3D:
    var cylinder := shape as CylinderShape3D
    var radius := cylinder.radius
    var height := cylinder.height
    var angle := rng.randf() * TAU
    var r := sqrt(rng.randf()) * radius
    var y := rng.randf_range(-height * 0.5, height * 0.5)
    return Vector3(r * cos(angle), y, r * sin(angle))
  
  else:
    push_warning("Unsupported Shape3D type: %s — returning zero." % shape.get_class())
    return Vector3.ZERO
