## Inserts breather gaps between combat encounters based on difficulty curves
## and rhythm rules.
##
## The spacer operates on an already-built segment list, inserting empty
## breather Encounters (no events, just duration) where needed.
## This is a runtime helper, not a Resource.
class_name RhythmSpacer

## ── Configuration ───────────────────────────────────────────────────────────

## Minimum gap duration (seconds / distance units) between combat encounters.
var min_gap: float = 2.0

## Maximum gap duration before the difficulty profile scales it down.
var max_gap: float = 6.0

## If true, always insert a breather after encounter slots even if the
## template already has explicit BREATHER slots.
var force_breathers: bool = false

var _rng: RandomNumberGenerator
var _profile: DifficultyProfile


func _init(rng: RandomNumberGenerator, profile: DifficultyProfile = null,
		p_min_gap: float = 2.0, p_max_gap: float = 6.0) -> void:
	_rng = rng
	_profile = profile
	min_gap = p_min_gap
	max_gap = p_max_gap


## Process a flat list of segments and insert breather encounters where
## two combat encounters sit back-to-back.
##
## [param segments]        — the built segment list (mutated in place).
## [param total_slots]     — total slot count (used for progress normalisation).
## [param combat_indices]  — indices in `segments` that are combat encounters.
func insert_breathers(
	segments: Array[Encounter],
	total_slots: int,
	combat_indices: Array[int]
) -> void:
	if combat_indices.size() < 2:
		return

	# Work backwards so insertions don't shift indices
	var insert_count := 0
	for i in range(combat_indices.size() - 1, 0, -1):
		var current_idx := combat_indices[i] + insert_count
		var prev_idx := combat_indices[i - 1] + insert_count

		# Check if there's already a breather between these two combat slots
		if current_idx - prev_idx > 1:
			continue

		# Calculate progress at this point in the stage
		var progress := float(i) / float(maxi(total_slots, 1))

		# Calculate gap duration
		var gap := _calculate_gap(progress)

		# Create breather encounter
		var breather := _make_breather(gap)

		# Insert after the previous combat encounter
		segments.insert(prev_idx + 1, breather)
		insert_count += 1


## Calculate gap duration scaled by difficulty profile and jitter.
func _calculate_gap(progress: float) -> float:
	var base_gap := lerpf(max_gap, min_gap, progress)

	# Apply difficulty curve scaling if available
	if _profile != null:
		var breather_mult := _profile.sample(&"breather", progress)
		base_gap *= breather_mult

	# Add small random jitter (±15%)
	var jitter := _rng.randf_range(-0.15, 0.15)
	base_gap *= (1.0 + jitter)

	return clampf(base_gap, min_gap, max_gap)


## Create an empty encounter that acts as a breather gap.
func _make_breather(duration: float) -> Encounter:
	var enc := Encounter.new()
	enc.id = "breather_%d" % _rng.randi()
	enc.display_name = "Breather"
	enc.duration = duration
	enc.tags = PackedStringArray(["breather", "auto_generated"])
	# No events — just empty time / distance for the player to breathe
	return enc
