## Ambusher AI — lurks far away nearly motionless, then suddenly
## charges at extreme speed toward the player before veering off.
##
## Phases:
##   1. LURK    — hover at long range, barely moving (intimidating dot in the distance)
##   2. TELEGRAPH — brief "wind-up" where it shakes/drifts slightly (tells the player)
##   3. CHARGE  — explosive straight-line rush toward the player's position
##   4. FLYBY   — overshoots past the camera and despawns or loops back to LURK
@tool
extends MoveLogic
class_name AmbusherMoveLogic

enum Phase {LURK, TELEGRAPH, CHARGE, FLYBY}

## How long to lurk before the first attack.
@export var lurk_time: float = 2.5

## Duration of the telegraph "wind-up" (seconds).
@export var telegraph_time: float = 0.6

## Charge speed (very fast).
@export var charge_speed: float = 250.0

## How far past the camera the enemy flies before resetting (negative = behind camera).
@export var overshoot_z: float = 50.0

## Whether to loop back to LURK after a flyby (true) or queue_free (false).
@export var loops: bool = true

## Z-distance for the lurking position (far ahead of camera).
@export var lurk_distance: float = 120.0

## Shake amplitude during telegraph.
@export var shake_amplitude: float = 3.0

# ── Instance state ───────────────────────────────────────────────────────────

var _phase: Phase = Phase.LURK
var _timer: float = 0.0
var _charge_dir: Vector3 = Vector3.ZERO
var _lurk_pos: Vector3 = Vector3.ZERO
var _initial_lurk_offset: Vector2 = Vector2.ZERO


func setup(_enemy: Node, _rig: CameraRig) -> void:
	_phase = Phase.LURK
	_timer = 0.0
	# Randomize lurk position offset so multiple ambushers spread out
	_initial_lurk_offset = Vector2(
		randf_range(-40.0, 40.0),
		randf_range(-15.0, 15.0)
	)


func update(enemy: Node, rig: CameraRig, delta: float) -> void:
	_timer += delta
	var cam := rig.camera_world_position

	match _phase:
		Phase.LURK:
			# Hover far away, barely noticeable
			_lurk_pos = Vector3(
				cam.x + _initial_lurk_offset.x,
				cam.y + _initial_lurk_offset.y,
				cam.z - lurk_distance
			)
			enemy.world_pos = lerp(enemy.world_pos, _lurk_pos, 1.0 - exp(-1.5 * delta))

			if _timer >= lurk_time:
				_phase = Phase.TELEGRAPH
				_timer = 0.0

		Phase.TELEGRAPH:
			# Shake in place to warn the player
			enemy.world_pos.x = _lurk_pos.x + sin(_timer * 40.0) * shake_amplitude
			enemy.world_pos.y = _lurk_pos.y + cos(_timer * 35.0) * shake_amplitude * 0.5

			if _timer >= telegraph_time:
				_phase = Phase.CHARGE
				_timer = 0.0
				# Lock charge direction toward current player position
				var player: Node = enemy.get_tree().get_first_node_in_group("player")
				var target := cam
				if player != null:
					target = player.world_pos
				_charge_dir = (target - enemy.world_pos).normalized()

		Phase.CHARGE:
			enemy.world_pos += _charge_dir * charge_speed * delta

			# Check if we've passed the camera (overshot)
			var rel_z: float = enemy.world_pos.z - cam.z
			if rel_z > overshoot_z:
				_phase = Phase.FLYBY
				_timer = 0.0

		Phase.FLYBY:
			if loops:
				# Reset far ahead and lurk again
				enemy.world_pos = Vector3(
					cam.x + randf_range(-40.0, 40.0),
					cam.y + randf_range(-15.0, 15.0),
					cam.z - lurk_distance
				)
				_initial_lurk_offset = Vector2(
					enemy.world_pos.x - cam.x,
					enemy.world_pos.y - cam.y
				)
				_phase = Phase.LURK
				_timer = 0.0
			else:
				enemy.queue_free()
