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


func get_display_name() -> String:
	return "敌人"


func is_available() -> bool:
	return false


func accepts_spawn(_cell: Vector2i, _board_size: Vector2i) -> bool:
	return true


# Implementations choose from the supplied pre-turn snapshot without storing turn state.
func choose_intent(_board: GameState, _unit_id: int, _player_id: int) -> ActionIntent:
	return null
