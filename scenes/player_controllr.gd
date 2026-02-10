extends Node
class_name PlayerController

@export var move_speed_x: float = 180.0
@export var move_speed_y: float = 140.0
@export var accel: float = 14.0

@export var bounds_x: float = 140.0
@export var bounds_y: float = 80.0

@onready var player: Player = get_tree().get_first_node_in_group("player") as Player

var vel := Vector2.ZERO

func _process(delta: float) -> void:
  if player == null:
    return

  var ix := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
  var iy := Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

  var target_v := Vector2(ix * move_speed_x, iy * move_speed_y)

  # Smooth velocity
  vel = vel.lerp(target_v, 1.0 - exp(-accel * delta))

  # Apply to player world coords
  player.world_pos.x += vel.x * delta
  player.world_pos.y += vel.y * delta

  # Clamp within play area
  player.world_pos.x = clamp(player.world_pos.x, -bounds_x, bounds_x)
  player.world_pos.y = clamp(player.world_pos.y, -bounds_y, bounds_y)
