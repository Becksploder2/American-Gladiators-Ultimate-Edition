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
var powerball_out := false
var powerball_reset_time := 0.0
var breakthrough_juke_time := 0.0
var breakthrough_juke_cooldown := 0.0
var breakthrough_tackle_time := 0.0
var conquer_tug_meter := 0.0
var conquer_tug_active := false
var conquer_tug_defense := 0.0
var conquer_tug_flash := 0.0
var conquer_grab_limb := -1
var conquer_grab_cooldown := 0.0
var breakthrough_phase := 0
var breakthrough_won := false
var conquer_won := false
var conquer_push := 0.0
var conquer_clock := 10.0
var breakthrough_guard_cooldown := 0.0
var joust_fall_timer := 0.0
var joust_fall_loser := ""
var joust_fall_trapdoor := false
var joust_fall_origin := Vector2.ZERO
var joust_player_hp := 100.0
var joust_gladiator_hp := 100.0
var joust_cpu_attack_cooldown := 0.0
var joust_hit_flash := 0.0
var joust_survival := 0.0
var joust_finished := false
var joust_attack_cooldown := 0.0
var cannon_phase := 0.0
var cannon_velocity := 0.0
var cannon_launched := false
var cannon_resolved := false
var cannon_guard := 0.0
var cannon_attempts := 0
var cannon_pivot := Vector2(475, 145)
var cannon_length := 250.0
var assault_station := 0
var assault_fired: Array[bool] = [false, false, false, false, false]
var assault_projectile := Vector2(-100, -100)
var assault_timer := 1.0
var assault_jump_time := 0.0
var assault_roll_time := 0.0
var assault_roll_direction := Vector2.RIGHT
var score := 0
var time_left := 50.0
var whistle_countdown := 0.0
var move_speed := 205.0
var ai_speed := 125.0
var gamepad_name := "KEYBOARD"
var unlock_gladiator := false
var season_wins := 0
var highest_era_unlocked := 0
var tournament_round := 0
var tournament_names: Array[String] = []
var tournament_opponents: Array[String] = []
var match_player_points := 0
var match_cpu_points := 0
var event_player_start := 0
var tournament_result := ""
var event_index := 0
var normal_events := ["POWERBALL", "ATLASPHERE", "JOUST"]
var upcoming_events: Array[String] = []
var last_touch := ""
var message := ""
var hud_font: Font = ThemeDB.fallback_font
var sound_player: AudioStreamPlayer
var whistle_played := false
var theme_player: AudioStreamPlayer
var theme_slot := "early"
var theme_picker: FileDialog
var classic_logo: Texture2D = preload("res://assets/logos/classic.svg")
var rock_logo: Texture2D = preload("res://assets/logos/rock_era.svg")
var modern_logo: Texture2D = preload("res://assets/logos/prime_2026.svg")
var roster_page := 0
var roster_names: Array[String] = []

func _ready() -> void:
	_install_input_actions()
	_setup_audio()
	_load_progress()
	var music_cfg := ConfigFile.new()
	if music_cfg.load("user://music.cfg") == OK:
		var saved_path: String = music_cfg.get_value("music", "early", music_cfg.get_value("music", "theme", ""))
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
	_bind_action("fourth_face", KEY_V, JOY_BUTTON_Y, -1, 0.0)

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

func _current_theme_slot() -> String:
	if mode == "MODERN" or era_index == 12:
		return "modern"
	return "rock" if era_index >= 8 else "early"

func _play_era_theme() -> void:
	theme_slot = _current_theme_slot()
	var cfg := ConfigFile.new()
	if cfg.load("user://music.cfg") != OK:
		return
	var path: String = cfg.get_value("music", theme_slot, "")
	if theme_slot == "early" and path.is_empty():
		path = cfg.get_value("music", "theme", "")
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var stream := _load_pcm_wav(path)
	if stream != null:
		theme_player.stream = stream
		theme_player.play()

func _theme_selected(path: String) -> void:
	var stream: AudioStreamWAV = _load_pcm_wav(path)
	if stream == null:
		message = "USE 16-BIT PCM WAV"
		queue_redraw()
		return
	theme_player.stream = stream
	theme_player.play()
	var cfg := ConfigFile.new()
	cfg.set_value("music", theme_slot, path)
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
			theme_slot = _current_theme_slot()
			theme_picker.popup_centered_ratio(0.75)
		elif screen == "INTRO":
			screen = "MENU"
		elif screen == "MENU":
			if key == KEY_R:
				screen = "ROSTER"
				roster_page = 0
			elif key == KEY_E:
				era_index = (era_index + 1) % (highest_era_unlocked + 1)
				_refresh_schedule()
			elif key == KEY_1:
				_start_season("ERAS")
			elif key == KEY_2:
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
		elif screen == "CHAMPION" and key == KEY_ENTER:
			if mode == "ERAS" and era_index < highest_era_unlocked:
				era_index += 1
				_start_season("ERAS")
			else:
				screen = "MENU"
		elif screen == "RESULT" and (key == KEY_ENTER or key == KEY_Z):
			_next_event()
	if screen == "INTRO" and event is InputEventJoypadButton and event.pressed:
		screen = "MENU"
	elif screen == "MENU" and event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_A:
			_start_season("ERAS")
		elif event.button_index == JOY_BUTTON_Y:
			_start_season("MODERN")
	if screen == "RESULT" and event.is_action_pressed("primary_action"):
		_next_event()
	queue_redraw()

func _make_contender_name() -> String:
	var first := ["ALEX", "JORDAN", "CASEY", "TAYLOR", "MORGAN", "RILEY", "JAMIE", "DREW", "CAMERON", "SKYLER", "PARKER", "DEVON", "SAM", "JESSE", "QUINN", "DANA"]
	var last := ["MARTINEZ", "BROOKS", "TURNER", "REED", "BENNETT", "FOSTER", "RAMIREZ", "MORGAN", "PRICE", "COLEMAN", "HAYES", "SULLIVAN", "PARKER", "HENDERSON", "BAILEY", "WALKER"]
	return first.pick_random() + " " + last.pick_random()

func _prepare_tournament() -> void:
	tournament_names.clear()
	while tournament_names.size() < 7:
		var candidate := _make_contender_name()
		if not tournament_names.has(candidate):
			tournament_names.append(candidate)
	tournament_opponents = [tournament_names[0], tournament_names[1], tournament_names[2]]
	tournament_round = 0
	match_player_points = 0
	match_cpu_points = 0

func _start_season(chosen_mode: String) -> void:
	mode = chosen_mode
	if mode == "ERAS":
		era_index = mini(era_index, highest_era_unlocked)
	elif mode == "MODERN":
		era_index = 12
	_prepare_tournament()
	event_index = 0
	score = 0
	_refresh_schedule()
	_start_event()
	_play_era_theme()

func _event_duration(event: String) -> float:
	match event:
		"ASSAULT", "ATLASPHERE", "HANG TOUGH", "SKYTRACK":
			return 60.0
		"POWERBALL", "SUPER POWERBALL", "THE MAZE", "SWINGSHOT", "PYRAMID":
			return 45.0
		"JOUST", "TUG O WAR", "WHIPLASH":
			return 30.0
		"THE WALL":
			return 120.0 if era_index == 1 else 60.0
		"GAUNTLET":
			return 20.0 if era_index >= 11 else 25.0
		_:
			return 45.0


func _draw_ag_clock() -> void:
	if event_name == "HUMAN CANNONBALL" or event_name == "BREAKTHROUGH AND CONQUER":
		return
	var seconds: int = maxi(0, ceili(time_left))
	var digits := "%02d:%02d" % [int(seconds / 60), seconds % 60]
	var clock_color := RED if seconds <= 10 and whistle_countdown <= 0.0 else GOLD
	if mode == "MODERN" or era_index == 12:
		draw_rect(Rect2(758, 86, 157, 57), Color("#15263b"))
		draw_rect(Rect2(758, 86, 157, 57), LIGHT, false, 2)
		_draw_text(digits, Vector2(774, 124), 30, clock_color)
	elif era_index < 6:
		var shield := PackedVector2Array([Vector2(782, 85), Vector2(895, 85), Vector2(907, 99), Vector2(896, 129), Vector2(840, 147), Vector2(781, 129), Vector2(769, 99), Vector2(782, 85)])
		draw_colored_polygon(shield, Color("#173c83"))
		draw_polyline(shield, GOLD, 3.0)
		_draw_text("AG", Vector2(823, 105), 15, LIGHT)
		_draw_text(digits, Vector2(783, 131), 27, clock_color)
	else:
		draw_rect(Rect2(761, 83, 153, 65), Color("#080b16"))
		draw_rect(Rect2(761, 83, 153, 65), GOLD, false, 2)
		_draw_text("ARMITRON", Vector2(773, 102), 17, LIGHT)
		_draw_text(digits, Vector2(778, 137), 29, clock_color)


func _start_event() -> void:
	if theme_player.playing:
		theme_player.stop()
	screen = "PLAY"
	event_name = upcoming_events[event_index]
	event_player_start = score
	ai_score = 0
	time_left = _event_duration(event_name)
	whistle_countdown = 3.0 if mode == "MODERN" else 1.8
	contender = Vector2(150, 295)
	gladiator = Vector2(680, 295)
	ai_contender = Vector2(815, 395)
	ai_holding = false
	ai_score = 0
	ai_recovery = 0.0
	powerball_out = false
	powerball_reset_time = 0.0
	ai_goal_index = randi_range(0, _powerball_goals().size() - 1)
	breakthrough_phase = 0
	breakthrough_juke_time = 0.0
	breakthrough_juke_cooldown = 0.0
	breakthrough_tackle_time = 0.0
	conquer_grab_limb = -1
	conquer_tug_meter = 0.0
	conquer_tug_active = false
	conquer_tug_defense = 0.0
	conquer_tug_flash = 0.0
	conquer_grab_cooldown = 0.0
	breakthrough_won = false
	conquer_won = false
	conquer_push = 0.0
	conquer_clock = 10.0
	breakthrough_guard_cooldown = 0.0
	if event_name == "BREAKTHROUGH AND CONQUER":
		contender = Vector2(145, 320)
		gladiator = Vector2(485, 320)
	joust_fall_timer = 0.0
	joust_fall_loser = ""
	joust_fall_trapdoor = false
	joust_fall_origin = Vector2.ZERO
	joust_player_hp = 100.0
	joust_gladiator_hp = 100.0
	joust_cpu_attack_cooldown = 1.1
	joust_hit_flash = 0.0
	joust_survival = 0.0
	joust_finished = false
	joust_attack_cooldown = 0.0
	if event_name == "JOUST" and era_index == 0 and mode == "ERAS":
		contender = Vector2(345, 320)
		gladiator = Vector2(615, 320)
	cannon_phase = -1.0
	cannon_velocity = 0.0
	cannon_launched = false
	cannon_resolved = false
	cannon_guard = 0.0
	cannon_attempts = 0
	assault_station = 0
	assault_fired = [false, false, false, false, false]
	assault_projectile = Vector2(-100, -100)
	assault_timer = 1.0
	assault_jump_time = 0.0
	assault_roll_time = 0.0
	powerball_defenders = [Vector2(325, 245), Vector2(480, 315), Vector2(640, 245)]
	ai_contender = Vector2(815, 395)
	ai_holding = true
	ai_recovery = 0.0
	ball = Vector2(380, 295)
	holding_ball = false
	message = "CONTENDER READY!  GLADIATOR READY!"
	whistle_played = false
	_play_tone(440.0, 0.22)
	queue_redraw()

func _s1a_inside_powerball(pos: Vector2) -> bool:
	# Upper half of a circle, with the baseline at y=445.
	var dx := pos.x - 480.0
	var dy := pos.y - 445.0
	return dy <= 0.0 and dx * dx + dy * dy <= 390.0 * 390.0

func _draw_soccer_ball(pos: Vector2, radius: float = 9.0) -> void:
	draw_circle(pos, radius, Color("#f6f4e8"))
	draw_circle(pos, radius, Color("#172131"), false, 1.5)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(0, -radius * 0.55),
		pos + Vector2(radius * 0.52, -radius * 0.17),
		pos + Vector2(radius * 0.34, radius * 0.45),
		pos + Vector2(-radius * 0.34, radius * 0.45),
		pos + Vector2(-radius * 0.52, -radius * 0.17)
	]), Color("#172131"))

func _draw_ball_holder(pos: Vector2) -> void:
	# Upright open cylindrical ball rack with visible soccer balls.
	draw_rect(Rect2(pos + Vector2(-23, -18), Vector2(46, 40)), Color("#b4a467"))
	draw_rect(Rect2(pos + Vector2(-23, -18), Vector2(46, 40)), GOLD, false, 2)
	for offset in [-12, 0, 12]:
		_draw_soccer_ball(pos + Vector2(offset, -15), 7.0)
	draw_arc(pos + Vector2(0, -18), 23.0, 0.0, TAU, 24, GOLD, 3.0)

func _assault_stations() -> Array[Vector2]:
	return [Vector2(145, 400), Vector2(305, 345), Vector2(465, 290), Vector2(625, 345), Vector2(785, 400)]

func _powerball_goals() -> Array[Vector2]:
	if event_name.begins_with("SUPER POWERBALL"):
		return [Vector2(220, 285), Vector2(740, 285)]
	if era_index == 0:
		return [Vector2(185, 285), Vector2(480, 285), Vector2(775, 285)]
	# Five cylinders form an X, with the center scoring cylinder in the middle.
	return [Vector2(250, 215), Vector2(710, 215), Vector2(480, 290), Vector2(250, 365), Vector2(710, 365)]

func _powerball_points(goal_index: int) -> int:
	if era_index == 0:
		return 15
	if event_name.begins_with("SUPER POWERBALL"):
		return 1 # Temporary until its scoring configuration is explicitly reviewed.
	if goal_index == 2:
		return 2 if era_index == 1 else 3
	return 1 if era_index <= 3 else 2

func _process(delta: float) -> void:
	if screen == "INTRO":
		intro_time += delta
		if intro_time > 3.5:
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
	if event_name != "HUMAN CANNONBALL" and event_name != "BREAKTHROUGH AND CONQUER":
		time_left -= delta
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if event_name != "HUMAN CANNONBALL" and event_name != "BREAKTHROUGH AND CONQUER" and not (event_name == "JOUST" and era_index == 0 and mode == "ERAS"):
		contender += movement * move_speed * (1.4 if Input.is_action_pressed("dash") else 1.0) * delta
		contender.x = clampf(contender.x, 60, WIDTH - 60)
		contender.y = clampf(contender.y, 180, HEIGHT - 75)
	if event_name.contains("POWERBALL"):
		powerball_reset_time = maxf(0.0, powerball_reset_time - delta)
		if powerball_out and powerball_reset_time <= 0.0:
			contender = Vector2(150, 370)
			powerball_out = false
			message = "BACK IN PLAY!"
		if era_index == 0 and not powerball_out and not _s1a_inside_powerball(contender):
			powerball_out = true
			powerball_reset_time = 1.0
			holding_ball = false
			message = "OUT OF BOUNDS - BALL LOST!"
		var holder := Vector2(145, 395)
		var cpu_holder := Vector2(815, 395)
		ai_recovery = maxf(0.0, ai_recovery - delta)
		var cpu_target := _powerball_goals()[ai_goal_index] if ai_holding else cpu_holder
		ai_contender = ai_contender.move_toward(cpu_target, delta * 115.0)
		if not ai_holding and ai_recovery <= 0.0 and ai_contender.distance_to(cpu_holder) < 24:
			ai_holding = true
		if ai_holding and ai_contender.distance_to(_powerball_goals()[ai_goal_index]) < 40:
			ai_score += _powerball_points(ai_goal_index)
			ai_holding = false
			ai_recovery = 0.8
			ai_goal_index = randi_range(0, _powerball_goals().size() - 1)
		for i in range(powerball_defenders.size()):
			var target := ai_contender if i == 2 else (ai_contender if i == 1 and ai_holding and not holding_ball else contender)
			powerball_defenders[i] = powerball_defenders[i].move_toward(target, delta * ai_speed * 0.72)
		if not powerball_out and Input.is_action_just_pressed("secondary_action") and contender.distance_to(holder) < 45 and not holding_ball:
			holding_ball = true
			message = "BALL TAKEN - HOLDER REFILLED"
		if holding_ball:
			for goal in _powerball_goals():
				if contender.distance_to(goal) < 43:
					var points := _powerball_points(_powerball_goals().find(goal))
					score += points
					holding_ball = false
					message = "SCORE! +" + str(points)
					_play_tone(740.0, 0.18)
					break
		for defender in powerball_defenders:
			if holding_ball and contender.distance_to(defender) < 30:
				holding_ball = false
				message = "GLADIATOR BLOCK!"
				if era_index == 0:
					contender = Vector2(150, 465)
					powerball_out = true
					powerball_reset_time = 1.0
			if ai_holding and ai_contender.distance_to(defender) < 30:
				ai_holding = false
				ai_recovery = 0.8
	elif event_name == "BREAKTHROUGH AND CONQUER":
		if breakthrough_phase == 0:
			# Breakthrough: get past the defender and enter the marked end zone.
			breakthrough_juke_time = maxf(0.0, breakthrough_juke_time - delta)
			breakthrough_juke_cooldown = maxf(0.0, breakthrough_juke_cooldown - delta)
			breakthrough_tackle_time = maxf(0.0, breakthrough_tackle_time - delta)
			if Input.is_action_just_pressed("secondary_action") and breakthrough_juke_cooldown <= 0.0:
				breakthrough_juke_time = 0.45
				breakthrough_juke_cooldown = 1.4
				contender.y = clampf(contender.y + (-75.0 if contender.y >= 320.0 else 75.0), 225.0, 400.0)
				message = "JUKE! EVADE THE TACKLE!"
			contender += movement * 205.0 * delta
			contender.x = clampf(contender.x, 100.0, 865.0)
			contender.y = clampf(contender.y, 225.0, 400.0)
			gladiator = gladiator.move_toward(Vector2(contender.x + 48.0, contender.y), 115.0 * delta)
			breakthrough_guard_cooldown = maxf(0.0, breakthrough_guard_cooldown - delta)
			if contender.distance_to(gladiator) < 43.0 and breakthrough_guard_cooldown <= 0.0:
				breakthrough_tackle_time = 0.5
				breakthrough_guard_cooldown = 1.0
				if breakthrough_juke_time > 0.0:
					message = "TACKLE MISSED! GREAT JUKE!"
				else:
					contender.x = maxf(105.0, contender.x - 100.0)
					message = "TACKLED! KEEP DRIVING FOR THE END ZONE!"
			if contender.x >= 825.0:
				breakthrough_won = true
				score += 40 if era_index == 0 else 5
				breakthrough_phase = 1
				contender = Vector2(375, 320)
				gladiator = Vector2(480, 320)
				conquer_clock = 10.0
				message = "BREAKTHROUGH! NOW CONQUER: 10 SECONDS!"
		else:
			conquer_clock = maxf(0.0, conquer_clock - delta)
			contender += movement * 145.0 * delta
			contender.x = clampf(contender.x, 280.0, 680.0)
			contender.y = clampf(contender.y, 210.0, 425.0)
			conquer_grab_cooldown = maxf(0.0, conquer_grab_cooldown - delta)
			var limb := -1
			if Input.is_action_pressed("primary_action"):
				limb = 0
			elif Input.is_action_pressed("secondary_action"):
				limb = 1
			elif Input.is_action_pressed("pickup_weapon"):
				limb = 2
			elif Input.is_action_pressed("fourth_face"):
				limb = 3
			# Retro wrestling-game tug-of-war: tap the selected limb button repeatedly.
			# Gladiator actively resists; holding a button does not generate repeated pulls.
			conquer_tug_flash = maxf(0.0, conquer_tug_flash - delta)
			var within_reach := contender.distance_to(gladiator) < 100.0
			if limb >= 0 and within_reach and conquer_grab_cooldown <= 0.0:
				conquer_tug_active = true
				conquer_grab_limb = limb
			elif not within_reach:
				conquer_tug_active = false
				conquer_grab_limb = -1
				conquer_tug_meter = move_toward(conquer_tug_meter, 0.0, 25.0 * delta)
			var pressed_limb := (Input.is_action_just_pressed("primary_action") or Input.is_action_just_pressed("secondary_action") or Input.is_action_just_pressed("pickup_weapon") or Input.is_action_just_pressed("fourth_face"))
			if conquer_tug_active:
				conquer_tug_defense += delta
				# Defense pushes the meter back and can break a weak grip.
				conquer_tug_meter = maxf(0.0, conquer_tug_meter - (20.0 + 8.0 * sin(conquer_tug_defense * 7.0)) * delta)
				if pressed_limb:
					conquer_tug_meter = minf(100.0, conquer_tug_meter + 19.0)
					conquer_tug_flash = 0.16
					message = "GRAPPLE! TAP FACE BUTTONS TO BEAT GLADIATOR RESISTANCE!"
				if conquer_tug_meter >= 68.0:
					var limb_offsets := [Vector2(-14, 28), Vector2(14, 28), Vector2(-26, -10), Vector2(26, -10)]
					var grab_point: Vector2 = gladiator + limb_offsets[conquer_grab_limb]
					var pull_dir := (contender - grab_point).normalized()
					if pull_dir.length() < 0.1:
						pull_dir = Vector2(1, 0)
					gladiator += pull_dir * (115.0 + conquer_tug_meter) * delta
					conquer_push += delta
				elif conquer_tug_meter < 10.0 and conquer_tug_defense > 0.8:
					conquer_tug_active = false
					conquer_grab_limb = -1
					conquer_tug_defense = 0.0
					conquer_grab_cooldown = 0.45
					message = "GLADIATOR BROKE THE HOLD!"
			else:
				gladiator = gladiator.move_toward(Vector2(480, 320), 42.0 * delta)
				conquer_tug_meter = move_toward(conquer_tug_meter, 0.0, 35.0 * delta)
			if conquer_grab_cooldown > 0.0:
				conquer_tug_active = false
				conquer_grab_limb = -1
			# A body part crossing the 105px circle boundary wins Conquer.
			if gladiator.distance_to(Vector2(480, 320)) + 20.0 >= 105.0:
				conquer_won = true
				score += 40 if era_index == 0 else 5
				if era_index == 0 and breakthrough_won:
					score += 20
				message = "CONQUER WON! BOTH EVENTS COMPLETE!"
				screen = "RESULT"
			elif conquer_clock <= 0.0:
				message = "CONQUER TIME EXPIRED!"
				screen = "RESULT"
	elif event_name == "JOUST" and mode == "ERAS":
		if joust_finished:
			joust_fall_timer += delta
			if joust_fall_timer >= 1.25:
				screen = "RESULT"
			queue_redraw()
			return
		joust_survival += delta
		joust_attack_cooldown = maxf(0.0, joust_attack_cooldown - delta)
		var previous_milestone := mini(5, int((joust_survival - delta) / 10.0))
		var current_milestone := mini(5, int(joust_survival / 10.0))
		if current_milestone > previous_milestone and era_index == 0:
			score = event_player_start + current_milestone * 5
			message = "SURVIVED " + str(current_milestone * 10) + " SECONDS! +" + str(current_milestone * 5)
		joust_cpu_attack_cooldown = maxf(0.0, joust_cpu_attack_cooldown - delta)
		joust_hit_flash = maxf(0.0, joust_hit_flash - delta)
		contender.x = clampf(contender.x + movement.x * 150.0 * delta, 205.0, 755.0)
		gladiator.x = move_toward(gladiator.x, contender.x + 62.0, 48.0 * delta)
		if Input.is_action_just_pressed("primary_action") and joust_attack_cooldown <= 0.0:
			joust_attack_cooldown = 0.55
			if absf(contender.x - gladiator.x) < 105.0:
				gladiator.x += 30.0
				joust_gladiator_hp = maxf(0.0, joust_gladiator_hp - 25.0)
				joust_hit_flash = 0.22
				message = "PUGIL STICK STRIKE!"
			else:
				message = "STRIKE MISSED!"
		if absf(contender.x - gladiator.x) < 110.0 and joust_cpu_attack_cooldown <= 0.0:
			joust_cpu_attack_cooldown = 1.25
			joust_player_hp = maxf(0.0, joust_player_hp - 18.0)
			contender.x -= 25.0
			message = "GLADIATOR COUNTERATTACK!"
		if (era_index == 0 and gladiator.x >= 755.0) or joust_gladiator_hp <= 0.0:
			score = event_player_start + (100 if era_index == 0 else 10)
			joust_finished = true
			joust_fall_loser = "GLADIATOR"
			joust_fall_origin = gladiator
			joust_fall_trapdoor = era_index == 0 and gladiator.x >= 755.0
			message = "GLADIATOR FALLS! VICTORY!"
		elif (era_index == 0 and contender.x <= 205.0) or joust_player_hp <= 0.0:
			joust_finished = true
			joust_fall_loser = "CONTENDER"
			joust_fall_origin = contender
			joust_fall_trapdoor = era_index == 0 and contender.x <= 205.0
			message = "CONTENDER FALLS! GLADIATOR WINS!"
		elif time_left <= 0.0:
			score = event_player_start + (50 if era_index == 0 else 0)
			screen = "RESULT"
			message = "60-SECOND DRAW! 50 POINTS!"
	elif event_name == "HUMAN CANNONBALL":
		# Side-view pendulum: release from the left, strike the pad-bearing Gladiator on the right.
		if not cannon_launched and Input.is_action_just_pressed("primary_action"):
			cannon_launched = true
			cannon_velocity = 1.95
			message = "SWING! TIME YOUR IMPACT!"
		if cannon_launched and not cannon_resolved:
			cannon_velocity += (-4.7 * sin(cannon_phase) - 0.18 * cannon_velocity) * delta
			cannon_phase += cannon_velocity * delta
			cannon_guard = clampf(cannon_guard + (0.9 if cannon_phase > 0.25 else -0.5) * delta, 0.0, 1.0)
			var swing_pos := cannon_pivot + Vector2(sin(cannon_phase), cos(cannon_phase)) * cannon_length
			if swing_pos.x > 615.0 and cannon_velocity > 0.0:
				cannon_resolved = true
				cannon_attempts += 1
				if cannon_velocity > 1.2 and cannon_guard < 0.55:
					var earned := 40 if cannon_attempts == 3 else 30
					score += earned
					message = "GLADIATOR KNOCKED OFF! +" + str(earned)
					gladiator = Vector2(760, 450)
				else:
					message = "BLOCKED BY GLADIATOR!"
					_play_tone(740.0 if gladiator.y > 400.0 else 210.0, 0.3)
		if cannon_resolved and Input.is_action_just_pressed("secondary_action") and cannon_attempts < 3:
			cannon_phase = -1.0
			cannon_velocity = 0.0
			cannon_launched = false
			cannon_resolved = false
			cannon_guard = 0.0
			gladiator = Vector2(680, 295)
			message = "READY FOR NEXT SWING - Z TO LAUNCH"
	elif event_name == "ASSAULT":
		var stations := _assault_stations()
		if Input.is_action_just_pressed("secondary_action") and contender.distance_to(stations[assault_station]) < 50:
			message = "WEAPON READY - A TO FIRE"
		if Input.is_action_just_pressed("primary_action") and contender.distance_to(stations[assault_station]) < 50 and not assault_fired[assault_station]:
			assault_fired[assault_station] = true
			if era_index >= 4 and era_index < 12:
				score += 1
				message = "WEAPON FIRED! +1"
			else:
				message = "WEAPON FIRED!"
			assault_station = mini(4, assault_station + 1)
		assault_jump_time = maxf(0.0, assault_jump_time - delta)
		assault_roll_time = maxf(0.0, assault_roll_time - delta)
		if Input.is_action_just_pressed("pickup_weapon") and assault_jump_time <= 0.0 and assault_roll_time <= 0.0:
			assault_jump_time = 0.55
			message = "JUMP!"
		if era_index >= 1 and era_index < 12 and Input.is_action_just_pressed("fourth_face") and assault_roll_time <= 0.0 and assault_jump_time <= 0.0:
			assault_roll_time = 0.6
			assault_roll_direction = movement.normalized() if movement.length() > 0.1 else Vector2.RIGHT
			message = "ROLL-A-DOPE!"
		if assault_roll_time > 0.0:
			contender += assault_roll_direction * 230.0 * delta
			contender.x = clampf(contender.x, 60.0, WIDTH - 60.0)
			contender.y = clampf(contender.y, 180.0, HEIGHT - 75.0)
		assault_timer -= delta
		if assault_timer <= 0:
			assault_projectile = Vector2(480, 185)
			assault_timer = 2.0
		assault_projectile = assault_projectile.move_toward(contender, delta * 245.0)
		var safe := false
		for station in stations:
			if contender.distance_to(station) < 35:
				safe = true
		if not safe and assault_projectile.distance_to(contender) < (10.0 if assault_roll_time > 0.0 else 14.0 if assault_jump_time > 0.0 else 20.0):
			screen = "RESULT"
			message = "DIRECT HIT - ROUND OVER"
	else:
		gladiator = gladiator.move_toward(contender, delta * ai_speed)
	if (time_left <= 0 and not (event_name == "JOUST" and mode == "ERAS")) or (event_name == "HUMAN CANNONBALL" and cannon_resolved and cannon_attempts >= 3):
		screen = "RESULT"
		time_left = 0.0
		_play_tone(950.0, 0.7)
		message = "EVENT COMPLETE"
	queue_redraw()

func _next_event() -> void:
	match_player_points += maxi(0, score - event_player_start)
	match_cpu_points += ai_score
	event_index += 1
	if event_index >= upcoming_events.size():
		if match_player_points > match_cpu_points:
			tournament_round += 1
			if tournament_round >= 3:
				screen = "CHAMPION"
				season_wins += 1
				if mode == "ERAS":
					highest_era_unlocked = maxi(highest_era_unlocked, mini(era_index + 1, era_labels.size() - 1))
				_save_progress()
			else:
				match_player_points = 0
				match_cpu_points = 0
				event_index = 0
				_refresh_schedule()
				_start_event()
		else:
			screen = "TOURNAMENT_OUT"
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
		var primary := RED if not is_cpu else BLUE
		if era_index >= 8 and era_index < 12:
			primary = Color("#11131c") if not is_cpu else Color("#e7e8ef")
		draw_rect(Rect2(pos + Vector2(-15, -10), Vector2(30, 28)), primary)
		draw_rect(Rect2(pos + Vector2(-13, 18), Vector2(11, 23)), primary)
		draw_rect(Rect2(pos + Vector2(2, 18), Vector2(11, 23)), primary)
		if era_index >= 8 and era_index < 12:
			var trim := LIGHT if not is_cpu else INK
			draw_rect(Rect2(pos + Vector2(-15, -10), Vector2(3, 28)), trim)
			draw_rect(Rect2(pos + Vector2(12, -10), Vector2(3, 28)), trim)
		draw_rect(Rect2(pos + Vector2(-7, -3), Vector2(14, 10)), GOLD)
		_draw_text("AG", pos + Vector2(-6, 5), 9, INK)
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

func _era_logo() -> Texture2D:
	if mode == "MODERN" or era_index == 12:
		return modern_logo
	return rock_logo if era_index >= 8 else classic_logo

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(WIDTH, HEIGHT)), INK)
	for i in range(0, 960, 48):
		draw_rect(Rect2(i, 0, 2, 540), Color("#16234a"))
	_draw_text("AMERICAN GLADIATORS", Vector2(32, 47), 34, GOLD)
	_draw_text("ULTIMATE EDITION  |  16-BIT PROTOTYPE", Vector2(34, 78), 16)
	_draw_text("INPUT: " + gamepad_name, Vector2(32, 517), 13, GOLD)
	if screen == "INTRO":
		draw_texture_rect(_era_logo(), Rect2(720, 82, 190, 90), false)
		_draw_text("AMERICAN GLADIATORS", Vector2(210, 155), 40, GOLD)
		var cast_names := ["GEMINI", "NITRO", "ZAP", "LACE", "LASER", "ICE", "TURBO", "2026 CAST"]
		for i in range(cast_names.size()):
			var x := 95 + (i % 4) * 210
			var y := 220 + int(i / 4) * 100
			_draw_pixel_avatar(Vector2(x + 23, y - 5), cast_names[i], i)
			_draw_text(cast_names[i], Vector2(x, y + 72), 15, GOLD)
		_draw_text("GLADIATORS - PIXEL SPRITE PREVIEW", Vector2(315, 480), 18)
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
		draw_texture_rect(rock_logo if era_index >= 8 and era_index < 12 else classic_logo, Rect2(70, 145, 340, 170), false)
		_draw_text("1  ERAS MODE", Vector2(145, 327), 21, GOLD)
		draw_texture_rect(modern_logo, Rect2(525, 145, 340, 170), false)
		_draw_text("2  2026 TOURNAMENT MODE", Vector2(532, 327), 16, RED)
		_draw_text("3  GLADIATOR MODE " + ("UNLOCKED" if unlock_gladiator else "[LOCKED]"), Vector2(70, 358), 18, GREEN if unlock_gladiator else RED)
		_draw_text("4  CREATE A CONTENDER (PLANNED)", Vector2(480, 358), 17)
		_draw_text("F5: IMPORT ORIGINAL TV THEME (WAV)", Vector2(70, 398), 17, GOLD)
		_draw_text("E: UNLOCKED ERA - " + era_labels[era_index] + "", Vector2(70, 426), 17, GOLD)
		_draw_text("R: GLADIATOR ROSTER PREVIEW   |   Gladiator Creator locked.", Vector2(70, 458), 15)
	elif screen == "PLAY":
		draw_texture_rect(_era_logo(), Rect2(755, 52, 165, 75), false)
		_draw_era_arena()
		if event_name.contains("POWERBALL") and era_index == 0:
			# Season 1A Powerball: green playing surface with gold semicircular boundary.
			var center := Vector2(480, 445)
			var radius := 390.0
			draw_colored_polygon(PackedVector2Array([Vector2(90, 445), Vector2(870, 445), Vector2(870, 220), Vector2(90, 220)]), Color("#287044"))
			draw_arc(center, radius, PI, TAU, 64, Color("#e7bb45"), 9.0)
			draw_line(Vector2(90, 445), Vector2(870, 445), Color("#e7bb45"), 8.0)
		else:
			draw_rect(Rect2(64, 169, 832, 270), Color("#286ba9"), false, 6)
		if event_name.contains("POWERBALL"):
			for goal in _powerball_goals():
				draw_rect(Rect2(goal + Vector2(-29, -3), Vector2(58, 30)), Color("#9b9da4"))
				draw_circle(goal, 29, GOLD)
				draw_circle(goal, 21, Color("#28394b"))
			for holder in [Vector2(145, 395), Vector2(815, 395)]:
				if era_index == 0:
					_draw_ball_holder(holder)
				else:
					draw_rect(Rect2(holder - Vector2(22, 15), Vector2(44, 30)), GOLD, false, 3)
					draw_circle(holder, 9, GOLD)
			_draw_contender_uniform(ai_contender, true)
			_draw_contender_uniform(contender, false)
			for i in range(powerball_defenders.size()):
				var defender := powerball_defenders[i]
				draw_circle(defender + Vector2(0, 38), 23.0, Color("#172036"))
				draw_circle(defender + Vector2(0, 38), 23.0, GOLD, false, 2.0)
				_draw_character(defender, true)
				_draw_text("G" + str(i + 1), defender + Vector2(-12, -49), 16, GOLD)
			_draw_text("CPU CONTENDER", ai_contender + Vector2(-52, -54), 13, LIGHT)
		elif event_name == "BREAKTHROUGH AND CONQUER":
			if breakthrough_phase == 0:
				draw_rect(Rect2(95, 210, 780, 225), Color("#286b42"))
				for stripe in range(1, 8):
					draw_line(Vector2(95 + stripe * 95, 210), Vector2(95 + stripe * 95, 435), LIGHT, 2.0)
				draw_rect(Rect2(825, 210, 50, 225), GOLD)
				_draw_text("END ZONE", Vector2(746, 200), 17, GOLD)
				_draw_character(contender, false)
				if breakthrough_tackle_time > 0.0:
					draw_line(gladiator + Vector2(-18, -12), gladiator + Vector2(-48, 10), GOLD, 9.0)
					draw_line(gladiator + Vector2(18, -12), gladiator + Vector2(-40, 12), GOLD, 9.0)
					draw_arc(gladiator, 38.0, PI, TAU, 12, RED, 4.0)
				_draw_character(gladiator, true)
				_draw_text("BREAKTHROUGH: ARROWS MOVE  X/B JUKE", Vector2(255, 456), 18, GOLD)
			else:
				draw_circle(Vector2(480, 320), 105.0, LIGHT)
				draw_circle(Vector2(480, 320), 101.0, Color("#2b6c95"))
				for ring_line in range(8):
					var angle := float(ring_line) * TAU / 8.0
					draw_line(Vector2(480, 320) + Vector2(cos(angle), sin(angle)) * 92.0, Vector2(480, 320) + Vector2(cos(angle), sin(angle)) * 103.0, GOLD, 2.0)
				_draw_character(contender, false)
				_draw_character(gladiator, true)
				if conquer_grab_limb >= 0:
					var limb_offsets := [Vector2(-14, 28), Vector2(14, 28), Vector2(-26, -10), Vector2(26, -10)]
					draw_line(contender, gladiator + limb_offsets[conquer_grab_limb], GOLD, 5.0)
				draw_rect(Rect2(300, 172, 360, 16), RED)
				draw_rect(Rect2(300, 172, 360.0 * conquer_tug_meter / 100.0, 16), GOLD if conquer_tug_flash > 0.0 else GREEN)
				draw_rect(Rect2(300, 172, 360, 16), LIGHT, false, 2.0)
				_draw_text("GRAPPLE " + str(int(conquer_tug_meter)) + "% - TAP TO WIN", Vector2(334, 163), 15, GOLD)
				_draw_text("TAP A/Z LEG-L  B/X LEG-R  X/C ARM-L  Y/V ARM-R", Vector2(165, 455), 15, GOLD)
				_draw_text("TIME: " + str(ceili(conquer_clock)), Vector2(410, 202), 20, GOLD)
		elif event_name == "JOUST" and mode == "ERAS":
			# S1A drawbridge; S1B onward elevated pedestals over crash mats.
			if era_index == 0:
				draw_rect(Rect2(185, 349, 590, 22), Color("#9d754c"))
			else:
				draw_rect(Rect2(170, 398, 625, 24), BLUE)
				draw_rect(Rect2(250, 349, 120, 14), GOLD)
				draw_rect(Rect2(585, 349, 120, 14), GOLD)
				_draw_text("CRASH MATS", Vector2(405, 415), 17, LIGHT)
			for i in range(14 if era_index == 0 else 0):
				draw_line(Vector2(198 + i * 40, 349), Vector2(198 + i * 40, 370), INK, 2.0)
			if era_index == 0:
				draw_rect(Rect2(Vector2(185, 349), Vector2(70, 22) if not (joust_finished and joust_fall_trapdoor and joust_fall_loser == "CONTENDER") else Vector2(70, 8)), RED, false, 3.0)
				draw_rect(Rect2(Vector2(705, 349), Vector2(70, 22) if not (joust_finished and joust_fall_trapdoor and joust_fall_loser == "GLADIATOR") else Vector2(70, 8)), RED, false, 3.0)
			draw_line(Vector2(185, 349), Vector2(100, 205), GOLD, 4.0)
			draw_line(Vector2(775, 349), Vector2(860, 205), GOLD, 4.0)
			if joust_finished:
				var fall_progress := clampf(joust_fall_timer / 1.25, 0.0, 1.0)
				var fall_offset := Vector2(0, 220.0 * fall_progress * fall_progress)
				if joust_fall_loser == "CONTENDER":
					_draw_character(joust_fall_origin + fall_offset, false)
					_draw_character(gladiator, true)
				else:
					_draw_character(contender, false)
					_draw_character(joust_fall_origin + fall_offset, true)
				_draw_text("FALL!", Vector2(440, 250), 31, GOLD)
			else:
				_draw_character(contender, false)
				_draw_character(gladiator, true)
			draw_line(contender + Vector2(12, -9), contender + Vector2(72, -34), GOLD, 9.0)
			draw_line(gladiator + Vector2(-12, -9), gladiator + Vector2(-72, -34), GOLD, 9.0)
			draw_rect(Rect2(250, 175, 205, 17), RED)
			draw_rect(Rect2(250, 175, 205.0 * joust_player_hp / 100.0, 17), GREEN)
			draw_rect(Rect2(505, 175, 205, 17), RED)
			draw_rect(Rect2(505, 175, 205.0 * joust_gladiator_hp / 100.0, 17), GREEN)
			_draw_text("CONTENDER", Vector2(250, 168), 15, LIGHT)
			_draw_text("GLADIATOR", Vector2(505, 168), 15, LIGHT)
			_draw_text("ARROWS: MOVE   Z: STRIKE   EMPTY BAR = FALL", Vector2(205, 445), 17, GOLD)
		elif event_name == "HUMAN CANNONBALL":
			# Side-on staging with a raised takeoff, swinging rope, and padded Gladiator platform.
			draw_rect(Rect2(95, 365, 170, 25), GOLD)
			draw_rect(Rect2(610, 360, 160, 24), GOLD)
			draw_rect(Rect2(670, 384, 22, 75), Color("#a5aab6"))
			draw_line(Vector2(325, 142), Vector2(625, 142), Color("#d6d9e5"), 7.0)
			draw_circle(cannon_pivot, 10, GOLD)
			var swing_pos := cannon_pivot + Vector2(sin(cannon_phase), cos(cannon_phase)) * cannon_length
			draw_line(cannon_pivot, swing_pos, Color("#e5e3d7"), 4.0)
			_draw_contender_uniform(swing_pos, false)
			_draw_character(gladiator, true)
			draw_rect(Rect2(gladiator + Vector2(-32, -18 - cannon_guard * 20.0), Vector2(15, 55)), BLUE)
			draw_rect(Rect2(gladiator + Vector2(-35, -21 - cannon_guard * 20.0), Vector2(21, 7)), GOLD)
			_draw_text("BLOCK PAD: " + str(int(cannon_guard * 100.0)) + "%", Vector2(620, 245), 15, GOLD)
			_draw_text("SWING " + str(mini(cannon_attempts + (0 if cannon_launched else 1), 3)) + "/3   Z: LAUNCH   X: NEXT SWING", Vector2(240, 425), 18, GOLD)
		elif event_name == "ASSAULT":
			for i in range(5):
				var station := _assault_stations()[i]
				var cover := Rect2(station + Vector2(-35, -23), Vector2(70, 46))
				draw_rect(cover, Color("#25385b") if assault_fired[i] else Color("#647c98"))
				draw_rect(cover, GOLD, false, 4.0)
				draw_rect(Rect2(station + Vector2(-28, -15), Vector2(56, 9)), Color("#d5dbe7"))
				draw_rect(Rect2(station + Vector2(-29, 7), Vector2(58, 9)), Color("#1a233e"))
				draw_line(station + Vector2(-10, -28), station + Vector2(28, -39), INK, 9.0)
				draw_line(station + Vector2(-10, -28), station + Vector2(28, -39), GOLD if not assault_fired[i] else GREEN, 4.0)
				draw_circle(station + Vector2(-10, -28), 9.0, GOLD)
				_draw_text(str(i + 1), station + Vector2(-6, 5), 18, LIGHT)
				if i == assault_station and not assault_fired[i]:
					draw_rect(Rect2(station - Vector2(41, 29), Vector2(82, 64)), GOLD, false, 2.0)
			draw_circle(Vector2(480, 185), 23, RED)
			draw_circle(assault_projectile, 8, GOLD)
			if assault_roll_time > 0.0:
				var roll_progress := 1.0 - assault_roll_time / 0.6
				var roll_pos := contender + Vector2(0, 12.0 * sin(roll_progress * TAU))
				draw_rect(Rect2(roll_pos - Vector2(25, 11), Vector2(50, 22)), BLUE)
				draw_circle(roll_pos + assault_roll_direction * 19.0, 10.0, Color("#f1b98c"))
				draw_line(roll_pos - assault_roll_direction * 20.0, roll_pos + assault_roll_direction * 20.0, GOLD, 3.0)
			elif assault_jump_time > 0.0:
				var jump_progress := 1.0 - assault_jump_time / 0.55
				_draw_character(contender - Vector2(0, 64.0 * sin(jump_progress * PI)), false)
			else:
				_draw_character(contender, false)
			_draw_character(gladiator, true)
			if era_index == 0:
				_draw_text("S1A RULES: NO POINTS FOR FIRING A WEAPON", Vector2(220, 170), 16, GOLD)
				_draw_text("A/Z: FIRE   B/X: PICK UP   X/C: JUMP", Vector2(230, 445), 16, GOLD)
			else:
				_draw_text("A/Z: FIRE   B/X: PICK UP   X/C: JUMP   Y/V: ROLL (S1B+)", Vector2(130, 445), 16, GOLD)
		else:
			_draw_character(contender, false)
			_draw_character(gladiator, true)
		_draw_text(mode + " " + era_labels[era_index] + " - " + event_name, Vector2(63, 126), 22, GOLD)
		_draw_text(host_primary + " / " + host_secondary, Vector2(64, 145), 13, LIGHT)
		_draw_text("YOU " + str(score) + " CPU " + str(ai_score), Vector2(535, 85), 18)
		_draw_ag_clock()
		_draw_text(message, Vector2(70, 484), 21, GOLD)
		if whistle_countdown > 0:
			_draw_text("READY... " + (str(ceili(whistle_countdown)) if mode == "MODERN" else "WHISTLE"), Vector2(360, 285), 26, GOLD)
	elif screen == "RESULT":
		# Original Genesis-inspired inter-event scorecard, drawn as native pixel-era shapes.
		draw_rect(Rect2(82, 91, 796, 372), Color("#080b1b"))
		draw_rect(Rect2(82, 91, 796, 372), GOLD, false, 5.0)
		draw_rect(Rect2(96, 104, 768, 57), Color("#143b77"))
		draw_texture_rect(_era_logo(), Rect2(99, 105, 150, 54), false)
		draw_rect(Rect2(96, 104, 768, 57), LIGHT, false, 2.0)
		_draw_text("AMERICAN GLADIATORS", Vector2(235, 141), 31, GOLD)
		_draw_text("EVENT RESULTS", Vector2(337, 191), 25, LIGHT)
		_draw_text(event_name, Vector2(170, 226), 23, GOLD)
		_draw_text("ROUND " + str(tournament_round + 1) + "  -  " + era_labels[era_index], Vector2(635, 225), 17, LIGHT)
		draw_rect(Rect2(119, 241, 722, 45), Color("#17315c"))
		_draw_text("CONTENDER", Vector2(152, 270), 20, LIGHT)
		_draw_text("GLADIATOR", Vector2(565, 270), 20, LIGHT)
		var event_pts := maxi(0, score - event_player_start)
		_draw_text(str(event_pts), Vector2(245, 323), 33, GOLD)
		_draw_text(str(ai_score), Vector2(663, 323), 33, GOLD)
		_draw_text("EVENT POINTS", Vector2(393, 310), 16, LIGHT)
		draw_line(Vector2(130, 335), Vector2(830, 335), GOLD, 2.0)
		_draw_text(str(match_player_points + event_pts), Vector2(245, 376), 29, GREEN)
		_draw_text(str(match_cpu_points + ai_score), Vector2(663, 376), 29, GREEN)
		_draw_text("MATCH TOTAL", Vector2(402, 365), 16, LIGHT)
		_draw_text("PRESS ENTER / A FOR NEXT EVENT", Vector2(254, 432), 19, GOLD)
	elif screen == "CHAMPION":
		_draw_text("TOURNAMENT CHAMPION!", Vector2(160, 200), 36, GOLD)
		_draw_text("NEXT ERA UNLOCKED: " + era_labels[highest_era_unlocked] if mode == "ERAS" else "2026 TOURNAMENT WON!", Vector2(140, 270), 25, GREEN)
		_draw_text("ENTER: NEXT ERA   ESC: MENU" if mode == "ERAS" else "ENTER / ESC: MENU", Vector2(140, 350), 20)
	elif screen == "TOURNAMENT_OUT":
		_draw_text("ELIMINATED IN ROUND " + str(tournament_round + 1), Vector2(130, 235), 30, RED)
		_draw_text("OPPONENT: " + tournament_opponents[tournament_round], Vector2(130, 290), 22)
	else:
		_draw_text(screen + " - IN DEVELOPMENT", Vector2(120, 235), 30, GOLD)
		_draw_text("PRESS ESC TO RETURN TO MENU", Vector2(140, 300), 19)

func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		unlock_gladiator = cfg.get_value("progress", "gladiator_unlocked", false)
		season_wins = cfg.get_value("progress", "season_wins", 0)
		highest_era_unlocked = int(cfg.get_value("progress", "highest_era_unlocked", 0))

func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "gladiator_unlocked", unlock_gladiator)
	cfg.set_value("progress", "season_wins", season_wins)
	cfg.set_value("progress", "highest_era_unlocked", highest_era_unlocked)
	cfg.save(SAVE_PATH)
