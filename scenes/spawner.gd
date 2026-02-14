extends Node

@export var enemy_scene: PackedScene
@export var spawn_ahead_z: float = 90.0
@export var spawn_interval: float = 0.35

@export var spawn_x_range: float = 14.0
@export var spawn_y_range: float = 8.0

@onready var rig: CameraRig = get_tree().get_first_node_in_group("camera_rig") as CameraRig
@onready var world := $"../World"

var t: float = 0.0

func _process(delta: float) -> void:
  if rig == null or enemy_scene == null:
    return

  t -= delta
  if t > 0.0:
    return

  t = spawn_interval
  var e := enemy_scene.instantiate()
  world.add_child(e)

  # spawn in world space ahead of camera (negative z is ahead)
  var x := randf_range(-spawn_x_range, spawn_x_range)
  var y := randf_range(-spawn_y_range, spawn_y_range)
  var z := rig.camera_world_position.z - spawn_ahead_z - randf_range(0.0, 30.0)

  e.world_pos = Vector3(x, y, z)
