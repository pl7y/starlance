extends WorldObject
class_name Bullet

@export var bullet_speed_z: float = 180.0 # world units/sec
@export var life_seconds: float = 2.0
@export var damage: int = 1
@export var hit_radius_px: float = 6.0 # collision radius in screen pixels

var _t: float = 0.0

func _process(delta: float) -> void:
  # Move forward in world space.
  world_pos.z += bullet_speed_z * delta

  _t += delta
  if _t >= life_seconds:
    queue_free()
    return

  # Run the base projection + draw placement
  super._process(delta)
