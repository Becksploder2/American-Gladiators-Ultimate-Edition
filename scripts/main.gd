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
var era_labels := ["S1A 1989", "S1B 1990", "1990-92", "1992-94", "1994-96", "2026"]
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

func _refresh_schedule() -> void:
	upcoming_events = ["POWERBALL", "ATLASPHERE", "JOUST", "RETRO ELIMINATOR" if mode == "ERAS" else "ELIMINATOR '26"]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.keycode
		if key == KEY_F5:
			theme_picker.popup_centered_ratio(0.75)
		elif screen == "INTRO":
			screen = "MENU"
		elif screen == "MENU":
			if key == KEY_E:
				era_index = (era_index + 1) % era_labels.size()
				_refresh_schedule()
			elif key == KEY_1:
				_start_season("ERAS")
			elif key == KEY_2:
				_start_season("MODERN")
			elif key == KEY_3 and unlock_gladiator:
				screen = "GLADIATOR"
			elif key == KEY_4:
				screen = "CREATOR"
		elif key == KEY_ESCAPE:
			screen = "MENU"
		elif screen == "RESULT" and (key == KEY_ENTER or key == KEY_SPACE):
			_next_event()
	if screen == "MENU" and event is InputEventJoypadButton and event.pressed:
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
	elif screen == "MENU":
		_draw_text("1  ERAS MODE (1989-2026)", Vector2(70, 166), 27)
		_draw_text("2  MODERN SEASON (2026)", Vector2(70, 224), 27)
		_draw_text("3  GLADIATOR MODE " + ("UNLOCKED" if unlock_gladiator else "[LOCKED]"), Vector2(70, 282), 25, GREEN if unlock_gladiator else RED)
		_draw_text("4  CREATE A CONTENDER (PLANNED)", Vector2(70, 340), 23)
		_draw_text("F5: IMPORT ORIGINAL TV THEME (WAV)", Vector2(70, 390), 18, GOLD)
		_draw_text("E: SELECT ERA - " + era_labels[era_index] + "", Vector2(70, 421), 18, GOLD)
		_draw_text("Gladiator Mode and Creator unlock after a season victory.", Vector2(70, 455), 15)
	elif screen == "PLAY":
		draw_rect(Rect2(50, 151, 860, 307), BLUE)
		draw_rect(Rect2(64, 169, 832, 270), Color("#286ba9"), false, 6)
		draw_circle(Vector2(850, 260), 32, GOLD)
		draw_circle(ball, 10, GOLD)
		draw_rect(Rect2(contender - Vector2(12, 20), Vector2(24, 40)), GREEN)
		draw_rect(Rect2(gladiator - Vector2(15, 22), Vector2(30, 44)), RED)
		_draw_text(mode + "  -  " + event_name, Vector2(63, 126), 23, GOLD)
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
