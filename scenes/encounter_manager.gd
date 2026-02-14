extends Node
class_name EncounterManager

@export var disabled: bool = false
@export var enemy_scene: PackedScene
@export var spawn_ahead_z: float = 95.0
@export var height_over_horizon: float = -30.0

# How long to rest between chunks
@export var rest_time: float = 1.0

@onready var rig: CameraRig = get_tree().get_first_node_in_group("camera_rig") as CameraRig
@export var world: Node


var _time_in_chunk: float = 0.0
var _state: String = "idle" # "playing", "rest"
var _rest_t: float = 0.0

var _events: Array = [] # current chunk events
var _event_i: int = 0

func _ready() -> void:
  randomize()
  _start_next_chunk()

func _process(delta: float) -> void:
  if disabled or rig == null or enemy_scene == null:
    return

  if _state == "rest":
    _rest_t -= delta
    if _rest_t <= 0.0:
      _start_next_chunk()
    return

  _time_in_chunk += delta

  # Execute due events
  while _event_i < _events.size() and _events[_event_i].t <= _time_in_chunk:
    _execute_event(_events[_event_i])
    _event_i += 1

  # End chunk
  if _event_i >= _events.size():
    _state = "rest"
    _rest_t = rest_time

func _start_next_chunk() -> void:
  _state = "playing"
  _time_in_chunk = 0.0
  _event_i = 0

  # Pick one chunk from a small pool (later: biome-specific)
  var chunk_id := _pick_chunk_id()
  _events = _build_chunk(chunk_id)
  _events.sort_custom(func(a, b): return a.t < b.t)

func _pick_chunk_id() -> String:
  var pool := ["swarm", "lane_wall", "snipers", "mini_boss_intro"]
  return pool[randi() % pool.size()]

func _execute_event(ev) -> void:
  match ev.kind:
    "spawn":
      _spawn_enemy(ev)
    _:
      pass

func _spawn_enemy(ev) -> void:
  var e := enemy_scene.instantiate() as Enemy
  world.add_child(e)

  # Negative z is ahead
  var z: float = rig.camera_world_position.z - spawn_ahead_z - ev.z_offset
  e.world_pos = Vector3(ev.x, ev.y, z)

  # Defaults
  var p_hp := 3
  var p_fire_interval := 1.2
  var p_bullet_speed := 90.0
  var p_pattern := Enemy.MovePattern.STATIC

  # If you're using SpawnEvent fields:
  p_hp = ev.hp
  p_fire_interval = ev.fire_interval
  p_bullet_speed = ev.bullet_speed
  if ev.has("pattern"):
    p_pattern = ev.pattern

  e.configure(p_hp, p_fire_interval, p_bullet_speed, p_pattern)


class SpawnEvent:
  var t: float
  var kind: String = "spawn"
  var x: float
  var y: float
  var z_offset: float
  var hp: int
  var fire_interval: float
  var bullet_speed: float
  var pattern: int

  func _init(_t: float, _x: float, _y: float, _zoff: float,
      _p_hp := 3, _p_fire_interval := 1.2, _p_bullet_speed := 90.0, _pattern := 0) -> void:
    t = _t
    x = _x
    y = _y
    z_offset = _zoff
    hp = _p_hp
    fire_interval = _p_fire_interval
    bullet_speed = _p_bullet_speed
    pattern = _pattern

  func has(key: String) -> bool:
    return key == "pattern" or key in ["hp", "fire_interval", "bullet_speed"]

func _build_chunk(id: String) -> Array:
  match id:
    "swarm":
      return _chunk_swarm()
    "lane_wall":
      return _chunk_lane_wall()
    "snipers":
      return _chunk_snipers()
    "mini_boss_intro":
      return _chunk_mini_boss_intro()
    _:
      return _chunk_swarm()

func _chunk_swarm() -> Array:
  var evs: Array = []
  var rows := 4
  var cols := 5
  var spacing_x := 5.0
  var spacing_y := 3.0
  var start_x := -spacing_x * (cols - 1) * 0.5
  var start_y := -spacing_y * (rows - 1) * 0.5

  for r in range(rows):
    for c in range(cols):
      var t := 0.2 + (r * 0.22) + randf_range(0.0, 0.06)
      var x := start_x + c * spacing_x
      var y := start_y + r * spacing_y
      evs.append(SpawnEvent.new(
        t, x, y + height_over_horizon, 0.0,
        1, 999.0, 0.0,
        Enemy.MovePattern.SINE_STRAFE
      ))
  return evs

func _chunk_lane_wall() -> Array:
  var evs: Array = []
  var lanes := 9
  var half_w := 14.0
  var gap_lane := randi() % lanes
  var t0 := 0.4

  for i in range(lanes):
    if i == gap_lane:
      continue
    var x: float = lerp(-half_w, half_w, float(i) / float(lanes - 1))
    evs.append(SpawnEvent.new(
      t0, x, randf_range(-2.0, 2.0) + height_over_horizon, 0.0,
      2, 1.5, 85.0,
      Enemy.MovePattern.SWOOP
    ))
  return evs


func _chunk_snipers() -> Array:
  var evs: Array = []
  for k in range(4):
    var t := 0.3 + k * 0.9
    var x := randf_range(-12.0, 12.0)
    var y := randf_range(-6.0, 6.0)
    evs.append(SpawnEvent.new(
      t, x, y + height_over_horizon, k * 10.0,
      4, 1.9, 130.0,
      Enemy.MovePattern.DRIFT
    ))
  return evs

func _chunk_mini_boss_intro() -> Array:
  var evs: Array = []
  # Escorts first
  for i in range(4):
    var t := 0.3 + i * 0.25
    evs.append(SpawnEvent.new(t, -10.0 + i * 6.5, randf_range(-4.0, 4.0) + height_over_horizon, 0.0, 2, 1.6, 85.0))

  # “Boss” (for now just a tanky enemy)
  evs.append(SpawnEvent.new(1.4, 0.0, 0.0 + height_over_horizon, 0.0, 18, 0.9, 95.0))
  return evs
