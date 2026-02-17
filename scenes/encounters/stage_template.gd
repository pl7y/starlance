## Defines the macro-structure of a stage as a sequence of slots.
## Each slot is a SlotDefinition that the StageBuilder fills from an
## EncounterPool + EncounterDeck.
##
## Author several templates per biome / planet type, then let the
## StageBuilder pick encounters to fill them procedurally.
@tool
extends Resource
class_name StageTemplate

## Human-readable name for this template (e.g. "Forest — Standard Run").
@export var display_name: String = ""

## Ordered list of slots that define the stage skeleton.
@export var slots: Array[SlotDefinition] = []

## Tags for biome filtering / run modifier selection.
@export var tags: PackedStringArray = PackedStringArray()

## Target total distance budget for the stage.  0 = sum of slot durations.
@export var target_distance: float = 0.0


## Returns the number of combat slots in this template.
func combat_slot_count() -> int:
	var n := 0
	for s in slots:
		if s != null and s.role == SlotDefinition.Role.COMBAT:
			n += 1
	return n


## Returns the number of breather slots.
func breather_slot_count() -> int:
	var n := 0
	for s in slots:
		if s != null and s.role == SlotDefinition.Role.BREATHER:
			n += 1
	return n


## Returns all unique required tags across every combat slot.
func all_required_tags() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for s in slots:
		if s == null or s.role != SlotDefinition.Role.COMBAT:
			continue
		for t in s.required_tags:
			if not result.has(t):
				result.append(t)
	return result
