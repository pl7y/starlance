extends Node2D
@onready var rig: CameraRig = get_tree().get_first_node_in_group("camera_rig") as CameraRig

@onready var player_sprite = %Sprite2D as Sprite2D

func _process(_d):
  queue_redraw()

func _draw():
  if rig == null: return
  # player is at camera position projected at a fixed Z distance
  var p = rig.project(Vector3(rig.cam_x, rig.cam_y, rig.cam_z + 100.0))
  player_sprite.visible = p.visible
    # draw_circle(p.screen, 6.0, Color(1, 1, 1, 0.8))
  player_sprite.position = p.screen
  player_sprite.z_index = p.rel_z
  player_sprite.scale = Vector2(p.scale, p.scale)
