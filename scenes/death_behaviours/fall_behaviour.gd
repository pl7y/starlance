@tool
extends DeathBehaviour
class_name FallBehaviour

@export var duration: float = 0.35
@export var drop_distance: float = 20.0
@export var forward_drift: float = 8.0

@export var explosion_scene: PackedScene

func execute(creature: Enemy) -> void:
  var end_pos: Vector3 = creature.world_pos
  end_pos.y = 0
  end_pos.z += forward_drift

  var tween := creature.create_tween()
  tween.set_parallel(true)
  tween.tween_property(creature, "world_pos", end_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
  tween.finished.connect((func(c: Enemy) -> void:
    if explosion_scene:
      var explosion: WorldObject = explosion_scene.instantiate()
      explosion.world_pos = c.world_pos
      if c.get_parent() != null:
        c.get_parent().add_child(explosion)

    creature.queue_free()
  ).bind(creature))
