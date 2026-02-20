@tool
extends DeathBehaviour
class_name ExplosionDeathBehaviour

@export var explosion_scene: PackedScene

func execute(creature: Enemy) -> void:
  var explosion: WorldObject = explosion_scene.instantiate()
  explosion.world_pos = creature.world_pos
  if creature.get_parent() != null:
    creature.get_parent().add_child(explosion)

  creature.queue_free()
