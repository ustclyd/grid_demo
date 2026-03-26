class_name TurnResolver
extends RefCounted


func resolve_turn(state: GameState, intents: Array[ActionIntent]) -> TurnResult:
	var result := TurnResult.new()
	result.state_before = state
	result.intents = intents

	# Stub only.
	# Future implementation should follow the documented resolution order:
	# 0. next-turn system processing
	# 1. submit intents
	# 2. pick/throw resource changes
	# 3. theoretical target positions
	# 4. environment death
	# 5. conflict resolution 1
	# 6. knockback from throws
	# 7. conflict resolution 2
	# 8. death drops
	# 9. forced stay marking
	# 10. portal queue
	# 11. exit queue
	# 12. map events

	result.state_after = state
	return result
