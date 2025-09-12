extends MeshInstance3D
class_name Champion

signal champion_dropped(cell_position: int)
signal champion_clicked

@export var can_be_dragged: bool = false
@export var can_be_clicked: bool = false
@export var show_hover_style: bool = false:
	set(hs):
		show_hover_style = hs
		if (
			hs
			and (
				interaction_state == InteractionState.HOVERED
				or interaction_state == InteractionState.MAYBE_DRAG
				or interaction_state == InteractionState.DRAGGING
			)
		):
			_apply_hover_state(true)
		if not hs:
			_apply_hover_state(false)

@export var cell_position: int = 0:
	set(cp):
		cell_position = cp
		if cp == -1:
			return
		var v = GridPosition.unidx(cp)
		global_position = GridPosition.coordinates(v)

# Which half of the grid the champion is allowed to be dropped in
# 0: no constraints
# -1: left half of the grid (in negative x direction)
# 1: right half of the grid (in positive x direction)
@export var allowed_cell_sector: int = 0

@export var outlined: bool = false:
	set(o):
		outlined = o
		if outlined:
			set_layer_mask_value(6, true)
		else:
			set_layer_mask_value(6, false)

var drag_offset: Vector3
var original_position: Vector3
var collision_body: StaticBody3D
var hover_material: Material

# Define all possible grid positions
var grid_positions := GridPosition.all_coordinates()

enum InteractionState {
	NOT_HOVERED, MOUSE_INVALID, MOUSE_INVALID_HOVERED, HOVERED, MAYBE_DRAG, DRAGGING
}
var interaction_state := InteractionState.NOT_HOVERED


func _ready() -> void:
	# Add to champion group for easy identification
	add_to_group("champion")

	# Create the hover material
	hover_material = StandardMaterial3D.new()
	hover_material.albedo_color = Color.YELLOW
	hover_material.render_priority = 1  # this is needed for material_overlay to work

	# Find the StaticBody3D child for collision detection
	collision_body = get_node("StaticBody3D")
	if not collision_body:
		return

	# Store original position and parent
	original_position = global_position

	# Enable input processing
	set_process_input(true)

	# Connect mouse signals to StaticBody3D
	collision_body.mouse_entered.connect(_on_mouse_entered.bind(collision_body))
	collision_body.mouse_exited.connect(_on_mouse_exited.bind(collision_body))


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Mouse down
				if interaction_state == InteractionState.NOT_HOVERED:
					interaction_state = InteractionState.MOUSE_INVALID
				elif interaction_state == InteractionState.HOVERED and can_be_dragged:
					interaction_state = InteractionState.MAYBE_DRAG
					_prepare_drag(event)
			else:
				# Mouse up
				if interaction_state == InteractionState.MOUSE_INVALID:
					interaction_state = InteractionState.NOT_HOVERED
				elif interaction_state == InteractionState.MOUSE_INVALID_HOVERED:
					interaction_state = InteractionState.HOVERED
					if show_hover_style:
						_apply_hover_state(true)
				elif interaction_state == InteractionState.HOVERED:
					if can_be_clicked:
						champion_clicked.emit()
				elif interaction_state == InteractionState.MAYBE_DRAG:
					if can_be_clicked:
						champion_clicked.emit()
					interaction_state = InteractionState.HOVERED
				elif interaction_state == InteractionState.DRAGGING:
					interaction_state = InteractionState.HOVERED
					_end_drag(event)

	elif event is InputEventMouseMotion:
		# Mouse move
		if interaction_state == InteractionState.MAYBE_DRAG:
			interaction_state = InteractionState.DRAGGING
			_update_drag_position(event)
		elif interaction_state == InteractionState.DRAGGING:
			_update_drag_position(event)


func _on_mouse_entered(_static_body: StaticBody3D) -> void:
	if interaction_state == InteractionState.NOT_HOVERED:
		interaction_state = InteractionState.HOVERED
		if show_hover_style:
			_apply_hover_state(true)
	elif interaction_state == InteractionState.MOUSE_INVALID:
		interaction_state = InteractionState.MOUSE_INVALID_HOVERED


func _on_mouse_exited(_static_body: StaticBody3D) -> void:
	if interaction_state == InteractionState.HOVERED:
		interaction_state = InteractionState.NOT_HOVERED
		_apply_hover_state(false)
	elif interaction_state == InteractionState.MOUSE_INVALID_HOVERED:
		interaction_state = InteractionState.MOUSE_INVALID


func _apply_hover_state(state: bool) -> void:
	if state:
		material_overlay = hover_material
	else:
		material_overlay = null


func _prepare_drag(event: InputEventMouseButton) -> void:
	drag_offset = global_position - _get_mouse_world_position(event.position)


func _end_drag(_event: InputEventMouseButton) -> void:
	# Find the closest grid cell
	var result = _find_closest_grid_cell()

	if not result["found"]:
		# Return to original position if no valid drop target
		global_position = original_position
		return

	# Check if the cell is in the allowed sector
	var cell := GridPosition.unidx(result["index"])
	@warning_ignore("integer_division") var half_width := GridPosition.D / 2
	var is_in_allowed_cell_range = (
		allowed_cell_sector == 0 or ((cell.y - half_width + 0.5) * -1 * allowed_cell_sector > 0)
	)

	if not is_in_allowed_cell_range:
		# Return to original position if no valid drop target
		global_position = original_position
		return

	# Snap to grid cell
	global_position = result["position"]
	original_position = global_position
	cell_position = result["index"]
	champion_dropped.emit(cell_position)


func _update_drag_position(event: InputEventMouseMotion) -> void:
	var new_position = _get_mouse_world_position(event.position) + drag_offset
	global_position = new_position


func _get_mouse_sector(mouse_pos: Vector2) -> int:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return 0

	# Project the two sector lines onto the viewport
	var line1_start = camera.unproject_position(
		Vector3(GridPosition.EAST_EDGE_X, 0, -1000)
	)
	var line1_end = camera.unproject_position(
		Vector3(GridPosition.EAST_EDGE_X, 0, 1000)
	)
	var line2_start = camera.unproject_position(
		Vector3(
			GridPosition.EAST_EDGE_X,
			GridPosition.CELL_HEIGHT,
			-1000
		)
	)
	var line2_end = camera.unproject_position(
		Vector3(
			GridPosition.EAST_EDGE_X,
			GridPosition.CELL_HEIGHT,
			1000
		)
	)

	# Test which side of each line the mouse is on
	var mouse_side_line1 = _point_side_of_line(mouse_pos, line1_start, line1_end)
	var mouse_side_line2 = _point_side_of_line(mouse_pos, line2_start, line2_end)

	# Determine which sector the mouse is in
	# If mouse is on the "left" side of line1, it's in sector 0
	# If mouse is on the "right" side of line1 but "left" side of line2, it's in sector 1
	# If mouse is on the "right" side of line2, it's in sector 2
	if mouse_side_line1 < 0:
		return 0  # Below/left of first line
	elif mouse_side_line2 < 0:
		return 1  # Between the two lines
	else:
		return 2  # Above/right of second line


func _point_side_of_line(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	# Calculate which side of the line the point is on using cross product
	# Returns negative if point is on one side, positive if on the other
	var line_vector = line_end - line_start
	var point_vector = point - line_start
	return line_vector.x * point_vector.y - line_vector.y * point_vector.x


func _get_mouse_world_position(mouse_pos: Vector2) -> Vector3:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return Vector3.ZERO

	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000

	# Determine which ground plane to use based on mouse sector
	# TODO: these constants should be in GridPosition
	var sector = _get_mouse_sector(mouse_pos)
	var ground_y = 0.0
	if sector == 0:
		ground_y = -2.0
	elif sector == 1:
		ground_y = 0.0
	elif sector == 2:
		ground_y = 2.0

	# Project onto the appropriate ground plane
	var direction = (to - from).normalized()
	var t = (ground_y - from.y) / direction.y
	return from + direction * t


func _find_closest_grid_cell() -> Dictionary:
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
