extends Node2D

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

@export var near_z := 6.0
@export var far_z := 220.0

# Ground plane height in world space (Y = 0 typically)
@export var ground_y := 0.0

var rig: CameraRig
var player: Player

func _ready() -> void:
  rig = get_tree().get_first_node_in_group("camera_rig") as CameraRig
  player = get_tree().get_first_node_in_group("player") as Player

func _process(_delta: float) -> void:
  queue_redraw()

func _draw() -> void:
  if not rig:
    return
    
  var vp := get_viewport_rect().size
  var horizon_y := rig.horizon_y

  # Optional sky fill
  draw_rect(Rect2(Vector2.ZERO, Vector2(vp.x, horizon_y + 1.0)), sky_color, true)

  # For each scanline below the horizon, find the world Z that projects to that Y
  for y in range(int(horizon_y), int(vp.y)):
    var dy := float(y) - horizon_y
    if dy < 1.0:
      continue

    # Calculate world Z position where ground plane (world Y = ground_y) projects to screen Y
    # From camera_rig.project(): sy = horizon_y - rel.y * scale, where scale = focal / depth
    # For ground: rel.y = ground_y - camera_world_position.y
    # So: y = horizon_y - (ground_y - camera_world_position.y) * (focal / depth)
    # Solving for depth: depth = (ground_y - camera_world_position.y) * focal / (horizon_y - y)
    
    var rel_y := ground_y - rig.camera_world_position.y
    var depth := (rel_y * rig.focal) / dy
    
    if depth <= 0.1:
      continue
    
    # World Z position for this scanline (negative depth means ahead)
    var wz := rig.camera_world_position.z - depth
    
    # Fog factor (0 near -> 1 far)
    var fog_t: float = clamp((depth - near_z) / max(far_z - near_z, 0.001), 0.0, 1.0)
    var fog := pow(fog_t, fog_power) * fog_strength
    
    # Scale at this depth
    var scale_ := rig.focal / depth
    
    # Convert screen edges to world X at this depth
    # From camera_rig.project(): sx = (center.x + bank * bank_pixels) + rel.x * scale
    # Where rel.x = world_x - camera_world_position.x
    # Solving for world_x: world_x = (sx - center.x - bank * bank_pixels) / scale + camera_world_position.x
    
    var screen_center := rig.center.x + rig.bank * rig.bank_pixels
    var wx0 := (0.0 - screen_center) / scale_ + rig.camera_world_position.x
    var wx1 := (vp.x - screen_center) / scale_ + rig.camera_world_position.x
    
    if wx0 > wx1:
      var tmp := wx0
      wx0 = wx1
      wx1 = tmp

    # Which tile row are we in? (constant for this scanline)
    var iz := int(floor(wz / tile_z))

    # Tile column range visible
    var i0 := int(floor(wx0 / tile_x)) - 1
    var i1 := int(floor(wx1 / tile_x)) + 1

    # Draw the tiled ground across the whole width
    for ix in range(i0, i1 + 1):
      var wx_a := float(ix) * tile_x
      var wx_b := float(ix + 1) * tile_x

      # Convert world X back to screen using camera_rig projection
      var world_pos_a := Vector3(wx_a, ground_y, wz)
      var world_pos_b := Vector3(wx_b, ground_y, wz)
      
      var proj_a := rig.project(world_pos_a)
      var proj_b := rig.project(world_pos_b)
      
      if not proj_a.visible or not proj_b.visible:
        continue
      
      var sx_a := proj_a.screen.x
      var sx_b := proj_b.screen.x

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

      # Optional thin outline at tile boundary (helps "square" read)
      if tile_outline_alpha > 0.0:
        var edge_col := Color(1, 1, 1, tile_outline_alpha).lerp(sky_color, fog)
        # draw boundary at the start of the tile
        if x_a > 0.0 and x_a < vp.x:
          draw_line(Vector2(x_a, y), Vector2(x_a, y), edge_col, 1.0)

    # Optional: draw "road edges" over the tiles (OutRun flavor)
    var world_pos_left := Vector3(rig.camera_world_position.x - road_half_width_world, ground_y, wz)
    var world_pos_right := Vector3(rig.camera_world_position.x + road_half_width_world, ground_y, wz)
    var proj_left := rig.project(world_pos_left)
    var proj_right := rig.project(world_pos_right)
    
    if proj_left.visible and proj_right.visible:
      var x1 := proj_left.screen.x
      var x2 := proj_right.screen.x
      var edge := Color(1, 1, 1, 0.10).lerp(sky_color, fog)
      draw_line(Vector2(clampf(x1, 0, vp.x), y), Vector2(clampf(x1, 0, vp.x), y), edge, 2.0)
      draw_line(Vector2(clampf(x2, 0, vp.x), y), Vector2(clampf(x2, 0, vp.x), y), edge, 2.0)
