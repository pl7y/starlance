## Circle formation: units are arranged around a radius.
@tool
extends Formation
class_name CircleFormation

## Radius of the circle.
@export var radius: float = 6.0


func get_offsets(count: int, _rng: RandomNumberGenerator = null) -> Array[Vector2]:
  var offsets: Array[Vector2] = []
  if count == 1:
    offsets.append(Vector2.ZERO)
    return offsets

  for i in count:
    var angle := TAU * float(i) / float(count)
    offsets.append(Vector2(cos(angle), sin(angle)) * radius)
  return offsets
