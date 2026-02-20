@tool
extends DeathBehaviour
class_name AscendBehavior

@export var duration: float = 0.35
@export var rise_distance: float = 24.0
@export var backward_drift: float = 10.0

func execute(creature: Enemy) -> void:
	var end_pos: Vector3 = creature.world_pos
	end_pos.y += rise_distance
	end_pos.z -= backward_drift

	var tween := creature.create_tween()
	tween.set_parallel(true)
	tween.tween_property(creature, "world_pos", end_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(creature, "modulate:a", 0.0, duration)
	tween.finished.connect(func() -> void:
		creature.queue_free()
	)
