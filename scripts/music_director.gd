extends Node
## Event-driven soundtrack. Optional user-provided WAV cues live in user://music/.
## Keys: intro, gladiator_entrance, event_start, event_end, score, block,
## countdown, victory, defeat, eliminator, champion, and event_<event_name>.
var player: AudioStreamPlayer
var config := ConfigFile.new()
var current_cue := ""
var era := "S1A"

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.volume_db = -9.0
	add_child(player)
	config.load("user://music_cues.cfg")

func set_era(value: String) -> void:
	era = value

func cue(name: String) -> void:
	var key := name.to_lower().replace(" ", "_")
	var path: String = str(config.get_value(era, key, config.get_value("default", key, "")))
	if path.is_empty():
		path = "user://music/" + era + "/" + key + ".wav"
	if not FileAccess.file_exists(path):
		path = "user://music/default/" + key + ".wav"
	if not FileAccess.file_exists(path):
		return
	var stream := _read_wav(path)
	if stream == null:
		return
	current_cue = key
	player.stop()
	player.stream = stream
	player.play()

func stop() -> void:
	player.stop()
	current_cue = ""

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
