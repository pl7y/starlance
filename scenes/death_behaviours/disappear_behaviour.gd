@tool
extends DeathBehaviour
class_name DisappearBehaviour

func execute(creature: Enemy) -> void:
	creature.queue_free()
