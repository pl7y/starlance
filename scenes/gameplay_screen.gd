extends CanvasLayer
class_name GameplayScreen

# Private vars -------
var _run_config: RunConfiguration

var _logger = EchoLogger.new("GameplayScreen", "orange", EchoLogger.LogLevel.DEBUG)

func start(run_config: RunConfiguration) -> void:
  _run_config = run_config
  _logger.debug("Starting gameplay with config: %s" % [run_config])