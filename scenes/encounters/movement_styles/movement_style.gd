## Base class for movement style resources.
## Describes how a spawned enemy should move after spawning.
##
## Each concrete subclass contains only the parameters relevant to its strategy.
@tool
extends Resource
class_name MovementStyle

## Creates and returns the appropriate MovementStrategy instance.
## Override in subclasses to return the correct strategy type.
func create_strategy() -> MovementStrategy:
  push_error("MovementStyle.create_strategy() must be overridden in subclass")
  return null
