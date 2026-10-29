extends Node3D
## Powerball 3D visual test. Standalone arena scene; gameplay integration follows.
## Coordinates: x across field, z from the contender baseline toward the goals.

func _ready() -> void:
	_build_arena()

func _material(color: Color, metallic: float = 0.0, roughness: float = 0.65) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat

func _box(parent: Node3D, name: String, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = position
	node.material_override = _material(color)
	parent.add_child(node)
	return node

func _cylinder(parent: Node3D, name: String, position: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.position = position
	node.material_override = _material(color, 0.35, 0.32)
	parent.add_child(node)
	return node

func _build_arena() -> void:
	_box(self, "Powerball playing floor", Vector3(0, -0.12, 0), Vector3(24, 0.24, 16), Color("#276b52"))
	_box(self, "Gold perimeter left", Vector3(-12, 0.02, 0), Vector3(0.12, 0.04, 16), Color("#e5b84d"))
	_box(self, "Gold perimeter right", Vector3(12, 0.02, 0), Vector3(0.12, 0.04, 16), Color("#e5b84d"))
	_box(self, "Gold baseline", Vector3(0, 0.02, 8), Vector3(24, 0.04, 0.12), Color("#e5b84d"))
	_box(self, "Rear arena wall", Vector3(0, 2.5, -9.2), Vector3(29, 5, 0.8), Color("#182c58"))
	for x in [-9.0, 0.0, 9.0]:
		_cylinder(self, "Season 1A scoring cylinder", Vector3(x, 0.58, -3.0), 0.8, 1.15, Color("#aab4bf"))
		_cylinder(self, "Goal rim", Vector3(x, 1.19, -3.0), 0.88, 0.12, Color("#f0c44d"))
	for x in [-10.0, 10.0]:
		_cylinder(self, "Ball rack", Vector3(x, 0.6, 5.9), 0.65, 1.2, Color("#a9a9aa"))
	for row in range(4):
		_box(self, "Crowd terrace", Vector3(0, 0.4 + row * 0.65, -10.0 - row * 1.25), Vector3(29, 0.35, 1.25), Color("#344267"))
	var key := DirectionalLight3D.new()
	key.name = "Arena overhead lighting"
	key.rotation_degrees = Vector3(-65, -20, 0)
	key.light_energy = 1.6
	key.shadow_enabled = true
	add_child(key)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#101a30")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#8290a6")
	environment.environment.ambient_light_energy = 0.6
	add_child(environment)
	var camera := Camera3D.new()
	camera.name = "TV broadcast camera"
	camera.position = Vector3(0, 15, 20)
	camera.rotation_degrees = Vector3(-35, 0, 0)
	camera.fov = 57
	camera.current = true
	add_child(camera)
