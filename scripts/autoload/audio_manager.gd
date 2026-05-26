extends Node

var ambient_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var breathing_player: AudioStreamPlayer

const MAX_SFX_PLAYERS := 4
const RANDOM_SCARE_CHANCE := 0.1

func _ready() -> void:
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = "Master"
	ambient_player.volume_db = -6.0
	add_child(ambient_player)

	breathing_player = AudioStreamPlayer.new()
	breathing_player.bus = "Master"
	breathing_player.volume_db = -20.0
	add_child(breathing_player)

	for i in MAX_SFX_PLAYERS:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_players.append(p)

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	for p in sfx_players:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.play()
			return

func play_ambient(stream: AudioStream, fade_in: float = 1.0) -> void:
	if ambient_player.playing:
		var tween_out := create_tween()
		tween_out.tween_property(ambient_player, "volume_db", -40.0, fade_in * 0.5)
		await tween_out.finished
	ambient_player.stream = stream
	ambient_player.volume_db = -40.0
	ambient_player.play()
	var tween_in := create_tween()
	tween_in.tween_property(ambient_player, "volume_db", -6.0, fade_in)

func stop_ambient(fade_out: float = 1.0) -> void:
	var tween := create_tween()
	tween.tween_property(ambient_player, "volume_db", -40.0, fade_out)
	await tween.finished
	ambient_player.stop()

func set_breathing_intensity(intensity: float) -> void:
	breathing_player.volume_db = lerpf(-40.0, -8.0, clampf(intensity, 0.0, 1.0))

func maybe_play_random_scare(sounds: Array[AudioStream]) -> void:
	if randf() < RANDOM_SCARE_CHANCE and not sounds.is_empty():
		var sound: AudioStream = sounds[randi() % sounds.size()]
		play_sfx(sound, -12.0)
