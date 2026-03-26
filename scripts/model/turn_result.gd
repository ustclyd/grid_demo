class_name TurnResult
extends RefCounted

var state_before: GameState
var state_after: GameState

var intents: Array[ActionIntent] = []

var moved_unit_ids: Array[int] = []
var conflict1_survivor_unit_ids: Array[int] = []
var conflict1_defeated_unit_ids: Array[int] = []
var teleported_unit_ids: Array[int] = []
var knocked_back_unit_ids: Array[int] = []
var dead_unit_ids: Array[int] = []

var picked_bag_records: Array[Dictionary] = []
var thrown_bag_records: Array[Dictionary] = []
var dropped_bag_ids: Array[int] = []

var forced_stay_unit_ids: Array[int] = []
var portal_ready_unit_ids: Array[int] = []
var exit_ready_unit_ids: Array[int] = []
var overheated_portal_pair_ids: Array[int] = []
