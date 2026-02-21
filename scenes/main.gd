# ________                              _____               
# ___  __ \________      _________________  /______ ________
# __  / / /  __ \_ | /| / /_  __ \_  ___/  __/  __ `/_  ___/
# _  /_/ // /_/ /_ |/ |/ /_  / / /(__  )/ /_ / /_/ /_  /    
# /_____/ \____/____/|__/ /_/ /_//____/ \__/ \__,_/ /_/     
#
# (c) Pl7y.com 2026

extends Node
class_name Main

var current_run_config: RunConfiguration

@export var main_menu_scene: PackedScene

func _ready() -> void:
  var main_menu = main_menu_scene.instantiate()
  add_child(main_menu)
  main_menu.start_pressed.connect(_on_main_menu_start_pressed)
  main_menu.quit_pressed.connect(_on_main_menu_quit_pressed)

func _on_main_menu_start_pressed() -> void:
  current_run_config = RunConfiguration.new()

func _on_main_menu_quit_pressed() -> void:
  get_tree().quit()
