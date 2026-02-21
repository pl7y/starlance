# ________                              _____               
# ___  __ \________      _________________  /______ ________
# __  / / /  __ \_ | /| / /_  __ \_  ___/  __/  __ `/_  ___/
# _  /_/ // /_/ /_ |/ |/ /_  / / /(__  )/ /_ / /_/ /_  /    
# /_____/ \____/____/|__/ /_/ /_//____/ \__/ \__,_/ /_/     
#
# (c) Pl7y.com 2026

extends Node
class_name ShooterComponent

@export var bullet_scene: PackedScene
@export var fire_rate: float = 12.0 # bullets/sec
@export var muzzle_ahead_z: float = 6.0 # spawn a bit in front
@export var muzzle_y_offset: float = 0.5 # tiny lift (currently unused)

@onready var rig: CameraRig = get_tree().get_first_node_in_group("camera_rig") as CameraRig
@export var world: Node

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

  owner.get_parent().add_child(b)

  if player:
    var spawn := player.world_pos + Vector3.UP * muzzle_y_offset
    spawn.z -= muzzle_ahead_z
    b.world_pos = spawn

    # Shoot straight ahead
    b.velocity_direction = Vector3(0, 0, -1)

    # Group for collision system
    b.add_to_group("bullets")
