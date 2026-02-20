## Base class for movement style resources.
## Describes how a spawned enemy should move after spawning.
##
## Each concrete subclass contains only the parameters relevant to its strategy.
@tool
extends Resource
class_name MovementStyle

enum ZLock {NONE, PLAYER}

## Z lock mode shared by all movement styles.
## NONE: absolute world movement.
## PLAYER: compensate player forward run so movement is player-relative.
@export var z_lock: ZLock = ZLock.NONE

## Creates and returns the appropriate MovementStrategy instance.
## Override in subclasses to return the correct strategy type.
func create_strategy() -> MovementStrategy:
  push_error("MovementStyle.create_strategy() must be overridden in subclass")
  return null


func _apply_shared_settings(strategy: MovementStrategy) -> MovementStrategy:
  strategy.z_lock = z_lock
  return strategy
