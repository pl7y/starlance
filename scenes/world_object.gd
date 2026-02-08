extends Node2D
class_name WorldObject

@export var world_pos: Vector3 = Vector3.ZERO
@export var min_scale: float = 0.02
@export var max_scale: float = 6.0

@onready var rig: CameraRig = get_tree().get_first_node_in_group("camera_rig") as CameraRig

func _ready() -> void:
  if rig == null:
    push_error("CameraRig not found. Did you add it to group 'camera_rig'?")

func _process(_delta: float) -> void:
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
  z_index = int(4096 - p.rel_z * 10.0)

  # Despawn when past camera
  if p.rel_z < 1.2:
    queue_free()