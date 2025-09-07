extends Node3D

@onready var grid := $Floor
@onready var champions: Array[Champion] = [$Champion0, $Champion1]

var current_player_id: int = 0


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


func _ready():
	print(grid)
	grid.cell_clicked.connect(_on_cell_clicked)
	Game.turn_started.connect(_on_turn_started)
	Game.phase_changed.connect(_on_phase_changed)
	Game.start_game()

	for i in champions.size():
		champions[i].champion_dropped.connect(_on_champion_dropped.bind(i))


func _on_turn_started(player_id: int) -> void:
	$Instructions.text = "Player %d's turn" % [player_id + 1]
	self.current_player_id = player_id

	# Determine the movement range for this chamption.
	var movement_range: Array[GridPosition] = []
	var chamption_position = GridPosition.from_cell_index(champions[player_id].cell_position)
	movement_range.append_array(chamption_position.get_neighbors())

	# Don't allow this chamption to move to a cell if it's occupied.
	var other_player_id = 1 - player_id
	var other_champion_position = GridPosition.from_cell_index(
		Game.get_champion_position(other_player_id)
	)
	movement_range = movement_range.filter(
		func(cell): return not cell.equals(other_champion_position)
	)

	GridPosition.debug_print(movement_range)

	grid.set_range(GridPosition.to_bitmask(movement_range))


func _on_cell_clicked(_cell_index: int) -> void:
	champions[self.current_player_id].cell_position = _cell_index
	Game.set_champion_position(self.current_player_id, _cell_index)
	Game.end_turn(self.current_player_id)


func _on_champion_dropped(
	cell_position: int,
	champion_id: int,
) -> void:
	print("Champion ", champion_id, " dropped in cell: ", cell_position)
	Game.set_champion_position(champion_id, cell_position)


func _on_phase_changed(phase: Game.Phase) -> void:
	match phase:
		Game.Phase.POSITION_CHAMPION:
			$Instructions.text = "Place the champions on the grid"
			for i in champions.size():
				champions[i].can_be_dragged = true
			champions[0].allowed_cell_range = [12, 23]
			champions[1].allowed_cell_range = [0, 11]
		Game.Phase.COMBAT:
			for i in champions.size():
				champions[i].can_be_dragged = false
