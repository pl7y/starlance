## Static movement strategy - enemy stays in place.
extends MovementStrategy
class_name StaticMovementStrategy

func update(enemy: Node, rig: CameraRig, _delta: float) -> void:
	# No movement
	_apply_z_lock(enemy, rig)
