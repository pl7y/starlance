## Pattern-based formation: arranges units in geometric shapes.
## Supports POINT, LINE, V, GRID, CIRCLE patterns.
@tool
extends Formation
class_name ShapeFormation

enum Shape {POINT, LINE, V, GRID, CIRCLE}

## The geometric shape of this formation.
@export var shape: Shape = Shape.POINT

## Spacing between units on the primary axis.
@export var spacing: Vector2 = Vector2(5.0, 3.0)

## Number of columns (for GRID shape).
@export var columns: int = 3

## Radius (for CIRCLE shape).
@export var radius: float = 6.0


func get_offsets(count: int, _rng: RandomNumberGenerator = null) -> Array[Vector2]:
  var offsets: Array[Vector2] = []
  match shape:
    Shape.POINT:
      for i in count:
        offsets.append(Vector2.ZERO)

    Shape.LINE:
      var half := (count - 1) * spacing.x * 0.5
      for i in count:
        offsets.append(Vector2(i * spacing.x - half, 0.0))

    Shape.V:
      for i in count:
        var side := 1.0 if i % 2 == 0 else -1.0
        @warning_ignore("INTEGER_DIVISION")
        var depth := int(i / 2)
        offsets.append(Vector2(side * depth * spacing.x, depth * spacing.y))

    Shape.GRID:
      var cols := maxi(columns, 1)
      var rows := ceili(float(count) / cols)
      var ox := (cols - 1) * spacing.x * 0.5
      var oy := (rows - 1) * spacing.y * 0.5
      for i in count:
        var c := i % cols
        @warning_ignore("INTEGER_DIVISION")
        var r := int(i / cols)
        offsets.append(Vector2(c * spacing.x - ox, r * spacing.y - oy))

    Shape.CIRCLE:
      if count == 1:
        offsets.append(Vector2.ZERO)
      else:
        for i in count:
          var angle := TAU * float(i) / float(count)
          offsets.append(Vector2(cos(angle), sin(angle)) * radius)

  return offsets
