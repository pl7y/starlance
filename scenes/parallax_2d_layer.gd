extends Node2D
class_name Parallax2DLayer

# Base world position (x, y) - z is calculated from player + offset
@export var world_x: float = 0.0
@export var world_y: float = 20.0

# How far behind the player this layer is (positive = further back, more parallax)
@export var parallax_z_offset: float = -2000.0

# Scale locking
@export var lock_scale: bool = false
@export var locked_scale: float = 1.0

var camera_rig: CameraRig

func _ready() -> void:
  camera_rig = get_tree().get_first_node_in_group("camera_rig") as CameraRig
  if camera_rig == null:
    push_error("CameraRig not found. Did you add it to group 'camera_rig'?")

func _process(_delta: float) -> void:
  if camera_rig == null:
    return
  
  var player: Player = get_tree().get_first_node_in_group("player") as Player
  if player == null:
    return
  
  # Calculate world position: same x/y as set, but z is player's z + offset (further back)
  var world_pos := Vector3(world_x, world_y, player.world_pos.z + parallax_z_offset)
  
  # Project to screen space
  var projected := camera_rig.project(world_pos)
  
  if not projected.visible:
    visible = false
    return
  
  visible = true
  global_position = projected.screen
  
  if lock_scale:
    scale = Vector2.ONE * locked_scale
  else:
    scale = Vector2.ONE * projected.scale
