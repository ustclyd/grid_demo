class_name TileState
extends RefCounted

var pos: Vector2i = Vector2i.ZERO
var tile_type: String = TileType.NORMAL

var portal_pair_id: int = -1
var portal_color_id: int = -1

var has_storm: bool = false
