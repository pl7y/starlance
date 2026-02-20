## Swoop movement style - readable arc that crosses center.
@tool
extends MovementStyle
class_name SwoopMovementStyle

@export var speed_z: float = 12.0
@export var amplitude: Vector2 = Vector2(4.0, 2.0)
@export var frequency: float = 1.2

func create_strategy() -> MovementStrategy:
	var strategy := SwoopMovementStrategy.new()
	strategy.speed_z = speed_z
	strategy.amp_x = amplitude.x
	strategy.amp_y = amplitude.y
	strategy.freq = frequency
	return _apply_shared_settings(strategy)
