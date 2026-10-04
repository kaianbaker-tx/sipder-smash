extends Node
## Sound effects and music. Sfx.play("select") plays a sound; Sfx.music("town")
## switches the song. Sounds and songs are made by tools/gen_audio.py.

const SOUNDS := ["blip", "select", "back", "bump", "door", "step", "grass", "alert",
	"battle", "hit", "hit_super", "hit_weak", "faint", "levelup", "throw", "pop",
	"wobble", "caught", "heal", "drop", "win", "lose", "cry", "shout", "buff", "fire",
	"water", "leaf", "zap", "rock", "wind", "item", "flee"]
const SONGS := ["title", "town", "route", "lab", "battle", "rival", "victory", "c4"]

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_name := ""
var muted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in SOUNDS:
		var p := "res://assets/sounds/%s.wav" % k
		if ResourceLoader.exists(p):
			_streams[k] = load(p)
	for i in 12:
		var ap := AudioStreamPlayer.new()
		add_child(ap)
		_pool.append(ap)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -8.0
	add_child(_music)


func play(name: String, pitch_var := 0.0, volume_db := 0.0, pitch := 1.0) -> void:
	if muted or not _streams.has(name):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _streams[name]
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_var, pitch_var))
	p.volume_db = volume_db
	p.play()


## A Crittermon's cry: one sound, pitched for each species.
func cry(species: String, low := false) -> void:
	var c: float = Dex.SPECIES.get(species, {}).get("cry", 1.0)
	play("cry", 0.0, -2.0, c * (0.8 if low else 1.0))


func music(name: String) -> void:
	if name == _music_name:
		return
	_music_name = name
	var p := "res://assets/music/%s.ogg" % name
	if name == "" or not ResourceLoader.exists(p):
		_music.stop()
		return
	var s: AudioStreamOggVorbis = load(p)
	s.loop = name != "victory"
	_music.stream = s
	_music.play()


func set_muted(m: bool) -> void:
	muted = m
	AudioServer.set_bus_mute(0, m)
