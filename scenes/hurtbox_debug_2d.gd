# HurtboxDebug2D.gd
extends Node2D
class_name HurtboxDebug2D

@export var _area_3d: PseudoArea3D
@export var segments := 24
@export var color: Color = Color.RED

@onready var rig: CameraRig = get_tree().get_first_node_in_group("camera_rig") as CameraRig

func _process(_dt: float) -> void:
  queue_redraw() # redraw each frame while debugging

func project_3d_to_2d(p: Vector3) -> Vector2:
  return rig.project(p).screen

func _draw() -> void:
  # Get first CollisionShape3d child of _area_3d and its shape.
  var collision_shape := _area_3d.get_node_or_null("CollisionShape3D") as CollisionShape3D
  var shape := collision_shape.shape

  if shape is BoxShape3D:
    _draw_box(shape as BoxShape3D, _area_3d.global_transform)
  elif shape is SphereShape3D:
    _draw_sphere(shape as SphereShape3D, _area_3d.global_transform)
  elif shape is CapsuleShape3D:
    _draw_capsule(shape as CapsuleShape3D, _area_3d.global_transform)
  else:
    push_warning("Unsupported shape type for HurtboxDebug2D: " + str(shape))
  # Add CapsuleShape3D / CylinderShape3D etc. as needed.

func _draw_box(box: BoxShape3D, xf: Transform3D) -> void:
  var e := box.size * 0.5
  var local_pts: Array[Vector3] = [
    Vector3(-e.x, -e.y, -e.z),
    Vector3(e.x, -e.y, -e.z),
    Vector3(e.x, -e.y, e.z),
    Vector3(-e.x, -e.y, e.z),
    Vector3(-e.x, e.y, -e.z),
    Vector3(e.x, e.y, -e.z),
    Vector3(e.x, e.y, e.z),
    Vector3(-e.x, e.y, e.z),
  ]

  var pts2d: Array[Vector2] = []
  pts2d.resize(8)
  for i in local_pts.size():
    var wp := xf * local_pts[i]
    pts2d[i] = project_3d_to_2d(wp)

  # Draw bottom rectangle + top rectangle + vertical edges
  var bottom := [0, 1, 2, 3, 0]
  var top := [4, 5, 6, 7, 4]

  for i in range(bottom.size() - 1):
    draw_line(pts2d[bottom[i]], pts2d[bottom[i + 1]], color, 2.0)
  for i in range(top.size() - 1):
    draw_line(pts2d[top[i]], pts2d[top[i + 1]], color, 2.0)
  for i in range(4):
    draw_line(pts2d[i], pts2d[i + 4], color, 2.0)

enum CollisionPlane {XY, XZ, YZ}

func _draw_sphere(s: SphereShape3D, xf: Transform3D) -> void:
  var center := xf.origin
  var r := s.radius

  _draw_circle_on_plane(center, xf.basis, r, CollisionPlane.XY)
  _draw_circle_on_plane(center, xf.basis, r, CollisionPlane.XZ)
  _draw_circle_on_plane(center, xf.basis, r, CollisionPlane.YZ)

func _draw_capsule(c: CapsuleShape3D, xf: Transform3D) -> void:
  var r := c.radius
  var half_h := c.height * 0.5
  var axis := xf.basis.y
  var center := xf.origin
  var cylinder_half := maxf(0.0, half_h - r)
  var top_center := center + axis * cylinder_half
  var bottom_center := center - axis * cylinder_half

  _draw_circle_on_plane(top_center, xf.basis, r, CollisionPlane.XY)
  _draw_circle_on_plane(top_center, xf.basis, r, CollisionPlane.XZ)
  _draw_circle_on_plane(top_center, xf.basis, r, CollisionPlane.YZ)
  _draw_circle_on_plane(bottom_center, xf.basis, r, CollisionPlane.XY)
  _draw_circle_on_plane(bottom_center, xf.basis, r, CollisionPlane.XZ)
  _draw_circle_on_plane(bottom_center, xf.basis, r, CollisionPlane.YZ)

  var side_dirs: Array[Vector3] = [xf.basis.x, -xf.basis.x, xf.basis.z, -xf.basis.z]
  for dir in side_dirs:
    var p1 := bottom_center + dir * r
    var p2 := top_center + dir * r
    draw_line(project_3d_to_2d(p1), project_3d_to_2d(p2), color, 2.0)

func _draw_circle_on_plane(center: Vector3, basis: Basis, radius: float, plane: int) -> void:
  var prev: Vector2
  
  for i in range(segments + 1):
    var a := TAU * float(i) / float(segments)
    var cos_a := cos(a)
    var sin_a := sin(a)
    
    # Calculate point based on plane
    var local_point: Vector3
    match plane:
      CollisionPlane.XY:
        local_point = Vector3(cos_a * radius, sin_a * radius, 0.0)
      CollisionPlane.XZ:
        local_point = Vector3(cos_a * radius, 0.0, sin_a * radius)
      CollisionPlane.YZ:
        local_point = Vector3(0.0, cos_a * radius, sin_a * radius)
    
    var wp := center + basis * local_point
    var p2 := project_3d_to_2d(wp)

    if i > 0:
      draw_set_transform_matrix(global_transform.affine_inverse())
      draw_line(prev, p2, color, 2.0)
    prev = p2