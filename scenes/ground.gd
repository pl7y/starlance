extends ColorRect

@onready var rig: CameraRig = get_tree().get_first_node_in_group("camera_rig") as CameraRig

@export var near_z: float = 5.0
@export var far_z: float = 2000.0
@export var tile_size: float = 20.0 # Size of tiles/stripes in world units

@export_enum("Checkers", "Hatched", "Horizontal Stripes") var pattern: int = 0
@export var band_width: float = 0.4 # Width of bands for hatched pattern (0.0-1.0)

func _ready() -> void:
	# Fill the entire viewport
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if material:
		print("Ground shader material found!")
	else:
		print("WARNING: No material on Ground! Create a ShaderMaterial and assign ground.gdshader to it")

func _process(_delta: float) -> void:
	if rig == null:
		push_warning("Ground: CameraRig not found!")
		return
	if material == null:
		push_warning("Ground: Material not set!")
		return
	
	# Update shader parameters with camera state
	var vp := get_viewport().get_visible_rect().size
	material.set_shader_parameter("focal", rig.focal)
	material.set_shader_parameter("screen_center", Vector2(vp.x * 0.5, vp.y * 0.5))
	material.set_shader_parameter("horizon_y", rig.horizon_y)
	material.set_shader_parameter("camera_world_pos", rig.camera_world_position)
	material.set_shader_parameter("bank_offset", rig.bank * rig.bank_pixels)
	
	# Update grid parameters
	material.set_shader_parameter("near_z", near_z)
	material.set_shader_parameter("far_z", far_z)
	material.set_shader_parameter("tile_size", tile_size)
	material.set_shader_parameter("pattern", pattern)
	material.set_shader_parameter("band_width", band_width)
