extends RefCounted
class_name Projection2D

var visible: bool = true
var screen: Vector2 = Vector2.ZERO
var scale: float = 1.0
var rel_z: float = 0.0

@warning_ignore("SHADOWED_VARIABLE")
func _init(visible: bool, screen: Vector2 = Vector2.ZERO, scale: float = 1.0, rel_z: float = 0.0) -> void:
  self.visible = visible
  self.screen = screen
  self.scale = scale
  self.rel_z = rel_z