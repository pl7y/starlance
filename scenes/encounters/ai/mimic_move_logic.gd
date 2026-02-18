## Mimic AI — shadows the player's X/Y position with configurable
## offset and delay, creating an eerie "dark twin" feeling.
##
## The enemy maintains a fixed Z-distance ahead of the camera and
## mirrors the player's lateral movement with a smoothed delay.
## Periodically "glitches" — snapping to a random offset before
## resuming the mirror, keeping the player on edge.
@tool
extends MoveLogic
class_name MimicMoveLogic

## Z-distance ahead of camera where the mimic hovers.
@export var hover_distance: float = 35.0

## How quickly the mimic follows the player's X/Y (higher = tighter mirror).
@export var mirror_strength: float = 3.0

## Offset from exact mirror position (so it's not pixel-perfect, feels organic).
@export var offset: Vector2 = Vector2(5.0, 3.0)

## X-axis mirror multiplier. -1.0 = true mirror, 1.0 = same side, 0.5 = partial.
@export var mirror_x: float = -1.0

## Y-axis mirror multiplier.
@export var mirror_y: float = 1.0

## Average interval between "glitch" snaps (seconds).
@export var glitch_interval: float = 3.0

## How long a glitch displacement lasts (seconds).
@export var glitch_duration: float = 0.3

## Maximum random displacement during a glitch.
@export var glitch_magnitude: float = 25.0

# ── Instance state ───────────────────────────────────────────────────────────

var _glitch_timer: float = 0.0
var _glitch_offset: Vector2 = Vector2.ZERO
var _in_glitch: bool = false
var _glitch_hold: float = 0.0


func setup(_enemy: Node, _rig: CameraRig) -> void:
	_glitch_timer = randf_range(glitch_interval * 0.5, glitch_interval * 1.5)


func update(enemy: Node, rig: CameraRig, delta: float) -> void:
	var cam := rig.camera_world_position
	var player: Node = enemy.get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var player_pos: Vector3 = player.world_pos

	# Target: mirrored player position at fixed Z
	var rel_x := player_pos.x - cam.x
	var rel_y := player_pos.y - cam.y
	var target_x := cam.x + rel_x * mirror_x + offset.x
	var target_y := cam.y + rel_y * mirror_y + offset.y
	var target_z := cam.z - hover_distance

	# Glitch system
	_glitch_timer -= delta
	if _in_glitch:
		_glitch_hold -= delta
		if _glitch_hold <= 0.0:
			_in_glitch = false
			_glitch_offset = Vector2.ZERO
	elif _glitch_timer <= 0.0:
		_in_glitch = true
		_glitch_hold = glitch_duration
		_glitch_timer = randf_range(glitch_interval * 0.7, glitch_interval * 1.3)
		_glitch_offset = Vector2(
			randf_range(-glitch_magnitude, glitch_magnitude),
			randf_range(-glitch_magnitude * 0.5, glitch_magnitude * 0.5)
		)

	# Apply movement
	var final_x := target_x + _glitch_offset.x
	var final_y := target_y + _glitch_offset.y

	if _in_glitch:
		# Snap instantly during glitch
		enemy.world_pos.x = final_x
		enemy.world_pos.y = final_y
	else:
		enemy.world_pos.x = lerp(enemy.world_pos.x, final_x, 1.0 - exp(-mirror_strength * delta))
		enemy.world_pos.y = lerp(enemy.world_pos.y, final_y, 1.0 - exp(-mirror_strength * delta))

	enemy.world_pos.z = lerp(enemy.world_pos.z, target_z, 1.0 - exp(-2.0 * delta))
