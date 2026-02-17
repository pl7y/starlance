## Curve-based difficulty scaling profile.
## Maps normalised stage progress (0.0 → 1.0) to multipliers for various
## gameplay parameters.  StageBuilder reads these when mutating encounters
## to fit their position in the stage.
@tool
extends Resource
class_name DifficultyProfile

## Human-readable name (e.g. "Normal", "Nightmare").
@export var display_name: String = ""

## ── Curve exports ───────────────────────────────────────────────────────────
## Each Curve maps X = normalised progress [0..1] → Y = multiplier.
## Leave null to use the fallback scalar instead.

## Enemy HP multiplier over the stage.
@export var hp_curve: Curve

## Enemy fire-rate multiplier over the stage.
@export var fire_rate_curve: Curve

## Spawn count multiplier (rounds to int).
@export var spawn_count_curve: Curve

## Enemy speed multiplier.
@export var speed_curve: Curve

## Breather duration multiplier (lower = shorter breathers later).
@export var breather_curve: Curve

## Overall intensity / pressure value for custom systems.
@export var intensity_curve: Curve

## ── Fallback scalars ────────────────────────────────────────────────────────
## Used when the corresponding curve is null.

@export var hp_scalar: float = 1.0
@export var fire_rate_scalar: float = 1.0
@export var spawn_count_scalar: float = 1.0
@export var speed_scalar: float = 1.0
@export var breather_scalar: float = 1.0
@export var intensity_scalar: float = 1.0


## Sample a named parameter at the given normalised progress.
## Returns the curve value if the curve exists, otherwise the scalar fallback.
func sample(param: StringName, progress: float) -> float:
	progress = clampf(progress, 0.0, 1.0)
	match param:
		&"hp":
			return hp_curve.sample(progress) if hp_curve != null else hp_scalar
		&"fire_rate":
			return fire_rate_curve.sample(progress) if fire_rate_curve != null else fire_rate_scalar
		&"spawn_count":
			return spawn_count_curve.sample(progress) if spawn_count_curve != null else spawn_count_scalar
		&"speed":
			return speed_curve.sample(progress) if speed_curve != null else speed_scalar
		&"breather":
			return breather_curve.sample(progress) if breather_curve != null else breather_scalar
		&"intensity":
			return intensity_curve.sample(progress) if intensity_curve != null else intensity_scalar
		_:
			push_warning("DifficultyProfile: unknown param '%s'" % param)
			return 1.0


## Convenience: sample all params at once into a Dictionary.
func sample_all(progress: float) -> Dictionary:
	return {
		&"hp": sample(&"hp", progress),
		&"fire_rate": sample(&"fire_rate", progress),
		&"spawn_count": sample(&"spawn_count", progress),
		&"speed": sample(&"speed", progress),
		&"breather": sample(&"breather", progress),
		&"intensity": sample(&"intensity", progress),
	}
