extends Node2D
class_name GameplayScreen

var _logger = EchoLogger.new("GameplayScreen", "blue", EchoLogger.LogLevel.DEBUG)

func _on_stage_director_rail_paused() -> void:
	_logger.debug("Rail paused.")


func _on_stage_director_rail_resumed() -> void:
	_logger.debug("Rail resumed.")


func _on_stage_director_segment_finished(index: int, encounter: Encounter) -> void:
	_logger.debug("Segment finished: %d, %s" % [index, encounter])


func _on_stage_director_segment_started(index: int, encounter: Encounter) -> void:
	_logger.debug("Segment started: %d, %s" % [index, encounter])


func _on_stage_director_stage_failed(reason: String) -> void:
	_logger.debug("Stage failed: %s" % [reason])


func _on_stage_director_stage_finished() -> void:
	_logger.debug("Stage finished.")

func _on_stage_director_stage_started() -> void:
	_logger.debug("Stage started.")
