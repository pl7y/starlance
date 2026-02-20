## Bounce movement strategy - oscillates vertically while moving toward a target mode.
extends MovementStrategy
class_name BounceMovementStrategy

enum Target {PLAYER, DIRECTION}

var target: Target = Target.PLAYER

## Travel speed along target direction.
var speed: float = 18.0

## Vertical bounce amplitude in world units.
var bounce_amplitude: float = 4.0

## Bounce duration in seconds.
var bounce_duration: float = 0.83

## Seconds spent on ground between bounces.
var pause: float = 0.0

## Used when target == DIRECTION.
var direction: Vector3 = Vector3(0.0, 0.0, 1.0)

var _age: float = 0.0
var _base_y: float = 0.0
var _player: Node = null


func setup(enemy: Node, rig: CameraRig) -> void:
	_age = 0.0
	_base_y = enemy.world_pos.y
	_player = enemy.get_tree().get_first_node_in_group("player")
	_setup_z_lock(rig)


func update(enemy: Node, rig: CameraRig, delta: float) -> void:
	_age += delta

	var move_dir := _resolve_move_direction(enemy)
	enemy.world_pos += move_dir * speed * delta

	# Gravity-like parabolic bounce: touches ground at phase 0 and 1,
	# reaches apex at phase 0.5.
	var bounce := 0.0
	if bounce_duration > 0.0:
		var active_duration := bounce_duration
		var cycle_duration := active_duration + maxf(pause, 0.0)
		var cycle_time := fposmod(_age, cycle_duration)
		if cycle_time < active_duration:
			var phase := cycle_time / active_duration
			bounce = 4.0 * phase * (1.0 - phase) # 0..1 parabola
	enemy.world_pos.y = _base_y + bounce * bounce_amplitude

	_apply_z_lock(enemy, rig)


func _resolve_move_direction(enemy: Node) -> Vector3:
	if target == Target.PLAYER and _player != null and "world_pos" in _player:
		var to_player: Vector3 = _player.world_pos - enemy.world_pos
		to_player.y = 0.0
		if to_player.length_squared() > 0.0001:
			return to_player.normalized()

	var axis := direction
	axis.y = 0.0
	if axis.length_squared() <= 0.0001:
		return Vector3(0.0, 0.0, 1.0)
	return axis.normalized()
