#   _________ __               .__                              
#  /   _____//  |______ _______|  | _____    ____   ____  ____  
#  \_____  \\   __\__  \\_  __ \  | \__  \  /    \_/ ___\/ __ \ 
#  /        \|  |  / __ \|  | \/  |__/ __ \|   |  \  \__\  ___/ 
# /_______  /|__| (____  /__|  |____(____  /___|  /\___  >___  >
#         \/           \/                \/     \/     \/    \/ 
# (c) 2026 Pl7y.com

extends Node
class_name PlayerMovementComponent

@export var target: WorldObject
@export var ground_y: float = 0.0
@export var lift_speed: float = 22.0 # climb speed when pressing up
@export var max_altitude: float = 100.0
@export var min_altitude: float = 3.0
@export var grounded_threshold: float = 4.0 # how close to ground counts as grounded
@export var speed: float = 1.0

@export_group("Screen Controller")
@export var enable_screen_controller: bool = false
@export var move_speed_x: float = 180.0
@export var move_speed_y: float = 140.0
@export var controller_accel: float = 14.0

const INPUT_THRESHOLD := 0.1
const DOWNWARD_GRAVITY_SCALE := 0.8

var _plane_velocity := Vector2.ZERO

func apply_movement(delta: float) -> float:
  if target == null or target.rig == null:
    return 0.0

  var distance_delta := _advance_along_rail(delta)
  if enable_screen_controller:
    _apply_screen_controller(delta)
  else:
    _update_vertical_position(delta)
  return distance_delta

func _advance_along_rail(delta: float) -> float:
  var step := speed * delta
  target.world_pos.z -= step
  return absf(step)

func _update_vertical_position(delta: float) -> void:
  var up_strength := Input.get_action_strength("move_up")
  var down_strength := Input.get_action_strength("move_down")

  if up_strength > INPUT_THRESHOLD:
    target.world_pos.y += lift_speed * up_strength * delta

  if down_strength > INPUT_THRESHOLD:
    target.world_pos.y -= lift_speed * down_strength * delta

  target.world_pos.y = clampf(target.world_pos.y, ground_y, max_altitude)

func get_altitude() -> float:
  if target == null:
    return 0.0
  return target.world_pos.y - ground_y

func _apply_screen_controller(delta: float) -> void:
  var ix := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
  var iy := Input.get_action_strength("move_up") - Input.get_action_strength("move_down")

  var target_velocity := Vector2(ix * move_speed_x, iy * move_speed_y)
  var lerp_weight := 1.0 - exp(-controller_accel * delta)
  _plane_velocity = _plane_velocity.lerp(target_velocity, lerp_weight)

  target.world_pos.x += _plane_velocity.x * delta
  target.world_pos.y += _plane_velocity.y * delta

  target.world_pos.y = clampf(target.world_pos.y, ground_y, max_altitude)
