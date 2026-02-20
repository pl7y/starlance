## Drift movement style - constant velocity in all axes.
@tool
extends MovementStyle
class_name DriftMovementStyle

@export var speed_z: float = 12.0
@export var speed_x: float = 0.0
@export var speed_y: float = 0.0

func create_strategy() -> MovementStrategy:
	var strategy := DriftMovementStrategy.new()
	strategy.speed_z = speed_z
	strategy.speed_x = speed_x
	strategy.speed_y = speed_y
	return _apply_shared_settings(strategy)
