## Base class for death behavior resources.
##
## Assign a concrete subclass to creatures to define what happens on death.
@tool
extends Resource
class_name DeathBehaviour

func execute(_creature: Enemy) -> void:
	push_error("DeathBehaviour.execute() must be overridden in subclass")
