## Point formation: all units spawn at the same origin offset.
@tool
extends Formation
class_name PointFormation


func get_offsets(count: int, _rng: RandomNumberGenerator = null) -> Array[Vector2]:
  var offsets: Array[Vector2] = []
  for i in count:
    offsets.append(Vector2.ZERO)
  return offsets
