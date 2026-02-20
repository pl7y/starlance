## Polyline movement strategy - follows a sequence of points.
extends MovementStrategy
class_name PolylineMovementStrategy

enum Cycle {NONE, LOOP, PING_PONG}

## Points are interpreted as local offsets from spawn origin.
var points: PackedVector3Array = PackedVector3Array()

## If true, appends first point at the end (closed path).
var close: bool = false

## How to continue after reaching the end.
var cycle: Cycle = Cycle.NONE

## Units per second along the polyline.
var speed: float = 40.0

var _path: PackedVector3Array = PackedVector3Array()
var _current_index: int = 0
var _next_index: int = 0
var _direction: int = 1
var _segment_progress: float = 0.0
var _stopped: bool = false
var _z_lock_offset: float = 0.0


func setup(enemy: Node, rig: CameraRig) -> void:
  _build_path(enemy.world_pos)
  _segment_progress = 0.0
  _direction = 1
  _stopped = _path.size() <= 1
  _current_index = 0
  _next_index = 1 if _path.size() > 1 else 0
  _z_lock_offset = 0.0
  _setup_z_lock(rig)
  if _path.size() > 0:
    enemy.world_pos = _path_with_z_lock(_path[0])

func update(enemy: Node, rig: CameraRig, delta: float) -> void:
  var prev_z_lock_offset := _z_lock_offset
  _update_z_lock_offset(rig)

  if _stopped or speed <= 0.0 or _path.size() <= 1:
    if z_lock == MovementStyle.ZLock.PLAYER:
      enemy.world_pos.z += _z_lock_offset - prev_z_lock_offset
    return

  var remaining := speed * delta
  while remaining > 0.0 and not _stopped:
    var a := _path[_current_index]
    var b := _path[_next_index]
    var seg_len := a.distance_to(b)

    if seg_len <= 0.0001:
      enemy.world_pos = _path_with_z_lock(b)
      _finish_segment(enemy)
      continue

    var left := seg_len - _segment_progress
    var step: float = min(remaining, left)
    _segment_progress += step
    remaining -= step

    var t: float = clamp(_segment_progress / seg_len, 0.0, 1.0)
    enemy.world_pos = _path_with_z_lock(a.lerp(b, t))

    if _segment_progress >= seg_len - 0.0001:
      enemy.world_pos = _path_with_z_lock(b)
      _finish_segment(enemy)

func _build_path(origin: Vector3) -> void:
  _path = PackedVector3Array()
  if points.is_empty():
    _path.append(origin)
    return

  for p in points:
    _path.append(origin + p)

  if close and _path.size() > 1 and _path[0].distance_to(_path[_path.size() - 1]) > 0.0001:
    _path.append(_path[0])

  prints("Built polyline path with ", _path.size(), " points: ", _path)

func _finish_segment(enemy: Node) -> void:
  _current_index = _next_index
  _segment_progress = 0.0

  var candidate := _current_index + _direction
  if candidate >= 0 and candidate < _path.size():
    _next_index = candidate
    return

  match cycle:
    Cycle.NONE:
      _stopped = true
      _next_index = _current_index

    Cycle.LOOP:
      _current_index = 0
      enemy.world_pos = _path_with_z_lock(_path[_current_index])
      if _path.size() > 1:
        _next_index = 1
      else:
        _stopped = true
        _next_index = _current_index

    Cycle.PING_PONG:
      _direction *= -1
      candidate = _current_index + _direction
      if candidate >= 0 and candidate < _path.size():
        _next_index = candidate
      else:
        _stopped = true
        _next_index = _current_index


func _update_z_lock_offset(rig: CameraRig) -> void:
  if z_lock != MovementStyle.ZLock.PLAYER or rig == null:
    return

  if not _z_lock_ready:
    _setup_z_lock(rig)
    return

  var current_z := rig.camera_world_position.z
  var delta_z := current_z - _last_camera_z
  _last_camera_z = current_z
  _z_lock_offset += delta_z


func _path_with_z_lock(path_pos: Vector3) -> Vector3:
  if z_lock != MovementStyle.ZLock.PLAYER:
    return path_pos
  return path_pos + Vector3(0.0, 0.0, _z_lock_offset)
