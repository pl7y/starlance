## Orbit movement style - orbits around camera position.
@tool
extends MovementStyle
class_name OrbitMovementStyle

@export var speed_z: float = 12.0
@export var orbit_radius: float = 6.0
@export var orbit_speed: float = 1.5

func create_strategy() -> MovementStrategy:
	var strategy := OrbitMovementStrategy.new()
	strategy.speed_z = speed_z
	strategy.orbit_radius = orbit_radius
	strategy.orbit_speed = orbit_speed
	return strategy
