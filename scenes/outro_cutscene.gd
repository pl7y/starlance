extends CanvasLayer
class_name OutroCutscene

signal finished

@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var end_game_ui: Control = %EndGameUI
@onready var continue_button: Button = %ContinueButton

func _ready() -> void:
  end_game_ui.visible = false

func play() -> void:
  animation_player.play("starship_arrival")
  animation_player.seek(0.0)


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
  if anim_name == "starship_arrival":
    end_game_ui.visible = true
    continue_button.grab_focus()


func _on_continue_button_pressed() -> void:
  finished.emit()
