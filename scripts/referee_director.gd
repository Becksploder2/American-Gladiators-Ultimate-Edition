extends Node
## User-supplied referee WAVs; S1A is intentionally silent.
## Put 16-bit PCM WAV clips in user://referees/<profile>/<cue>.wav.
## Profiles: bob, larry, thomas, custom. Cues: contender_ready,
## gladiator_ready, gladiators_ready, countdown, start, finish, out_of_bounds.
var voice: AudioStreamPlayer
var whistle: AudioStreamPlayer
var profile := "silent"
var override_profile := ""
var cue_time := 0.0
var announced := false

func _ready() -> void:
	voice = AudioStreamPlayer.new()
	voice.volume_db = -3.0
	add_child(voice)
	whistle = AudioStreamPlayer.new()
	add_child(whistle)
	var cfg := ConfigFile.new()
	if cfg.load("user://referees.cfg") == OK:
		override_profile = str(cfg.get_value("settings", "override", ""))

func select_era(era: String) -> void:
	if override_profile in ["bob", "larry", "thomas", "custom", "silent"]:
		profile = override_profile
	elif era == "S1A":
		profile = "silent"
	elif era == "S1B":
		profile = "bob"
	elif era == "2026":
		profile = "thomas"
	else:
		profile = "larry"

func play_cue(cue: String) -> void:
	if profile == "silent":
		return
	var path := "user://referees/" + profile + "/" + cue + ".wav"
	if not FileAccess.file_exists(path):
		return
	var stream := _read_wav(path)
	if stream == null:
		return
	voice.stop()
	voice.stream = stream
	voice.play()

func play_whistle() -> void:
	var path := "user://referees/whistle.wav"
	var stream := _read_wav(path) if FileAccess.file_exists(path) else null
	if stream == null:
		stream = _generated_whistle()
	whistle.stop()
	whistle.stream = stream
	whistle.play()

func _generated_whistle() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 0.32)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	for i in range(count):
		var t := float(i) / float(rate)
		var envelope := minf(1.0, t * 90.0) * minf(1.0, (0.32 - t) * 35.0)
		var tone := sin(TAU * (2050.0 * t + 90.0 * t * t)) + 0.3 * sin(TAU * 4100.0 * t)
		samples.encode_s16(i * 2, int(clampf(tone * 11000.0 * envelope, -32767.0, 32767.0)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = samples
	return wav

func _read_wav(path: String) -> AudioStreamWAV:
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
	var payload := PackedByteArray()
	while offset + 8 <= bytes.size():
		var tag := bytes.slice(offset, offset + 4).get_string_from_ascii()
		var size := int(bytes.decode_u32(offset + 4))
		var start := offset + 8
		if start + size > bytes.size():
			break
		if tag == "fmt " and size >= 16:
			encoding = bytes.decode_u16(start)
			channels = bytes.decode_u16(start + 2)
			rate = bytes.decode_u32(start + 4)
			bits = bytes.decode_u16(start + 14)
		elif tag == "data":
			payload = bytes.slice(start, start + size)
		offset = start + size + size % 2
	if encoding != 1 or bits != 16 or channels not in [1, 2] or rate <= 0 or payload.is_empty():
		return null
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = channels == 2
	wav.data = payload
	return wav
