## Describes the firing / attack pattern for spawned enemies.
## Data-only — read by the enemy at configure-time.
@tool
extends Resource
class_name Pattern

## Fire rate in seconds between shots.
@export var fire_interval: float = 1.2

## Bullet travel speed.
@export var bullet_speed: float = 90.0

## Aim lead on Y axis (vertical prediction).
@export var aim_lead_y: float = 0.0

## Minimum Z distance at which the enemy starts firing.
@export var fire_min_z: float = 18.0

## Maximum Z distance (stop firing beyond this).
@export var fire_max_z: float = 95.0
