## Weighted bag-without-replacement for encounter selection.
## Draws encounters from a pool, only refilling the bag when empty.
## Prevents repeats within a cycle while still respecting weights.
##
## This is a runtime helper — not a Resource.  StageBuilder creates one
## per pool when building a stage.
class_name EncounterDeck

var _pool: EncounterPool
var _rng: RandomNumberGenerator
var _bag: Array[EncounterPoolEntry] = []
var _history: PackedStringArray = PackedStringArray()
var _history_limit: int = 3


func _init(pool: EncounterPool, rng: RandomNumberGenerator, history_limit: int = 3) -> void:
	_pool = pool
	_rng = rng
	_history_limit = history_limit


## Draw an encounter matching the given constraints.
## Returns null if no match exists even after a refill attempt.
func draw(
	required_tags: PackedStringArray = PackedStringArray(),
	excluded_tags: PackedStringArray = PackedStringArray(),
	min_tier: int = 0,
	max_tier: int = 0,
	allow_repeat: bool = false
) -> Encounter:
	# Build exclude list from recent history (unless repeats allowed)
	var exclude_ids := PackedStringArray()
	if not allow_repeat:
		exclude_ids = _history.duplicate()

	# Try drawing from the current bag first
	var result := _try_draw_from_bag(required_tags, excluded_tags, min_tier, max_tier, exclude_ids)
	if result != null:
		_record(result)
		return result.encounter

	# Bag exhausted — refill and try once more
	_refill()
	result = _try_draw_from_bag(required_tags, excluded_tags, min_tier, max_tier, exclude_ids)
	if result != null:
		_record(result)
		return result.encounter

	# Still nothing — relax repeat constraint as last resort
	if not allow_repeat and not exclude_ids.is_empty():
		_refill()
		result = _try_draw_from_bag(required_tags, excluded_tags, min_tier, max_tier, PackedStringArray())
		if result != null:
			_record(result)
			return result.encounter

	return null


## Peek at how many entries remain in the current bag.
func remaining() -> int:
	return _bag.size()


## Force a refill of the bag from the pool.
func refill() -> void:
	_refill()


## Clear draw history (e.g. between stage phases).
func reset_history() -> void:
	_history.resize(0)


# ── Internal ─────────────────────────────────────────────────────────────────

func _refill() -> void:
	_bag.clear()
	for entry in _pool.entries:
		if entry != null and entry.encounter != null:
			_bag.append(entry)


func _try_draw_from_bag(
	required_tags: PackedStringArray,
	excluded_tags: PackedStringArray,
	min_tier: int,
	max_tier: int,
	exclude_ids: PackedStringArray
) -> EncounterPoolEntry:
	# Filter bag to candidates
	var candidates: Array[EncounterPoolEntry] = []
	var candidate_indices: Array[int] = []

	for i in _bag.size():
		var entry := _bag[i]
		if _matches(entry, required_tags, excluded_tags, min_tier, max_tier, exclude_ids):
			candidates.append(entry)
			candidate_indices.append(i)

	if candidates.is_empty():
		return null

	# Weighted random selection
	var total_weight := 0.0
	for c in candidates:
		total_weight += c.weight

	var roll := _rng.randf() * total_weight
	var cumulative := 0.0

	for idx in candidates.size():
		cumulative += candidates[idx].weight
		if roll <= cumulative:
			# Remove from bag (no replacement within cycle)
			var bag_idx := candidate_indices[idx]
			_bag.remove_at(bag_idx)
			return candidates[idx]

	# Fallback (floating-point edge case)
	var last_bag_idx := candidate_indices[candidates.size() - 1]
	_bag.remove_at(last_bag_idx)
	return candidates[candidates.size() - 1]


func _matches(
	entry: EncounterPoolEntry,
	required_tags: PackedStringArray,
	excluded_tags: PackedStringArray,
	min_tier: int,
	max_tier: int,
	exclude_ids: PackedStringArray
) -> bool:
	if entry == null or entry.encounter == null:
		return false

	if min_tier > 0 and entry.tier < min_tier:
		return false
	if max_tier > 0 and entry.tier > max_tier:
		return false

	for tag in required_tags:
		if not entry.has_tag(tag):
			return false

	for tag in excluded_tags:
		if entry.has_tag(tag):
			return false

	if exclude_ids.has(entry.encounter.id):
		return false

	return true


func _record(entry: EncounterPoolEntry) -> void:
	if entry.encounter == null:
		return
	_history.append(entry.encounter.id)
	while _history.size() > _history_limit:
		_history.remove_at(0)
