extends Node
## Sound effects and music. Sfx.play("thwip") plays a sound with a little
## random pitch so repeated hits never sound the same.

const SOUNDS := {
	"thwip": "res://assets/sounds/thwip.wav",
	"zip": "res://assets/sounds/zip.wav",
	"whoosh": "res://assets/sounds/whoosh.wav",
	"punch": "res://assets/sounds/punch.wav",
	"punch_big": "res://assets/sounds/punch_big.wav",
	"flip": "res://assets/sounds/flip.wav",
	"jump": "res://assets/sounds/jump_a.ogg",
	"land": "res://assets/sounds/land.ogg",
	"land_hard": "res://assets/sounds/land_hard.wav",
	"stick": "res://assets/sounds/stick.wav",
	"hurt": "res://assets/sounds/hurt.wav",
	"splash": "res://assets/sounds/splash.wav",
	"splat": "res://assets/sounds/splat.wav",
	"token": "res://assets/sounds/coin.ogg",
	"bot_shoot": "res://assets/sounds/blaster.ogg",
	"bot_hurt": "res://assets/sounds/enemy_hurt.ogg",
	"bot_die": "res://assets/sounds/enemy_destroy.ogg",
	"explode": "res://assets/sounds/explode.wav",
	"click": "res://assets/sounds/click.wav",
	"select": "res://assets/sounds/select.wav",
	"glitch": "res://assets/sounds/glitch.wav",
	"alarm": "res://assets/sounds/alarm.wav",
	"win": "res://assets/sounds/win.wav",
	"chapter": "res://assets/sounds/chapter.wav",
	"boss_roar": "res://assets/sounds/boss_roar.wav",
	"cheer": "res://assets/sounds/cheer.wav",
}
const MUSIC := {
	"city": "res://assets/music/city_beat.wav",
	"boss": "res://assets/music/boss_beat.wav",
	"title": "res://assets/music/title_beat.wav",
}

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_name := ""
var muted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in SOUNDS:
		if ResourceLoader.exists(SOUNDS[k]):
			_streams[k] = load(SOUNDS[k])
	for i in 14:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -7.0
	add_child(_music)


func play(name: String, pitch_var := 0.0, volume_db := 0.0) -> void:
	if muted or not _streams.has(name):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _streams[name]
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.volume_db = volume_db
	p.play()


func music(name: String) -> void:
	if name == _music_name:
		return
	_music_name = name
	if name == "" or not MUSIC.has(name) or not ResourceLoader.exists(MUSIC[name]):
		_music.stop()
		return
	var s: AudioStream = load(MUSIC[name])
	if s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(s as AudioStreamWAV).loop_end = int((s as AudioStreamWAV).get_length() * (s as AudioStreamWAV).mix_rate)
	_music.stream = s
	_music.play()


func set_muted(m: bool) -> void:
	muted = m
	AudioServer.set_bus_mute(0, m)
