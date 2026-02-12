#   ___________           __________                        __                 
#  /   _____/  | _____.__.\______   \_______   ____ _____  |  | __ ___________ 
#  \_____  \|  |/ <   |  | |    |  _/\_  __ \_/ __ \\__  \ |  |/ // __ \_  __ \
#  /        \    < \___  | |    |   \ |  | \/\  ___/ / __ \|    <\  ___/|  | \/
# /_______  /__|_ \/ ____| |______  / |__|    \___  >____  /__|_ \\___  >__|   
#         \/     \/\/             \/              \/     \/     \/    \/       
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
  position = p.screen

  var s: float = clamp(p.scale, min_scale, max_scale)
  scale = Vector2(s, s)

  # Painter’s algorithm: nearer = higher z_index
  # Tune multiplier for your game scale.
  # z_index = int(4096 - p.rel_z * 10.0)
  z_index = - int(p.rel_z)
  if z_index < RenderingServer.CANVAS_ITEM_Z_MIN:
    push_warning("Object is too far away and may not render correctly. Consider adjusting the scale or z_index calculation.")
  elif z_index > RenderingServer.CANVAS_ITEM_Z_MAX:
    push_warning("Object is too close and may not render correctly. Consider adjusting the scale or z_index calculation.")

  # Despawn when past camera
  if p.rel_z < 1.0:
    queue_free()