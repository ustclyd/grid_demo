class_name PortalPairState
extends RefCounted

var id: int = -1
var entry_a: Vector2i = Vector2i.ZERO
var entry_b: Vector2i = Vector2i.ZERO

var cooldown_turns: int = 0
var is_overheated: bool = false

var color_id: int = -1
var discovered_by_player_ids: Array[int] = []


func refresh_overheat_state() -> void:
	is_overheated = cooldown_turns > 0


func tick_cooldown() -> void:
	if cooldown_turns > 0:
		cooldown_turns -= 1
	refresh_overheat_state()
