extends Node2D

@export var horizon_ratio := 0.75
var _horizon_ratio := horizon_ratio
var _horizon_ratio_target := horizon_ratio

@export var focal := 320.0

@export var near_z := 6.0
@export var far_z := 220.0

# Vanishing point position (0.0 = left edge, 0.5 = center, 1.0 = right edge)
@export_range(0.0, 1.0) var vanishing_point := 0.5

# ROAD placement in world units (still used for optional edge lines)
@export var road_half_width_world := 10.0
@export var shoulder_world := 5.0

# --- TILE PATTERN (this is the Space Harrier/OutRun banded squares/rectangles) ---
@export var tile_x := 8.0 # tile width in WORLD units
@export var tile_z := 6.0 # tile depth in WORLD units (set != tile_x for rectangles)
@export var tile_color_a := Color(0.07, 0.22, 0.10, 1.0)
@export var tile_color_b := Color(0.05, 0.18, 0.09, 1.0)

# optional outline lines between tiles
@export var tile_outline_alpha := 0.12

# Fog toward horizon
@export var sky_color := Color(0.55, 0.35, 0.75, 1.0)
@export var fog_strength := 1.0
@export var fog_power := 1.6

@export var camera_height := 12.0

# Lerp factors for camera-driven ground perspective (x: vanishing point, y: horizon)
@export var camera_ground_lerp := Vector2(0.01, 0.01)

var cam_z := 0.0

var rig: CameraRig

var player: Player

func _ready() -> void:
  rig = get_tree().get_first_node_in_group("camera_rig") as CameraRig
  player = get_tree().get_first_node_in_group("player") as Player

func _process(delta: float) -> void:
  # Update vanishing_point to be opposite of player position 
  # (e.g. if player is on left side of screen, vanishing point 
  # moves to right) damped for smoothness and reduced by some
  # factor. Horizontal movement is allowed to one third from 
  # center in either direction before vanishing point hits the edge.
  var target_vp := 0.5 - (player.position.x / get_viewport_rect().size.x - 0.5) * 0.33
  vanishing_point = lerp(vanishing_point, target_vp, camera_ground_lerp.x)


  var speed = player.speed / 50.0
  cam_z += speed * delta
  # cam_z = rig.camera_world_position.z

  # Get screen position of player wrt viewport height
  var vp := get_viewport_rect().size
  var horizon_r := player.position.y / vp.y

  # Move horizon height up if player is low on the screen (e.g. falling), 
  # down if high (e.g. jumping).  
  _horizon_ratio_target = horizon_ratio + (horizon_r - horizon_ratio) * 0.5
  _horizon_ratio = _horizon_ratio_target # lerp(_horizon_ratio, _horizon_ratio_target, camera_ground_lerp.y)

  camera_height = 1 - horizon_r

  queue_redraw()

func _draw() -> void:
  var vp := get_viewport_rect().size
  var horizon_y := vp.y * _horizon_ratio
  var cx := vp.x * vanishing_point

  # Optional sky fill
  draw_rect(Rect2(Vector2.ZERO, Vector2(vp.x, horizon_y + 1.0)), sky_color, true)

  for y in range(int(horizon_y), int(vp.y)):
    var dy := float(y) - horizon_y
    if dy < 1.0:
      continue

    # Perspective: row -> distance

    var z := (camera_height * focal) / dy
    var scale_ := focal / z

    # World Z position for tiling (scrolling)
    var wz := cam_z + z

    # Fog factor (0 near -> 1 far)
    var fog_t: float = clamp((z - near_z) / max(far_z - near_z, 0.001), 0.0, 1.0)
    var fog := pow(fog_t, fog_power) * fog_strength

    # Convert screen edges into world X range visible on this scanline
    var wx0 := (0.0 - cx) / scale_
    var wx1 := (vp.x - cx) / scale_
    if wx0 > wx1:
      var tmp := wx0
      wx0 = wx1
      wx1 = tmp

    # Which tile row are we in? (constant for this scanline)
    var iz := int(floor(wz / tile_z))

    # Tile column range visible
    var i0 := int(floor(wx0 / tile_x)) - 1
    var i1 := int(floor(wx1 / tile_x)) + 1

    # Draw the tiled ground across the whole width (or clamp to a “ground plane” width if you want)
    for ix in range(i0, i1 + 1):
      var wx_a := float(ix) * tile_x
      var wx_b := float(ix + 1) * tile_x

      # Convert back to screen
      var sx_a := cx + wx_a * scale_
      var sx_b := cx + wx_b * scale_

      # Clamp to viewport
      var x_a := clampf(minf(sx_a, sx_b), 0.0, vp.x)
      var x_b := clampf(maxf(sx_a, sx_b), 0.0, vp.x)
      if x_b <= x_a:
        continue

      # Checker parity (squares/rectangles)
      var parity := (ix + iz) & 1
      var base_col := tile_color_a if parity == 0 else tile_color_b

      # Fog toward sky color
      var col := base_col.lerp(sky_color, fog)

      # Fill this scanline segment
      draw_line(Vector2(x_a, y), Vector2(x_b, y), col, 1.0)

      # Optional thin outline at tile boundary (helps “square” read)
      if tile_outline_alpha > 0.0:
        var edge_col := Color(1, 1, 1, tile_outline_alpha).lerp(sky_color, fog)
        # draw boundary at the start of the tile
        if x_a > 0.0 and x_a < vp.x:
          draw_line(Vector2(x_a, y), Vector2(x_a, y), edge_col, 1.0)

    # Optional: draw “road edges” over the tiles (OutRun flavor)
    var road_half_px := road_half_width_world * scale_
    var x1 := cx - road_half_px
    var x2 := cx + road_half_px
    var edge := Color(1, 1, 1, 0.10).lerp(sky_color, fog)
    draw_line(Vector2(clampf(x1, 0, vp.x), y), Vector2(clampf(x1, 0, vp.x), y), edge, 2.0)
    draw_line(Vector2(clampf(x2, 0, vp.x), y), Vector2(clampf(x2, 0, vp.x), y), edge, 2.0)
