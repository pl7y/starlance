extends Node
class_name Shooter

@export var bullet_scene: PackedScene
@export var fire_rate: float = 12.0 # bullets/sec
@export var muzzle_ahead_z: float = 6.0 # spawn a bit in front
# ???
@export var muzzle_y_offset: float = -0.5 # tiny lift if you want

@onready var rig: CameraRig = get_tree().get_first_node_in_group("camera_rig") as CameraRig
@onready var world := $"../World"

@onready var player: Player = get_tree().get_first_node_in_group("player") as Player

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

  if player:
    var spawn := player.world_pos
    spawn.z += muzzle_ahead_z
    b.world_pos = spawn

    # Get player offset from viewport center
    var horizontal_offset: float = player.world_pos.x / rig.focal
    b.velocity_direction = Vector3(horizontal_offset, 0, 1).normalized()

    # Group for collision system
    b.add_to_group("bullets")
