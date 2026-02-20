## Fires an arbitrary Godot signal name on the EncounterRunner.
## Allows the encounter timeline to trigger game-specific hooks
## without the DSL knowing about them.
@tool
extends EncounterEvent
class_name SignalEvent

## The signal name to emit on the runner (must exist as a user signal).
@export var signal_name: String = ""

## Optional argument passed with the signal.
@export var argument: String = ""
