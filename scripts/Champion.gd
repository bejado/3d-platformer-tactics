extends MeshInstance3D

@export var can_be_dragged: bool = true
@export var cell_position: int = 0:
	set(cp):
		var col = cp % 3
		var row = cp / 3
		global_position = Vector3(-1 + col, 0.6, -3.5 + row)
		cell_position = cp

var is_dragging: bool = false
var drag_offset: Vector3
var original_position: Vector3
var collision_body: StaticBody3D


func _ready() -> void:
	# Add to champion group for easy identification
	add_to_group("champion")

	# Find the StaticBody3D child for collision detection
	collision_body = get_node("StaticBody3D")
	if not collision_body:
		return

	# Store original position and parent
	original_position = global_position

	# Enable input processing
	set_process_input(true)


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
	# Check if this champion can be dragged
	if not can_be_dragged:
		return

	# Check if mouse is over this champion
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return

	# Create a ray from camera through mouse position
	var from = camera.project_ray_origin(event.position)
	var to = from + camera.project_ray_normal(event.position) * 1000

	# Check if ray intersects with this champion's bounding box
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)

	# Check if this champion is being clicked (check collision body instead of self)
	if result and result.collider == collision_body:
		is_dragging = true
		drag_offset = global_position - _get_mouse_world_position(event.position)


func _end_drag(_event: InputEventMouseButton) -> void:
	if not is_dragging:
		return

	is_dragging = false

	# Find the closest grid cell
	var result = _find_closest_grid_cell()

	if result["found"]:
		# Snap to grid cell
		global_position = result["position"]
		original_position = global_position
		cell_position = result["index"]
		print("Champion dropped in cell: ", cell_position)
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
	var grid_positions = []
	# Generate a 3x4 grid of positions in a loop
	for row in range(8):
		for col in range(3):
			grid_positions.append(Vector3(-1 + col, 0.6, -3.5 + row))

	var closest_position = Vector3.ZERO
	var closest_distance = INF

	# Find the closest grid position and save its index
	var closest_index = -1
	for i in grid_positions.size():
		var pos = grid_positions[i]
		var distance = global_position.distance_to(pos)
		if distance < closest_distance:
			closest_distance = distance
			closest_position = pos
			closest_index = i

	# Only snap if within a reasonable distance
	if closest_distance < 2.0:  # Adjust this threshold as needed
		return {"found": true, "position": closest_position, "index": closest_index}

	return {"found": false, "position": Vector3.ZERO, "index": -1}
