## Marks the beginning of a named phase inside an encounter.
## Downstream systems can read the active phase to adjust music,
## background scroll speed, HUD state, etc.
@tool
extends EncounterEvent
class_name PhaseEvent

## Human-readable phase label (e.g. "approach", "assault", "retreat").
@export var phase_name: String = ""
