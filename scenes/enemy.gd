extends WorldObject
class_name Enemy

@export var hp: int = 3
@export var hit_radius_px: float = 18.0 # screen-space radius at scale=1

func take_hit(dmg: int) -> void:
  hp -= dmg
  if hp <= 0:
    queue_free()
