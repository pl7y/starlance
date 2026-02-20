## Rush follow movement style - rushes to a point ahead of camera, then orbits.
@tool
extends MovementStyle
class_name RushFollowMovementStyle

@export var follow_distance: float = 30.0
@export var rush_turn: float = 4.0
@export var orbit_radius: float = 6.0
@export var orbit_speed: float = 1.5

func create_strategy() -> MovementStrategy:
	var strategy := RushFollowMovementStrategy.new()
	strategy.follow_distance = follow_distance
	strategy.rush_turn = rush_turn
	strategy.orbit_radius = orbit_radius
	strategy.orbit_speed = orbit_speed
	return _apply_shared_settings(strategy)
