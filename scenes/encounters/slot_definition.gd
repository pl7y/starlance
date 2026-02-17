## Describes one slot in a StageTemplate.
## Each slot pulls an encounter from the pool that matches its constraints.
@tool
extends Resource
class_name SlotDefinition

## ── Slot role ────────────────────────────────────────────────────────────────

## What kind of content this slot expects.
enum Role {
	## A combat encounter pulled from the pool.
	COMBAT,
	## An empty breather gap (auto-generated, no pool query).
	BREATHER,
	## A fixed encounter — always uses `fixed_encounter`.
	FIXED,
}

## Role of this slot in the stage rhythm.
@export var role: Role = Role.COMBAT

## ── Pool query constraints ──────────────────────────────────────────────────

## Tags the encounter MUST have (all must match).
@export var required_tags: PackedStringArray = PackedStringArray()

## Tags the encounter must NOT have.
@export var excluded_tags: PackedStringArray = PackedStringArray()

## Minimum difficulty tier (inclusive).  0 = any.
@export var min_tier: int = 0

## Maximum difficulty tier (inclusive).  0 = any.
@export var max_tier: int = 0

## ── Overrides ───────────────────────────────────────────────────────────────

## Duration override for the encounter placed here.  0 = use encounter default.
@export var duration_override: float = 0.0

## For FIXED role — the specific encounter to place.
@export var fixed_encounter: Encounter

## If true and no pool match is found, the builder skips the slot silently.
## If false and no match is found, the builder logs a warning and skips.
@export var optional: bool = false

## Allow the same encounter to appear again even if it was recently used.
@export var allow_repeat: bool = false

## ── Breather settings ───────────────────────────────────────────────────────

## Duration of the breather gap (only used when role == BREATHER).
@export var breather_duration: float = 3.0
