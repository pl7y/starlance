extends WorldObject
class_name Player

@export var hp: int = 5
@export var invuln_seconds: float = 0.8
@export var hurt_radius_px: float = 14.0 # screen-space radius
@export var player_z_offset: float = 10.0 # how far in front of camera the player is drawn
@export var muzzle_z_offset: float = 6.0 # useful later for bullet spawning

@export var flash_speed: float = 18.0 # blink speed during iframes
@export var lock_scale: bool = false # keep player same size on screen
@export var locked_scale: float = 1.0 # only used if lock_scale=true

var invuln_t: float = 0.0

func _ready() -> void:
  super._ready()
  add_to_group("player")

func _process(delta: float) -> void:
  if rig == null:
    return

  # Anchor player to camera in world space
  world_pos.x = rig.cam_x
  world_pos.y = rig.cam_y
  world_pos.z = rig.cam_z + player_z_offset

  # Tick iframes
  invuln_t = maxf(0.0, invuln_t - delta)

  # Use WorldObject projection to update position/scale/z_index
  super._process(delta)

  # Optional: keep player sprite size constant (more arcade-like)
  if lock_scale:
    scale = Vector2(locked_scale, locked_scale)

  # Blink feedback during iframes
  if invuln_t > 0.0:
    var blink := (sin(Time.get_ticks_msec() / 1000.0 * flash_speed) * 0.5 + 0.5)
    modulate.a = lerp(0.25, 1.0, blink)
  else:
    modulate.a = 1.0

func can_be_hit() -> bool:
  return invuln_t <= 0.0

func take_hit(dmg: int) -> void:
  if not can_be_hit():
    return
  hp -= dmg
  invuln_t = invuln_seconds
  print("Player HP:", hp)
  if hp <= 0:
    print("DEAD (prototype)")
    # Later: emit a signal / trigger run reset

func get_muzzle_world_pos() -> Vector3:
  # Handy for the Shooter: spawn bullets from player's world position
  return Vector3(world_pos.x, world_pos.y, rig.cam_z + muzzle_z_offset)
