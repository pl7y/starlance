extends Node
class_name PlayerController

@export var move_speed_x: float = 180.0
@export var move_speed_y: float = 140.0
@export var accel: float = 14.0
@export var max_altitude: float = 90.0

@onready var player: Player = get_tree().get_first_node_in_group("player") as Player
@onready var rig: CameraRig = get_tree().get_first_node_in_group("camera_rig") as CameraRig

var vel := Vector2.ZERO

func _process(delta: float) -> void:
  if player == null or rig == null:
    return

  var ix := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
  var iy := Input.get_action_strength("move_up") - Input.get_action_strength("move_down")

  var target_v := Vector2(ix * move_speed_x, iy * move_speed_y)

  # Smooth velocity
  vel = vel.lerp(target_v, 1.0 - exp(-accel * delta))

  # Apply to player world coords
  player.world_pos.x += vel.x * delta
  player.world_pos.y += vel.y * delta

  # Calculate viewport bounds in world coordinates
  var vp := get_viewport().get_visible_rect().size
  
  # Clamp within horizontal range and altitude range
  player.world_pos.x = clamp(player.world_pos.x, -vp.x * 0.5, vp.x * 0.5)
  player.world_pos.y = clamp(player.world_pos.y, 0.0, max_altitude)
