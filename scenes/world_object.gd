#   _________ __               .__                              
#  /   _____//  |______ _______|  | _____    ____   ____  ____  
#  \_____  \\   __\__  \\_  __ \  | \__  \  /    \_/ ___\/ __ \ 
#  /        \|  |  / __ \|  | \/  |__/ __ \|   |  \  \__\  ___/ 
# /_______  /|__| (____  /__|  |____(____  /___|  /\___  >___  >
#         \/           \/                \/     \/     \/    \/ 
# (c) 2026 Pl7y.com
extends Node2D
class_name WorldObject

enum EscapeType {
  NONE,
  BEHIND_CAMERA, # Went behind the camera (negative depth)
  OFF_SCREEN_LEFT, # Went too far left
  OFF_SCREEN_RIGHT, # Went too far right
  TOO_FAR_AHEAD # Went too far ahead of camera
}

signal escaped(escape_type: EscapeType)

@export var world_pos: Vector3 = Vector3.ZERO:
  set(value):
    world_pos = value
    _update()
  get:
    return world_pos

@export var min_scale: float = 0.02
@export var max_scale: float = 6.0
@export var fixed_sprite: bool = false
@export var lock_scale: bool = false
@export var locked_scale: float = 1.0

# Escape detection settings
@export_group("Escape Detection")
@export var enable_escape_detection: bool = true
@export var despawn_on_escape: bool = true
@export var screen_margin_pixels: float = 200.0 # Buffer zone before triggering escape
@export var max_distance_ahead: float = 150.0 # Max Z distance ahead of camera before escaping

# Shadow settings
@export_group("Shadow Settings")
@export var casts_shadow: bool = true
@export var shadow_sprite: Node2D
@export var shadow_opacity_at_ground: float = 0.5
@export var shadow_fade_distance: float = 10.0 # Height at which shadow fully fades
@export var shadow_min_scale: float = 0.1
@export var shadow_max_scale: float = 1.0

@onready var rig: CameraRig = get_tree().get_first_node_in_group("camera_rig") as CameraRig

var _has_escaped: bool = false

func _ready() -> void:
  if rig == null:
    push_error("CameraRig not found. Did you add it to group 'camera_rig'?")

func _process(_delta: float) -> void:
  _update()

func _update() -> void:
  if rig == null:
    return

  # Check for escape conditions
  if enable_escape_detection and not _has_escaped:
    var escape_type := _check_escape()
    if escape_type != EscapeType.NONE:
      _on_escaped(escape_type)
      return

  var p := rig.project(world_pos)
  if not p.visible:
    # Fallback: still despawn if not visible (shouldn't happen if escape detection is on)
    if not enable_escape_detection and not _has_escaped:
      queue_free()
    return

  visible = true
  global_position = p.screen

  var projected_scale := clampf(p.scale, min_scale, max_scale)
  var target_scale := Vector2(projected_scale, projected_scale)

  if fixed_sprite:
    target_scale = Vector2(1, 1)

  if lock_scale:
    target_scale = Vector2(locked_scale, locked_scale)

  global_scale = target_scale

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
  if fixed_sprite:
    shadow_sprite.global_scale = Vector2(1, 1)
  else:
    var shadow_scale := clampf(shadow_p.scale, shadow_min_scale, shadow_max_scale)
    shadow_sprite.global_scale = Vector2(shadow_scale, shadow_scale)

  shadow_sprite.modulate.a = 0.5

  # Shadow should render below the object
  shadow_sprite.z_index = z_index - 1


## Check if object has escaped based on various conditions
func _check_escape() -> EscapeType:
  var p := rig.project(world_pos)
  
  # Check if behind camera
  if not p.visible:
    return EscapeType.BEHIND_CAMERA
  
  # Get viewport size
  var viewport_size := get_viewport_rect().size
  
  # Check if too far off screen horizontally
  if p.screen.x < -screen_margin_pixels:
    return EscapeType.OFF_SCREEN_LEFT
  if p.screen.x > viewport_size.x + screen_margin_pixels:
    return EscapeType.OFF_SCREEN_RIGHT
  
  # Check if too far ahead of camera
  var distance_ahead := world_pos.z - rig.camera_world_position.z
  if distance_ahead > max_distance_ahead:
    return EscapeType.TOO_FAR_AHEAD
  
  return EscapeType.NONE


## Called when object escapes - emits signal and optionally despawns
func _on_escaped(escape_type: EscapeType) -> void:
  _has_escaped = true
  escaped.emit(escape_type)
  
  if despawn_on_escape:
    queue_free()


## Can be called from child classes to manually trigger escape
func trigger_escape(escape_type: EscapeType = EscapeType.NONE) -> void:
  if not _has_escaped:
    _on_escaped(escape_type)
