extends SceneTree

const Game = preload("res://scripts/game.gd")


func _init() -> void:
	var game = Game.new()
	# Connect signals
	game.phase_changed.connect(on_phase_changed)
	game.turn_started.connect(on_turn_started)

	print("[CLIENT] Starting game...")
	game.start_game()

	print("[CLIENT] Setting player 0 champion position to 13")
	game.set_champion_position(0, 13)

	print("[CLIENT] Setting player 1 champion position to 7")
	game.set_champion_position(1, 7)

	# Now it's player 0's turn
	print("[CLIENT] Moving player 0 to cell 10")
	var actions = game.move_champion(0, 10)
	print("[SERVER] Actions: ", actions.to_debug_string())

	print("[CLIENT] Attacking player 1")
	actions = game.attack_champion(0)
	print("[SERVER] Actions: ", actions.to_debug_string())

	print("[CLIENT] Ending turn")
	game.end_turn(0)


func on_phase_changed(phase: Game.Phase) -> void:
	var phase_name = ""
	match phase:
		Game.Phase.POSITION_CHAMPION:
			phase_name = "POSITION_CHAMPION"
		Game.Phase.COMBAT:
			phase_name = "COMBAT"
	print("[SERVER] Phase changed: ", phase_name)


func on_turn_started(player_id: int, actions: Game.PlayerActions) -> void:
	print("[SERVER] Turn started for player ", player_id)
	print("[SERVER] Actions: ", actions.to_debug_string())
