extends CanvasLayer
class_name GameplayScreen

signal stage_completed

# Private vars -------
var _run_config: RunConfiguration

var _logger = EchoLogger.new("GameplayScreen", "orange", EchoLogger.LogLevel.DEBUG)

@onready var _intro_cutscene: IntroCutscene = %IntroCutscene
@onready var _outro_cutscene: OutroCutscene = %OutroCutscene
@onready var _stage_director: StageDirector = %StageDirector

func start(run_config: RunConfiguration) -> void:
  _run_config = run_config
  _logger.debug("Starting gameplay with config: %s" % [run_config])

  _intro_cutscene.visible = true
  _intro_cutscene.play()
  _intro_cutscene.finished.connect(_on_intro_cutscene_finished)

  _intro_cutscene.visible = false

func _on_intro_cutscene_finished() -> void:
  _logger.debug("Intro cutscene finished, starting stage.")
  _intro_cutscene.visible = false
  _stage_director.start_stage(_run_config.seed)

func _on_stage_director_stage_finished() -> void:
  _logger.debug("Stage finished, returning to main menu.")
  _outro_cutscene.visible = true
  _outro_cutscene.play()
  _outro_cutscene.finished.connect(_on_outro_cutscene_finished)

func _on_outro_cutscene_finished() -> void:
  _logger.debug("Outro cutscene finished, returning to main menu.")
  stage_completed.emit()