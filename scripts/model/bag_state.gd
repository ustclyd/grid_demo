class_name BagState
extends RefCounted

var id: int = -1
var pos: Vector2i = Vector2i.ZERO
var coins: int = 0

var is_throw_bag: bool = false
var is_ultimate_bag: bool = false


func duplicate_state() -> BagState:
	var copy := BagState.new()
	copy.id = id
	copy.pos = pos
	copy.coins = coins
	copy.is_throw_bag = is_throw_bag
	copy.is_ultimate_bag = is_ultimate_bag
	return copy
