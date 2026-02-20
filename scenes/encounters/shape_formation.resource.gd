## Legacy shape selector formation.
## Prefer PointFormation, LineFormation, VFormation, GridFormation, CircleFormation.
## Kept for backward compatibility with existing resources.
@tool
extends Formation
class_name ShapeFormation

const POINT_FORMATION_SCRIPT := preload("res://scenes/encounters/point_formation.resource.gd")
const LINE_FORMATION_SCRIPT := preload("res://scenes/encounters/line_formation.resource.gd")
const V_FORMATION_SCRIPT := preload("res://scenes/encounters/v_formation.resource.gd")
const GRID_FORMATION_SCRIPT := preload("res://scenes/encounters/grid_formation.resource.gd")
const CIRCLE_FORMATION_SCRIPT := preload("res://scenes/encounters/circle_formation.resource.gd")

enum Shape {POINT, LINE, V, GRID, CIRCLE}

## The geometric shape of this formation.
@export var shape: Shape = Shape.POINT

## Spacing between units on the primary axis.
@export var spacing: Vector2 = Vector2(5.0, 3.0)

## Number of columns (for GRID shape).
@export var columns: int = 3

## Radius (for CIRCLE shape).
@export var radius: float = 6.0


func get_offsets(_count: int, _rng: RandomNumberGenerator = null) -> Array[Vector2]:
  return []
