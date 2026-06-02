extends Node2D

var _laika_appeared: bool = false
var _chapter_started: bool = false
var _silhouette_triggered: bool = false
var _balagan_triggered: bool = false
var _ghost_shown: bool = false

func _ready() -> void:
	var player := get_node_or_null("Player")
	if player:
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			cam.limit_left = 0
			cam.limit_right = 3928

	var laika_trigger := get_node_or_null("LaikaTrigger")
	if laika_trigger:
		laika_trigger.body_entered.connect(_on_laika_trigger)
	var exit_zone := get_node_or_null("ExitZone")
	if exit_zone:
		exit_zone.body_entered.connect(_on_exit_zone)
	var silhouette_trigger := get_node_or_null("SilhouetteTrigger")
	if silhouette_trigger:
		silhouette_trigger.body_entered.connect(_on_silhouette_trigger)
	var balagan_trigger := get_node_or_null("BalaganTrigger")
	if balagan_trigger:
		balagan_trigger.body_entered.connect(_on_balagan_trigger)

	var murder := get_node_or_null("ShamanAmulet")
	if not murder:
		murder = get_node_or_null("MurderSite")
	if murder:
		murder.examined.connect(_on_murder_site_examined)

func _on_murder_site_examined() -> void:
	if not _ghost_shown:
		_ghost_shown = true
		_flash_ghost_once()
	DialogueManager.show_text("", "Птичьи кости, нанизанные на истлевшую нить. Давно. Кора дерева вросла в узел — значит, висит годами.")
	await DialogueManager.dialogue_finished
	DialogueManager.show_text("", "Такое оставляют не как подношение. Как замок. Чтобы что-то не ушло с этого места.")

func _flash_ghost_once() -> void:
	var ghost := get_node_or_null("GhostFigure")
	if not ghost:
		return
	ghost.modulate = Color(0.6, 0.75, 1.0, 0.8)
	ghost.visible = true
	await get_tree().create_timer(1.2).timeout
	ghost.visible = false
	ghost.modulate = Color(0.6, 0.75, 1.0, 0.0)

func _on_laika_trigger(body: Node2D) -> void:
	if not body.is_in_group("player") or _laika_appeared:
		return
	_laika_appeared = true

	if body.has_method("freeze"):
		body.freeze()

	DialogueManager.show_text("", "Лайка? Куда побежала? Возможно она приведёт меня к людям.")
	await DialogueManager.dialogue_finished

	var laika := get_node_or_null("Laika")
	if laika and is_instance_valid(laika):
		laika.set_physics_process(false)
		var anim: AnimatedSprite2D = laika.get_node_or_null("AnimatedSprite2D")
		if anim:
			anim.flip_h = false
			anim.play("walk")
		var tween := create_tween()
		tween.tween_property(laika, "global_position:x", laika.global_position.x + 520.0, 1.6)
		tween.parallel().tween_property(laika, "modulate:a", 0.0, 1.6)
		await tween.finished
		laika.visible = false

	if body.has_method("unfreeze"):
		body.unfreeze()

func _on_silhouette_trigger(body: Node2D) -> void:
	if not body.is_in_group("player") or _silhouette_triggered:
		return
	if not _ghost_shown:
		return
	_silhouette_triggered = true
	DialogueManager.show_text("", "Там кто-то стоял. Я видел.")

func _on_balagan_trigger(body: Node2D) -> void:
	if not body.is_in_group("player") or _balagan_triggered:
		return
	_balagan_triggered = true
	DialogueManager.show_text("", "Балаган. Старый, явно нежилой — но дым идёт. Здесь кто-то есть. Или был. Только что.\n\nХорошо это или плохо — я ещё не решил.")

func _on_exit_zone(body: Node2D) -> void:
	if body.is_in_group("player") and not _chapter_started:
		_chapter_started = true
		ChapterManager.start_chapter(ChapterManager.Chapter.BALAGAN)
