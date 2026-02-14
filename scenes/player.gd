#   _________ __               .__                              
#  /   _____//  |______ _______|  | _____    ____   ____  ____  
#  \_____  \\   __\__  \\_  __ \  | \__  \  /    \_/ ___\/ __ \ 
#  /        \|  |  / __ \|  | \/  |__/ __ \|   |  \  \__\  ___/ 
# /_______  /|__| (____  /__|  |____(____  /___|  /\___  >___  >
#         \/           \/                \/     \/     \/    \/ 
# (c) 2026 Pl7y.com

extends WorldObject
class_name Player

@onready var _label = %PlayerLabel as Label

@export var hp: int = 5
@export var invuln_seconds: float = 0.8
@export var hurt_radius_px: float = 14.0

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
  world_pos.z -= speed * delta


  # Ground at y = 0. Higher altitude = POSITIVE y.
  var up := Input.get_action_strength("move_up")
  var down := Input.get_action_strength("move_down")

  if up > 0.1:
    world_pos.y += lift_speed * up * delta # go UP = more positive
  else:
    world_pos.y -= gravity * delta # fall DOWN = more negative

  if down > 0.1:
    world_pos.y -= (gravity * 0.8) * down * delta

  # Clamp between ground level and max altitude (positive)
  world_pos.y = clamp(world_pos.y, ground_y, max_altitude)

  # --- Iframes timer (keep your existing code) ---
  invuln_t = maxf(0.0, invuln_t - delta)

  # Project + place sprite
  super._process(delta)

  # Keep player size constant (recommended)
  if lock_scale:
    scale = Vector2(locked_scale, locked_scale)

  # --- Run vs Fly state ---
  var altitude := world_pos.y - ground_y
  var grounded := altitude <= grounded_threshold

  var status := "fly"
  if grounded:
    status = "run"
  
  _label.text = "%s/(%.1f, %.1f, %.1f)" % [status, world_pos.x, world_pos.y, world_pos.z]

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


func _on_hurt_box_area_entered(area: Area3D) -> void:
  prints("Player hurt box entered by:", area)