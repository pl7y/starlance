## Base class for enemy movement strategies.
##
## Each concrete strategy encapsulates a specific movement behavior.
## The Enemy delegates movement updates to the active strategy.
extends RefCounted
class_name MovementStrategy

var z_lock = MovementStyle.ZLock.NONE

var _z_lock_ready: bool = false
var _last_camera_z: float = 0.0

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


func _setup_z_lock(rig: CameraRig) -> void:
	_z_lock_ready = true
	_last_camera_z = rig.camera_world_position.z if rig != null else 0.0


func _apply_z_lock(enemy: Node, rig: CameraRig) -> void:
	if z_lock != MovementStyle.ZLock.PLAYER or rig == null:
		return

	if not _z_lock_ready:
		_setup_z_lock(rig)
		return

	var current_z := rig.camera_world_position.z
	var delta_z := current_z - _last_camera_z
	_last_camera_z = current_z
	enemy.world_pos.z += delta_z
