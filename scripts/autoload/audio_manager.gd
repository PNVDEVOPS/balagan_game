extends Node

var ambient_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var breathing_player: AudioStreamPlayer

const MAX_SFX_PLAYERS := 4
const RANDOM_SCARE_CHANCE := 0.1
const AMBIENT_VOLUME_DB := -6.0
const MUSIC_VOLUME_DB := -8.0      # ← ГРОМКОСТЬ музыки (Start Melody и т.п.)
const SILENT_DB := -40.0

func _ready() -> void:
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = "Master"
	ambient_player.volume_db = AMBIENT_VOLUME_DB
	add_child(ambient_player)

	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	music_player.volume_db = MUSIC_VOLUME_DB
	add_child(music_player)

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

# Надёжное зацикливание: не полагаемся на stream.loop (в рантайме срабатывает не
# всегда), а перезапускаем плеер по сигналу finished.
func _ensure_loop(p: AudioStreamPlayer) -> void:
	if not p.finished.is_connected(p.play):
		p.finished.connect(p.play)

func _drop_loop(p: AudioStreamPlayer) -> void:
	if p.finished.is_connected(p.play):
		p.finished.disconnect(p.play)

func play_ambient(stream: AudioStream, fade_in: float = 1.0, volume_db: float = AMBIENT_VOLUME_DB) -> void:
	if stream == null:
		return
	# Уже играет этот же эмбиент (например highway→forest) — не перезапускаем.
	if ambient_player.playing and ambient_player.stream == stream:
		return
	_drop_loop(ambient_player)
	if stream is AudioStreamMP3:
		stream.loop = true
	if ambient_player.playing:
		var tween_out := create_tween()
		tween_out.tween_property(ambient_player, "volume_db", SILENT_DB, fade_in * 0.5)
		await tween_out.finished
	ambient_player.stream = stream
	ambient_player.volume_db = SILENT_DB
	ambient_player.play()
	_ensure_loop(ambient_player)
	var tween_in := create_tween()
	tween_in.tween_property(ambient_player, "volume_db", volume_db, fade_in)

func stop_ambient(fade_out: float = 1.0) -> void:
	if not ambient_player.playing:
		return
	_drop_loop(ambient_player)
	var tween := create_tween()
	tween.tween_property(ambient_player, "volume_db", SILENT_DB, fade_out)
	await tween.finished
	ambient_player.stop()

# Зацикленная музыка с плавным появлением (Start Melody и т.п.).
func play_music(stream: AudioStream, fade_in: float = 1.5, loop: bool = true) -> void:
	if stream == null:
		return
	if music_player.playing and music_player.stream == stream:
		return
	_drop_loop(music_player)
	if stream is AudioStreamMP3:
		stream.loop = loop
	music_player.stream = stream
	music_player.volume_db = SILENT_DB
	music_player.play()
	if loop:
		_ensure_loop(music_player)
	var tween_in := create_tween()
	tween_in.tween_property(music_player, "volume_db", MUSIC_VOLUME_DB, fade_in)

func stop_music(fade_out: float = 1.0) -> void:
	if not music_player.playing:
		return
	_drop_loop(music_player)
	var tween := create_tween()
	tween.tween_property(music_player, "volume_db", SILENT_DB, fade_out)
	await tween.finished
	music_player.stop()

func set_breathing_intensity(intensity: float) -> void:
	breathing_player.volume_db = lerpf(-40.0, -8.0, clampf(intensity, 0.0, 1.0))

func maybe_play_random_scare(sounds: Array[AudioStream]) -> void:
	if randf() < RANDOM_SCARE_CHANCE and not sounds.is_empty():
		var sound: AudioStream = sounds[randi() % sounds.size()]
		play_sfx(sound, -12.0)
