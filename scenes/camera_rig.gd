extends Node
class_name CameraRig

@export var bank_pixels: float = 40.0
@export var bank_smoothing: float = 8.0
var bank: float = 0.0

@export var move_speed_x: float = 18.0
@export var move_speed_y: float = 14.0
@export var accel: float = 10.0 # bigger = snappier
@export var damp: float = 10.0 # bigger = less overshoot (keep near accel)

@export var follow_strength: float = 0.15 # 0 = fixed camera, 1 = camera fully follows

@export var forward_speed: float = 35.0

# "Camera" position in world space (X,Y,Z)
var cam_x: float = 0.0
var cam_y: float = 0.0
var cam_z: float = 0.0

# Projection tuning
@export var focal: float = 320.0
@export var horizon_ratio: float = 0.65 # 0..1 of screen height

var center: Vector2
var horizon_y: float

func _ready() -> void:
  _update_screen_params()

func _process(delta: float) -> void:
  var player: Player = get_tree().get_first_node_in_group("player") as Player
  if player != null:
    cam_x = lerp(cam_x, player.world_pos.x * follow_strength, 1.0 - exp(-8.0 * delta))
    cam_y = lerp(cam_y, player.world_pos.y * follow_strength, 1.0 - exp(-8.0 * delta))

  # cam_z += forward_speed * delta
  cam_z = player.world_pos.z - player.player_z_offset
  _update_screen_params()


func _update_screen_params() -> void:
  var vp := get_viewport().get_visible_rect().size
  center = Vector2(vp.x * 0.5, vp.y * 0.5)
  horizon_y = vp.y * horizon_ratio

func project(world_pos: Vector3) -> Projection2D:
  var rel := world_pos - Vector3(cam_x, cam_y, cam_z)
  if rel.z <= 0.1:
    return Projection2D.new(false, Vector2.ZERO, 1.0, 0.0)

  var scale := focal / rel.z
  # var sx := center.x + rel.x * scale
  var sx := (center.x + bank * bank_pixels) + rel.x * scale

  var sy := horizon_y + rel.y * scale
  return Projection2D.new(true, Vector2(sx, sy), scale, rel.z)
