## Declarative event: spawn a wave of enemies at a given time.
@tool
extends EncounterEvent
class_name SpawnEvent

## The enemy scene to instantiate.
@export var enemy_scene: PackedScene

## Number of enemies to spawn this event.
@export_range(1, 100) var count: int = 1

## Spatial formation for the group. Leave null for single-point spawn.
@export var formation: Formation

## World-Z distance ahead of the camera where enemies appear.
@export var z_start: float = 95.0

## Movement descriptor applied to each spawned enemy.
@export var move_style: MoveStyle

## Firing / attack pattern applied to each spawned enemy.
@export var pattern: Pattern

## HP override per enemy. 0 = use scene default.
@export var hp: int = 0

## Whether positions are in screen-normalised space or world space.
enum SpawnSpace {WORLD, SCREEN}
@export var spawn_space: SpawnSpace = SpawnSpace.WORLD

## Centre of the spawn group in world (or screen-normalised) coords.
@export var spawn_origin: Vector2 = Vector2.ZERO

## Per-axis random jitter added to each unit's offset.
@export var spread: Vector2 = Vector2.ZERO

## Height offset relative to horizon (matches old height_over_horizon).
@export var height_offset: float = -30.0
