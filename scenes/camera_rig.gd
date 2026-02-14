#   _________ __               .__                              
#  /   _____//  |______ _______|  | _____    ____   ____  ____  
#  \_____  \\   __\__  \\_  __ \  | \__  \  /    \_/ ___\/ __ \ 
#  /        \|  |  / __ \|  | \/  |__/ __ \|   |  \  \__\  ___/ 
# /_______  /|__| (____  /__|  |____(____  /___|  /\___  >___  >
#         \/           \/                \/     \/     \/    \/ 
# (c) 2026 Pl7y.com

extends Node
class_name CameraRig

# Camera banking (roll/tilt) effect - maximum horizontal screen offset in pixels
@export var bank_pixels: float = 40.0
# Smoothing factor for bank transitions (higher = smoother/slower response)
@export var bank_smoothing: float = 8.0
# Current bank amount (-1 to 1, where -1 is full left tilt, 1 is full right tilt)
var bank: float = 0.0

@export var move_speed_x: float = 18.0
@export var move_speed_y: float = 14.0
@export var accel: float = 10.0 # bigger = snappier
@export var damp: float = 10.0 # bigger = less overshoot (keep near accel)

@export var follow_strength: float = 0.15 # 0 = fixed camera, 1 = camera fully follows
@export var follow_smoothing: float = 8.0 # camera follow smoothing speed

@export var forward_speed: float = 35.0

@export var camera_z_offset: float = 128.0 # how far behind player the camera is (positive value)

# Altitude constraints for camera position
@export var min_altitude: float = 10.0
@export var max_altitude: float = 100.0

# "Camera" position in world space (X,Y,Z)
var camera_world_position: Vector3 = Vector3.ZERO

# Projection tuning
@export var focal: float = 320.0
@export var min_horizon_ratio: float = 0.55 # horizon ratio at min altitude
@export var max_horizon_ratio: float = 0.75 # horizon ratio at max altitude

var horizon_ratio: float = 0.65 # dynamically calculated based on altitude
var center: Vector2
var horizon_y: float

func _ready() -> void:
  _update_screen_params()

func _process(delta: float) -> void:
  var player: Player = get_tree().get_first_node_in_group("player") as Player
  if player != null:
    # Calculate target positions with altitude constraints
    var target_y = clamp(player.world_pos.y * follow_strength, min_altitude, max_altitude)
    
    camera_world_position.x = lerp(camera_world_position.x, player.world_pos.x * follow_strength, 1.0 - exp(-follow_smoothing * delta))
    camera_world_position.y = lerp(camera_world_position.y, target_y, 1.0 - exp(-follow_smoothing * delta))
    
  # camera_world_position.x = player.world_pos.x
  # camera_world_position.y = player.world_pos.y
  # camera_world_position.z -= forward_speed * delta
  camera_world_position.z = player.world_pos.z + camera_z_offset
  _update_screen_params()

func _update_screen_params() -> void:
  # Update horizon ratio based on camera altitude
  var altitude_t = inverse_lerp(min_altitude, max_altitude, camera_world_position.y)
  horizon_ratio = lerp(min_horizon_ratio, max_horizon_ratio, altitude_t)
  
  var vp := get_viewport().get_visible_rect().size
  center = Vector2(vp.x * 0.5, vp.y * 0.5)
  horizon_y = vp.y * horizon_ratio

func project(world_pos: Vector3) -> Projection2D:
  var rel := world_pos - camera_world_position
  # Negative z is ahead, so use -rel.z for distance
  var depth := -rel.z
  if depth <= 0.1:
    return Projection2D.new(false, Vector2.ZERO, 1.0, 0.0)

  var scale := focal / depth
  # var sx := center.x + rel.x * scale
  # Apply camera banking: shift the horizontal center by bank amount for tilt effect
  var sx := (center.x + bank * bank_pixels) + rel.x * scale

  var sy := horizon_y - rel.y * scale
  return Projection2D.new(true, Vector2(sx, sy), scale, depth)
