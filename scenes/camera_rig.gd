extends Node
class_name CameraRig

@export var forward_speed: float = 35.0

# "Camera" position in world space (X,Y,Z)
var cam_x: float = 0.0
var cam_y: float = 0.0
var cam_z: float = 0.0

# Projection tuning
@export var focal: float = 320.0
@export var horizon_ratio: float = 0.35 # 0..1 of screen height

var center: Vector2
var horizon_y: float

func _ready() -> void:
	_update_screen_params()

func _process(delta: float) -> void:
	cam_z += forward_speed * delta
	_update_screen_params()

func _update_screen_params() -> void:
	var vp := get_viewport().get_visible_rect().size
	center = Vector2(vp.x * 0.5, vp.y * 0.5)
	horizon_y = vp.y * horizon_ratio

func project(world_pos: Vector3) -> Dictionary:
	var rel := world_pos - Vector3(cam_x, cam_y, cam_z)
	if rel.z <= 0.1:
		return {"visible": false}

	var scale := focal / rel.z
	var sx := center.x + rel.x * scale
	var sy := horizon_y + rel.y * scale
	return {
		"visible": true,
		"screen": Vector2(sx, sy),
		"scale": scale,
		"rel_z": rel.z
	}
