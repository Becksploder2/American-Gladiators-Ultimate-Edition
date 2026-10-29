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
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var bytes := file.get_buffer(file.get_length())
	var stream := AudioStreamWAV.load_from_buffer(bytes)
	if stream == null:
		return
	current_cue = key
	player.stop()
	player.stream = stream
	player.play()

func stop() -> void:
	player.stop()
	current_cue = ""
