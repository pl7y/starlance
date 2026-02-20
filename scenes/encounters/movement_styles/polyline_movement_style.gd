## Polyline movement style - follows an authored sequence of points.
@tool
extends MovementStyle
class_name PolylineMovementStyle

const POLYLINE_MOVEMENT_STRATEGY_SCRIPT := preload("res://scenes/movement/polyline_movement_strategy.gd")

enum Cycle {NONE, LOOP, PING_PONG}
enum PathOriginMode {ENCOUNTER, SPAWN}

## Points interpreted as local offsets from the enemy spawn position.
@export var points: PackedVector3Array = PackedVector3Array()

## If true, appends first point at the end before cycling logic.
@export var close: bool = false

## How movement continues after reaching the end.
@export var cycle: Cycle = Cycle.NONE

## Units per second along the polyline path.
@export_range(0.0, 2000.0, 1.0) var speed: float = 40.0

## Coordinate space of polyline points.
## ENCOUNTER: points relative to SpawnEvent.world_pos.
## SPAWN: points relative to each enemy spawn point.
@export var path_origin_mode: PathOriginMode = PathOriginMode.SPAWN


func create_strategy() -> MovementStrategy:
	var strategy: MovementStrategy = POLYLINE_MOVEMENT_STRATEGY_SCRIPT.new()
	strategy.points = points
	strategy.close = close
	strategy.speed = speed
	strategy.cycle = _to_strategy_cycle(cycle)
	strategy.path_origin_mode = _to_strategy_path_origin_mode(path_origin_mode)
	return _apply_shared_settings(strategy)


func _to_strategy_cycle(value: Cycle) -> int:
	match value:
		Cycle.LOOP:
			return 1
		Cycle.PING_PONG:
			return 2
		_:
			return 0


func _to_strategy_path_origin_mode(value: PathOriginMode) -> int:
	match value:
		PathOriginMode.ENCOUNTER:
			return 0
		_:
			return 1
