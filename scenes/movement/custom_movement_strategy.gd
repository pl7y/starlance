## Custom movement strategy - delegates to a MoveLogic resource.
extends MovementStrategy
class_name CustomMovementStrategy

var custom_logic: MoveLogic

func setup(enemy: Node, rig: CameraRig) -> void:
	_setup_z_lock(rig)
	if custom_logic != null:
		custom_logic.setup(enemy, rig)

func update(enemy: Node, rig: CameraRig, delta: float) -> void:
	if custom_logic != null:
		custom_logic.update(enemy, rig, delta)
	_apply_z_lock(enemy, rig)
