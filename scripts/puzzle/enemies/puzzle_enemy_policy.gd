class_name PuzzleEnemyPolicy
extends Resource

enum Kind {
	SENTRY,
	STRAIGHT_MOVER,
	BOUNCER,
	PATROLLER,
	PURSUER,
	FLEEING,
	WATCHER,
	COIN_SEEKER,
	INTERCEPTOR,
	THROWER,
	LEADING_THROWER,
	KNOCKBACK_SPECIALIST,
	STUN_HUNTER,
	LURE,
	COORDINATED,
	PORTAL_TRAVELER,
	FOG_SCOUT,
}

@export var kind: Kind = Kind.SENTRY


func is_available() -> bool:
	return false


# Implementations choose from the supplied pre-turn snapshot without storing turn state.
func choose_intent(_board: GameState, _unit_id: int, _player_id: int) -> ActionIntent:
	return null
