extends WorldObject
class_name EnemyBullet

@export var speed: float = 90.0
@export var life_seconds: float = 3.0
@export var damage: int = 1
@export var hit_radius_px: float = 10.0

var vel: Vector3 = Vector3.ZERO
var _t: float = 0.0

func _ready() -> void:
  super._ready()
  add_to_group("enemy_bullets")

func _process(delta: float) -> void:
  # Move in world space
  world_pos += vel * delta

  _t += delta
  if _t >= life_seconds:
    queue_free()
    return

  super._process(delta)

  # Despawn once it passes the camera (i.e., gets too close/behind)
  if rig != null:
    var rel_z := world_pos.z - rig.cam_z
    if rel_z < 0.8:
      queue_free()
