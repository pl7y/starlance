## Orchestrates procedural stage generation.
##
## Takes a StageTemplate (skeleton), an EncounterPool (content), and a
## DifficultyProfile (curves), then outputs an Array[Encounter] ready to
## be fed into StageDirector.segments.
##
## Pipeline:
##   1. Walk template slots
##   2. For each COMBAT slot → draw from EncounterDeck matching constraints
##   3. For each FIXED slot  → use the slot's fixed_encounter directly
##   4. For each BREATHER slot → generate an empty breather encounter
##   5. Apply difficulty mutations based on slot position + curves
##   6. Run RhythmSpacer to insert auto-breathers between adjacent combat slots
##   7. Return the final segment array
##
## This is a runtime utility class — not a Node or Resource.
class_name StageBuilder

# ── Build result ─────────────────────────────────────────────────────────────

## Returned by build() with the segment array and metadata.
class BuildResult:
	var segments: Array[Encounter] = []
	var seed_used: int = 0
	var slots_filled: int = 0
	var slots_skipped: int = 0
	var breathers_inserted: int = 0

# ── Configuration ────────────────────────────────────────────────────────────

var template: StageTemplate
var pool: EncounterPool
var profile: DifficultyProfile

## Minimum breather gap between adjacent combat encounters (distance/seconds).
var min_gap: float = 2.0
## Maximum breather gap.
var max_gap: float = 6.0
## If true, the spacer inserts breathers between adjacent combat encounters
## even if the template doesn't have explicit BREATHER slots between them.
var auto_breathers: bool = true
## How many recent draws to remember for repeat prevention.
var history_limit: int = 3

var _rng: RandomNumberGenerator
var _deck: EncounterDeck


func _init(
	p_template: StageTemplate,
	p_pool: EncounterPool,
	p_profile: DifficultyProfile = null,
	p_rng: RandomNumberGenerator = null
) -> void:
	template = p_template
	pool = p_pool
	profile = p_profile
	_rng = p_rng if p_rng != null else RandomNumberGenerator.new()


## Build the stage segments from the template + pool.
## Returns a BuildResult with the segments array and stats.
func build(run_seed: int = 0) -> BuildResult:
	var result := BuildResult.new()

	# Seed
	if run_seed != 0:
		_rng.seed = run_seed
	else:
		_rng.randomize()
	result.seed_used = _rng.seed

	# Create deck from pool
	_deck = EncounterDeck.new(pool, _rng, history_limit)
	_deck.refill()

	var segments: Array[Encounter] = []
	var combat_indices: Array[int] = [] # track where combat encounters land
	var total_slots := template.slots.size()

	# ── Walk slots ───────────────────────────────────────────────────────
	for slot_idx in total_slots:
		var slot := template.slots[slot_idx]
		if slot == null:
			continue

		var progress := float(slot_idx) / float(maxi(total_slots - 1, 1))

		match slot.role:
			SlotDefinition.Role.COMBAT:
				var enc := _fill_combat_slot(slot, progress)
				if enc != null:
					combat_indices.append(segments.size())
					segments.append(enc)
					result.slots_filled += 1
				else:
					result.slots_skipped += 1

			SlotDefinition.Role.FIXED:
				var enc := _fill_fixed_slot(slot)
				if enc != null:
					segments.append(enc)
					result.slots_filled += 1
				else:
					result.slots_skipped += 1

			SlotDefinition.Role.BREATHER:
				var enc := _fill_breather_slot(slot, progress)
				segments.append(enc)
				result.slots_filled += 1

	# ── Auto-breathers ───────────────────────────────────────────────────
	if auto_breathers and combat_indices.size() > 1:
		var spacer := RhythmSpacer.new(_rng, profile, min_gap, max_gap)
		var before := segments.size()
		spacer.insert_breathers(segments, total_slots, combat_indices)
		result.breathers_inserted = segments.size() - before

	result.segments = segments
	return result


# ── Slot filling ─────────────────────────────────────────────────────────────

func _fill_combat_slot(slot: SlotDefinition, progress: float) -> Encounter:
	var enc := _deck.draw(
		slot.required_tags,
		slot.excluded_tags,
		slot.min_tier,
		slot.max_tier,
		slot.allow_repeat
	)

	if enc == null:
		if not slot.optional:
			push_warning("StageBuilder: no match for combat slot (tags=%s, tier=%d-%d)" % [
				str(slot.required_tags), slot.min_tier, slot.max_tier])
		return null

	# Deep-duplicate so mutations don't affect the pool's originals
	enc = enc.duplicate(true)

	# Apply duration override
	if slot.duration_override > 0.0:
		enc.duration = slot.duration_override

	# Apply difficulty mutations
	if profile != null:
		_mutate_encounter(enc, progress)

	return enc


func _fill_fixed_slot(slot: SlotDefinition) -> Encounter:
	if slot.fixed_encounter == null:
		push_warning("StageBuilder: FIXED slot has no fixed_encounter set.")
		return null
	# Duplicate so runtime mutations don't affect the authored resource
	var enc := slot.fixed_encounter.duplicate(true) as Encounter
	if slot.duration_override > 0.0:
		enc.duration = slot.duration_override
	return enc


func _fill_breather_slot(slot: SlotDefinition, progress: float) -> Encounter:
	var duration := slot.breather_duration
	if profile != null:
		duration *= profile.sample(&"breather", progress)
	duration = maxf(duration, 1.0)

	var enc := Encounter.new()
	enc.id = "breather_%d" % _rng.randi()
	enc.display_name = "Breather"
	enc.duration = duration
	enc.tags = PackedStringArray(["breather"])
	return enc


# ── Difficulty mutations ─────────────────────────────────────────────────────

## Mutate an encounter's SpawnEvents based on the difficulty profile at the
## given progress point.
func _mutate_encounter(enc: Encounter, progress: float) -> void:
	var scales := profile.sample_all(progress)

	for ev in enc.events:
		if ev == null:
			continue
		if ev is SpawnEvent:
			_mutate_spawn_event(ev as SpawnEvent, scales)


func _mutate_spawn_event(ev: SpawnEvent, scales: Dictionary) -> void:
	# Scale HP
	if ev.hp > 0:
		ev.hp = maxi(roundi(float(ev.hp) * scales[&"hp"]), 1)

	# Scale spawn count
	var count_mult: float = scales[&"spawn_count"]
	if count_mult != 1.0:
		ev.count = maxi(roundi(float(ev.count) * count_mult), 1)

	# Scale move style speed
	if ev.move_style != null:
		ev.move_style = ev.move_style.duplicate() as MovementStyle
		ev.move_style.speed_x *= scales[&"speed"]
		ev.move_style.speed_z *= scales[&"speed"]

	# Scale pattern fire rate
	if ev.pattern != null:
		ev.pattern = ev.pattern.duplicate() as Pattern
		var fr: float = scales[&"fire_rate"]
		if fr > 0.0:
			ev.pattern.fire_interval = maxf(ev.pattern.fire_interval / fr, 0.1)
