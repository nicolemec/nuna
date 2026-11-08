extends Node

const SLOT := 987653
const Composition := preload("composition_check.gd")
var _save_created := false
var _failed := false
var _room: PopochiuRoom
var _auto_dialogue := true
var _completion_cards := 0
var _started := 0


func _ready() -> void:
	_started = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - _started > 120000 and not _failed:
		_check(false, "timeout")
	if not _auto_dialogue or not is_instance_valid(R.current):
		return
	G.gui.completar_dialogo(true)
	for child in R.current.get_children():
		if child is OrdenTrabajo and not child.is_queued_for_deletion():
			_completion_cards += 1
			child._al_aceptar()


func run(room: PopochiuRoom) -> void:
	reparent(get_tree().root)
	_room = room
	Engine.time_scale = 4.0
	Globals.pausado = true
	if not _check(not FileAccess.file_exists("user://save_%d.json" % SLOT), "No sobrescribir slots existentes"):
		return
	await _capturar("inicio")
	if not _check_composition():
		return
	if not _check(_room.get_props().size() == 11 and not get_tree().root.has_node("GameState"), "11 Props nativos y controlador único"):
		return
	for name in ["Puerta", "Pantuflas", "Huesped", "Velador", "Lumi", "Comoda", "Dentadura", "Vaso", "Cortina", "Ramon", "Ovillo"]:
		await _native_click(name)
		if _failed:
			return
	for name in ["Puerta", "Pantuflas", "Huesped", "Velador", "Comoda", "Dentadura", "Vaso"]:
		await _action(name, Globals.MIRAR)
		if _failed:
			return
	if not _check(G.gui.historial.has("No, se van a extrañar.") == false and G.gui.historial.has("¿Siempre juntitas?"), "Frases secundarias originales"):
		return
	await _action("Pantuflas", Globals.PERTURBAR)
	await _action("Velador", Globals.PERTURBAR)
	await _action("Ramon", Globals.MIRAR)
	await _action("Ramon", Globals.PERTURBAR)
	await _action("Ramon", Globals.PERTURBAR)
	if not _check(Globals.sellos == 1 and Globals.vela_101 == 20.0, "Ramón: sello y recompensa"):
		return
	await _action("Cortina", Globals.PERTURBAR)
	if not _check(_room.state.saltos_ventana == 0, "Cortina exige presentación"):
		return
	await _action("Cortina", Globals.MIRAR)
	for i in 3:
		await _action("Cortina", Globals.PERTURBAR)
	if not _check(_room.state.saltos_ventana == 3 and Globals.bruma == 54.0 and G.gui.historial.has("Si tuviera un escaloncito…"), "Tres saltos: coste, animación y pista"):
		return
	await _action("Lumi", Globals.PERTURBAR)
	if not _check(_room.get_prop("Lumi").estado == Lumi.Estado.APAGADA, "Lumi exige presentación"):
		return
	await _action("Lumi", Globals.MIRAR)
	if not _check(_room.get_prop("Lumi").mirada_inicial and G.gui.ui._letra_chica.visible == false, "Certificación inicial finalizada"):
		return
	for i in 3:
		await _action("Lumi", Globals.PERTURBAR)
	if not _check(_room.get_prop("Lumi").estado == Lumi.Estado.NIVEL_3 and Globals.vela_101 == 50.0 and Globals.bruma == 69.0, "Lumi: tres niveles y costes/recompensas"):
		return
	await _action("Lumi", Globals.PERTURBAR)
	if not _check(_room.get_prop("Lumi").estado == Lumi.Estado.QUEMADA and Globals.vela_101 == 75.0 and Globals.bruma == 54.0, "Fogonazo y quemada"):
		return
	await _action("Ovillo", Globals.MIRAR)
	await _action("Ovillo", Globals.AGARRAR)
	await _action("Dentadura", Globals.AGARRAR)
	if not _check(Globals.tiene(&"ovillo") and Globals.tiene(&"dentadura") and C.player.inventory.size() == 2 and not _room.get_prop("Ovillo").visible and not _room.get_prop("Dentadura").visible, "Inventario nativo y Props recogidos"):
		return
	if not _check(G.gui.ui._casilleros[0].text == "O" and G.gui.ui._casilleros[1].text == "S", "Casilleros originales actualizados"):
		return
	if not await _save_restore("quemada, Ovi y Sonrisa"):
		return
	if not _check(_room.get_prop("Lumi").estado == Lumi.Estado.QUEMADA and _room.get_prop("Lumi").segundos_quemada > 0.0 and Globals.tiene(&"ovillo") and not _room.get_prop("Ovillo").visible and _room.get_prop("Ramon").nombrado and _room.get_prop("Ramon").get_node("Sprite").animation == &"sonando", "Restaurar progreso y cooldown"):
		return
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	G.gui.ui._seleccionar_inventario(click, 0)
	if not _check(I.active != null and I.active.script_name == "Ovillo", "Seleccionar Ovi desde HUD"):
		return
	await _room.usar_objeto(I.active, _room.get_prop("Cortina"))
	if not _check(_room.state.cortina_bailando and not Globals.tiene(&"ovillo") and C.player.inventory.size() == 1 and I.active == null and Globals.sellos == 2 and Globals.vela_101 == 90.0, "Usar y consumir Ovi sin inventario paralelo"):
		return
	await _action("Cortina", Globals.PERTURBAR)
	if not _check(Globals.sellos == 2 and Globals.vela_101 == 90.0, "Recompensa de cortina única"):
		return
	if not await _save_restore("Ovi consumido"):
		return
	if not _check(not _room.get_prop("Ovillo").visible and not Globals.tiene(&"ovillo") and _room.state.cortina_bailando and _room.get_prop("Cortina").get_node("Sprite").animation == &"baila", "Ovi no reaparece y cortina sigue bailando"):
		return
	Globals.pausado = false
	await get_tree().create_timer(20.2).timeout
	Globals.pausado = true
	if not _check(_room.get_prop("Lumi").estado == Lumi.Estado.APAGADA, "Cooldown reanudado tras carga"):
		return
	var vela_antes: float = Globals.vela_101
	var bruma_antes: float = Globals.bruma
	for i in 3:
		await _action("Lumi", Globals.PERTURBAR)
	if not _check(Globals.vela_101 == vela_antes and Globals.bruma == bruma_antes - 15.0, "Niveles repetidos no vuelven a premiar"):
		return
	await _action("Lumi", Globals.MIRAR)
	if not _check(_room.get_prop("Lumi").estado == Lumi.Estado.CUIDADA and Globals.sellos == 3 and _room.state.mision_completada and _completion_cards == 1, "Tercer sello y cierre de misión original"):
		return
	await _action("Lumi", Globals.MIRAR)
	await _action("Lumi", Globals.PERTURBAR)
	if not _check(_room.state.sombra_gigante_activada and Globals.vela_101 == 100.0 and Globals.sellos == 3 and _completion_cards == 1, "Combo sombra y cierre no repetido"):
		return
	if not await _save_restore("misión completa y sombra"):
		return
	if not _check(_room.state.mision_completada and _room.state.sombra_gigante_activada and Globals.sellos == 3 and Globals.vela_101 == 100.0 and not _room.get_prop("Ovillo").visible, "Partida completa persistente"):
		return
	Globals.pausado = false
	G.gui.abrir_menu()
	if not _check(Globals.pausado and G.is_blocked, "Menú pausa goteo y entrada"):
		return
	G.gui.cerrar_menu()
	if not _check(not Globals.pausado and not G.is_blocked and not _room.ocupado, "Menú reanuda entrada"):
		return
	await _capturar("final")
	_cleanup()
	print("FULL PASS: 11 Props, verbos, inventario nativo, todos los puzzles, cooldown, recompensas únicas, misión, sombra, HUD, pausa y 4 guardados/cargas")
	get_tree().quit(0)


func _native_click(name: String) -> void:
	var obj: ObjetoInteractivo = _room.get_prop(name)
	E.clear_hovered()
	obj._on_mouse_entered()
	var event := InputEventMouseButton.new()
	event.position = obj.global_position + obj._rect_local().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	await obj._on_input_event(get_viewport(), event, 0)
	_check(_room.objeto_seleccionado == _room.objeto_en(event.position), "Selección nativa de " + name)


func _action(name: String, verbo: StringName) -> void:
	await get_tree().process_frame
	if _failed:
		return
	_room.seleccionar_objeto(_room.get_prop(name))
	var button: Button = G.gui.ui._botones[verbo]
	if not _check(not button.disabled and button.visible, "Verbo disponible: " + name + " " + String(verbo)):
		return
	button.pressed.emit()
	await get_tree().process_frame
	while _room.ocupado and not _failed:
		await get_tree().process_frame
	_check(not G.is_blocked and not E.playing_queue, "Liberación tras " + name)
	await get_tree().create_timer(0.3).timeout
	_check_composition()


func _check_composition() -> bool:
	var error: String = Composition.error_en(_room)
	return _check(error.is_empty(), "Composición original: " + error)


func _save_restore(description: String) -> bool:
	if _failed:
		return false
	if not _check(G.gui.guardar_partida(SLOT), "Guardar " + description):
		return false
	_save_created = true
	var save_path := "user://save_%d.json" % SLOT
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	for prop_state: Dictionary in saved.rooms.Habitacion101.props.values():
		if not _check(not prop_state.has("_x_base") and not prop_state.has("_posicion_base"), "El guardado no persiste anclajes visuales"):
			return false
		# Simula los snapshots anteriores que sobrescribían _x_base con cero.
		prop_state["_x_base"] = 0.0
	var save_file := FileAccess.open(save_path, FileAccess.WRITE)
	save_file.store_string(JSON.stringify(saved))
	save_file.close()
	Globals.bruma = 1.0
	_room.state.intentos_ramon = 99
	var cargado: bool = G.gui.cargar_partida(SLOT)
	if not cargado:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://save_%d.json" % SLOT))
		print("Load diagnostic: ", G.gui.ultimo_aviso, " keys=", data.keys(), " player=", data.player, " rooms=", data.rooms.keys())
	if not _check(cargado, "Solicitar carga " + description):
		return false
	await E.game_loaded
	_room = R.current
	await get_tree().process_frame
	for obj: ObjetoInteractivo in _room.get_props():
		obj._sacudir()
	await get_tree().create_timer(0.12).timeout
	for obj: ObjetoInteractivo in _room.get_props():
		obj._sacudir()
	await get_tree().create_timer(0.3).timeout
	if not _check_composition():
		return false
	return _check(_room.state.intentos_ramon == 2 and Globals.bruma != 1.0 and C.player.inventory.has("Dentadura"), "Restaurar " + description)


func _check(condition: bool, detail: String) -> bool:
	if _failed:
		return false
	if not condition:
		_failed = true
		push_error("FULL FAIL: " + detail)
		_cleanup()
		get_tree().quit(1)
	return condition


func _capturar(etapa: String) -> void:
	var args := OS.get_cmdline_user_args()
	if "--capture-prefix" not in args:
		return
	await RenderingServer.frame_post_draw
	var prefix: String = args[args.find("--capture-prefix") + 1]
	var error := get_viewport().get_texture().get_image().save_png(prefix + "-" + etapa + ".png")
	_check(error == OK, "Captura " + etapa)


func _cleanup() -> void:
	Engine.time_scale = 1.0
	if _save_created:
		if _failed or "--retain-full-save" not in OS.get_cmdline_user_args():
			DirAccess.remove_absolute("user://save_%d.json" % SLOT)
		_save_created = false
