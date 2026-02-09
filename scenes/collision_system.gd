extends Node
class_name CollisionSystem

@export var max_checks_per_frame: int = 20000 # safety for later

func _process(_delta: float) -> void:
  var bullets := get_tree().get_nodes_in_group("bullets")
  var enemies := get_tree().get_nodes_in_group("enemies")

  var checks := 0
  for b in bullets:
    if not is_instance_valid(b) or not b.visible:
      continue
    if not (b is Bullet):
      continue

    var bpos: Vector2 = b.position
    var br: float = b.hit_radius_px * b.scale.x

    for e in enemies:
      checks += 1
      if checks > max_checks_per_frame:
        return

      if not is_instance_valid(e) or not e.visible:
        continue
      if not (e is Enemy):
        continue

      var epos: Vector2 = e.position
      var er: float = e.hit_radius_px * e.scale.x

      if bpos.distance_to(epos) <= (br + er):
        (e as Enemy).take_hit((b as Bullet).damage)
        b.queue_free()
        break
