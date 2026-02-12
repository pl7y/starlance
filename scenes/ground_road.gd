extends Node2D

@export var horizon_ratio := 0.35
@export var focal := 320.0

@export var near_z := 6.0
@export var far_z := 220.0

@export var speed := 35.0

# Curve (OutRun-ish optional bend)
@export var curve_strength := 0.0
@export var curve_freq := 0.12

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

var cam_z := 0.0

var rig: CameraRig

func _ready() -> void:
  rig = get_tree().get_first_node_in_group("camera_rig") as CameraRig

func _process(delta: float) -> void:
  cam_z += speed * delta
  # cam_z = rig.camera_world_position.z
  queue_redraw()

func _draw() -> void:
  var vp := get_viewport_rect().size
  var horizon_y := vp.y * horizon_ratio
  var cx := vp.x * 0.5

  # Optional sky fill
  draw_rect(Rect2(Vector2.ZERO, Vector2(vp.x, horizon_y + 1.0)), sky_color, true)

  for y in range(int(horizon_y), int(vp.y)):
    var dy := float(y) - horizon_y
    if dy < 1.0:
      continue

    # Perspective: row -> distance

    var z := (camera_height * focal) / dy


    var scale_ := focal / z

    # Curve offset in pixels (falls off with distance)
    var curve := sin((cam_z + z) * curve_freq) * curve_strength
    var x_shift_px := curve * 220.0 * (1.0 / (1.0 + z * 0.02))
    var center_x := cx + x_shift_px

    # World Z position for tiling (scrolling)
    var wz := cam_z + z

    # Fog factor (0 near -> 1 far)
    var fog_t: float = clamp((z - near_z) / max(far_z - near_z, 0.001), 0.0, 1.0)
    var fog := pow(fog_t, fog_power) * fog_strength

    # Convert screen edges into world X range visible on this scanline
    var wx0 := (0.0 - center_x) / scale_
    var wx1 := (vp.x - center_x) / scale_
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
      var sx_a := center_x + wx_a * scale_
      var sx_b := center_x + wx_b * scale_

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
    var x1 := center_x - road_half_px
    var x2 := center_x + road_half_px
    var edge := Color(1, 1, 1, 0.10).lerp(sky_color, fog)
    draw_line(Vector2(clampf(x1, 0, vp.x), y), Vector2(clampf(x1, 0, vp.x), y), edge, 2.0)
    draw_line(Vector2(clampf(x2, 0, vp.x), y), Vector2(clampf(x2, 0, vp.x), y), edge, 2.0)
