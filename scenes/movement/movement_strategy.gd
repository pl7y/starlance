## Base class for enemy movement strategies.
##
## Each concrete strategy encapsulates a specific movement behavior.
## The Enemy delegates movement updates to the active strategy.
extends RefCounted
class_name MovementStrategy

## Called once after the enemy is spawned and configured.
## Store references and initialize per-instance state here.
@warning_ignore("unused_parameter")
func setup(enemy: Node, rig: CameraRig) -> void:
	pass


## Called every _process frame. Move the enemy by writing to
## enemy.world_pos directly.
@warning_ignore("unused_parameter")
func update(enemy: Node, rig: CameraRig, delta: float) -> void:
	pass
