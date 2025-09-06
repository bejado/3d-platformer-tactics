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
			static_body.add_child(mi)
			
			# Create collision shape for mouse detection
			var collision_shape := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			box_shape.size = Vector3(cube_size, cube_thickness, cube_size)
			collision_shape.shape = box_shape
			static_body.add_child(collision_shape)
			
			# Create materials for hover effect
			var original_material := StandardMaterial3D.new()
			original_material.albedo_color = Color.WHITE
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
			
			add_child(static_body)

func _ready() -> void:
	_create_grid()

func _on_mouse_entered(static_body: StaticBody3D) -> void:
	# Change to hover material when mouse enters
	var hover_material = static_body.get_meta("hover_material")
	var mesh_instance = static_body.get_meta("mesh_instance")
	mesh_instance.material_override = hover_material

func _on_mouse_exited(static_body: StaticBody3D) -> void:
	# Revert to original material when mouse exits
	var original_material = static_body.get_meta("original_material")
	var mesh_instance = static_body.get_meta("mesh_instance")
	mesh_instance.material_override = original_material
