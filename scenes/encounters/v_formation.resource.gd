## V formation: units alternate left and right while stepping forward.
@tool
extends Formation
class_name VFormation

## Horizontal and depth spacing between units.
@export var spacing: Vector2 = Vector2(5.0, 3.0)


func get_offsets(count: int, _rng: RandomNumberGenerator = null) -> Array[Vector2]:
  var offsets: Array[Vector2] = []
  for i in count:
    var side := 1.0 if i % 2 == 0 else -1.0
    @warning_ignore("INTEGER_DIVISION")
    var depth := int(i / 2)
    offsets.append(Vector2(side * depth * spacing.x, depth * spacing.y))
  return offsets
