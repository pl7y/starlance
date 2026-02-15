extends Area3D
class_name PseudoArea3D

@export var world_object: WorldObject:
  set(value):
    world_object = value
    _update()
  get:
    return world_object

func _ready() -> void:
  _update()

func _enable(flag: bool) -> void:
  # Loop over all CollisionShape3D children and enable/disable them.
  for child in get_children():
    var cs := child as CollisionShape3D
    if cs != null:
      cs.disabled = !flag

func _update() -> void:
  if !is_inside_tree():
    return

  _enable(!!world_object)

  # Get first CollisionShape3d child and its shape.
  var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D

  if world_object != null:
    global_position = world_object.world_pos + collision_shape.position
  else:
    prints("Warning: PseudoArea3D has no world_object assigned.")

func _process(_delta: float) -> void:
  # Get first CollisionShape3d child and its shape.
  var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
  
  if world_object != null:
    global_position = world_object.world_pos + collision_shape.position
