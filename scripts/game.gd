extends Node

var current_player_id: int = 0
signal turn_started(player_id: int)

func start_game() -> void:
    turn_started.emit(current_player_id)

func end_turn(player_id: int) -> void:
    if player_id != current_player_id:
        print("Error: End turn called by player ", player_id, " but current player is ", current_player_id)
        return
    current_player_id = (current_player_id + 1) % 2
    turn_started.emit(current_player_id)
