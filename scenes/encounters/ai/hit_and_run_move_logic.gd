## HitAndRun AI — approaches the player, pauses to fire a burst,
## then retreats to safety.  Repeats in a rhythmic push/pull pattern
## that creates pressure windows the player can learn and punish.
##
## Phases:
##   1. APPROACH  — close in toward the player at medium speed
##   2. ATTACK    — hold position for a burst window (enemy fires normally)
##   3. RETREAT   — pull back to safe distance
##   4. REPOSITION — drift laterally before next approach
@tool
extends MoveLogic
class_name HitAndRunMoveLogic

enum Phase {APPROACH, ATTACK, RETREAT, REPOSITION}

## Z-distance from camera during the attack hold.
@export var attack_distance: float = 30.0

## Approach speed.
@export var approach_speed: float = 70.0

## Retreat speed.
@export var retreat_speed: float = 50.0

## How long to hold the attack position (seconds).
@export var attack_hold: float = 1.5

## How far to retreat (Z units away from attack distance).
@export var retreat_distance: float = 40.0

## How long to drift laterally during reposition.
@export var reposition_time: float = 1.0

## Lateral drift speed during reposition.
@export var reposition_speed: float = 40.0

# ── Instance state ───────────────────────────────────────────────────────────

var _phase: Phase = Phase.APPROACH
var _timer: float = 0.0
var _drift_dir: float = 1.0
var _target_x: float = 0.0


func setup(_enemy: Node, _rig: CameraRig) -> void:
	_phase = Phase.APPROACH
	_timer = 0.0
	_drift_dir = 1.0 if randf() > 0.5 else -1.0


func update(enemy: Node, rig: CameraRig, delta: float) -> void:
	_timer += delta
	var cam := rig.camera_world_position
	var target_z_attack := cam.z - attack_distance
	var target_z_retreat := cam.z - attack_distance - retreat_distance

	match _phase:
		Phase.APPROACH:
			# Close in toward attack distance
			var dir_z := 1.0 if enemy.world_pos.z < target_z_attack else -1.0
			enemy.world_pos.z += dir_z * approach_speed * delta

			# Gently track player X
			var player: Node = enemy.get_tree().get_first_node_in_group("player")
			if player != null:
				_target_x = player.world_pos.x
			enemy.world_pos.x = lerp(enemy.world_pos.x, _target_x, 1.0 - exp(-2.0 * delta))
			enemy.world_pos.y = lerp(enemy.world_pos.y, cam.y, 1.0 - exp(-1.5 * delta))

			# Check if in position
			if absf(enemy.world_pos.z - target_z_attack) < 3.0:
				_phase = Phase.ATTACK
				_timer = 0.0

		Phase.ATTACK:
			# Hold position — enemy's normal fire_interval handles shooting
			enemy.world_pos.z = lerp(enemy.world_pos.z, target_z_attack, 1.0 - exp(-4.0 * delta))
			# Slight tracking
			enemy.world_pos.x = lerp(enemy.world_pos.x, _target_x, 1.0 - exp(-1.0 * delta))

			if _timer >= attack_hold:
				_phase = Phase.RETREAT
				_timer = 0.0

		Phase.RETREAT:
			# Pull back
			enemy.world_pos.z -= retreat_speed * delta
			enemy.world_pos.x = lerp(enemy.world_pos.x, _target_x, 1.0 - exp(-0.5 * delta))

			if enemy.world_pos.z <= target_z_retreat:
				_phase = Phase.REPOSITION
				_timer = 0.0
				_drift_dir *= -1.0 # alternate sides

		Phase.REPOSITION:
			# Drift laterally to approach from a different angle
			enemy.world_pos.x += _drift_dir * reposition_speed * delta
			# Hold Z
			enemy.world_pos.z = lerp(enemy.world_pos.z, target_z_retreat, 1.0 - exp(-2.0 * delta))

			if _timer >= reposition_time:
				_phase = Phase.APPROACH
				_timer = 0.0
