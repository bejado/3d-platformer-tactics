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

func _create_grid() -> void:
	# Create one BoxMesh and share it across all children to save memory.
	var shared_mesh := BoxMesh.new()
	shared_mesh.size = Vector3(cube_size, cube_thickness, cube_size)

	# Clear debug labels array
	debug_labels.clear()
	
	# Optional: clear previous children if you re-run this scene often
	for child in get_children():
		child.queue_free()

	# Center the grid around (0, 0, 0)
	var x_center := (cols - 1) * 0.5
	var z_center := (rows - 1) * 0.5

	var i = 0
	for r in range(rows):
		for c in range(cols):
			# Create a StaticBody3D to handle mouse picking
			var static_body := StaticBody3D.new()
			static_body.transform.origin = Vector3(
				(c - x_center) * spacing,  # X
				cube_thickness * 0.5,      # Y
				(r - z_center) * spacing   # Z
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
			
			# Create materials for hover effect
			var original_material := StandardMaterial3D.new()
			# Alternate white and grey for grid cells
			if ((r + c) % 2) == 0:
				original_material.albedo_color = Color.WHITE
			else:
				original_material.albedo_color = Color(0.7, 0.7, 0.7)
			mi.material_override = original_material
			
			var hover_material := StandardMaterial3D.new()
			hover_material.albedo_color = Color.YELLOW
			
			# Store materials as metadata for hover detection
			static_body.set_meta("original_material", original_material)
			static_body.set_meta("hover_material", hover_material)
			static_body.set_meta("mesh_instance", mi)
			
			# Connect mouse signals to StaticBody3D
			static_body.mouse_entered.connect(_on_mouse_entered.bind(static_body))
			static_body.mouse_exited.connect(_on_mouse_exited.bind(static_body))
			
			# Store cell information as metadata for click detection
			static_body.set_meta("cell_index", i)
			
			add_child(static_body)
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
				cell_clicked.emit(cell_index)
				print("Cell clicked: index=%d" % cell_index)

func _on_mouse_entered(static_body: StaticBody3D) -> void:
	# Track the currently hovered cell
	currently_hovered_cell = static_body
	
	# Change to hover material when mouse enters
	var hover_material = static_body.get_meta("hover_material")
	var mesh_instance = static_body.get_meta("mesh_instance")
	mesh_instance.material_override = hover_material

func _on_mouse_exited(static_body: StaticBody3D) -> void:
	# Clear the currently hovered cell if it's this one
	if currently_hovered_cell == static_body:
		currently_hovered_cell = null
	
	# Revert to original material when mouse exits
	var original_material = static_body.get_meta("original_material")
	var mesh_instance = static_body.get_meta("mesh_instance")
	mesh_instance.material_override = original_material
