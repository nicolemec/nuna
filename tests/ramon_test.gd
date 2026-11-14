extends Node

const SLOT := 987654
var _blocked_dialogues := 0
var _reaction := false
var _save_created := false


func _ready() -> void:
	get_tree().create_timer(50.0).timeout.connect(func (): _expect(false, "timeout"))


func run(room: PopochiuRoom) -> void:
	reparent(get_tree().root)
	Globals.pausado = true
	var gui = G.gui
	if not _expect(room.objeto_seleccionado == null and gui.ui._botones[Globals.MIRAR].disabled, "Acciones sin seleccion"):
		return
	C.character_spoke.connect(_on_dialogue)
	var radio = room.get_node("Props/Ramon")
	radio._on_mouse_entered()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	await radio._on_input_event(get_viewport(), click, 0)
	if not _expect(room.objeto_seleccionado == radio and gui.ui._texto_base.begins_with("RADIO"), "Seleccion nativa del Prop"):
		return
	await gui._ejecutar("perturbar")
	if not _expect(room.state.intentos_ramon == 0 and Globals.sellos == 0 and not Globals.goteo_iniciado, "Perturbar sin presentacion cambio el progreso"):
		return
	await gui._ejecutar("mirar")
	if not _expect(radio.nombrado and gui.historial.has("¡Hola, radio! Te llamaré Ramón."), "Presentacion de Ramon"):
		return
	var lines_before: int = gui.historial.size()
	await gui._ejecutar("mirar")
	if not _expect(gui.historial.size() == lines_before + 1, "El bautismo se repitio"):
		return
	DialRadio.respuestas_automaticas = [1, 0]  # una estación equivocada y cerrar el dial
	await gui._ejecutar("perturbar")
	if not _expect(room.state.intentos_ramon == 1 and Globals.sellos == 0 and Globals.vela_101 == 0.0 and Globals.goteo_iniciado and Globals.bruma == 48.0, "Primer intento"):
		return

	var save_path := "user://save_%d.json" % SLOT
	if not _expect(not FileAccess.file_exists(save_path), "Slot de prueba ya existe; no se sobrescribe"):
		return
	E.save_game(SLOT, "Prueba automatizada Ramon")
	_save_created = FileAccess.file_exists(save_path)
	if not _expect(_save_created, "No se creo el guardado"):
		return
	radio.nombrado = false
	room.state.intentos_ramon = 0
	Globals.bruma = 5.0
	E.load_game(SLOT)
	await E.game_loaded
	room = R.current
	if not _expect(room.get_node("Props/Ramon").nombrado and room.state.intentos_ramon == 1 and Globals.bruma == 48.0, "Restauracion del primer intento"):
		return
	radio = room.get_node("Props/Ramon")
	radio._on_click()
	var guest_sprite := room.get_node("Props/Huesped/Sprite") as AnimatedSprite2D
	guest_sprite.animation_changed.connect(func ():
		if guest_sprite.animation == &"tiembla":
			_reaction = true
	)
	DialRadio.respuestas_automaticas = [4]  # la estación correcta: CUATRO
	await gui._ejecutar("perturbar")
	if not _expect(room.state.intentos_ramon == 2 and room.state.ramon_sonando and Globals.sellos == 1 and Globals.vela_101 == 20.0 and Globals.bruma == 58.0, "Segundo intento y recompensa"):
		return
	if not _expect(radio.get_node("Sprite").animation == &"sonando", "Radio no quedo sonando"):
		return
	if not _expect(_reaction, "La huesped no temblo"):
		return
	await gui._ejecutar("perturbar")
	if not _expect(room.state.intentos_ramon == 2 and Globals.sellos == 1 and Globals.vela_101 == 20.0 and Globals.bruma == 58.0, "Recompensa duplicada"):
		return
	E.save_game(SLOT, "Ramon completado")
	room.state.ramon_sonando = false
	Globals.sellos = 0
	Globals.sellos_obtenidos.clear()
	Globals.vela_101 = 0.0
	E.load_game(SLOT)
	await E.game_loaded
	room = R.current
	if not _expect(room.state.ramon_sonando and Globals.sellos == 1 and Globals.sellos_obtenidos.has("ramon") and Globals.vela_101 == 20.0 and room.get_node("Props/Ramon/Sprite").animation == &"sonando", "Restauracion del puzzle completado"):
		return
	if not _expect(_blocked_dialogues >= 7 and not G.is_blocked and not room.ocupado and not E.playing_queue, "Bloqueo y liberacion de entrada"):
		return
	Globals.pausado = false
	Globals.segundos_goteo = 4.9
	Globals._process(0.2)
	if not _expect(Globals.bruma == 57.0, "Goteo de bruma"):
		return
	_cleanup()
	print("RAMON PASS: seleccion, presentacion, 2 intentos, reaccion, recompensa unica, bloqueo y guardado/carga")
	get_tree().quit(0)


func _on_dialogue(_character: PopochiuCharacter, _text: String) -> void:
	if G.is_blocked and R.current.ocupado and G.gui.ui._botones[Globals.PERTURBAR].disabled:
		_blocked_dialogues += 1
	var attempts: int = R.current.state.intentos_ramon
	var line: String = G.gui.dialogo_actual
	G.gui.completar_dialogo()
	if G.gui.dialogo_actual != line:
		_expect(false, "El dialogo se omitio antes de los 0.4 segundos")
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(12, 128)
	R.current._unhandled_input(click)
	if C.player.is_moving:
		_expect(false, "Nuna se movio durante un dialogo")
	R.current.ejecutar_accion("perturbar")
	if R.current.state.intentos_ramon != attempts:
		_expect(false, "Se ejecuto otra accion durante un dialogo")
	await get_tree().create_timer(0.5).timeout
	if G.gui.puede_continuar:
		G.gui.completar_dialogo()


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("RAMON FAIL: " + message)
		_cleanup()
		get_tree().quit(1)
	return condition


func _cleanup() -> void:
	if _save_created:
		DirAccess.remove_absolute("user://save_%d.json" % SLOT)
		_save_created = false
