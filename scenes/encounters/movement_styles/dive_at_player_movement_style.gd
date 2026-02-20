## Dive at player movement style - smoothly homes towards camera position.
@tool
extends MovementStyle
class_name DiveAtPlayerMovementStyle

@export var speed_z: float = 12.0
@export var dive_turn: float = 2.5

func create_strategy() -> MovementStrategy:
	var strategy := DiveAtPlayerMovementStrategy.new()
	strategy.speed_z = speed_z
	strategy.dive_turn = dive_turn
	return _apply_shared_settings(strategy)
