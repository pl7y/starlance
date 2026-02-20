## Orbit movement strategy - orbits around camera position.
extends MovementStrategy
class_name OrbitMovementStrategy

var speed_z: float = 12.0
var orbit_radius: float = 6.0
var orbit_speed: float = 1.5

var _orbit_angle: float = 0.0

func setup(_enemy: Node, _rig: CameraRig) -> void:
	_orbit_angle = randf_range(0.0, TAU)

func update(enemy: Node, rig: CameraRig, delta: float) -> void:
	enemy.world_pos.z += speed_z * delta
	_orbit_angle += orbit_speed * delta
	
	var cx := rig.camera_world_position.x
	var cy := rig.camera_world_position.y
	enemy.world_pos.x = cx + cos(_orbit_angle) * orbit_radius
	enemy.world_pos.y = cy + sin(_orbit_angle) * (orbit_radius * 0.6)
