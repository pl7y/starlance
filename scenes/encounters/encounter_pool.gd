## A curated pool of encounter entries with weighted selection.
## Used by EncounterDeck / StageBuilder to draw encounters that match
## slot constraints.
@tool
extends Resource
class_name EncounterPool

## Human-readable pool name (e.g. "Forest — All Encounters").
@export var display_name: String = ""

## All available encounters with their weights and metadata.
@export var entries: Array[EncounterPoolEntry] = []

## Tags applied to the entire pool (biome, difficulty bracket, etc.).
@export var tags: PackedStringArray = PackedStringArray()


## Query the pool for entries matching the given constraints.
## Returns a filtered Array[EncounterPoolEntry].
##
## [param required_tags]  — entry must have ALL of these.
## [param excluded_tags]  — entry must have NONE of these.
## [param min_tier]       — minimum tier (0 = no lower bound).
## [param max_tier]       — maximum tier (0 = no upper bound).
## [param exclude_ids]    — encounter IDs to skip (for repeat prevention).
func query(
	required_tags: PackedStringArray = PackedStringArray(),
	excluded_tags: PackedStringArray = PackedStringArray(),
	min_tier: int = 0,
	max_tier: int = 0,
	exclude_ids: PackedStringArray = PackedStringArray()
) -> Array[EncounterPoolEntry]:
	var result: Array[EncounterPoolEntry] = []

	for entry in entries:
		if entry == null or entry.encounter == null:
			continue

		# Tier filter
		if min_tier > 0 and entry.tier < min_tier:
			continue
		if max_tier > 0 and entry.tier > max_tier:
			continue

		# Required tags — entry must have ALL
		var tags_ok := true
		for tag in required_tags:
			if not entry.has_tag(tag):
				tags_ok = false
				break
		if not tags_ok:
			continue

		# Excluded tags — entry must have NONE
		var excluded := false
		for tag in excluded_tags:
			if entry.has_tag(tag):
				excluded = true
				break
		if excluded:
			continue

		# Repeat prevention
		if exclude_ids.has(entry.encounter.id):
			continue

		result.append(entry)

	return result


## Convenience: get all unique encounter IDs in the pool.
func all_encounter_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for entry in entries:
		if entry != null and entry.encounter != null:
			if not ids.has(entry.encounter.id):
				ids.append(entry.encounter.id)
	return ids


## Total number of valid (non-null) entries.
func valid_count() -> int:
	var n := 0
	for entry in entries:
		if entry != null and entry.encounter != null:
			n += 1
	return n
