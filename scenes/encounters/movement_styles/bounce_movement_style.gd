## Bounce movement style - moves toward a target while bouncing up/down.
@tool
extends MovementStyle
class_name BounceMovementStyle

const BOUNCE_MOVEMENT_STRATEGY_SCRIPT := preload("res://scenes/movement/bounce_movement_strategy.gd")

enum Target {PLAYER, DIRECTION}

## Bounce movement target mode.
@export var target: Target = Target.PLAYER

## Travel speed along the target direction.
@export var speed: float = 18.0

## Vertical bounce amplitude in world units.
@export var bounce_amplitude: float = 4.0

## Bounce duration in seconds.
@export_range(0.01, 10.0, 0.01) var bounce_duration: float = 0.83

## Seconds spent on ground between bounces.
@export_range(0.0, 10.0, 0.01) var pause: float = 0.0

## Direction used when target == DIRECTION.
@export var direction: Vector3 = Vector3(0.0, 0.0, 1.0)


func create_strategy() -> MovementStrategy:
	var strategy: MovementStrategy = BOUNCE_MOVEMENT_STRATEGY_SCRIPT.new()
	strategy.target = _to_strategy_target(target)
	strategy.speed = speed
	strategy.bounce_amplitude = bounce_amplitude
	strategy.bounce_duration = bounce_duration
	strategy.pause = pause
	strategy.direction = direction
	return _apply_shared_settings(strategy)


func _to_strategy_target(value: Target) -> int:
	match value:
		Target.DIRECTION:
			return 1
		_:
			return 0
