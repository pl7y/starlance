extends Node
class_name CharacterRenderer

@export var camera: Camera3D
@export var animationPlayer: AnimationPlayer
@export var animation: StringName
@export_range(0, 10) var frames: int
@export_dir var target_directory: String = "res://"
@export var prefix: String = "camera_screenshot_{f}.png"
@export var spritesheet_prefix: String = "spritesheet.png"
@export var lag = 3
@export var viewport: Viewport

var shot_once = false
var shot_times = []
var time = 0
var last_shot_time_msec = 0
var images: Array[Image] = []

func _shot(t, f, total_frames) -> void:
  # Take camera screenshot
  var texture = viewport.get_texture()
  var img: Image = texture.get_image()

  var size = img.get_size()
  var min_size = min(size.x, size.y)
  # crop image to centered min_size square
  var crop_rect = Rect2((Vector2(size.x, size.y) - Vector2(min_size, min_size)) / 2, Vector2(min_size, min_size))
  img.crop(crop_rect.size.x, crop_rect.size.y)

  var format_string = "{target_directory}/{prefix}"
  var filename = format_string.format({
    "target_directory": target_directory,
    "prefix": prefix,
    "t": t,
    "f": f
  })
  img.save_png(filename)
  images.append(img)
  var current_time_msec = Time.get_ticks_msec()
  var actual_elapsed = 0.0 if f == 0 else (current_time_msec - last_shot_time_msec) / 1000.0
  last_shot_time_msec = current_time_msec
  prints("Saved camera screenshot to %s at frame %d (actual elapsed: %.3f s)" % [filename, f, actual_elapsed])

  if f == total_frames:
    prints("All frames captured.")

    save_spritesheet()
    
    get_tree().quit()

func save_spritesheet() -> void:
  if images.size() == 0:
    prints("No images to save for spritesheet.")
    return

  var img_size = images[0].get_size()
  var sheet_width = img_size.x * frames
  var sheet_height = img_size.y
  var sheet_image = Image.create(sheet_width, sheet_height, false, images[0].get_format())

  for i in range(images.size()):
    var x_offset = i * img_size.x
    sheet_image.blit_rect(images[i], Rect2(Vector2.ZERO, img_size), Vector2(x_offset, 0))

  var filename = "%s/%s" % [target_directory, spritesheet_prefix]
  sheet_image.save_png(filename)
  prints("Saved spritesheet to %s" % filename)

# For testing: take screenshots at the specified times after starting the scene.
func _ready() -> void:
  prints("CharacterRenderer ready. Starting animation and scheduling shots.")
  # Compute shot times based on animation length and frame count
  var anim_length = animationPlayer.get_animation(animation).length / animationPlayer.speed_scale
  for i in frames - 1:
    var t = anim_length * (float(i + 1) / frames)
    shot_times.append(t)

  prints("Animation length: %f seconds. Scheduling shots at times: %s" % [anim_length, shot_times])

func _process(delta: float) -> void:
  time += delta
  if time > lag - delta and not shot_once:
    animationPlayer.play(animation) # restart to ensure consistent timing
  if time > lag and not shot_once:
    shot_once = true


    # Short first frame immediately to capture initial pose
    _shot(0.0, 0, shot_times.size())

    
    var frame = 1
    for t in shot_times:
      var timer = Timer.new()
      timer.wait_time = t
      timer.one_shot = true
      timer.connect("timeout", _shot.bind(t, frame, shot_times.size()))
      add_child(timer)
      timer.start()
      frame += 1
