extends Node

signal turn_started(player_id: int)
signal phase_changed(phase: Phase)

enum Phase { POSITION_CHAMPION, COMBAT }
var current_player_id: int = 0
var current_phase: Phase = Phase.POSITION_CHAMPION
var champions_positions: Array[int] = [-1, -1]


func start_game() -> void:
	current_phase = Phase.POSITION_CHAMPION
	phase_changed.emit(current_phase)


func set_champion_position(player_id: int, cell_position: int) -> void:
	if current_phase != Phase.POSITION_CHAMPION:
		print("Error: Set champion position called in phase ", current_phase)
		return
	champions_positions[player_id] = cell_position
	if champions_positions[0] != -1 and champions_positions[1] != -1:
		current_phase = Phase.COMBAT
		phase_changed.emit(current_phase)
		turn_started.emit(current_player_id)


func end_turn(player_id: int) -> void:
	if player_id != current_player_id:
		print(
			"Error: End turn called by player ",
			player_id,
			" but current player is ",
			current_player_id
		)
		return
	current_player_id = (current_player_id + 1) % 2
	turn_started.emit(current_player_id)
