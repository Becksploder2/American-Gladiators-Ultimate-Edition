extends Node2D
## Early playable Powerball prototype. No copyrighted assets are bundled.

const SAVE_PATH := "user://age_save.cfg"
const WIDTH := 960.0
const HEIGHT := 540.0
const INK := Color("#0b1230")
const BLUE := Color("#194b9b")
const RED := Color("#d94a4a")
const GOLD := Color("#f5cf6b")
const LIGHT := Color("#f1f3ff")
const GREEN := Color("#2caa81")

var mode := "ERAS"
var era_index := 0
var era_labels := ["S1A", "S1B", "S2A", "S2B", "S3A", "S3B", "S4A", "S4B", "S5A", "S5B", "S6", "S7", "2026"]
var host_primary := "MIKE ADAMLE"
var host_secondary := "JOE THEISMANN"
var screen := "INTRO"
var intro_time := 0.0
var event_name := "POWERBALL"
var contender := Vector2(150, 295)
var gladiator := Vector2(680, 295)
var powerball_defenders: Array[Vector2] = []
var ball := Vector2(380, 295)
var holding_ball := false
var ai_contender := Vector2(815, 395)
var ai_holding := false
var ai_score := 0
var ai_recovery := 0.0
var ai_goal_index := 0
var assault_station := 0
var assault_fired: Array[bool] = [false, false, false, false, false]
var assault_projectile := Vector2(-100, -100)
var assault_timer := 1.0
var score := 0
var time_left := 50.0
var whistle_countdown := 0.0
var move_speed := 205.0
var ai_speed := 125.0
var gamepad_name := "KEYBOARD"
var unlock_gladiator := false
var season_wins := 0
var event_index := 0
var normal_events := ["POWERBALL", "ATLASPHERE", "JOUST"]
var upcoming_events: Array[String] = []
var last_touch := ""
var message := ""
var hud_font: Font = ThemeDB.fallback_font
var sound_player: AudioStreamPlayer
var whistle_played := false
var theme_player: AudioStreamPlayer
var theme_picker: FileDialog
var classic_logo: Texture2D = preload("res://assets/logos/classic.svg")
var modern_logo: Texture2D = preload("res://assets/logos/prime_2026.svg")
var roster_page := 0
var roster_names: Array[String] = []

func _ready() -> void:
	_install_input_actions()
	_setup_audio()
	_load_progress()
	var music_cfg := ConfigFile.new()
	if music_cfg.load("user://music.cfg") == OK:
		var saved_path: String = music_cfg.get_value("music", "theme", "")
		if FileAccess.file_exists(saved_path):
			_theme_selected(saved_path)
	Input.joy_connection_changed.connect(_controller_changed)
	_controller_changed(0, false)
	_refresh_schedule()
	_load_roster_gallery()
	queue_redraw()

func _install_input_actions() -> void:
	_bind_action("move_left", KEY_LEFT, JOY_BUTTON_DPAD_LEFT, JOY_AXIS_LEFT_X, -1.0)
	_bind_action("move_right", KEY_RIGHT, JOY_BUTTON_DPAD_RIGHT, JOY_AXIS_LEFT_X, 1.0)
	_bind_action("move_up", KEY_UP, JOY_BUTTON_DPAD_UP, JOY_AXIS_LEFT_Y, -1.0)
	_bind_action("move_down", KEY_DOWN, JOY_BUTTON_DPAD_DOWN, JOY_AXIS_LEFT_Y, 1.0)
	_bind_action("primary_action", KEY_Z, JOY_BUTTON_A, -1, 0.0)
	_bind_action("secondary_action", KEY_X, JOY_BUTTON_B, -1, 0.0)
	_bind_action("pickup_weapon", KEY_C, JOY_BUTTON_X, -1, 0.0)
	_bind_action("dash", KEY_SHIFT, JOY_BUTTON_RIGHT_SHOULDER, -1, 0.0)

# Genesis-style keyboard layout: arrow D-pad, Z=A, X=B, C=C.
# Actions B and C are reserved for event-specific behavior where not yet implemented.
func _bind_action(action: String, key: Key, button: int, axis: int, axis_direction: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	var keyboard := InputEventKey.new()
	keyboard.physical_keycode = key
	InputMap.action_add_event(action, keyboard)
	var pad := InputEventJoypadButton.new()
	pad.button_index = button
	InputMap.action_add_event(action, pad)
	if axis >= 0:
		var stick := InputEventJoypadMotion.new()
		stick.axis = axis
		stick.axis_value = axis_direction
		InputMap.action_add_event(action, stick)

func _setup_audio() -> void:
	sound_player = AudioStreamPlayer.new()
	add_child(sound_player)
	sound_player.volume_db = -8.0
	theme_player = AudioStreamPlayer.new()
	add_child(theme_player)
	theme_picker = FileDialog.new()
	theme_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	theme_picker.access = FileDialog.ACCESS_FILESYSTEM
	theme_picker.add_filter("*.wav", "WAV audio")
	theme_picker.file_selected.connect(_theme_selected)
	add_child(theme_picker)

func _play_tone(frequency: float, duration: float) -> void:
	var rate := 22050
	var samples := PackedByteArray()
	samples.resize(int(rate * duration) * 2)
	for i in range(int(rate * duration)):
		var fade := minf(1.0, float(i) / 180.0) * minf(1.0, float(int(rate * duration) - i) / 300.0)
		var sample := int(sin(TAU * frequency * float(i) / float(rate)) * 9000.0 * fade)
		samples.encode_s16(i * 2, sample)
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = rate
	audio.stereo = false
	audio.data = samples
	sound_player.stream = audio
	sound_player.play()

func _load_pcm_wav(path: String) -> AudioStreamWAV:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var bytes := file.get_buffer(file.get_length())
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	var offset := 12
	var channels := 0
	var rate := 0
	var bits := 0
	var encoding := 0
	var audio_bytes := PackedByteArray()
	while offset + 8 <= bytes.size():
		var chunk := bytes.slice(offset, offset + 4).get_string_from_ascii()
		var size := int(bytes.decode_u32(offset + 4))
		var start := offset + 8
		if start + size > bytes.size():
			break
		if chunk == "fmt " and size >= 16:
			encoding = bytes.decode_u16(start)
			channels = bytes.decode_u16(start + 2)
			rate = bytes.decode_u32(start + 4)
			bits = bytes.decode_u16(start + 14)
		elif chunk == "data":
			audio_bytes = bytes.slice(start, start + size)
		offset = start + size + (size % 2)
	if encoding != 1 or bits != 16 or (channels != 1 and channels != 2) or rate <= 0 or audio_bytes.is_empty():
		return null
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = channels == 2
	wav.mix_rate = rate
	wav.data = audio_bytes
	return wav

func _theme_selected(path: String) -> void:
	var stream: AudioStreamWAV = _load_pcm_wav(path)
	if stream == null:
		message = "USE 16-BIT PCM WAV"
		queue_redraw()
		return
	theme_player.stream = stream
	theme_player.play()
	var cfg := ConfigFile.new()
	cfg.set_value("music", "theme", path)
	cfg.save("user://music.cfg")
	queue_redraw()

func _controller_changed(_device: int, _connected: bool) -> void:
	var pads := Input.get_connected_joypads()
	gamepad_name = Input.get_joy_name(pads[0]) if not pads.is_empty() else "KEYBOARD"
	queue_redraw()

func _update_hosts() -> void:
	host_primary = "MIKE ADAMLE"
	if era_index == 0:
		host_secondary = "JOE THEISMANN"
	elif era_index == 1:
		host_secondary = "TODD CHRISTENSEN"
	elif era_index >= 2 and era_index <= 4:
		host_secondary = "LARRY CSONKA"
	elif era_index == 5:
		host_secondary = "LARRY CSONKA / LISA MALOSKY"
	elif era_index >= 6 and era_index <= 9:
		host_secondary = "LISA MALOSKY"
	elif era_index == 10 or era_index == 11:
		host_secondary = "DAN NITRO CLARK"
	else:
		host_primary = "2026 HOST"
		host_secondary = "2026 CO-HOST"

func _refresh_schedule() -> void:
	_update_hosts()
	if mode == "MODERN" or era_index == 12:
		upcoming_events = ["POWERBALL 2026", "JOUST 2026"]
		upcoming_events.shuffle()
		upcoming_events.append("ELIMINATOR 2026")
		return
	# Classic US event introduction timeline. Event implementations remain prototypes.
	var events: Array[String] = ["POWERBALL", "ASSAULT", "JOUST", "HUMAN CANNONBALL", "BREAKTHROUGH AND CONQUER"]
	if era_index >= 1:
		events.append("THE WALL")
	if era_index >= 2:
		events.append_array(["HANG TOUGH", "ATLASPHERE"])
	if era_index >= 4:
		events.append_array(["THE MAZE", "SWINGSHOT"])
	if era_index >= 6:
		events.erase("HUMAN CANNONBALL")
		events.append_array(["SKYTRACK", "SUPER POWERBALL"])
	if era_index >= 8:
		# Season 5 replaces The Maze with Gauntlet.
		events.erase("THE MAZE")
		events.append_array(["GAUNTLET", "TUG O WAR", "WHIPLASH", "SNAPBACK", "PYRAMID"])
	events.shuffle()
	events.append("ELIMINATOR")
	upcoming_events = events

func _load_roster_gallery() -> void:
	roster_names.clear()
	var classic_file := FileAccess.open("res://data/us_classic_roster_timeline.json", FileAccess.READ)
	if classic_file != null:
		var parsed: Variant = JSON.parse_string(classic_file.get_as_text())
		if parsed is Dictionary:
			var seasons: Dictionary = parsed.get("seasons", {})
			for season_key in seasons:
				var record: Dictionary = seasons[season_key]
				for field in ["original", "brief", "debut", "returning", "core", "returns", "return"]:
					var entries: Array = record.get(field, [])
					for entry in entries:
						var name: String = str(entry)
						if not roster_names.has(name):
							roster_names.append(name)
	var modern_file := FileAccess.open("res://data/roster_2026.json", FileAccess.READ)
	if modern_file != null:
		var parsed_modern: Variant = JSON.parse_string(modern_file.get_as_text())
		if parsed_modern is Dictionary:
			for gender in ["male", "female"]:
				for person in parsed_modern.get(gender, []):
					roster_names.append(str(person.get("alias", "")) + " (2026)")

func _draw_pixel_avatar(pos: Vector2, name: String, index: int) -> void:
	var palette := [Color("#d94552"), Color("#2473b9"), Color("#e8c553"), Color("#8a4eb0"), Color("#31a48b")]
	var suit: Color = palette[index % palette.size()]
	var skin: Color = [Color("#e7ad7f"), Color("#a66a4a"), Color("#d78e67"), Color("#f1c29c")][index % 4]
	var hair: Color = [Color("#241b24"), Color("#c88b37"), Color("#6a3d30"), Color("#e5c76a")][index % 4]
	draw_rect(Rect2(pos + Vector2(14, 3), Vector2(24, 9)), hair)
	draw_rect(Rect2(pos + Vector2(17, 12), Vector2(18, 17)), skin)
	draw_rect(Rect2(pos + Vector2(12, 29), Vector2(28, 25)), suit)
	draw_rect(Rect2(pos + Vector2(4, 32), Vector2(8, 25)), skin)
	draw_rect(Rect2(pos + Vector2(40, 32), Vector2(8, 25)), skin)
	draw_rect(Rect2(pos + Vector2(14, 54), Vector2(10, 15)), suit)
	draw_rect(Rect2(pos + Vector2(30, 54), Vector2(10, 15)), suit)
	draw_rect(Rect2(pos + Vector2(20, 20), Vector2(4, 3)), INK)
	draw_rect(Rect2(pos + Vector2(31, 20), Vector2(4, 3)), INK)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.keycode
		if key == KEY_F5:
			theme_picker.popup_centered_ratio(0.75)
		elif screen == "INTRO":
			screen = "MENU"
		elif screen == "MENU":
			if key == KEY_R:
				screen = "ROSTER"
				roster_page = 0
			elif key == KEY_E:
				era_index = (era_index + 1) % era_labels.size()
				_refresh_schedule()
			elif key == KEY_1:
				_start_season("ERAS")
			elif key == KEY_2 and unlock_gladiator:
				_start_season("MODERN")
			elif key == KEY_3 and unlock_gladiator:
				screen = "GLADIATOR"
			elif key == KEY_4:
				screen = "CREATOR"
		elif screen == "ROSTER" and key == KEY_RIGHT:
			roster_page += 1
		elif screen == "ROSTER" and key == KEY_LEFT:
			roster_page = maxi(0, roster_page - 1)
		elif key == KEY_ESCAPE:
			screen = "MENU"
		elif screen == "RESULT" and (key == KEY_ENTER or key == KEY_Z):
			_next_event()
	if screen == "INTRO" and event is InputEventJoypadButton and event.pressed:
		screen = "MENU"
	elif screen == "MENU" and event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_A:
			_start_season(mode)
		elif event.button_index == JOY_BUTTON_Y:
			_start_season("MODERN" if mode == "RETRO" else "RETRO")
	if screen == "RESULT" and event.is_action_pressed("primary_action"):
		_next_event()
	queue_redraw()

func _start_season(chosen_mode: String) -> void:
	if chosen_mode == "MODERN" and not unlock_gladiator:
		message = "2026 MODE LOCKED UNTIL ERAS CHAMPIONSHIP"
		queue_redraw()
		return
	mode = chosen_mode
	event_index = 0
	score = 0
	_refresh_schedule()
	_start_event()

func _start_event() -> void:
	if theme_player.playing:
		theme_player.stop()
	screen = "PLAY"
	event_name = upcoming_events[event_index]
	time_left = 60.0 if event_name == "ASSAULT" else 45.0
	whistle_countdown = 3.0 if mode == "MODERN" else 1.8
	contender = Vector2(150, 295)
	gladiator = Vector2(680, 295)
	ai_contender = Vector2(815, 395)
	ai_holding = false
	ai_score = 0
	ai_recovery = 0.0
	ai_goal_index = randi_range(0, _powerball_goals().size() - 1)
	assault_station = 0
	assault_fired = [false, false, false, false, false]
	assault_projectile = Vector2(-100, -100)
	assault_timer = 1.0
	powerball_defenders = [Vector2(310, 295), Vector2(540, 295), Vector2(760, 295)]
	ball = Vector2(380, 295)
	holding_ball = false
	message = "CONTENDER READY!  GLADIATOR READY!"
	whistle_played = false
	_play_tone(440.0, 0.22)
	queue_redraw()

func _assault_stations() -> Array[Vector2]:
	return [Vector2(145, 400), Vector2(305, 345), Vector2(465, 290), Vector2(625, 345), Vector2(785, 400)]

func _powerball_goals() -> Array[Vector2]:
	if event_name.begins_with("SUPER POWERBALL"):
		return [Vector2(220, 285), Vector2(740, 285)]
	return [Vector2(185, 285), Vector2(480, 285), Vector2(775, 285)]

func _process(delta: float) -> void:
	if screen == "INTRO":
		intro_time += delta
		if intro_time > 12.0:
			screen = "MENU"
		queue_redraw()
		return
	if screen != "PLAY":
		return
	if whistle_countdown > 0:
		whistle_countdown = maxf(0, whistle_countdown - delta)
		if whistle_countdown <= 0 and not whistle_played:
			whistle_played = true
			_play_tone(1150.0, 0.45)
			message = "WHISTLE! GO!"
		queue_redraw()
		return
	time_left -= delta
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	contender += movement * move_speed * (1.4 if Input.is_action_pressed("dash") else 1.0) * delta
	contender.x = clampf(contender.x, 60, WIDTH - 60)
	contender.y = clampf(contender.y, 180, HEIGHT - 75)
	if event_name.contains("POWERBALL"):
		var holder := Vector2(145, 395)
		var cpu_holder := Vector2(815, 395)
		ai_recovery = maxf(0.0, ai_recovery - delta)
		var cpu_target := _powerball_goals()[ai_goal_index] if ai_holding else cpu_holder
		ai_contender = ai_contender.move_toward(cpu_target, delta * 115.0)
		if not ai_holding and ai_recovery <= 0.0 and ai_contender.distance_to(cpu_holder) < 24:
			ai_holding = true
		if ai_holding and ai_contender.distance_to(_powerball_goals()[ai_goal_index]) < 40:
			ai_score += 2 if ai_goal_index == 1 and _powerball_goals().size() == 3 else 1
			ai_holding = false
			ai_recovery = 0.8
			ai_goal_index = randi_range(0, _powerball_goals().size() - 1)
		for i in range(powerball_defenders.size()):
			var target := ai_contender if i == 2 else contender
			powerball_defenders[i] = powerball_defenders[i].move_toward(target, delta * ai_speed)
		if Input.is_action_just_pressed("secondary_action") and contender.distance_to(holder) < 45 and not holding_ball:
			holding_ball = true
			message = "BALL TAKEN - HOLDER REFILLED"
		if holding_ball:
			for goal in _powerball_goals():
				if contender.distance_to(goal) < 43:
					var points := 2 if goal == Vector2(480, 285) else 1
					score += points
					holding_ball = false
					message = "SCORE! +" + str(points)
					_play_tone(740.0, 0.18)
					break
		for defender in powerball_defenders:
			if holding_ball and contender.distance_to(defender) < 30:
				holding_ball = false
				message = "GLADIATOR BLOCK!"
			if ai_holding and ai_contender.distance_to(defender) < 30:
				ai_holding = false
				ai_recovery = 0.8
	elif event_name == "ASSAULT":
		var stations := _assault_stations()
		if Input.is_action_just_pressed("pickup_weapon") and contender.distance_to(stations[assault_station]) < 50:
			message = "WEAPON READY - Z TO FIRE"
		if Input.is_action_just_pressed("primary_action") and contender.distance_to(stations[assault_station]) < 50 and not assault_fired[assault_station]:
			assault_fired[assault_station] = true
			score += 1
			message = "WEAPON FIRED! +1"
			assault_station = mini(4, assault_station + 1)
		assault_timer -= delta
		if assault_timer <= 0:
			assault_projectile = Vector2(480, 185)
			assault_timer = 2.0
		assault_projectile = assault_projectile.move_toward(contender, delta * 245.0)
		var safe := false
		for station in stations:
			if contender.distance_to(station) < 35:
				safe = true
		if not safe and assault_projectile.distance_to(contender) < 20:
			screen = "RESULT"
			message = "DIRECT HIT - ROUND OVER"
	else:
		gladiator = gladiator.move_toward(contender, delta * ai_speed)
	if time_left <= 0:
		screen = "RESULT"
		time_left = 0.0
		_play_tone(950.0, 0.7)
		message = "EVENT COMPLETE"
	queue_redraw()

func _next_event() -> void:
	event_index += 1
	if event_index >= upcoming_events.size():
		# Placeholder events do not count as a completed championship.
		# Unlock will be enabled only after a real winning season is implemented.
		screen = "PROTOTYPE_END"
	else:
		_start_event()
	queue_redraw()

func _draw_text(label: String, pos: Vector2, size: int = 20, tint: Color = LIGHT) -> void:
	draw_string(hud_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, tint)

func _draw_character(pos: Vector2, gladiator_side: bool) -> void:
	# Temporary 16-bit character silhouette; unique photo-based character sprites remain pending.
	var skin := Color("#c48b6a") if gladiator_side else Color("#e5b38a")
	var suit := RED if gladiator_side else BLUE
	var hair := Color("#34251d")
	draw_rect(Rect2(pos + Vector2(-12, -39), Vector2(24, 9)), hair)
	draw_rect(Rect2(pos + Vector2(-11, -30), Vector2(22, 20)), skin)
	draw_rect(Rect2(pos + Vector2(-9, -22), Vector2(5, 3)), INK)
	draw_rect(Rect2(pos + Vector2(4, -22), Vector2(5, 3)), INK)
	draw_rect(Rect2(pos + Vector2(-15, -10), Vector2(30, 28)), suit)
	draw_rect(Rect2(pos + Vector2(-23, -8), Vector2(8, 27)), skin)
	draw_rect(Rect2(pos + Vector2(15, -8), Vector2(8, 27)), skin)
	draw_rect(Rect2(pos + Vector2(-13, 18), Vector2(11, 23)), suit)
	draw_rect(Rect2(pos + Vector2(2, 18), Vector2(11, 23)), suit)
	draw_rect(Rect2(pos + Vector2(-13, 39), Vector2(11, 7)), Color("#1a233e"))
	draw_rect(Rect2(pos + Vector2(2, 39), Vector2(11, 7)), Color("#1a233e"))

func _draw_contender_uniform(pos: Vector2, is_cpu: bool) -> void:
	_draw_character(pos, false)
	if era_index != 0:
		return
	var shirt := Color("#1d3e85") if is_cpu else Color("#f0f1ee")
	var shorts := Color("#171c2d") if is_cpu else Color("#1d3e85")
	draw_rect(Rect2(pos + Vector2(-15, -10), Vector2(30, 28)), shirt)
	draw_rect(Rect2(pos + Vector2(-13, 18), Vector2(11, 23)), shorts)
	draw_rect(Rect2(pos + Vector2(2, 18), Vector2(11, 23)), shorts)
	if is_cpu:
		for offset in [-8, -4, 0]:
			draw_rect(Rect2(pos + Vector2(-13, offset), Vector2(4, 2)), Color("#d9dce3"))
	else:
		draw_rect(Rect2(pos + Vector2(-15, -10), Vector2(5, 28)), Color("#1d3e85"))

func _draw_era_arena() -> void:
	# Original US series: S1A Roman-style raised stands; S1B+ modern indoor arena.
	# This is a reference-informed procedural backdrop, not a frame-accurate recreation.
	var is_roman := era_index == 0
	var is_modern: bool = era_labels[era_index] == "2026"
	var wall := Color("#504638") if is_roman else Color("#14274a")
	var floor_color := Color("#89775a") if is_roman else Color("#3a6582")
	var metal := Color("#c7b9a0") if is_roman else Color("#a5b7cc")
	if era_index >= 4 and not is_modern:
		wall = Color("#192c45")
		floor_color = Color("#526c76")
	if era_index >= 8 and not is_modern:
		wall = Color("#343b4c")
		floor_color = Color("#727b88")
	if is_modern:
		wall = Color("#09152f")
		floor_color = Color("#1a476f")
		metal = Color("#7ccaff")
	draw_rect(Rect2(50, 150, 860, 310), wall)
	if is_roman:
		# High Roman coliseum stands, stone arches and columned parapet.
		for i in range(11):
			var x := 57.0 + float(i) * 78.0
			draw_rect(Rect2(x, 166, 66, 95), Color("#302b2a"))
			draw_arc(Vector2(x + 33, 201), 29, PI, TAU, 18, metal, 7)
			draw_rect(Rect2(x, 203, 8, 78), metal)
			draw_rect(Rect2(x + 58, 203, 8, 78), metal)
			draw_rect(Rect2(x - 3, 160, 72, 11), Color("#b7a183"))
		draw_rect(Rect2(53, 265, 854, 22), Color("#b7a183"))
		for i in range(10):
			draw_rect(Rect2(70 + i * 85, 275, 10, 26), Color("#675544"))
	else:
		# Indoor bleachers, horizontal lighting gantry and video scoreboard.
		draw_rect(Rect2(55, 162, 850, 102), Color("#0d1930"))
		for row in range(4):
			for seat in range(35):
				var sx := 65.0 + float(seat) * 24.0
				var sy := 175.0 + float(row) * 20.0
				draw_rect(Rect2(sx, sy, 10, 7), Color("#cf4253") if (seat + row) % 3 == 0 else Color("#9bacc5"))
		draw_rect(Rect2(55, 258, 850, 12), metal)
		for i in range(8):
			var lx := 105.0 + float(i) * 110.0
			draw_rect(Rect2(lx, 153, 42, 8), Color("#e6e4cd"))
		if era_index >= 4:
			for x in [120.0, 755.0]:
				draw_rect(Rect2(x, 183, 90, 54), Color("#0b1224"))
				draw_rect(Rect2(x, 183, 90, 54), metal, false, 3)
				_draw_text("AG", Vector2(x + 25, 219), 27, GOLD)
	draw_rect(Rect2(54, 300, 852, 153), floor_color)
	for i in range(6):
		draw_line(Vector2(65 + i * 165, 304), Vector2(65 + i * 165, 449), metal.darkened(0.3), 2)
	draw_rect(Rect2(54, 300, 852, 153), metal, false, 4)
	if is_roman:
		_draw_text("1989 ORIGINAL ROMAN ARENA", Vector2(320, 289), 14, GOLD)
	elif is_modern:
		_draw_text("2026 PRIME VIDEO ARENA - WORK IN PROGRESS", Vector2(265, 289), 14, GOLD)
	else:
		_draw_text("CLASSIC INDOOR GLADIATOR ARENA", Vector2(300, 289), 14, GOLD)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(WIDTH, HEIGHT)), INK)
	for i in range(0, 960, 48):
		draw_rect(Rect2(i, 0, 2, 540), Color("#16234a"))
	_draw_text("AMERICAN GLADIATORS", Vector2(32, 47), 34, GOLD)
	_draw_text("ULTIMATE EDITION  |  16-BIT PROTOTYPE", Vector2(34, 78), 16)
	_draw_text("INPUT: " + gamepad_name, Vector2(32, 517), 13, GOLD)
	if screen == "INTRO":
		_draw_text("AMERICAN GLADIATORS", Vector2(210, 155), 40, GOLD)
		var cast_names := ["GEMINI", "NITRO", "ZAP", "LACE", "LASER", "ICE", "TURBO", "2026 CAST"]
		for i in range(cast_names.size()):
			var x := 95 + (i % 4) * 210
			var y := 220 + int(i / 4) * 100
			draw_rect(Rect2(x + 35, y, 30, 45), RED if i % 2 == 0 else BLUE)
			_draw_text(cast_names[i], Vector2(x, y + 68), 15, GOLD)
		_draw_text("PRESS ANY KEY TO SKIP", Vector2(330, 480), 18)
	elif screen == "ROSTER":
		_draw_text("GLADIATOR ROSTER - PIXEL AVATAR PREVIEWS", Vector2(65, 118), 24, GOLD)
		var start := roster_page * 12
		for slot in range(12):
			var idx := start + slot
			if idx >= roster_names.size():
				break
			var x := 75 + (slot % 4) * 220
			var y := 150 + int(slot / 4) * 110
			_draw_pixel_avatar(Vector2(x, y), roster_names[idx], idx)
			_draw_text(roster_names[idx].substr(0, 20), Vector2(x, y + 90), 13)
		_draw_text("LEFT / RIGHT: PAGE     ESC: MENU     PAGE " + str(roster_page + 1), Vector2(65, 500), 16, GOLD)
	elif screen == "MENU":
		_draw_text("HOSTS: " + host_primary + " / " + host_secondary, Vector2(70, 110), 16, GOLD)
		draw_texture_rect(classic_logo, Rect2(70, 145, 340, 170), false)
		_draw_text("1  ERAS MODE", Vector2(145, 327), 21, GOLD)
		draw_texture_rect(modern_logo, Rect2(525, 145, 340, 170), false)
		_draw_text("2  2026 MODE [LOCKED - ERAS VICTORY]", Vector2(532, 327), 16, RED)
		_draw_text("3  GLADIATOR MODE " + ("UNLOCKED" if unlock_gladiator else "[LOCKED]"), Vector2(70, 358), 18, GREEN if unlock_gladiator else RED)
		_draw_text("4  CREATE A CONTENDER (PLANNED)", Vector2(480, 358), 17)
		_draw_text("F5: IMPORT ORIGINAL TV THEME (WAV)", Vector2(70, 398), 17, GOLD)
		_draw_text("E: SELECT ERA - " + era_labels[era_index] + "", Vector2(70, 426), 17, GOLD)
		_draw_text("R: GLADIATOR ROSTER PREVIEW   |   Gladiator Creator locked.", Vector2(70, 458), 15)
	elif screen == "PLAY":
		_draw_era_arena()
		draw_rect(Rect2(64, 169, 832, 270), Color("#286ba9"), false, 6)
		if event_name.contains("POWERBALL"):
			for goal in _powerball_goals():
				draw_rect(Rect2(goal + Vector2(-29, -3), Vector2(58, 30)), Color("#9b9da4"))
				draw_circle(goal, 29, GOLD)
				draw_circle(goal, 21, Color("#28394b"))
			for holder in [Vector2(145, 395), Vector2(815, 395)]:
				draw_rect(Rect2(holder - Vector2(22, 15), Vector2(44, 30)), GOLD, false, 3)
				draw_circle(holder, 9, GOLD)
			_draw_contender_uniform(ai_contender, true)
			_draw_contender_uniform(contender, false)
			for defender in powerball_defenders:
				_draw_character(defender, true)
		elif event_name == "ASSAULT":
			for i in range(5):
				var station := _assault_stations()[i]
				draw_rect(Rect2(station - Vector2(24, 12), Vector2(48, 24)), GREEN if assault_fired[i] else BLUE)
			draw_circle(Vector2(480, 185), 23, RED)
			draw_circle(assault_projectile, 8, GOLD)
			_draw_character(contender, false)
			_draw_character(gladiator, true)
		else:
			_draw_character(contender, false)
			_draw_character(gladiator, true)
		_draw_text(mode + " " + era_labels[era_index] + " - " + event_name, Vector2(63, 126), 22, GOLD)
		_draw_text(host_primary + " / " + host_secondary, Vector2(64, 145), 13, LIGHT)
		_draw_text("YOU " + str(score) + " CPU " + str(ai_score), Vector2(535, 85), 18)
		draw_rect(Rect2(766, 88, 137, 49), Color("#080b16"))
		draw_rect(Rect2(766, 88, 137, 49), GOLD, false, 3)
		_draw_text(":" + str(int(maxf(0.0, time_left)) % 60).pad_zeros(2), Vector2(818, 120), 27, GOLD)
		_draw_text(str(int(maxf(0.0, time_left)) / 60).pad_zeros(2), Vector2(776, 120), 27, GOLD)
		_draw_text(message, Vector2(70, 484), 21, GOLD)
		if whistle_countdown > 0:
			_draw_text("READY... " + (str(ceili(whistle_countdown)) if mode == "MODERN" else "WHISTLE"), Vector2(360, 285), 26, GOLD)
	elif screen == "RESULT":
		_draw_text(event_name + " COMPLETE", Vector2(140, 200), 32, GOLD)
		_draw_text("POINTS: " + str(score), Vector2(140, 255), 30)
		_draw_text("PRESS ENTER OR A FOR NEXT EVENT", Vector2(140, 332), 20)
	elif screen == "CHAMPION":
		_draw_text("SEASON COMPLETE!", Vector2(160, 200), 40, GOLD)
		_draw_text("GLADIATOR MODE + CREATOR UNLOCKED!", Vector2(100, 270), 27, GREEN)
		_draw_text("PRESS ESC TO RETURN TO MENU", Vector2(140, 350), 20)
	else:
		_draw_text(screen + " - IN DEVELOPMENT", Vector2(120, 235), 30, GOLD)
		_draw_text("PRESS ESC TO RETURN TO MENU", Vector2(140, 300), 19)

func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		unlock_gladiator = cfg.get_value("progress", "gladiator_unlocked", false)
		season_wins = cfg.get_value("progress", "season_wins", 0)

func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "gladiator_unlocked", unlock_gladiator)
	cfg.set_value("progress", "season_wins", season_wins)
	cfg.save(SAVE_PATH)
