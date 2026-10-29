extends Node3D
## Native Godot 3D broadcast intro preview. Procedural stand-ins until
## licensed/artist-created arena and Gladiator models are supplied.
var elapsed := 0.0
var era := "S1A"
var camera: Camera3D
var title: Label
var subtitle: Label
var music: Node
var roster: Array[String] = ["GLADIATOR ONE", "GLADIATOR TWO", "GLADIATOR THREE"]
var custom_intro := false

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://intro_studio.cfg") == OK:
		era = str(cfg.get_value("intro", "era", "S1A"))
		custom_intro = bool(cfg.get_value("intro", "custom_enabled", false))
		if custom_intro:
			var names: PackedStringArray = cfg.get_value("intro", "lineup", PackedStringArray())
			if not names.is_empty():
				roster = Array(names)
	_build_set()
	_build_overlay()
	music = load("res://scripts/music_director.gd").new()
	add_child(music)
	music.set_era(era)
	music.cue("intro_trumpet" if era == "2026" else "intro")

func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.35
	m.roughness = 0.42
	return m

func _box(label_name: String, at: Vector3, dimensions: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label_name
	var shape := BoxMesh.new()
	shape.size = dimensions
	mesh.mesh = shape
	mesh.position = at
	mesh.material_override = _material(color)
	add_child(mesh)

func _build_set() -> void:
	var modern := era == "2026"
	var floor_color := Color("#14212e") if modern else Color("#34486a")
	_box("Arena floor", Vector3(0, -0.2, 0), Vector3(26, 0.4, 18), floor_color)
	_box("Rear stands", Vector3(0, 2, -11), Vector3(32, 5, 2), Color("#16223b"))
	for side in [-1, 1]:
		_box("Light tower", Vector3(side * 11, 4, -7), Vector3(0.5, 8, 0.5), Color("#9cabb9"))
		for n in range(4):
			var light := OmniLight3D.new()
			light.position = Vector3(side * 11, 5 + n * 0.6, -6.5)
			light.light_color = Color("#8db8ff") if modern else Color("#ffd58b")
			light.light_energy = 1.6
			light.omni_range = 17
			add_child(light)
	for n in range(3):
		var podium := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 1.3
		cylinder.bottom_radius = 1.5
		cylinder.height = 1.2
		podium.mesh = cylinder
		podium.position = Vector3((n - 1) * 5.0, 0.6, -2)
		podium.material_override = _material(Color("#aab6c8"))
		add_child(podium)
		# Abstract figure is a temporary staging marker, not a Gladiator model.
		var figure := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.48
		capsule.height = 2.6
		figure.mesh = capsule
		figure.position = Vector3((n - 1) * 5.0, 2.5, -2)
		figure.material_override = _material(Color("#e1ac49") if modern else Color("#ce4658"))
		add_child(figure)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#070d20")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#a9b7d2")
	env.environment.ambient_light_energy = 0.5
	add_child(env)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 55
	add_child(camera)

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	title = Label.new()
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-420, 45)
	title.size = Vector2(840, 75)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("#f7d16d"))
	root.add_child(title)
	subtitle = Label.new()
	subtitle.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	subtitle.position = Vector2(-440, -105)
	subtitle.size = Vector2(880, 65)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color.WHITE)
	root.add_child(subtitle)

func _process(delta: float) -> void:
	elapsed += delta
	var phase := fmod(elapsed, 15.0)
	camera.position = Vector3(sin(elapsed * 0.23) * (12.0 if era == "2026" else 8.0), 5.0 + sin(elapsed * 0.4) * 1.8, 15.0 - minf(phase, 9.0) * 0.55)
	camera.look_at(Vector3(0, 1.5, -2), Vector3.UP)
	title.text = "AMERICAN GLADIATORS"
	if phase < 3.0:
		subtitle.text = ("2026 REVIVAL" if era == "2026" else "ERAS MODE - " + era)
	elif phase < 11.0:
		var index := int((phase - 3.0) / 2.7) % maxi(1, roster.size())
		subtitle.text = roster[index] if not roster.is_empty() else "GLADIATORS"
	else:
		subtitle.text = "THE COMPETITION BEGINS"
	if elapsed >= 15.0:
		get_tree().change_scene_to_file("res://scenes/main.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_SPACE]:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
