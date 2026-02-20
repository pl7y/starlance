## Sine strafe movement strategy - moves forward/back with sinusoidal horizontal motion.
extends MovementStrategy
class_name SineStrafMovementStrategy

var speed_z: float = 12.0
var amp_x: float = 4.0
var amp_y: float = 2.0
var freq: float = 1.2

var _spawn_pos: Vector3
var _age: float = 0.0

func setup(enemy: Node, _rig: CameraRig) -> void:
	_spawn_pos = enemy.world_pos
	_age = 0.0

func update(enemy: Node, _rig: CameraRig, delta: float) -> void:
	_age += delta
	enemy.world_pos.z += speed_z * delta
	enemy.world_pos.x = _spawn_pos.x + sin(_age * TAU * freq) * amp_x
	enemy.world_pos.y = _spawn_pos.y + sin(_age * TAU * (freq * 0.7)) * amp_y
