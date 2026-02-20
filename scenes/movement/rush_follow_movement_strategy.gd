## Rush follow movement strategy - rushes to a point ahead of camera, then orbits.
## Phase 1: Rush toward a point `follow_distance` ahead of camera.
## Phase 2: Once arrived, orbit at that distance like an escort.
extends MovementStrategy
class_name RushFollowMovementStrategy

var follow_distance: float = 30.0
var rush_turn: float = 4.0
var orbit_radius: float = 6.0
var orbit_speed: float = 1.5

var _rush_arrived: bool = false
var _orbit_angle: float = 0.0

func setup(_enemy: Node, _rig: CameraRig) -> void:
	_rush_arrived = false
	_orbit_angle = randf_range(0.0, TAU)

func update(enemy: Node, rig: CameraRig, delta: float) -> void:
	var target_z := rig.camera_world_position.z - follow_distance
	var target_x := rig.camera_world_position.x
	var target_y := rig.camera_world_position.y
	
	if not _rush_arrived:
		# Approach phase — fast homing toward the lock-on point
		enemy.world_pos.z = lerp(enemy.world_pos.z, target_z, 1.0 - exp(-rush_turn * delta))
		enemy.world_pos.x = lerp(enemy.world_pos.x, target_x, 1.0 - exp(-rush_turn * delta))
		enemy.world_pos.y = lerp(enemy.world_pos.y, target_y, 1.0 - exp(-rush_turn * delta))
		
		# Check if close enough to transition
		var dist_sq: float = (enemy.world_pos - Vector3(target_x, target_y, target_z)).length_squared()
		if dist_sq < 4.0: # within ~2 world units
			_rush_arrived = true
	else:
		# Follow phase — orbit around the player at fixed Z offset
		_orbit_angle += orbit_speed * delta
		enemy.world_pos.z = lerp(enemy.world_pos.z, target_z, 1.0 - exp(-2.0 * delta)) # gently track Z
		enemy.world_pos.x = target_x + cos(_orbit_angle) * orbit_radius
		enemy.world_pos.y = target_y + sin(_orbit_angle) * (orbit_radius * 0.6)
