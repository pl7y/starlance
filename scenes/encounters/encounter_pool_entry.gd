## One weighted entry in an EncounterPool.
## Wraps an Encounter resource with selection metadata.
@tool
extends Resource
class_name EncounterPoolEntry

## The encounter this entry refers to.
@export var encounter: Encounter

## Base selection weight (higher = more likely to be drawn).
@export_range(0.1, 100.0) var weight: float = 1.0

## Difficulty tier.  Used by SlotDefinition min/max_tier constraints.
@export_range(0, 10) var tier: int = 1

## Tags for pool queries (in addition to the encounter's own tags).
## Pool-level tags let you override/supplement encounter tags without
## editing the encounter resource itself.
@export var extra_tags: PackedStringArray = PackedStringArray()


## Returns true if this entry's effective tags contain `tag`.
func has_tag(tag: String) -> bool:
	if extra_tags.has(tag):
		return true
	if encounter != null and encounter.tags.has(tag):
		return true
	return false


## Returns the combined tag set (encounter tags + extra_tags).
func effective_tags() -> PackedStringArray:
	var result := PackedStringArray()
	if encounter != null:
		result.append_array(encounter.tags)
	for t in extra_tags:
		if not result.has(t):
			result.append(t)
	return result
