## A named marker in the encounter timeline.
## Useful for UI cues, audio triggers, or phase transitions
## that don't spawn anything.
@tool
extends EncounterEvent
class_name MarkerEvent

## Arbitrary label for this marker (e.g. "warning_flash", "music_shift").
@export var marker_name: String = ""

## Optional key-value payload (parsed by listeners).
@export var payload: Dictionary = {}
