## Declarative event: spawn a wave of enemies at a given time.
@tool
extends EncounterEvent
class_name SpawnEvent

## The enemy scene to instantiate.
@export var enemy_scene: PackedScene

## Number of enemies to spawn this event.
@export_range(1, 100) var count: int = 1

## Spatial formation for the group. Leave null for single-point spawn.
## Use ShapeFormation for geometric patterns or VolumeFormation for 3D volume sampling.
@export var formation: Formation

## Movement descriptor applied to each spawned enemy.
@export var move_style: MoveStyle

## Firing / attack pattern applied to each spawned enemy.
@export var pattern: Pattern

## HP override per enemy. 0 = use scene default.
@export var hp: int = 0

## World position (3D) where the spawn group originates.
@export var world_pos: Vector3 = Vector3.ZERO
