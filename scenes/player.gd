#   ___________           __________                        __                 
#  /   _____/  | _____.__.\______   \_______   ____ _____  |  | __ ___________ 
#  \_____  \|  |/ <   |  | |    |  _/\_  __ \_/ __ \\__  \ |  |/ // __ \_  __ \
#  /        \    < \___  | |    |   \ |  | \/\  ___/ / __ \|    <\  ___/|  | \/
# /_______  /__|_ \/ ____| |______  / |__|    \___  >____  /__|_ \\___  >__|   
#         \/     \/\/             \/              \/     \/     \/    \/       
# (c) 2026 Pl7y.com

extends WorldObject
class_name Player

@onready var _label = %PlayerLabel as Label

@export var hp: int = 5
@export var invuln_seconds: float = 0.8
@export var hurt_radius_px: float = 14.0

@export var player_z_offset: float = 12.0 # player “plane” in front of camera
@export var lock_scale: bool = false
@export var locked_scale: float = 1.0

@export var flash_speed: float = 18.0
var invuln_t: float = 0.0

@export var ground_y: float = 0.0
@export var gravity: float = 0.0 # pulls you down when not holding up
@export var lift_speed: float = 22.0 # how fast you gain altitude
@export var max_altitude: float = 100.0
@export var min_altitude: float = 3.0 # minimum height when running
@export var grounded_threshold: float = min_altitude + 1.0 # how close to ground counts as grounded

@export var speed = 1.0

func _ready() -> void:
  super._ready()
  add_to_group("player")

func _process(delta: float) -> void:
  if rig == null:
    return

  # Keep player at a constant depth in front of camera
  world_pos.z = rig.camera_world_position.z + player_z_offset


  world_pos.z += speed * delta


  # Ground at y = 0. Higher altitude = NEGATIVE y.
  var up := Input.get_action_strength("move_up")
  var down := Input.get_action_strength("move_down")

  if up > 0.1:
    world_pos.y -= lift_speed * up * delta # go UP = more negative
  else:
    world_pos.y += gravity * delta # fall DOWN = more positive

  if down > 0.1:
    world_pos.y += (gravity * 0.8) * down * delta

  # Clamp between max altitude (negative) and minimum altitude above ground
  world_pos.y = clamp(world_pos.y, -max_altitude, ground_y - min_altitude)

  # --- Iframes timer (keep your existing code) ---
  invuln_t = maxf(0.0, invuln_t - delta)

  # Project + place sprite
  super._process(delta)

  # Keep player size constant (recommended)
  if lock_scale:
    scale = Vector2(locked_scale, locked_scale)

  # --- Run vs Fly state ---
  var altitude := ground_y - world_pos.y
  var grounded := altitude <= grounded_threshold

  if grounded:
    if _label.text != "run":
      _label.text = "run"
  else:
    if _label.text != "fly":
      _label.text = "fly"

  # Blink feedback during iframes (keep your existing blink code)
  if invuln_t > 0.0:
    var blink := (sin(Time.get_ticks_msec() / 1000.0 * flash_speed) * 0.5 + 0.5)
    modulate.a = lerp(0.25, 1.0, blink)
  else:
    modulate.a = 1.0

func can_be_hit() -> bool:
  return invuln_t <= 0.0

func take_hit(dmg: int) -> void:
  if not can_be_hit():
    return
  hp -= dmg
  invuln_t = invuln_seconds
  print("Player HP:", hp)
