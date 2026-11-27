class_name PuzzleBagSpawn
extends Resource

@export var cell: Vector2i
@export var coins: int = 1
## A non-negative value makes this a fixed vault with an exact wallet requirement.
@export var required_coins: int = -1
