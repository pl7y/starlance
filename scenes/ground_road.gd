#   _________ __               .__                              
#  /   _____//  |______ _______|  | _____    ____   ____  ____  
#  \_____  \\   __\__  \\_  __ \  | \__  \  /    \_/ ___\/ __ \ 
#  /        \|  |  / __ \|  | \/  |__/ __ \|   |  \  \__\  ___/ 
# /_______  /|__| (____  /__|  |____(____  /___|  /\___  >___  >
#         \/           \/                \/     \/     \/    \/ 
# (c) 2026 Pl7y.com
# Space Harrier-style pseudo-3D ground plane renderer

extends Node2D
class_name GroundRoad

# Ground rendering parameters

@export var z_bias: float = 1.0 # Prevents division by zero and adjusts near distance
@export var tile_size_x: float = 50.0 # Width of ground tiles in world units
@export var tile_size_z: float = 50.0 # Depth of ground tiles in world units

# Visual styling
@export var color_1: Color = Color(0.2, 0.6, 0.2) # Green checker
@export var color_2: Color = Color(0.15, 0.5, 0.15) # Darker green
@export var fog_color: Color = Color(0.4, 0.6, 0.8) # Sky/haze color
@export var fog_start: float = 0.3 # Start fog at this ratio from horizon (0-1)
@export var fog_end: float = 1.0 # Full fog at this ratio

# Rendering optimization
@export var scanline_step: int = 1 # Draw every Nth scanline (1=all, 2=half, etc.)

# Cache
var camera_rig: CameraRig
var screen_width: int
var screen_height: int
var horizon_y: int


func _ready() -> void:
	# Find camera rig in scene tree
	camera_rig = get_tree().get_first_node_in_group("camera_rig") as CameraRig
	if camera_rig == null:
		push_error("GroundRoad: No CameraRig found in 'camera_rig' group!")
	_update_screen_params()


func _process(_delta: float) -> void:
	queue_redraw() # Request redraw every frame for animation


func _update_screen_params() -> void:
	var vp := get_viewport().get_visible_rect().size
	screen_width = int(vp.x)
	screen_height = int(vp.y)
	if camera_rig:
		horizon_y = int(camera_rig.horizon_y)


func _draw() -> void:
	if camera_rig == null:
		return
		
	_update_screen_params()
	
	var focal_len := camera_rig.focal
	var cam_x := camera_rig.camera_world_position.x
	var cam_y := camera_rig.camera_world_position.y
	var cam_z := camera_rig.camera_world_position.z
	var bank := camera_rig.bank
	var bank_offset := bank * camera_rig.bank_pixels
	
	var half_width := screen_width * 0.5
	
	# Render scanlines from horizon to bottom of screen
	for y in range(horizon_y + 1, screen_height, scanline_step):
		# Compute distance from camera for this scanline
		# The ground is at world Y=0, camera is at cam_y above it
		# Uses same perspective calculation as camera rig projection
		var scanline_offset := float(y - horizon_y)
		var z_distance := (focal_len * cam_y) / (scanline_offset + z_bias)
		
		# Fog factor based on scanline proximity to horizon (0 = at horizon, 1 = bottom)
		var fog_ratio: float = clamp((scanline_offset / (screen_height - horizon_y) - fog_start) / (fog_end - fog_start), 0.0, 1.0)
		
		# Draw horizontal line for this scanline
		var prev_color: Color
		var segment_start_x := 0
		
		for x in range(screen_width):
			# Compute world X coordinate for this pixel
			# Account for camera banking effect on vanishing point
			var screen_x_offset := float(x) - half_width - bank_offset
			var x_world := (screen_x_offset * z_distance) / focal_len + cam_x
			
			# Compute world Z coordinate (negative Z is forward in this system)
			var z_world := cam_z - z_distance
			
			# Sample pattern using floor division for tile coordinates
			var tile_x := int(floor(x_world / tile_size_x))
			var tile_z := int(floor(z_world / tile_size_z))
			
			# Checkerboard pattern: alternate colors based on parity of tile sum
			var tile_parity := (tile_x + tile_z) % 2
			var base_color := color_1 if tile_parity == 0 else color_2
			
			# Apply fog
			var final_color := base_color.lerp(fog_color, fog_ratio)
			
			# Batch horizontal segments of same color for performance
			if x == 0:
				prev_color = final_color
				segment_start_x = 0
			elif final_color != prev_color or x == screen_width - 1:
				# Draw the segment
				var segment_end_x := x if final_color != prev_color else x + 1
				draw_line(Vector2(segment_start_x, y), Vector2(segment_end_x, y), prev_color, scanline_step)
				prev_color = final_color
				segment_start_x = x
