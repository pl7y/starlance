extends Area3D
class_name PseudoArea3D

@export var world_object: WorldObject

func _process(_delta: float) -> void:
  # Get first CollisionShape3d child and its shape.
  var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
  
  if world_object != null:
    global_position = world_object.world_pos + collision_shape.position
