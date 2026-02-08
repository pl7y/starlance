extends Node
class_name CameraRig

@export var bank_pixels: float = 40.0
@export var bank_smoothing: float = 8.0
var bank: float = 0.0

@export var move_speed_x: float = 18.0
@export var move_speed_y: float = 14.0
@export var accel: float = 10.0 # bigger = snappier
@export var damp: float = 10.0 # bigger = less overshoot (keep near accel)

@export var bounds_x: float = 14.0
@export var bounds_y: float = 8.0

var vel_x: float = 0.0
var vel_y: float = 0.0
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
  # Forward motion (Space Harrier feel)
  cam_z += forward_speed * delta

  # Input
  var ix := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
  bank = lerp(bank, ix, 1.0 - exp(-bank_smoothing * delta))

  var iy := Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

  # Target velocity (world units per second)
  var target_vx := ix * move_speed_x
  var target_vy := iy * move_speed_y

  # Smooth velocity towards target (simple exponential approach)
  vel_x = lerp(vel_x, target_vx, 1.0 - exp(-accel * delta))
  vel_y = lerp(vel_y, target_vy, 1.0 - exp(-accel * delta))

  # Apply velocity to camera position
  cam_x += vel_x * delta
  cam_y += vel_y * delta

  # Boundaries
  cam_x = clamp(cam_x, -bounds_x, bounds_x)
  cam_y = clamp(cam_y, -bounds_y, bounds_y)

  # Make boundaries feel elastic, not “brick wall”
  var clamped_x: float = clamp(cam_x, -bounds_x, bounds_x)
  if clamped_x != cam_x:
    cam_x = clamped_x
    vel_x = 0.0

  var clamped_y: float = clamp(cam_y, -bounds_y, bounds_y)
  if clamped_y != cam_y:
    cam_y = clamped_y
    vel_y = 0.0


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
  # var sx := center.x + rel.x * scale
  var sx := (center.x + bank * bank_pixels) + rel.x * scale

  var sy := horizon_y + rel.y * scale
  return {
    "visible": true,
    "screen": Vector2(sx, sy),
    "scale": scale,
    "rel_z": rel.z
  }
