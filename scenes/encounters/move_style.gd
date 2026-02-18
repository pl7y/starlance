## Describes how a spawned enemy should move after spawning.
## This is a data-only descriptor — the enemy/spawner reads it at spawn time.
@tool
extends Resource
class_name MoveStyle

## Maps to Enemy.MovePattern (keep in sync).
enum Type {STATIC, DRIFT, SINE_STRAFE, DIVE_AT_PLAYER, SWOOP, ORBIT, RUSH_FOLLOW, CUSTOM}

## Primary movement type.
@export var type: Type = Type.STATIC

## Forward speed (negative = toward camera in Downstar convention).
@export var speed_z: float = 12.0

## Lateral speeds (used by DRIFT, etc.).
@export var speed_x: float = 0.0
@export var speed_y: float = 0.0

## Sine / curve amplitude.
@export var amplitude: Vector2 = Vector2(4.0, 2.0)

## Sine frequency.
@export var frequency: float = 1.2

## Dive homing strength.
@export var dive_turn: float = 2.5

## Orbit radius / speed.
@export var orbit_radius: float = 6.0
@export var orbit_speed: float = 1.5

## Z-distance from camera where RUSH_FOLLOW enemies lock in.
@export var follow_distance: float = 30.0

## Homing strength during the rush (approach) phase.
@export var rush_turn: float = 4.0

## Custom AI logic resource (only used when type == CUSTOM).
## EnemySpawner will duplicate() this per enemy so each has its own state.
@export var custom_logic: MoveLogic
