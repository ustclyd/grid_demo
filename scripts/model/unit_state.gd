class_name UnitState
extends RefCounted

var id: int = -1
var pos: Vector2i = Vector2i.ZERO
var prev_pos: Vector2i = Vector2i.ZERO

var coins: int = 0
var entry_coins: int = 0

var alive: bool = true
var won: bool = false

var forced_stay_turns: int = 0

var queued_teleport_to: Vector2i = Vector2i.ZERO
var has_queued_teleport: bool = false

var queued_exit: bool = false
var teleported_this_turn: bool = false

var discovered_portal_ids: Array[int] = []


func can_throw() -> bool:
	return coins > 1
