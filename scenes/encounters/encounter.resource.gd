## Top-level encounter resource.
## Contains metadata and an ordered timeline of EncounterEvent resources.
@tool
extends Resource
class_name Encounter

## Unique identifier for this encounter (used by progression / save system).
@export var id: String = ""

## Human-readable display name.
@export var display_name: String = ""

## Total duration in seconds. The runner stops after this even if events remain.
@export var duration: float = 30.0:
	set(v):
		duration = maxf(v, 0.1)

## Ordered list of events. Sorted by time on validate().
@export var events: Array[EncounterEvent] = []

## Freeform tags for biome filtering, difficulty tiers, etc.
@export var tags: PackedStringArray = PackedStringArray()

## Optional recommended seed (0 = let the runner pick one).
@export var seed_hint: int = 0


## Sort events by time ascending and clamp any negative times.
## Call this from the editor or at load-time.
func validate() -> void:
	for ev in events:
		if ev == null:
			continue
		ev.time = maxf(ev.time, 0.0)
	events.sort_custom(_by_time)


## Returns only events that carry the given tag.
func events_with_tag(tag: String) -> Array[EncounterEvent]:
	var result: Array[EncounterEvent] = []
	for ev in events:
		if ev != null and ev.has_tag(tag):
			result.append(ev)
	return result


## Returns the last event time (useful when duration is auto).
func last_event_time() -> float:
	if events.is_empty():
		return 0.0
	var t := 0.0
	for ev in events:
		if ev != null and ev.time > t:
			t = ev.time
	return t


static func _by_time(a: EncounterEvent, b: EncounterEvent) -> bool:
	if a == null:
		return true
	if b == null:
		return false
	return a.time < b.time
