#   _________ __               .__                              
#  /   _____//  |______ _______|  | _____    ____   ____  ____  
#  \_____  \\   __\__  \\_  __ \  | \__  \  /    \_/ ___\/ __ \ 
#  /        \|  |  / __ \|  | \/  |__/ __ \|   |  \  \__\  ___/ 
# /_______  /|__| (____  /__|  |____(____  /___|  /\___  >___  >
#         \/           \/                \/     \/     \/    \/ 
# (c) 2026 Pl7y.com

extends WorldObject
class_name Enemy

enum MovePattern {STATIC, DRIFT, SINE_STRAFE, DIVE_AT_PLAYER, SWOOP, ORBIT}

@export var hp: int = 30
@export var hit_radius_px: float = 18.0

# Shooting
@export var bullet_scene: PackedScene
@export var fire_interval: float = 1.2
@export var fire_min_z: float = 18.0
@export var fire_max_z: float = 95.0
@export var bullet_speed: float = 90.0
@export var aim_lead_y: float = 0.0

# Movement
@export var pattern: MovePattern = MovePattern.STATIC
@export var speed_z: float = -12.0 # negative = moves toward camera
@export var speed_x: float = 0.0
@export var speed_y: float = 0.0

# Sine/curve params
@export var amp_x: float = 4.0
@export var amp_y: float = 2.0
@export var freq: float = 1.2

# Dive params
@export var dive_turn: float = 2.5 # higher = homes faster (but keep readable)

# Orbit params
@export var orbit_radius: float = 6.0
@export var orbit_speed: float = 1.5

@onready var sprite := %Sprite2D

@export var explosion_scene: PackedScene

@onready var _label = %Label as Label

var _fire_t: float = 0.0
var _age: float = 0.0
var _spawn_pos: Vector3
var _orbit_angle: float = 0.0

func _ready() -> void:
  super._ready()
  add_to_group("enemies")
  _fire_t = randf_range(0.0, fire_interval)
  _age = 0.0
  _spawn_pos = world_pos
  _orbit_angle = randf_range(0.0, TAU)

func configure(p_hp: int, p_fire_interval: float, p_bullet_speed: float, p_pattern := MovePattern.STATIC) -> void:
  hp = p_hp
  fire_interval = p_fire_interval
  bullet_speed = p_bullet_speed
  pattern = p_pattern

func _process(delta: float) -> void:
  _age += delta

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

  match pattern:
    MovePattern.STATIC:
      # no-op
      pass

    MovePattern.DRIFT:
      world_pos.x += speed_x * delta
      world_pos.y += speed_y * delta
      world_pos.z -= speed_z * delta

    MovePattern.SINE_STRAFE:
      # Moves forward/back via speed_z, with sinusoidal x (and optional y)
      world_pos.z -= speed_z * delta
      world_pos.x = _spawn_pos.x + sin(_age * TAU * freq) * amp_x
      world_pos.y = _spawn_pos.y + sin(_age * TAU * (freq * 0.7)) * amp_y

    MovePattern.DIVE_AT_PLAYER:
      # Smoothly home towards camera X/Y while advancing in Z
      world_pos.z -= speed_z * delta

      var target_x := rig.camera_world_position.x
      var target_y := rig.camera_world_position.y
      world_pos.x = lerp(world_pos.x, target_x, 1.0 - exp(-dive_turn * delta))
      world_pos.y = lerp(world_pos.y, target_y, 1.0 - exp(-dive_turn * delta))

    MovePattern.SWOOP:
      # A readable “arc”: starts offset, crosses center, exits
      world_pos.z -= speed_z * delta
      world_pos.x = _spawn_pos.x + sin(_age * TAU * freq) * amp_x
      world_pos.y = _spawn_pos.y + cos(_age * TAU * freq) * amp_y

    MovePattern.ORBIT:
      # Orbits around a point in front of camera (feels 3D-ish even in fake 3D)
      world_pos.z -= speed_z * delta
      _orbit_angle += orbit_speed * delta
      var cx := rig.camera_world_position.x
      var cy := rig.camera_world_position.y
      world_pos.x = cx + cos(_orbit_angle) * orbit_radius
      world_pos.y = cy + sin(_orbit_angle) * (orbit_radius * 0.6)

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


func _on_hurt_box_area_entered(area: Area3D) -> void:
  take_hit(10) # TODO: use actual damage value from bullet
