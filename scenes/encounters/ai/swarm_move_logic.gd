## Swarm AI — boid-like flocking where enemies gravitate toward
## each other while also pursuing the player, creating an organic
## cloud of threats that shifts and breathes.
##
## Each enemy balances three forces:
##   - Cohesion:    steer toward the flock center
##   - Separation:  avoid getting too close to neighbors
##   - Chase:       gently home toward the player
##
## The result is a living swarm that flows around the player.
@tool
extends MoveLogic
class_name SwarmMoveLogic

## Weight of cohesion (pull toward flock center).
@export var cohesion_weight: float = 2.0

## Weight of separation (push away from nearby flock-mates).
@export var separation_weight: float = 3.0

## Minimum distance between flock members before separation kicks in.
@export var separation_radius: float = 8.0

## Weight of chase (pull toward player).
@export var chase_weight: float = 1.5

## Maximum speed (world units / second).
@export var max_speed: float = 60.0

## Forward drift speed (Z-axis, toward camera).
@export var drift_z: float = 30.0

## Velocity damping (0 = instant stop, 1 = no damping).
@export var damping: float = 0.92

# ── Instance state ───────────────────────────────────────────────────────────

var _velocity: Vector3 = Vector3.ZERO


func setup(_enemy: Node, _rig: CameraRig) -> void:
	_velocity = Vector3(randf_range(-10, 10), randf_range(-5, 5), drift_z)


func update(enemy: Node, _rig: CameraRig, delta: float) -> void:
	var flock := enemy.get_tree().get_nodes_in_group("enemies")
	var my_pos: Vector3 = enemy.world_pos

	# ── Cohesion: average position of all flock members ──
	var center := Vector3.ZERO
	var count := 0
	for other in flock:
		if other == enemy or other == null:
			continue
		if not "world_pos" in other:
			continue
		center += other.world_pos
		count += 1

	var cohesion_force := Vector3.ZERO
	if count > 0:
		center /= float(count)
		cohesion_force = (center - my_pos).normalized() * cohesion_weight

	# ── Separation: push away from neighbors that are too close ──
	var separation_force := Vector3.ZERO
	for other in flock:
		if other == enemy or other == null:
			continue
		if not "world_pos" in other:
			continue
		var diff: Vector3 = my_pos - other.world_pos
		var dist := diff.length()
		if dist < separation_radius and dist > 0.01:
			separation_force += diff.normalized() * (separation_radius - dist) / separation_radius

	separation_force *= separation_weight

	# ── Chase: gently pursue the player ──
	var chase_force := Vector3.ZERO
	var player: Node = enemy.get_tree().get_first_node_in_group("player")
	if player != null and "world_pos" in player:
		var to_player: Vector3 = player.world_pos - my_pos
		chase_force = to_player.normalized() * chase_weight

	# ── Combine forces ──
	var acceleration := cohesion_force + separation_force + chase_force

	# Always drift toward camera on Z
	acceleration.z += drift_z * 0.5

	_velocity += acceleration * delta
	_velocity *= damping

	# Clamp speed
	if _velocity.length() > max_speed:
		_velocity = _velocity.normalized() * max_speed

	enemy.world_pos += _velocity * delta
