@tool
extends Node3D

signal cell_clicked(cell_index: int)

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

var debug_labels: Array[Label3D] = []
var currently_hovered_cell: StaticBody3D = null
var grid_cells: Array[StaticBody3D] = []
var cells_in_movement_range: Array[int] = []
var is_showing_movement_range: bool = false


func set_range(range_bits: int) -> void:
	"""
	range_bits is a bitmask, where each bit represents a cell
	For example, if range_bits is 0b1, then only cell 0 is in range
	"""
	hide_range()

	var cell_count = rows * cols

	# Loop through each bit in range_bits
	for i in range(cell_count):
		if range_bits & (1 << i):
			cells_in_movement_range.append(i)

			# Get the target cell
			var target_cell = grid_cells[i]
			var mesh_instance = target_cell.get_meta("mesh_instance")
			var movement_material = target_cell.get_meta("movement_material")

			# Apply movement range material
			mesh_instance.material_override = movement_material

	# Set movement range mode
	is_showing_movement_range = true


func hide_range() -> void:
	# Clear movement range tracking
	cells_in_movement_range.clear()
	is_showing_movement_range = false

	# Reset all cells to their original materials
	for cell in grid_cells:
		var mesh_instance = cell.get_meta("mesh_instance")
		var original_material = cell.get_meta("original_material")
		mesh_instance.material_override = original_material


func _create_grid() -> void:
	# Create one BoxMesh and share it across all children to save memory.
	var shared_mesh := BoxMesh.new()
	shared_mesh.size = Vector3(cube_size, cube_thickness, cube_size)

	# Clear debug labels array
	debug_labels.clear()
	grid_cells.clear()

	# Optional: clear previous children if you re-run this scene often
	for child in get_children():
		child.queue_free()

	# Center the grid around (0, 0, 0)
	var x_center := (cols - 1) * 0.5
	var z_center := (rows - 1) * 0.5

	# Create 4 materials: one dimension is light/dark, the other is player 0/player 1
	var player_0_color: Color = Color(1.0, 0.5, 0.5)
	var player_1_color: Color = Color(0.5, 0.5, 1.0)
	var light_player_0_material: Material = StandardMaterial3D.new()
	light_player_0_material.albedo_color = player_0_color
	var dark_player_0_material: Material = StandardMaterial3D.new()
	dark_player_0_material.albedo_color = player_0_color * 0.7
	var light_player_1_material: Material = StandardMaterial3D.new()
	light_player_1_material.albedo_color = player_1_color
	var dark_player_1_material: Material = StandardMaterial3D.new()
	dark_player_1_material.albedo_color = player_1_color * 0.7

	# Create the movement range materials
	var light_movement_material: Material = StandardMaterial3D.new()
	light_movement_material.albedo_color = Color.GREEN
	var dark_movement_material: Material = StandardMaterial3D.new()
	dark_movement_material.albedo_color = Color.GREEN * 0.7

	# Create the hover materials
	var hover_material: Material = StandardMaterial3D.new()
	hover_material.albedo_color = Color.YELLOW

	var i = 0
	for r in range(rows):
		for c in range(cols):
			# Create a StaticBody3D to handle mouse picking
			var static_body := StaticBody3D.new()
			static_body.transform.origin = Vector3(
				(c - x_center) * spacing, cube_thickness * 0.5, (r - z_center) * spacing  # X  # Y  # Z
			)

			# Create MeshInstance3D as child of StaticBody3D
			var mi := MeshInstance3D.new()
			mi.mesh = shared_mesh
			# Disable shadow casting for grid meshes
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			static_body.add_child(mi)

			# Create collision shape for mouse detection
			var collision_shape := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			box_shape.size = Vector3(cube_size, cube_thickness, cube_size)
			collision_shape.shape = box_shape
			static_body.add_child(collision_shape)

			# Create 3D text label for debugging
			var label_3d := Label3D.new()
			label_3d.text = "%d" % [i]  # Show column, row index
			label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label_3d.no_depth_test = true
			label_3d.position = Vector3(0, 0.1, 0)  # Slightly above the cell
			label_3d.scale = Vector3(1.0, 1.0, 1.0)  # Make it smaller
			label_3d.visible = false  # Start hidden
			static_body.add_child(label_3d)

			# Store reference for debug toggle
			debug_labels.append(label_3d)

			# Alternate white and grey for grid cells
			var original_material: Material
			var movement_material: Material
			if ((r + c) % 2) == 0:
				if i <= 11:
					original_material = light_player_1_material
				else:
					original_material = light_player_0_material
				movement_material = light_movement_material
			else:
				if i <= 11:
					original_material = dark_player_1_material
				else:
					original_material = dark_player_0_material
				movement_material = dark_movement_material
			mi.material_override = original_material

			# Store materials as metadata for hover detection
			static_body.set_meta("original_material", original_material)
			static_body.set_meta("hover_material", hover_material)
			static_body.set_meta("movement_material", movement_material)
			static_body.set_meta("mesh_instance", mi)

			# Connect mouse signals to StaticBody3D
			static_body.mouse_entered.connect(_on_mouse_entered.bind(static_body))
			static_body.mouse_exited.connect(_on_mouse_exited.bind(static_body))

			# Store cell information as metadata for click detection
			static_body.set_meta("cell_index", i)

			add_child(static_body)
			grid_cells.append(static_body)
			i += 1


func _ready() -> void:
	_create_grid()
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_D:
			# Toggle debug labels visibility when D key is pressed/released
			var show_labels = event.pressed
			for label in debug_labels:
				label.visible = show_labels

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# If there's a currently hovered cell, emit the click signal
			if currently_hovered_cell:
				var cell_index = currently_hovered_cell.get_meta("cell_index")

				# If showing movement range, only allow clicks on movement range cells
				if is_showing_movement_range:
					if cell_index in cells_in_movement_range:
						cell_clicked.emit(cell_index)
					else:
						print("Can only select cells within movement range")
				else:
					# Normal mode - allow clicks on any cell
					cell_clicked.emit(cell_index)


func _on_mouse_entered(static_body: StaticBody3D) -> void:
	# Get cell index to check if it's in movement range
	var cell_index = static_body.get_meta("cell_index")

	# If showing movement range, only allow hover on movement range cells
	if is_showing_movement_range:
		if cell_index not in cells_in_movement_range:
			return  # Don't show hover for non-movement range cells

	# Track the currently hovered cell
	currently_hovered_cell = static_body

	var mesh_instance = static_body.get_meta("mesh_instance")
	var hover_material = static_body.get_meta("hover_material")
	mesh_instance.material_override = hover_material


func _on_mouse_exited(static_body: StaticBody3D) -> void:
	# Clear the currently hovered cell if it's this one
	if currently_hovered_cell == static_body:
		currently_hovered_cell = null

	# Get cell index to check if it's in movement range
	var cell_index = static_body.get_meta("cell_index")
	var mesh_instance = static_body.get_meta("mesh_instance")

	# Revert to appropriate material based on movement range state
	if cell_index in cells_in_movement_range:
		# Cell is in movement range - revert to green movement material
		var movement_material = static_body.get_meta("movement_material")
		mesh_instance.material_override = movement_material
	else:
		# Cell is not in movement range - revert to original material
		var original_material = static_body.get_meta("original_material")
		mesh_instance.material_override = original_material
