## Flanker AI — circles wide to one side, then commits to a diagonal
## attack run across the player's path before pulling away.
##
## Phases:
##   1. APPROACH  — drift toward player at an angle, circling laterally
##   2. COMMIT    — sharp diagonal dive across the screen
##   3. RETREAT   — pull away, then loop back to APPROACH
@tool
extends MoveLogic
class_name FlankerMoveLogic

enum Phase {APPROACH, COMMIT, RETREAT}

## How wide the flanking arc is (world units from center).
@export var flank_radius: float = 60.0

## Approach speed toward the player's Z.
@export var approach_speed: float = 50.0

## Dive speed during the commit phase.
@export var commit_speed: float = 120.0

## How long the commit dive lasts (seconds).
@export var commit_duration: float = 0.8

## How long the retreat lasts before looping (seconds).
@export var retreat_duration: float = 1.5

## Which side to flank (1.0 = right, -1.0 = left, 0 = random at setup).
@export var side: float = 0.0

# ── Instance state (safe because EnemySpawner duplicates) ────────────────────

var _phase: Phase = Phase.APPROACH
var _timer: float = 0.0
var _side: float = 1.0
var _commit_dir: Vector3 = Vector3.ZERO


func setup(_enemy: Node, _rig: CameraRig) -> void:
	_phase = Phase.APPROACH
	_timer = 0.0
	_side = side if side != 0.0 else (1.0 if randf() > 0.5 else -1.0)


func update(enemy: Node, rig: CameraRig, delta: float) -> void:
	_timer += delta
	var cam := rig.camera_world_position

	match _phase:
		Phase.APPROACH:
			# Arc toward the player from one side
			var target_x := cam.x + _side * flank_radius
			var target_y := cam.y
			var target_z := cam.z - 40.0 # ahead of camera

			enemy.world_pos.x = lerp(enemy.world_pos.x, target_x, 1.0 - exp(-2.0 * delta))
			enemy.world_pos.y = lerp(enemy.world_pos.y, target_y, 1.0 - exp(-1.5 * delta))
			enemy.world_pos.z += approach_speed * delta

			# Once close enough laterally and in Z, commit
			var dx := absf(enemy.world_pos.x - target_x)
			var dz := absf(enemy.world_pos.z - target_z)
			if dx < 8.0 and dz < 15.0:
				_phase = Phase.COMMIT
				_timer = 0.0
				# Aim diagonally across the screen
				_commit_dir = Vector3(-_side * 1.5, -0.3, 1.0).normalized()

		Phase.COMMIT:
			enemy.world_pos += _commit_dir * commit_speed * delta
			if _timer >= commit_duration:
				_phase = Phase.RETREAT
				_timer = 0.0

		Phase.RETREAT:
			# Pull away from camera, drift back to flanking side
			enemy.world_pos.z -= approach_speed * 0.6 * delta
			enemy.world_pos.x = lerp(enemy.world_pos.x, cam.x + _side * flank_radius, 1.0 - exp(-1.0 * delta))
			enemy.world_pos.y = lerp(enemy.world_pos.y, cam.y + 10.0, 1.0 - exp(-1.0 * delta))
			if _timer >= retreat_duration:
				_phase = Phase.APPROACH
				_timer = 0.0
				_side *= -1.0 # switch sides for variety
