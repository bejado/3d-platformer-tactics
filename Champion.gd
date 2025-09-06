extends MeshInstance3D

signal champion_dropped(grid_position: Vector2, world_position: Vector3)

var is_dragging: bool = false
var drag_offset: Vector3
var original_position: Vector3
var collision_body: StaticBody3D

func _ready() -> void:
	# Add to champion group for easy identification
	add_to_group("champion")
	print("Champion added to group 'champion'.")

	# Find the StaticBody3D child for collision detection
	collision_body = get_node("StaticBody3D")
	if not collision_body:
		print("ERROR: No StaticBody3D child found! Champion needs a StaticBody3D child for collision detection.")
		return
	print("Collision body found:", collision_body)

	# Store original position and parent
	original_position = global_position
	print("Original position:", original_position)

	# Enable input processing
	set_process_input(true)
	print("Input processing enabled for Champion.")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(event)
			else:
				_end_drag(event)
	
	elif event is InputEventMouseMotion and is_dragging:
		_update_drag_position(event)

func _start_drag(event: InputEventMouseButton) -> void:
	# Check if mouse is over this champion
	var camera = get_viewport().get_camera_3d()
	if not camera:
		print("No camera found in viewport.")
		return
	
	# Create a ray from camera through mouse position
	var from = camera.project_ray_origin(event.position)
	var to = from + camera.project_ray_normal(event.position) * 1000
	print("Ray from:", from, "to:", to)
	
	# Check if ray intersects with this champion's bounding box
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	print("Raycast result:", result)
	
	# Check if this champion is being clicked (check collision body instead of self)
	if result and result.collider == collision_body:
		print("Champion clicked for dragging.")
		is_dragging = true
		drag_offset = global_position - _get_mouse_world_position(event.position)
		print("Drag offset set to:", drag_offset)

func _end_drag(event: InputEventMouseButton) -> void:
	if not is_dragging:
		return
	
	is_dragging = false
	
	# Find the closest grid cell
	var result = _find_closest_grid_cell()
	
	if result["found"]:
		# Snap to grid cell
		global_position = result["position"]
		original_position = global_position
	else:
		# Return to original position if no valid drop target
		global_position = original_position

func _update_drag_position(event: InputEventMouseMotion) -> void:
	if not is_dragging:
		return
	
	var new_position = _get_mouse_world_position(event.position) + drag_offset
	global_position = new_position

func _get_mouse_world_position(mouse_pos: Vector2) -> Vector3:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return Vector3.ZERO
	
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	# Project onto the ground plane (y = 0)
	var direction = (to - from).normalized()
	var t = -from.y / direction.y
	return from + direction * t

func _find_closest_grid_cell() -> Dictionary:
	# Define all possible grid positions
	var grid_positions = [
		Vector3(-1, 0.6, 3.5),
		Vector3(0, 0.6, 3.5),
		Vector3(1, 0.6, 3.5),
		Vector3(-1, 0.6, 2.5),
		Vector3(0, 0.6, 2.5),
		Vector3(1, 0.6, 2.5),
		Vector3(-1, 0.6, 1.5),
		Vector3(0, 0.6, 1.5),
		Vector3(1, 0.6, 1.5),
		Vector3(-1, 0.6, 0.5),
		Vector3(0, 0.6, 0.5),
		Vector3(1, 0.6, 0.5)
	]
	
	var closest_position = Vector3.ZERO
	var closest_distance = INF
	
	# Find the closest grid position
	for pos in grid_positions:
		var distance = global_position.distance_to(pos)
		if distance < closest_distance:
			closest_distance = distance
			closest_position = pos
	
	# Only snap if within a reasonable distance
	if closest_distance < 2.0:  # Adjust this threshold as needed
		return {"found": true, "position": closest_position}
	
	return {"found": false, "position": Vector3.ZERO}
