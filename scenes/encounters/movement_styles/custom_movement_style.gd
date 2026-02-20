## Custom movement style - uses a MoveLogic resource for pluggable behavior.
@tool
extends MovementStyle
class_name CustomMovementStyle

@export var custom_logic: MoveLogic

func create_strategy() -> MovementStrategy:
	var strategy := CustomMovementStrategy.new()
	# Duplicate the logic so each enemy gets its own state
	if custom_logic != null:
		strategy.custom_logic = custom_logic.duplicate()
	return strategy
