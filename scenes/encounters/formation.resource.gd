## Base class: describes how a group of enemies is arranged spatially.
## Subclass this to implement different formation strategies.
@tool
@icon("res://icon.svg")
extends Resource
class_name Formation

## Returns an Array[Vector2] of local offsets for `count` units.
## Override this in subclasses to define formation behavior.
func get_offsets(count: int, _rng: RandomNumberGenerator = null) -> Array[Vector2]:
  var offsets: Array[Vector2] = []
  for i in count:
    offsets.append(Vector2.ZERO)
  return offsets
