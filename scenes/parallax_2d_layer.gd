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

# Sprite repetition
@export var repeat_x: bool = false
@export var repeat_y: bool = false

var camera_rig: CameraRig

func _ready() -> void:
  camera_rig = get_tree().get_first_node_in_group("camera_rig") as CameraRig
  if camera_rig == null:
    push_error("CameraRig not found. Did you add it to group 'camera_rig'?")
  
  # Handle sprite repetition
  if repeat_x or repeat_y:
    var sprite: Sprite2D = null
    
    # Find the Sprite2D child
    for child in get_children():
      if child is Sprite2D:
        sprite = child
        break
    
    if sprite != null and sprite.texture != null:
      var texture_size := sprite.texture.get_size() * sprite.scale
      
      # Determine which positions to create duplicates at
      var offsets: Array[Vector2] = []
      
      if repeat_x and repeat_y:
        # 3x3 grid (excluding center which already exists)
        for x in [-1, 0, 1]:
          for y in [-1, 0, 1]:
            if x != 0 or y != 0: # Skip center
              offsets.append(Vector2(x * texture_size.x, y * texture_size.y))
      elif repeat_x:
        # Left and right
        offsets.append(Vector2(-texture_size.x, 0))
        offsets.append(Vector2(texture_size.x, 0))
      elif repeat_y:
        # Up and down
        offsets.append(Vector2(0, -texture_size.y))
        offsets.append(Vector2(0, texture_size.y))
      
      # Create duplicates
      for offset in offsets:
        var duplicate := sprite.duplicate() as Sprite2D
        add_child(duplicate)
        duplicate.position = sprite.position + offset

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
