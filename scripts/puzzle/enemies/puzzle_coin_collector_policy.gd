class_name PuzzleCoinCollectorPolicy
extends PuzzlePatrollerPolicy


func get_display_name() -> String:
	return "拾金兵"


func is_available() -> bool:
	return kind == Kind.COIN_SEEKER and route.size() >= 3


func choose_intent(board: GameState, unit_id: int, player_id: int) -> ActionIntent:
	var unit := board.get_unit_by_id(unit_id)
	var occupied: Dictionary[Vector2i, bool] = {}
	for other in board.units:
		if other.id != unit_id and other.alive and not other.won:
			occupied[other.pos] = true

	var target := Vector2i(-1, -1)
	var best_distance := board.board_size.x + board.board_size.y
	for bag in board.bags:
		if bag.is_vault() or occupied.has(bag.pos):
			continue
		var distance := _distance(unit.pos, bag.pos)
		var comes_first := bag.pos.y < target.y or (bag.pos.y == target.y and bag.pos.x < target.x)
		if distance < best_distance or (distance == best_distance and comes_first):
			target = bag.pos
			best_distance = distance

	if target.x < 0:
		if route.has(unit.pos) or route.is_empty():
			return super.choose_intent(board, unit_id, player_id)
		target = route[0]
		best_distance = _distance(unit.pos, target)
		for cell in route:
			var distance := _distance(unit.pos, cell)
			if distance < best_distance:
				target = cell
				best_distance = distance

	var offset := target - unit.pos
	var step := Vector2i(signi(offset.x), signi(offset.y))
	var move := PuzzleActions.create_intent(board, unit_id, ActionType.MOVE, unit.pos + step)
	return move if move != null else PuzzleActions.create_intent(board, unit_id, ActionType.STAY)


func _distance(from: Vector2i, to: Vector2i) -> int:
	var offset := (to - from).abs()
	return maxi(offset.x, offset.y)
