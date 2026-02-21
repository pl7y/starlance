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

var _logger = EchoLogger.new("EnemySpawner", "violet", EchoLogger.LogLevel.DEBUG)

## Called by EncounterRunner when a SpawnEvent fires.
## [param event]  — the SpawnEvent resource (read-only data).
## [param offsets] — pre-computed Array[Vector2] from Formation (count entries).
## [param rng]    — the runner's deterministic RandomNumberGenerator.
##
## Override this in your concrete spawner.
func spawn_group(event: SpawnEvent, offsets: Array[Vector2], _rng: RandomNumberGenerator) -> void:
  _logger.debug("EnemySpawner: spawn_group() called with event: %s and offsets: %s" % [event, offsets])
  if world == null:
    push_error("EnemySpawner: world node is not set.")
    return
  if camera_rig == null:
    push_error("EnemySpawner: camera_rig is not set.")
    return
  if event.enemy_scene == null:
    push_warning("SpawnEvent has no enemy_scene — skipping.")
    return

  var player := get_tree().get_first_node_in_group("player") as Player
  var spawn_origin := event.world_pos
  if player != null:
    spawn_origin.z += player.world_pos.z

  for i in offsets.size():
    var offset := offsets[i]

    var enemy := event.enemy_scene.instantiate()

    # Start with the base world position and add formation offset
    var spawn_pos := spawn_origin
    spawn_pos.x += offset.x
    spawn_pos.y += offset.y

    enemy.world_pos = spawn_pos
    world.add_child(enemy)

    # Create and assign movement strategy from MovementStyle resource
    enemy.movement_strategy = event.move_style.create_strategy()

    # Apply pattern (firing config)
    _apply_pattern(enemy, event.pattern, event.hp)


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
