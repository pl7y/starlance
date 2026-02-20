#   _________ __               .__                              
#  /   _____//  |______ _______|  | _____    ____   ____  ____  
#  \_____  \\   __\__  \\_  __ \  | \__  \  /    \_/ ___\/ __ \ 
#  /        \|  |  / __ \|  | \/  |__/ __ \|   |  \  \__\  ___/ 
# /_______  /|__| (____  /__|  |____(____  /___|  /\___  >___  >
#         \/           \/                \/     \/     \/    \/ 
# (c) 2026 Pl7y.com

extends WorldObject
class_name Enemy

@export var hp: int = 30
@export var hit_radius_px: float = 18.0

# Shooting
@export var bullet_scene: PackedScene
@export var fire_interval: float = 1.2
@export var fire_min_z: float = 18.0
@export var fire_max_z: float = 95.0
@export var bullet_speed: float = 90.0
@export var aim_lead_y: float = 0.0

## Movement strategy (set by EnemySpawner at spawn time).
var movement_strategy: MovementStrategy = null

@onready var sprite := %Sprite2D

@export var explosion_scene: PackedScene

@onready var _label = %Label as Label

var _fire_t: float = 0.0

func _ready() -> void:
  super._ready()
  add_to_group("enemies")
  _fire_t = randf_range(0.0, fire_interval)

  # Initialize movement strategy if set
  if movement_strategy != null:
    movement_strategy.setup(self , rig)
  
  # Connect to escape signal
  escaped.connect(_on_enemy_escaped)


func _on_enemy_escaped(escape_type: WorldObject.EscapeType) -> void:
  # Handle enemy escape - you can add game logic here
  match escape_type:
    WorldObject.EscapeType.BEHIND_CAMERA:
      print("Enemy escaped behind camera")
    WorldObject.EscapeType.OFF_SCREEN_LEFT:
      print("Enemy escaped left")
    WorldObject.EscapeType.OFF_SCREEN_RIGHT:
      print("Enemy escaped right")
    WorldObject.EscapeType.TOO_FAR_AHEAD:
      print("Enemy escaped ahead")
  
  # Example: Notify a game manager, increment escaped counter, etc.
  # if has_node("/root/GameManager"):
  #   get_node("/root/GameManager").on_enemy_escaped(escape_type)

func configure(p_hp: int, p_fire_interval: float, p_bullet_speed: float) -> void:
  hp = p_hp
  fire_interval = p_fire_interval
  bullet_speed = p_bullet_speed

func _process(delta: float) -> void:
  _update_movement(delta)

  # Set label text to world_pos, rounded to first digit
  _label.text = "Pos: (%.1f, %.1f, %.1f)" % [world_pos.x, world_pos.y, world_pos.z]

  # Project + place sprite
  super._process(delta)

  # Shooting (unchanged, but uses current world_pos)
  _try_shoot(delta)

func _update_movement(delta: float) -> void:
  if rig == null:
    return

  # Delegate to movement strategy
  if movement_strategy != null:
    movement_strategy.update(self , rig, delta)

func _try_shoot(delta: float) -> void:
  if rig == null or bullet_scene == null:
    return

  _fire_t -= delta
  if _fire_t > 0.0:
    return

  # Check depth (distance from camera) - negative z is ahead
  var rel_z := world_pos.z - rig.camera_world_position.z
  var depth := -rel_z
  if depth < fire_min_z or depth > fire_max_z:
    return

  _fire_t = fire_interval
  _fire()

func _fire() -> void:
  var b := bullet_scene.instantiate() as EnemyBullet
  get_parent().add_child(b)

  b.world_pos = world_pos

  # Target slightly ahead of camera (negative z is ahead)
  var target := Vector3(rig.camera_world_position.x, rig.camera_world_position.y + aim_lead_y, rig.camera_world_position.z - 10.0)
  var dir := target - b.world_pos
  if dir.length() < 0.001:
    dir = Vector3(0, 0, 1) # Default: toward positive z (toward camera)
  dir = dir.normalized()
  b.vel_direction = dir
  b.vel = dir * bullet_speed

func take_hit(dmg: int) -> void:
  _flash_white()

  var explosion: Explosion = explosion_scene.instantiate()
  explosion.world_pos = world_pos

  hp -= dmg
  
  if hp <= 0:
    get_parent().add_child(explosion)
    queue_free()
  else:
    add_child(explosion)
    
func _flash_white() -> void:
  # Flash white on hit
  if sprite != null:
    sprite.modulate = Color("ff0000")
    get_tree().create_timer(0.1).timeout.connect(func(): sprite.modulate = Color(1, 1, 1, 1))


func _on_hurt_box_area_entered(_area: Area3D) -> void:
  var player = _area.get_parent() as Player
  if player:
    return

  var bullet = _area.get_parent() as Bullet
  if bullet:
    take_hit(bullet.damage)
    bullet.queue_free()
