## Static movement style - enemy stays in place.
@tool
extends MovementStyle
class_name StaticMovementStyle

func create_strategy() -> MovementStrategy:
	return StaticMovementStrategy.new()
