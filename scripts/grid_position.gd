extends Node

class_name GridPosition

# Grid constants
const W := 3
const D := 8
const H := 3
const N := W * D * H  # 72

const CELL_WIDTH := 1.0
const CELL_HEIGHT := 2.0
const CELL_DEPTH := 1.0

const EAST_EDGE_X := 1.5

var x: int
var y: int
var z: int


func _init(ix: int, iy: int, iz: int):
	y = iy
	x = ix
	z = iz


func to_cell_index() -> int:
	return idx(x, y, z)


func is_in_bounds() -> bool:
	return x >= 0 and x < W and y >= 0 and y < D and z >= 0 and z < H


func equals(other: GridPosition) -> bool:
	return x == other.x and y == other.y and z == other.z


func get_neighbors() -> Array[GridPosition]:
	"""
	Returns the neighbors (both diagonal and orthogonal) of the grid position.
	"""
	var neighbors: Array[GridPosition] = []
	neighbors.append(GridPosition.new(x, y + 1, z))
	neighbors.append(GridPosition.new(x, y - 1, z))
	neighbors.append(GridPosition.new(x + 1, y, z))
	neighbors.append(GridPosition.new(x - 1, y, z))
	neighbors.append(GridPosition.new(x + 1, y + 1, z))
	neighbors.append(GridPosition.new(x + 1, y - 1, z))
	neighbors.append(GridPosition.new(x - 1, y + 1, z))
	neighbors.append(GridPosition.new(x - 1, y - 1, z))
	return neighbors.filter(func(neighbor): return neighbor.is_in_bounds())


static func from_cell_index(cell_index: int) -> GridPosition:
	var v := unidx(cell_index)
	return GridPosition.new(v.x, v.y, v.z)


static func to_cell_positions(grid_positions: Array[GridPosition]) -> Array[int]:
	var cell_positions: Array[int] = []
	for grid_position in grid_positions:
		cell_positions.append(grid_position.to_cell_index())
	return cell_positions


static func debug_print(grid_positions: Array[GridPosition]) -> void:
	for grid_position in grid_positions:
		print(grid_position.to_cell_index())


static func idx(xx: int, yy: int, zz: int) -> int:
	assert(xx >= 0 and xx < W)
	assert(yy >= 0 and yy < D)
	assert(zz >= 0 and zz < H)
	return xx + W * (yy + D * zz)


static func unidx(i: int) -> Vector3i:
	assert(i >= 0 and i < N)
	var xx := i % W
	@warning_ignore("integer_division") var yy := (i / W) % D
	@warning_ignore("integer_division") var zz := i / (W * D)
	return Vector3i(xx, yy, zz)


static func coordinates(v: Vector3i) -> Vector3:
	return Vector3(-1.0 + v.x, -2.0 + v.z * 2.0, -3.5 + v.y)


static func all_coordinates() -> Array[Vector3]:
	var grid_positions: Array[Vector3] = []
	for i in range(N):
		grid_positions.append(coordinates(unidx(i)))
	return grid_positions
