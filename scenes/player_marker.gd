extends Node2D
@onready var rig: CameraRig = get_tree().get_first_node_in_group("camera_rig") as CameraRig

func _process(_d):
	queue_redraw()

func _draw():
	if rig == null: return
	# player is at camera position projected at a fixed Z distance
	var p = rig.project(Vector3(rig.cam_x, rig.cam_y, rig.cam_z + 10.0))
	if p.visible:
		draw_circle(p.screen, 6.0, Color(1, 1, 1, 0.8))
