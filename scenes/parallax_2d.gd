extends Parallax2D
class_name Parallax2DScene

func _process(_delta: float) -> void:
  var camera_rig: CameraRig = get_tree().get_first_node_in_group("camera_rig") as CameraRig
  var player: Player = get_tree().get_first_node_in_group("player") as Player
  if camera_rig and player:
    # Scroll the parallax background based on the camera's position and the player's position.
    # The parallax effect is achieved by multiplying the camera's position by a factor that depends
    # on the player's position. This creates a sense of depth as the background moves at a different speed than the foreground.
    var parallax_factor: float = 0.5 + (player.position.x / 1000.0) * 0.5
    scroll_offset = camera_rig.position * parallax_factor
