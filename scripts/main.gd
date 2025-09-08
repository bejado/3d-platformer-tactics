extends Node3D

@onready var grid := $Floor
@onready var champions: Array[Champion] = [$Champion0, $Champion1]

var current_player_id: int = 0


func _ready():
	print(grid)
	grid.cell_clicked.connect(_on_cell_clicked)
	Game.turn_started.connect(_on_turn_started)
	Game.phase_changed.connect(_on_phase_changed)
	Game.start_game()

	for i in champions.size():
		champions[i].champion_dropped.connect(_on_champion_dropped.bind(i))


func _on_turn_started(player_id: int, actions: Game.PlayerActions) -> void:
	$Instructions.text = "Player %d's turn" % [player_id + 1]
	if player_id == 0:
		$Instructions.label_settings.font_color = Color.RED
	else:
		$Instructions.label_settings.font_color = Color.BLUE
	self.current_player_id = player_id

	grid.set_range(actions.moveable_cells)


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
			$Instructions.label_settings.font_color = Color.WHITE
			for i in champions.size():
				champions[i].can_be_dragged = true
			champions[0].allowed_cell_range = [12, 23]
			champions[1].allowed_cell_range = [0, 11]
		Game.Phase.COMBAT:
			for i in champions.size():
				champions[i].can_be_dragged = false
