extends Node2D
class_name Player

@export var hp: int = 5
@export var invuln_seconds: float = 0.8
@export var hurt_radius_px: float = 14.0 # collision size in SCREEN pixels
@export var player_z_offset: float = 10.0 # where player is “drawn” in front of camera
@export var flash_speed: float = 18.0 # visual blink speed

@onready var rig: CameraRig = get_tree().get_first_node_in_group("camera_rig") as CameraRig

var invuln_t: float = 0.0

func _ready() -> void:
	add_to_group("player")

func _process(delta: float) -> void:
	if rig == null:
		return

	# Update where the player “is” on screen (based on camera X/Y)
	var p := rig.project(Vector3(rig.cam_x, rig.cam_y, rig.cam_z + player_z_offset))
	if p.visible:
		position = p.screen

	# Tick iframes
	invuln_t = maxf(0.0, invuln_t - delta)

	# Simple blink feedback during iframes
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
		# Later: trigger death/run reset
