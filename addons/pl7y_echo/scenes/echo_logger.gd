## EchoLogger Class
## Colors: https://docs.godotengine.org/en/latest/tutorials/ui/bbcode_in_richtextlabel.html#doc-bbcode-in-richtextlabel-named-colors
extends RefCounted
class_name EchoLogger

enum LogLevel {SILLY, DEBUG, INFO, WARN, ERROR}

var log_source: String = "Default"
var log_color: String = "white"
var log_format: String = "[color={color}][{source}][/color] [color={level_color}][{level}]: {message}[/color]"
var min_level: LogLevel = LogLevel.DEBUG
var log_file_path: String = "user://_log.txt"

func _init(source = "Default", color = "white", level = LogLevel.INFO, file_path = "", format = ""):
  log_source = source
  log_color = color
  if format != "":
    log_format = format
  min_level = level
  if file_path != "":
    log_file_path = file_path

func _get_level_color(level: LogLevel) -> String:
  match level:
    LogLevel.SILLY:
      return "plum"
    LogLevel.DEBUG:
      return "light_sea_green"
    LogLevel.INFO:
      return "white"
    LogLevel.WARN:
      return "tomato"
    LogLevel.ERROR:
      return "red"

  return "gray"

func _log(message: String, level: LogLevel = LogLevel.INFO) -> void:
  if level < min_level:
    return

  var level_name = LogLevel.keys()[level]
  var formatted = log_format.format({
    "color": log_color,
    "level_color": _get_level_color(level),
    "source": log_source,
    "level": level_name,
    "message": message
  })
  print_rich(formatted)

  if log_file_path:
    _append_to_file("[{0}] [{1}] {2}: {3}\n".format([
      level_name, log_source, Time.get_datetime_string_from_system(), message
    ]))

func _append_to_file(text: String) -> void:
  var file := FileAccess.open(log_file_path, FileAccess.WRITE_READ)
  if file:
    file.seek_end()
    file.store_string(text)
    file.close()

func silly(message: String) -> void:
  _log(message, LogLevel.SILLY)

func info(message: String) -> void:
  _log(message, LogLevel.INFO)

func debug(message: String) -> void:
  _log(message, LogLevel.DEBUG)

func warn(message: String) -> void:
  _log(message, LogLevel.WARN)

func error(message: String) -> void:
  _log(message, LogLevel.ERROR)
