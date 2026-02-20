## Drift movement strategy - constant velocity in all axes.
extends MovementStrategy
class_name DriftMovementStrategy

var speed_x: float = 0.0
var speed_y: float = 0.0
var speed_z: float = 12.0

func update(enemy: Node, rig: CameraRig, delta: float) -> void:
	enemy.world_pos.x += speed_x * delta
	enemy.world_pos.y += speed_y * delta
	enemy.world_pos.z += speed_z * delta
	_apply_z_lock(enemy, rig)
