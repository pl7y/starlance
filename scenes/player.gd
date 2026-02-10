#   ___________           __________                        __                 
#  /   _____/  | _____.__.\______   \_______   ____ _____  |  | __ ___________ 
#  \_____  \|  |/ <   |  | |    |  _/\_  __ \_/ __ \\__  \ |  |/ // __ \_  __ \
#  /        \    < \___  | |    |   \ |  | \/\  ___/ / __ \|    <\  ___/|  | \/
# /_______  /__|_ \/ ____| |______  / |__|    \___  >____  /__|_ \\___  >__|   
#         \/     \/\/             \/              \/     \/     \/    \/       
# (c) 2026 Pl7y.com

extends WorldObject
class_name Player

@export var hp: int = 5
@export var invuln_seconds: float = 0.8
@export var hurt_radius_px: float = 14.0

@export var player_z_offset: float = 12.0 # player “plane” in front of camera
@export var lock_scale: bool = false
@export var locked_scale: float = 1.0

@export var flash_speed: float = 18.0
var invuln_t: float = 0.0

func _ready() -> void:
	super._ready()
	add_to_group("player")

func _process(delta: float) -> void:
	if rig == null:
		return

	# Keep player at a constant depth in front of camera
	world_pos.z = rig.camera_world_position.z + player_z_offset

	invuln_t = maxf(0.0, invuln_t - delta)

	super._process(delta)

	if lock_scale:
		scale = Vector2(locked_scale, locked_scale)

	# if invuln_t > 0.0:
	# 	var blink := (sin(Time.get_ticks_msec() / 1000.0 * flash_speed) * 0.5 + 0.5)
	# 	modulate.a = lerp(0.25, 1.0, blink)
	# else:
	# 	modulate.a = 1.0

func can_be_hit() -> bool:
	return invuln_t <= 0.0

func take_hit(dmg: int) -> void:
	if not can_be_hit():
		return
	hp -= dmg
	invuln_t = invuln_seconds
	print("Player HP:", hp)
