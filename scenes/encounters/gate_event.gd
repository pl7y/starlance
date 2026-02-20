## Declarative gate: pauses encounter progression until a condition is met.
## The EncounterRunner emits gate_entered / gate_cleared signals so that
## StageDirector can pause/resume the rail accordingly (Pattern A+B).
@tool
extends EncounterEvent
class_name GateEvent

## How the gate decides it's been cleared.
enum Condition {
	## All enemies currently alive in the "enemies" group must be dead.
	ALL_ENEMIES_DEAD,
	## The enemies spawned since the previous gate (or encounter start) must be dead.
	WAVE_ENEMIES_DEAD,
	## Wait a fixed number of seconds after entering the gate.
	TIMER,
	## A named signal/flag must be set externally (boss died, trigger hit, etc.).
	CUSTOM,
}

## Which condition clears this gate.
@export var condition: Condition = Condition.ALL_ENEMIES_DEAD

## For TIMER condition — how many seconds to hold.
@export var hold_time: float = 3.0

## For CUSTOM condition — the key the runner checks via set_gate_flag().
@export var custom_key: String = ""

## Optional label shown in debug / HUD (e.g. "Clear this wave!").
@export var label: String = ""
