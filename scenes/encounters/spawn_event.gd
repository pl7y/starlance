## Declarative event: spawn a wave of enemies at a given time.
@tool
extends EncounterEvent
class_name SpawnEvent

## The enemy scene to instantiate.
@export var enemy_scene: PackedScene

## Number of enemies to spawn this event.
@export_range(1, 100) var count: int = 1

## Spatial formation for the group. Leave null for single-point spawn.
@export var formation: Formation:
  set(value):
    formation = value
    notify_property_list_changed()
  get:
    return formation

## Movement descriptor applied to each spawned enemy.
@export var move_style: MoveStyle

## Firing / attack pattern applied to each spawned enemy.
@export var pattern: Pattern

## HP override per enemy. 0 = use scene default.
@export var hp: int = 0

## World position (3D) where the spawn group originates.
@export var world_pos: Vector3 = Vector3.ZERO

## Optional Shape3D for randomizing spawn positions within a volume.
## If null, all enemies spawn at world_pos (plus formation offsets).
## WARNING: Conflicts with 'formation' - only use one positioning approach.
@export var spawn_shape: Shape3D:
  set(value):
    spawn_shape = value
    notify_property_list_changed()
  get:
    return spawn_shape


func _validate_property(property: Dictionary) -> void:
  if property.name == "spawn_shape" and formation != null:
    property.usage = PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_EDITOR
    spawn_shape = null
    property.hint_string = "⚠️ DISABLED: Conflicts with 'formation'. Clear formation to use spawn_shape."
  elif property.name == "formation" and spawn_shape != null:
    property.usage = PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_EDITOR
    formation = null
    property.hint_string = "⚠️ DISABLED: Conflicts with 'spawn_shape'. Clear spawn_shape to use formation."
