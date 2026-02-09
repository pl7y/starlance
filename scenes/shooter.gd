extends Node
class_name Shooter

@export var bullet_scene: PackedScene
@export var fire_rate: float = 12.0 # bullets/sec
@export var muzzle_ahead_z: float = 6.0 # spawn a bit in front
# ???
@export var muzzle_y_offset: float = 50 # tiny lift if you want

@onready var rig: CameraRig = get_tree().get_first_node_in_group("camera_rig") as CameraRig
@onready var world := $"../World"

var _cooldown: float = 0.0

func _process(delta: float) -> void:
  if rig == null or bullet_scene == null:
    return

  _cooldown = maxf(0.0, _cooldown - delta)

  if Input.is_action_pressed("fire") and _cooldown <= 0.0:
    _cooldown = 1.0 / fire_rate
    _fire()

func _fire() -> void:
  var b := bullet_scene.instantiate() as Node
  world.add_child(b)

  # Spawn bullet at camera position, slightly ahead
  b.world_pos = Vector3(rig.cam_x, rig.cam_y + muzzle_y_offset, rig.cam_z + muzzle_ahead_z)


  # Group for collision system
  b.add_to_group("bullets")
