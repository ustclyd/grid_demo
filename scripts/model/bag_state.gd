class_name BagState
extends RefCounted

var id: int = -1
var pos: Vector2i = Vector2i.ZERO
var coins: int = 0

var is_throw_bag: bool = false
var is_ultimate_bag: bool = false
var has_queued_teleport: bool = false
var queued_teleport_to: Vector2i = Vector2i.ZERO
var queued_exit: bool = false


func duplicate_state() -> BagState:
	var copy := BagState.new()
	copy.id = id
	copy.pos = pos
	copy.coins = coins
	copy.is_throw_bag = is_throw_bag
	copy.is_ultimate_bag = is_ultimate_bag
	copy.has_queued_teleport = has_queued_teleport
	copy.queued_teleport_to = queued_teleport_to
	copy.queued_exit = queued_exit
	return copy
