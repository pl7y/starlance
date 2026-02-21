extends CanvasLayer
class_name IntroCutscene

signal finished

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func play() -> void:
  animation_player.play("open")
  animation_player.seek(0.0)


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
  if anim_name == "open":
    finished.emit()