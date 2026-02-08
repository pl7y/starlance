extends Node2D

@onready var rig: CameraRig = get_tree().get_first_node_in_group("camera_rig") as CameraRig

@export var half_width: float = 18.0 # world units left/right
@export var near_z: float = 2.0
@export var far_z: float = 120.0

@export var lanes: int = 9 # vertical grid lines
@export var depth_lines: int = 28 # horizontal grid lines

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if rig == null:
		return

	# Lane lines (constant X, varying Z)
	for i in range(lanes):
		var t := 0.0 if lanes == 1 else float(i) / float(lanes - 1)
		var x: float = lerp(-half_width, half_width, t)

		var a := rig.project(Vector3(x, 0.0, rig.cam_z + near_z))
		var b := rig.project(Vector3(x, 0.0, rig.cam_z + far_z))
		if a.visible and b.visible:
			draw_line(a.screen, b.screen, Color(1, 1, 1, 0.35), 1.0)

	# Depth lines (constant Z, varying X)
	for j in range(depth_lines):
		# Non-linear spacing sells perspective: more lines near camera
		var u: float = float(j) / float(depth_lines - 1)
		var z: float = lerp(near_z, far_z, u * u) # quadratic bias

		var left := rig.project(Vector3(-half_width, 0.0, rig.cam_z + z))
		var right := rig.project(Vector3(half_width, 0.0, rig.cam_z + z))
		if left.visible and right.visible:
			draw_line(left.screen, right.screen, Color(1, 1, 1, 0.25), 1.0)
