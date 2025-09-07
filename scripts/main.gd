extends Node3D

@onready var grid := $Floor
@onready var champions: Array[Champion] = [$Champion0, $Champion1]

var current_player_id: int = 0


func _ready():
	print(grid)
	grid.cell_clicked.connect(_on_cell_clicked)
	Game.turn_started.connect(_on_turn_started)
	Game.start_game()


func _on_turn_started(player_id: int) -> void:
	self.current_player_id = player_id
	for i in champions.size():
		champions[i].can_be_dragged = i == player_id
	grid.show_movement_range(champions[player_id].cell_position)


func _on_cell_clicked(_cell_index: int) -> void:
	champions[self.current_player_id].cell_position = _cell_index
	Game.end_turn(self.current_player_id)
