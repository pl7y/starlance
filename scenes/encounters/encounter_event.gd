## Base resource for all encounter events.
## Subclass this to define declarative event types (SpawnEvent, MarkerEvent, etc.).
@tool
extends Resource
class_name EncounterEvent

## Time in seconds (relative to encounter start) when this event fires.
@export var time: float = 0.0:
	set(v):
		time = maxf(v, 0.0)

## If false the runner skips this event entirely.
@export var enabled: bool = true

## Freeform tags for roguelite mutation / filtering (e.g. "elite", "biome:ice").
@export var tags: PackedStringArray = PackedStringArray()

## Returns true when the event carries the given tag.
func has_tag(tag: String) -> bool:
	return tags.has(tag)
