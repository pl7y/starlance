extends Node
class_name CharacterRenderer

@export var camera: Camera3D
@export var animationPlayer: AnimationPlayer
@export var animation: StringName
@export_range(0, 10) var frames: int
@export_dir var target_directory: String = "res://"
@export var prefix: String = "camera_screenshot_{f}.png"


func _shot(t, f) -> void:
  # Take camera screenshot
  var texture = camera.get_viewport().get_texture()
  var img: Image = texture.get_image()
  var format_string = "{target_directory}/{prefix}"
  var filename = format_string.format({
    "target_directory": target_directory,
    "prefix": prefix,
    "t": t,
    "f": f
  })
  img.save_png(filename)
  prints("Saved camera screenshot to %s" % [filename])

# For testing: take screenshots at the specified times after starting the scene.
func _ready() -> void:
  # Compute shot times based on animation length and frame count
  var anim_length = animationPlayer.get_animation(animation).length / animationPlayer.speed_scale
  var shot_times = []
  for i in frames:
    var t = anim_length * (float(i) / frames)
    shot_times.append(t)

  animationPlayer.play(animation)
  # Wait a frame for animation to update
  await animationPlayer.animation_started

  var frame = 0
  for t in shot_times:
    var timer = Timer.new()
    timer.wait_time = t
    timer.one_shot = true
    timer.connect("timeout", _shot.bind(t, frame))
    add_child(timer)
    timer.start()
    frame += 1
