## Line formation: units are distributed evenly on the X axis.
@tool
extends Formation
class_name LineFormation

## Spacing between units on each axis. LINE uses spacing.x.
@export var spacing: Vector2 = Vector2(5.0, 0.0)


func get_offsets(count: int, _rng: RandomNumberGenerator = null) -> Array[Vector2]:
  var offsets: Array[Vector2] = []
  var half := (count - 1) * spacing.x * 0.5
  for i in count:
    offsets.append(Vector2(i * spacing.x - half, 0.0))
  return offsets
