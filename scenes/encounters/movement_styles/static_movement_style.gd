## Static movement style - enemy stays in place.
@tool
extends "res://scenes/encounters/movement_styles/movement_style.gd"
class_name StaticMovementStyle

func create_strategy() -> MovementStrategy:
	return _apply_shared_settings(StaticMovementStrategy.new())
