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
var era_labels := ["S1A", "S1B", "S2A", "S2B", "S3A", "S3B", "S4A", "S4B", "S5A", "S5B", "S6A", "S6B", "2026"]
var host_primary := "MIKE ADAMLE"
var host_secondary := "JOE THEISMANN"
var screen := "INTRO"
var intro_time := 0.0
var event_name := "POWERBALL"
var contender := Vector2(150, 295)
var gladiator := Vector2(680, 295)
var ball := Vector2(380, 295)
var holding_ball := false
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
	_bind_action("move_left", KEY_A, JOY_BUTTON_DPAD_LEFT, JOY_AXIS_LEFT_X, -1.0)
	_bind_action("move_right", KEY_D, JOY_BUTTON_DPAD_RIGHT, JOY_AXIS_LEFT_X, 1.0)
	_bind_action("move_up", KEY_W, JOY_BUTTON_DPAD_UP, JOY_AXIS_LEFT_Y, -1.0)
	_bind_action("move_down", KEY_S, JOY_BUTTON_DPAD_DOWN, JOY_AXIS_LEFT_Y, 1.0)
	_bind_action("primary_action", KEY_SPACE, JOY_BUTTON_A, -1, 0.0)
	_bind_action("dash", KEY_SHIFT, JOY_BUTTON_RIGHT_SHOULDER, -1, 0.0)

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
	if mode == "ERAS" and era_index == 0:
		upcoming_events = ["POWERBALL S1A", "ASSAULT S1A", "JOUST S1A", "HUMAN CANNONBALL S1A", "BREAKTHROUGH AND CONQUER S1A", "ELIMINATOR S1A"]
	elif mode == "MODERN" or era_index == 12:
		upcoming_events = ["POWERBALL 2026", "JOUST 2026", "ELIMINATOR 2026"]
	else:
		upcoming_events = ["POWERBALL", "ATLASPHERE", "JOUST", "RETRO ELIMINATOR"]

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
		elif screen == "RESULT" and (key == KEY_ENTER or key == KEY_SPACE):
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
	mode = chosen_mode
	event_index = 0
	score = 0
	_refresh_schedule()
	_start_event()

func _start_event() -> void:
	screen = "PLAY"
	event_name = upcoming_events[event_index]
	time_left = 50.0
	whistle_countdown = 3.0 if mode == "MODERN" else 1.8
	contender = Vector2(150, 295)
	gladiator = Vector2(680, 295)
	ball = Vector2(380, 295)
	holding_ball = false
	message = "CONTENDER READY!  GLADIATOR READY!"
	whistle_played = false
	_play_tone(440.0, 0.22)
	queue_redraw()

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
	gladiator = gladiator.move_toward(contender, delta * ai_speed)
	if event_name.begins_with("POWERBALL"):
		if Input.is_action_just_pressed("primary_action") and contender.distance_to(ball) < 46 and not holding_ball:
			holding_ball = true
		if holding_ball:
			ball = contender + Vector2(0, -19)
			if contender.distance_to(Vector2(850, 260)) < 52:
				score += 2
				_play_tone(740.0, 0.18)
				holding_ball = false
				ball = Vector2(380, randf_range(220, 395))
				message = "SCORE! +2"
	if contender.distance_to(gladiator) < 30:
		contender.x = maxf(60, contender.x - 140 * delta)
		if holding_ball:
			holding_ball = false
			ball = contender + Vector2(-26, 0)
			message = "GLADIATOR BLOCK!"
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

func _draw_era_arena() -> void:
	var wall := Color("#30333e")
	var floor_color := Color("#64676e")
	var accent := Color("#b7a17b")
	if era_index >= 1 and era_index <= 3:
		wall = Color("#243b64")
		floor_color = Color("#3c735f")
		accent = Color("#d1d6df")
	elif era_index >= 4 and era_index <= 7:
		wall = Color("#1a3457")
		floor_color = Color("#aab0b8") if era_index >= 6 else Color("#367a59")
		accent = Color("#e9e9ef")
	elif era_index >= 8 and era_index <= 11:
		wall = Color("#555b68")
		floor_color = Color("#b8bdc4")
		accent = Color("#c83a49")
	elif era_index >= 12:
		wall = Color("#111e3a")
		floor_color = Color("#226a93")
		accent = Color("#e9b34d")
	draw_rect(Rect2(50, 151, 860, 307), wall)
	for i in range(13):
		draw_rect(Rect2(55 + i * 65, 158, 56, 55), Color("#181b2b"))
		for j in range(4):
			draw_circle(Vector2(62 + i * 65 + j * 12, 178 + (j % 2) * 16), 4, accent)
	if era_index == 0:
		for i in range(9):
			draw_rect(Rect2(60 + i * 100, 208, 12, 95), Color("#8b8d91"))
			draw_rect(Rect2(55 + i * 100, 200, 23, 12), accent)
	draw_rect(Rect2(54, 302, 852, 152), floor_color)
	for i in range(5):
		draw_line(Vector2(70 + i * 175, 310), Vector2(70 + i * 175, 447), accent, 2)
	draw_rect(Rect2(54, 302, 852, 152), accent, false, 4)
	if era_index >= 9 and era_index <= 11:
		for x in [105, 760]:
			draw_rect(Rect2(x, 166, 90, 54), Color("#111b2b"))
			draw_rect(Rect2(x, 166, 90, 54), accent, false, 4)
			_draw_text("AG", Vector2(x + 27, 204), 29, accent)

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
		draw_circle(Vector2(850, 260), 32, GOLD)
		draw_circle(ball, 10, GOLD)
		draw_rect(Rect2(contender - Vector2(12, 20), Vector2(24, 40)), GREEN)
		draw_rect(Rect2(gladiator - Vector2(15, 22), Vector2(30, 44)), RED)
		_draw_text(mode + " " + era_labels[era_index] + " - " + event_name, Vector2(63, 126), 22, GOLD)
		_draw_text(host_primary + " / " + host_secondary, Vector2(64, 145), 13, LIGHT)
		_draw_text("POINTS " + str(score), Vector2(690, 126), 21)
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
