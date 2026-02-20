## Volume-based formation: randomly distributes units within a 3D shape.
## Returns 2D offsets (X, Y) sampled from the shape's X-Y plane projection.
@tool
extends Formation
class_name VolumeFormation

## The 3D shape to sample positions from.
@export var volume: Shape3D


func get_offsets(count: int, rng: RandomNumberGenerator = null) -> Array[Vector2]:
  var offsets: Array[Vector2] = []
  
  if volume == null or rng == null:
    # No volume or RNG provided - return zeros
    for i in count:
      offsets.append(Vector2.ZERO)
    return offsets
  
  # Sample random 3D points and project to 2D (X, Y)
  for i in count:
    var point_3d := _sample_point_in_shape(volume, rng)
    offsets.append(Vector2(point_3d.x, point_3d.y))
  
  return offsets


## Sample a random point within a Shape3D.
## Supports common shapes: BoxShape3D, SphereShape3D, CapsuleShape3D, CylinderShape3D.
func _sample_point_in_shape(shape: Shape3D, rng: RandomNumberGenerator) -> Vector3:
  if shape is BoxShape3D:
    var box := shape as BoxShape3D
    var size := box.size
    return Vector3(
      rng.randf_range(-size.x * 0.5, size.x * 0.5),
      rng.randf_range(-size.y * 0.5, size.y * 0.5),
      rng.randf_range(-size.z * 0.5, size.z * 0.5)
    )
  
  elif shape is SphereShape3D:
    var sphere := shape as SphereShape3D
    var radius := sphere.radius
    # Uniform sampling within a sphere using rejection sampling
    var point := Vector3.ZERO
    var max_attempts := 100
    for attempt in max_attempts:
      point = Vector3(
        rng.randf_range(-1.0, 1.0),
        rng.randf_range(-1.0, 1.0),
        rng.randf_range(-1.0, 1.0)
      )
      if point.length_squared() <= 1.0:
        break
    return point.normalized() * rng.randf_range(0.0, radius)
  
  elif shape is CapsuleShape3D:
    var capsule := shape as CapsuleShape3D
    var radius := capsule.radius
    var height := capsule.height
    # Sample within cylinder part + hemisphere caps
    var cylinder_height := height - 2.0 * radius
    if cylinder_height > 0:
      # Randomly choose cylinder or caps
      var total_volume := PI * radius * radius * cylinder_height + (4.0 / 3.0) * PI * radius * radius * radius
      if rng.randf() < (PI * radius * radius * cylinder_height) / total_volume:
        # Cylinder part
        var angle := rng.randf() * TAU
        var r := sqrt(rng.randf()) * radius
        var y := rng.randf_range(-cylinder_height * 0.5, cylinder_height * 0.5)
        return Vector3(r * cos(angle), y, r * sin(angle))
      else:
        # Hemisphere caps - simplified: sample sphere and offset
        var point := Vector3.ZERO
        for attempt in 100:
          point = Vector3(
            rng.randf_range(-1.0, 1.0),
            rng.randf_range(-1.0, 1.0),
            rng.randf_range(-1.0, 1.0)
          )
          if point.length_squared() <= 1.0:
            break
        point = point.normalized() * rng.randf_range(0.0, radius)
        point.y += cylinder_height * 0.5 if point.y > 0 else -cylinder_height * 0.5
        return point
    else:
      # Degenerate: just a sphere
      var sphere := SphereShape3D.new()
      sphere.radius = radius
      return _sample_point_in_shape(sphere, rng)
  
  elif shape is CylinderShape3D:
    var cylinder := shape as CylinderShape3D
    var radius := cylinder.radius
    var height := cylinder.height
    var angle := rng.randf() * TAU
    var r := sqrt(rng.randf()) * radius
    var y := rng.randf_range(-height * 0.5, height * 0.5)
    return Vector3(r * cos(angle), y, r * sin(angle))
  
  else:
    push_warning("Unsupported Shape3D type: %s — returning zero." % shape.get_class())
    return Vector3.ZERO
