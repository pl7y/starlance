## Grid formation: units are arranged in centered rows and columns.
@tool
extends Formation
class_name GridFormation

## Spacing between units on each axis.
@export var spacing: Vector2 = Vector2(5.0, 3.0)

## Number of columns in the grid.
@export var columns: int = 3


func get_offsets(count: int, _rng: RandomNumberGenerator = null) -> Array[Vector2]:
  var offsets: Array[Vector2] = []
  var cols := maxi(columns, 1)
  var rows := ceili(float(count) / cols)
  var ox := (cols - 1) * spacing.x * 0.5
  var oy := (rows - 1) * spacing.y * 0.5
  for i in count:
    var c := i % cols
    @warning_ignore("INTEGER_DIVISION")
    var r := int(i / cols)
    offsets.append(Vector2(c * spacing.x - ox, r * spacing.y - oy))
  return offsets
