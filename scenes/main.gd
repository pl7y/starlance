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
@export var gameplay_screen_scene: PackedScene
@export var starship_screen_scene: PackedScene

# Private variables -------
var _main_menu: MainMenu
var _gameplay_screen: GameplayScreen
var _starship_screen: StarshipScreen

func _ready() -> void:
  _show_main_menu()

# Main menu ---------------

func _show_main_menu() -> void:
  _clear_screens()

  _main_menu = main_menu_scene.instantiate()
  add_child(_main_menu)
  _main_menu.start_pressed.connect(_on_main_menu_start_pressed)
  _main_menu.quit_pressed.connect(_on_main_menu_quit_pressed)

func _on_main_menu_start_pressed() -> void:
  current_run_config = RunConfiguration.new()
  _show_gameplay_screen()
  _gameplay_screen.start(current_run_config)

func _on_main_menu_quit_pressed() -> void:
  get_tree().quit()

# Gameplay screen ----------

func _clear_screens() -> void:
  if _main_menu:
    remove_child(_main_menu)
    _main_menu.queue_free()

  if _gameplay_screen:
    remove_child(_gameplay_screen)
    _gameplay_screen.queue_free()

  if _starship_screen:
    remove_child(_starship_screen)
    _starship_screen.queue_free()

  
func _show_gameplay_screen() -> void:
  _clear_screens()

  _gameplay_screen = gameplay_screen_scene.instantiate()
  add_child(_gameplay_screen)
  _gameplay_screen.stage_completed.connect(_on_gameplay_screen_stage_completed)

func _on_gameplay_screen_stage_completed() -> void:
  _show_starship_screen()

# Starship screen ----------
func _show_starship_screen() -> void:
  _clear_screens()

  _starship_screen = starship_screen_scene.instantiate()
  add_child(_starship_screen)
