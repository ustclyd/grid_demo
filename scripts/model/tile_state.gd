class_name TileState
extends RefCounted

var pos: Vector2i = Vector2i.ZERO
var tile_type: String = TileType.NORMAL

var portal_pair_id: int = -1
var portal_color_id: int = -1

var has_storm: bool = false


func duplicate_state() -> TileState:
	var copy := TileState.new()
	copy.pos = pos
	copy.tile_type = tile_type
	copy.portal_pair_id = portal_pair_id
	copy.portal_color_id = portal_color_id
	copy.has_storm = has_storm
	return copy
