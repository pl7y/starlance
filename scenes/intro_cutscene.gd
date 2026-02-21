extends CanvasLayer
class_name IntroCutscene

signal finished

@export var duration_sec: float = 2.0
var _is_playing := false

func play() -> void:
    if _is_playing:
        return
    _is_playing = true
    visible = true

    await get_tree().create_timer(duration_sec).timeout

    visible = false
    _is_playing = false
    finished.emit()