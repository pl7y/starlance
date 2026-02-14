#   _________ __               .__                              
#  /   _____//  |______ _______|  | _____    ____   ____  ____  
#  \_____  \\   __\__  \\_  __ \  | \__  \  /    \_/ ___\/ __ \ 
#  /        \|  |  / __ \|  | \/  |__/ __ \|   |  \  \__\  ___/ 
# /_______  /|__| (____  /__|  |____(____  /___|  /\___  >___  >
#         \/           \/                \/     \/     \/    \/ 
# (c) 2026 Pl7y.com
extends Node2D
class_name WorldObject

@export var world_pos: Vector3 = Vector3.ZERO:
  set(value):
    world_pos = value
    _update()
  get:
    return world_pos

@export var min_scale: float = 0.02
@export var max_scale: float = 6.0

# Shadow settings
@export_group("Shadow Settings")
@export var casts_shadow: bool = true
@export var shadow_sprite: Node2D
@export var shadow_opacity_at_ground: float = 0.5
@export var shadow_fade_distance: float = 10.0 # Height at which shadow fully fades
@export var shadow_min_scale: float = 0.1
@export var shadow_max_scale: float = 1.0

@onready var rig: CameraRig = get_tree().get_first_node_in_group("camera_rig") as CameraRig

func _ready() -> void:
  if rig == null:
    push_error("CameraRig not found. Did you add it to group 'camera_rig'?")

func _process(_delta: float) -> void:
  _update()

func _update() -> void:
  if rig == null:
    return

  var p := rig.project(world_pos)
  if not p.visible:
    visible = false
    return

  visible = true
  global_position = p.screen

  var s: float = clamp(p.scale, min_scale, max_scale)
  global_scale = Vector2(s, s)

  # Painter’s algorithm: nearer = higher z_index
  # Painter's algorithm: nearer = higher z_index (smaller depth = higher z_index)
  # Tune multiplier for your game scale.
  # z_index = int(4096 - p.rel_z * 10.0)
  z_index = - int(p.rel_z)
  if z_index < RenderingServer.CANVAS_ITEM_Z_MIN:
    push_warning("Object is too far away and may not render correctly. Consider adjusting the scale or z_index calculation.")
  elif z_index > RenderingServer.CANVAS_ITEM_Z_MAX:
    push_warning("Object is too close and may not render correctly. Consider adjusting the scale or z_index calculation.")

  # Update shadow projection
  _update_shadow()

  # Despawn when behind camera (depth becomes negative when behind)
  if p.rel_z < 0.0:
    queue_free()

func _update_shadow() -> void:
  if not casts_shadow or shadow_sprite == null:
    if shadow_sprite != null:
      shadow_sprite.visible = false
    return

  # Project shadow onto the ground (y = 0)
  var shadow_world_pos := Vector3(world_pos.x, 0.0, world_pos.z)
  var shadow_p := rig.project(shadow_world_pos)

  if not shadow_p.visible:
    shadow_sprite.visible = false
    return

  shadow_sprite.visible = true
  shadow_sprite.global_position = shadow_p.screen
  
  # Scale shadow based on projection
  var shadow_scale := clampf(shadow_p.scale, shadow_min_scale, shadow_max_scale)
  shadow_sprite.global_scale = Vector2(shadow_scale, shadow_scale)

  shadow_sprite.modulate.a = 0.5

  # Shadow should render below the object
  shadow_sprite.z_index = z_index - 1