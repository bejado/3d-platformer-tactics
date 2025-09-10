extends Node

signal turn_started(player_id: int)
signal phase_changed(phase: Phase)

enum Phase { POSITION_CHAMPION, COMBAT }


class GridPosition:
	var row: int
	var col: int

	static var rows: int = 8
	static var cols: int = 3

	func _init(r: int = 0, c: int = 0):
		row = r
		col = c

	func to_cell_index() -> int:
		return row * cols + col

	func is_in_bounds() -> bool:
		return row >= 0 and row < rows and col >= 0 and col < cols

	func equals(other: GridPosition) -> bool:
		return row == other.row and col == other.col

	func get_neighbors() -> Array[GridPosition]:
		"""
		Returns the neighbors (both diagonal and orthogonal) of the grid position.
		"""
		var neighbors: Array[GridPosition] = []
		neighbors.append(GridPosition.new(row + 1, col))
		neighbors.append(GridPosition.new(row - 1, col))
		neighbors.append(GridPosition.new(row, col + 1))
		neighbors.append(GridPosition.new(row, col - 1))
		neighbors.append(GridPosition.new(row + 1, col + 1))
		neighbors.append(GridPosition.new(row - 1, col + 1))
		neighbors.append(GridPosition.new(row + 1, col - 1))
		neighbors.append(GridPosition.new(row - 1, col - 1))
		return neighbors.filter(func(neighbor): return neighbor.is_in_bounds())

	static func from_cell_index(cell_index: int) -> GridPosition:
		@warning_ignore("integer_division")
		return GridPosition.new(cell_index / cols, cell_index % cols)

	static func to_bitmask(grid_positions: Array[GridPosition]) -> int:
		var bitmask: int = 0
		for grid_position in grid_positions:
			bitmask |= 1 << grid_position.to_cell_index()
		return bitmask

	static func debug_print(grid_positions: Array[GridPosition]) -> void:
		for grid_position in grid_positions:
			print(grid_position.to_cell_index())


class ChampionTurn:
	var did_attack: bool = false
	var did_move: bool = false

	func to_debug_string() -> String:
		return "did_attack: %s, did_move: %s" % [did_attack, did_move]


class PlayerActions:
	var can_attack: bool = false
	var moveable_cells: int = 0

	func has_remaining_actions() -> bool:
		return can_attack or moveable_cells != 0

	func to_debug_string() -> String:
		return "can_attack: %s, moveable_cells: %s" % [can_attack, moveable_cells]


var current_player_id: int = 0
var current_phase: Phase = Phase.POSITION_CHAMPION
var champions_positions: Array[int] = [-1, -1]
var champion_turn_state: Array[ChampionTurn] = [ChampionTurn.new(), ChampionTurn.new()]


func start_game() -> void:
	current_phase = Phase.POSITION_CHAMPION
	phase_changed.emit(current_phase)


func set_champion_position(player_id: int, cell_position: int) -> void:
	champions_positions[player_id] = cell_position
	if current_phase != Phase.POSITION_CHAMPION:
		return
	if champions_positions[0] != -1 and champions_positions[1] != -1:
		# Initial combat turn
		current_phase = Phase.COMBAT
		phase_changed.emit(current_phase)
		champion_turn_state[current_player_id] = ChampionTurn.new()
		turn_started.emit(current_player_id, _get_player_actions(current_player_id))


func move_champion(player_id: int, cell_position: int) -> PlayerActions:
	"""
	Moves the champion to the given cell position.
	"""
	if current_phase != Phase.COMBAT:
		return
	if current_player_id != player_id:
		return
	champions_positions[player_id] = cell_position
	champion_turn_state[player_id].did_move = true
	return _get_player_actions(player_id)


func attack_champion(player_id: int) -> PlayerActions:
	"""
	Attacks the other champion.
	"""
	if current_phase != Phase.COMBAT:
		return
	if current_player_id != player_id:
		return
	champion_turn_state[player_id].did_attack = true
	return _get_player_actions(player_id)


func get_champion_position(player_id: int) -> int:
	return champions_positions[player_id]


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
	champion_turn_state[current_player_id] = ChampionTurn.new()
	turn_started.emit(current_player_id, _get_player_actions(current_player_id))


func _get_player_actions(player_id: int) -> PlayerActions:
	var actions = PlayerActions.new()

	var turn_state = champion_turn_state[player_id]

	# Determine the action range for this champion.
	var champion_range: Array[GridPosition] = []
	var champion_position = GridPosition.from_cell_index(champions_positions[player_id])
	champion_range.append_array(champion_position.get_neighbors())

	# Get the other champion's position.
	var other_player_id = 1 - player_id
	var other_champion_position = GridPosition.from_cell_index(champions_positions[other_player_id])

	# Determine if the champion is within attack range.
	# Don't allow this champion to attack this turn if it has already attacked.
	if not turn_state.did_attack:
		actions.can_attack = champion_range.any(
			func(cell): return cell.equals(other_champion_position)
		)

	# Don't allow this champion to move to a cell if it's occupied.
	champion_range = champion_range.filter(
		func(cell): return not cell.equals(other_champion_position)
	)

	# Don't allow this champion to move this turn if it has already moved.
	if not turn_state.did_move:
		actions.moveable_cells = GridPosition.to_bitmask(champion_range)

	return actions
