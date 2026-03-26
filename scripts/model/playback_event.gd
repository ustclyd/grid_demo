class_name PlaybackEvent
extends RefCounted

var type: String = ""
var start_time: float = 0.0
var duration: float = 0.0

var unit_id: int = -1
var bag_id: int = -1
var portal_pair_id: int = -1

var from_pos: Vector2i = Vector2i.ZERO
var to_pos: Vector2i = Vector2i.ZERO

var amount: int = 0
var extra: Dictionary = {}
