#   _________ __               .__                              
#  /   _____//  |______ _______|  | _____    ____   ____  ____  
#  \_____  \\   __\__  \\_  __ \  | \__  \  /    \_/ ___\/ __ \ 
#  /        \|  |  / __ \|  | \/  |__/ __ \|   |  \  \__\  ___/ 
# /_______  /|__| (____  /__|  |____(____  /___|  /\___  >___  >
#         \/           \/                \/     \/     \/    \/ 
# (c) 2026 Pl7y.com

extends WorldObject
class_name Player

## Emitted every frame with the cumulative distance travelled along the rail.
signal distance_changed(distance: float)

@onready var _label = %PlayerLabel as Label
@onready var _run_sprite = %RunSprite as Node2D
@onready var _fly_sprite = %FlySprite as Node2D

@export var hp: int = 5
@export var invuln_seconds: float = 0.8
@export var hurt_radius_px: float = 14.0

@export var flash_speed: float = 18.0
var invuln_t: float = 0.0

@export var speed: float = 1.0

## Cumulative distance travelled along the rail (always increasing).
var _distance: float = 0.0

enum Status {RUNNING, FLYING}

var _status: Status = Status.FLYING:
  set(value):
    if _status == value:
      return
    _status = value
    _apply_status_visuals()

@onready var _movement_component = %PlayerMovementComponent as PlayerMovementComponent

func _ready() -> void:
  super._ready()
  add_to_group("player")
  if _movement_component != null and _movement_component.target == null:
    _movement_component.target = self
  if _movement_component != null:
    _movement_component.speed = speed
  _apply_status_visuals()

func _process(delta: float) -> void:
  if rig == null:
    return

  if _movement_component != null:
    _movement_component.speed = speed
    _distance += _movement_component.apply_movement(delta)

  distance_changed.emit(_distance)

  # --- Iframes timer (keep your existing code) ---
  invuln_t = maxf(0.0, invuln_t - delta)

  # Project + place sprite
  super._process(delta)

  # --- Run vs Fly state ---
  var ground_reference := 0.0
  var grounded_threshold := 0.0
  if _movement_component != null:
    ground_reference = _movement_component.ground_y
    grounded_threshold = _movement_component.grounded_threshold

  var altitude := world_pos.y - ground_reference
  var grounded := altitude <= grounded_threshold

  _status = Status.RUNNING if grounded else Status.FLYING
  
  _label.text = "%s/(%.1f, %.1f, %.1f)" % [_status, world_pos.x, world_pos.y, world_pos.z]

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


func _on_hurt_box_area_entered(_area: Area3D) -> void:
  pass

func _apply_status_visuals() -> void:
  if _run_sprite == null or _fly_sprite == null:
    return

  var is_running := _status == Status.RUNNING
  _run_sprite.visible = is_running
  _fly_sprite.visible = not is_running
