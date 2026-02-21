extends CanvasLayer
class_name MainMenu

signal start_pressed()
signal quit_pressed()

@onready var _start_button: Button = %StartButton

func _ready() -> void:
  _start_button.grab_focus()

func _on_start_button_pressed() -> void:
  start_pressed.emit()


func _on_quit_button_pressed() -> void:
  quit_pressed.emit()
