extends WorldObject
class_name Enemy

@export var hp: int = 3
@export var hit_radius_px: float = 18.0 # screen-space radius at scale=1

func take_hit(dmg: int) -> void:
  hp -= dmg
  if hp <= 0:
    queue_free()

@export var bullet_scene: PackedScene
@export var fire_interval: float = 1.2
@export var fire_min_z: float = 18.0 # don’t shoot when extremely far
@export var fire_max_z: float = 95.0 # don’t shoot when too close (tune)

@export var bullet_speed: float = 90.0
@export var aim_lead_y: float = 0.0 # small tuning knob later

var _fire_t: float = 0.0

func _ready() -> void:
  super._ready()
  add_to_group("enemies")
  _fire_t = randf_range(0.0, fire_interval) # desync shots

func _process(delta: float) -> void:
  super._process(delta)

  if rig == null or bullet_scene == null:
    return

  _fire_t -= delta
  if _fire_t > 0.0:
    return

  # Only shoot if within a Z band (keeps prototype readable)
  var rel_z := world_pos.z - rig.cam_z
  if rel_z < fire_min_z or rel_z > fire_max_z:
    return

  _fire_t = fire_interval
  _fire()

func _fire() -> void:
  var b := bullet_scene.instantiate() as EnemyBullet
  get_parent().add_child(b) # assumes Enemy is under World node

  # Start bullet at enemy position
  b.world_pos = world_pos

  # Aim at camera/player position in world space at fire time
  var target := Vector3(rig.cam_x, rig.cam_y + aim_lead_y, rig.cam_z + 10.0)

  var dir := (target - b.world_pos)
  if dir.length() < 0.001:
    dir = Vector3(0, 0, -1)

  dir = dir.normalized()
  b.vel = dir * bullet_speed
