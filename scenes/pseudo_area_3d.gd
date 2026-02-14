extends Area3D
class_name PseudoArea3D

@export var world_object: WorldObject
@export var offset = Vector3.ZERO

func _process(_delta: float) -> void:
  if world_object != null:
    global_position = world_object.world_pos + offset
