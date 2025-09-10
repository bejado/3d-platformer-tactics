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
		if cp == -1:
			cell_position = -1
			return
		var col = cp % 3
		var row = cp / 3
		global_position = Vector3(-1 + col, 0.1, -3.5 + row)
		cell_position = cp
@export var allowed_cell_range: Array[int] = [0, INF]
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

	# Check if the cell is in the allowed cell range
	var is_in_allowed_cell_range = (
		result["index"] >= allowed_cell_range[0] and result["index"] <= allowed_cell_range[1]
	)

	if result["found"] and is_in_allowed_cell_range:
		# Snap to grid cell
		global_position = result["position"]
		original_position = global_position
		cell_position = result["index"]
		champion_dropped.emit(cell_position)
	else:
		# Return to original position if no valid drop target
		global_position = original_position


func _update_drag_position(event: InputEventMouseMotion) -> void:
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
			grid_positions.append(Vector3(-1 + col, 0.1, -3.5 + row))

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
