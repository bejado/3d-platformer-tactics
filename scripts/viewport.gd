extends SubViewport

@onready var stencil_viewport: SubViewport = self
@onready var stencil_camera: Camera3D = self.get_node("Camera3D")


func _process(_delta: float) -> void:
	var viewport := get_parent().get_viewport()
	var current_camera := viewport.get_camera_3d()

	if stencil_viewport.size != viewport.size:
		stencil_viewport.size = viewport.size

	if current_camera:
		stencil_camera.fov = current_camera.fov
		stencil_camera.global_transform = current_camera.global_transform
