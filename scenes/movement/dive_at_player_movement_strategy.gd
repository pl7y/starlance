## Dive at player movement strategy - smoothly homes towards camera position.
extends MovementStrategy
class_name DiveAtPlayerMovementStrategy

var speed_z: float = 12.0
var dive_turn: float = 2.5

func update(enemy: Node, rig: CameraRig, delta: float) -> void:
	enemy.world_pos.z += speed_z * delta
	
	var target_x := rig.camera_world_position.x
	var target_y := rig.camera_world_position.y
	enemy.world_pos.x = lerp(enemy.world_pos.x, target_x, 1.0 - exp(-dive_turn * delta))
	enemy.world_pos.y = lerp(enemy.world_pos.y, target_y, 1.0 - exp(-dive_turn * delta))
	_apply_z_lock(enemy, rig)
