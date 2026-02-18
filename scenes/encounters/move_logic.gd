## Base class for custom enemy AI movement.
##
## Extend this Resource and override setup() / update() to create
## pluggable movement behaviours.  Each enemy gets a duplicate() so
## instance state is safe.
##
## Usage in MoveStyle:
##   1. Set type = CUSTOM
##   2. Assign your MoveLogic subclass .tres to custom_logic
##
## The EnemySpawner calls duplicate() per enemy, then setup() once,
## then the Enemy calls update() every frame when pattern == CUSTOM.
@tool
extends Resource
class_name MoveLogic

## Called once after the enemy is spawned and configured.
## Store references and initialise per-instance state here.
@warning_ignore("unused_parameter")
func setup(enemy: Node, rig: CameraRig) -> void:
	pass


## Called every _process frame.  Move the enemy by writing to
## enemy.world_pos directly.
@warning_ignore("unused_parameter")
func update(enemy: Node, rig: CameraRig, delta: float) -> void:
	pass
