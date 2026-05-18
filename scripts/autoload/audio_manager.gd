extends Node

var ambient_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

func _ready() -> void:
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = "Master"
	add_child(ambient_player)

	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "Master"
	add_child(sfx_player)

func play_sfx(stream: AudioStream) -> void:
	sfx_player.stream = stream
	sfx_player.play()

func play_ambient(stream: AudioStream) -> void:
	ambient_player.stream = stream
	ambient_player.play()

func stop_ambient() -> void:
	ambient_player.stop()
