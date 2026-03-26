class_name ActionIntent
extends RefCounted

var actor_id: int = -1
var type: String = ActionType.STAY

var target_pos: Vector2i = Vector2i.ZERO
var target_bag_id: int = -1
var throw_amount: int = 0


func is_stationary() -> bool:
	return type == ActionType.STAY or type == ActionType.PICK or type == ActionType.THROW
