## Helix AI — enemies spiral in a 3D helix pattern toward the player,
## creating a mesmerizing corkscrew approach that's visually striking
## and tricky to hit.
##
## The helix unwinds toward the camera — the enemy spirals in
## progressively tighter circles as it gets closer, then loops
## back out if it overshoots.
@tool
extends MoveLogic
class_name HelixMoveLogic

## Forward speed toward camera.
@export var approach_speed: float = 40.0

## Base helix radius at max distance.
@export var max_radius: float = 30.0

## Helix radius once close to the player.
@export var min_radius: float = 5.0

## Rotation speed (radians/second).
@export var spin_speed: float = 3.5

## Z-distance from camera where the helix center aims.
@export var target_distance: float = 35.0

## If true, reverses back out after passing the camera (instead of dying).
@export var boomerang: bool = true

# ── Instance state ───────────────────────────────────────────────────────────

var _angle: float = 0.0
var _direction: float = 1.0 # 1 = approaching, -1 = retreating
var _center_x: float = 0.0
var _center_y: float = 0.0


func setup(enemy: Node, rig: CameraRig) -> void:
	_angle = randf_range(0.0, TAU)
	_direction = 1.0
	# Center the helix on the player
	var player: Node = enemy.get_tree().get_first_node_in_group("player")
	if player != null:
		_center_x = player.world_pos.x
		_center_y = player.world_pos.y
	else:
		_center_x = rig.camera_world_position.x
		_center_y = rig.camera_world_position.y


func update(enemy: Node, rig: CameraRig, delta: float) -> void:
	var cam := rig.camera_world_position

	# Slowly track player position as helix center
	var player: Node = enemy.get_tree().get_first_node_in_group("player")
	if player != null:
		_center_x = lerp(_center_x, player.world_pos.x, 1.0 - exp(-0.8 * delta))
		_center_y = lerp(_center_y, player.world_pos.y, 1.0 - exp(-0.8 * delta))

	# Advance along Z
	enemy.world_pos.z += approach_speed * _direction * delta

	# Calculate how close we are to the target (0 = far, 1 = at target)
	var depth: float = - (enemy.world_pos.z - cam.z)
	var progress := clampf(depth / (target_distance * 2.0), 0.0, 1.0)

	# Radius shrinks as we get closer
	var radius: float = lerp(max_radius, min_radius, progress)

	# Spin
	_angle += spin_speed * delta

	# Apply helix offset around the moving center
	enemy.world_pos.x = _center_x + cos(_angle) * radius
	enemy.world_pos.y = _center_y + sin(_angle) * (radius * 0.6) # squashed Y for perspective

	# Boomerang: if we've overshot, reverse
	var rel_z: float = enemy.world_pos.z - cam.z
	if rel_z > 20.0: # passed camera
		if boomerang:
			_direction = -1.0
		else:
			enemy.queue_free()
	elif _direction < 0.0 and depth > target_distance * 2.5:
		# Back at long range, reverse again for another pass
		_direction = 1.0
