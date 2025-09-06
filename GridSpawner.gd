@tool
extends Node3D

@export var rows: int = 5:
	set(r):
		rows = r
		_create_grid()
@export var cols: int = 5:
	set(c):
		cols = c
		_create_grid()
@export var spacing: float = 2.0:
	set(s):
		spacing = s
		_create_grid()
@export var cube_size: float = 1.0:
	set(s):
		cube_size = s
		_create_grid()
@export var cube_thickness: float = 0.1:
	set(t):
		cube_thickness = t
		_create_grid()

func _create_grid() -> void:
	# Create one BoxMesh and share it across all children to save memory.
	var shared_mesh := BoxMesh.new()
	shared_mesh.size = Vector3(cube_size, cube_thickness, cube_size)

	# Optional: clear previous children if you re-run this scene often
	for child in get_children():
		child.queue_free()

	# Center the grid around (0, 0, 0)
	var x_center := (cols - 1) * 0.5
	var z_center := (rows - 1) * 0.5

	for r in range(rows):
		for c in range(cols):
			var mi := MeshInstance3D.new()
			mi.mesh = shared_mesh
			mi.transform.origin = Vector3(
				(c - x_center) * spacing,  # X
				cube_thickness * 0.5,      # Y
				(r - z_center) * spacing   # Z
			)
			add_child(mi)

func _ready() -> void:
	_create_grid()
