extends Node
## Ejecutar esta escena con -- --menu-test, sin flags de otros runners.

const MENU := "res://game/menu/menu_inicio.tscn"
const Validador = preload("res://game/menu/menu_guardado.gd")
var _fallos: Array[String] = []
var _slot_existia := false
var _slot_original := PackedByteArray()
var _slot_tocado := false


@onready var _tree := get_tree()


func _ready() -> void:
	_ejecutar.call_deferred()


func _ejecutar() -> void:
	reparent(_tree.root)
	print("MENU USERDATA: ", ProjectSettings.globalize_path("user://"))
	var ruta := PopochiuSaveLoad.SAVE_GAME_PATH % 1
	_slot_existia = FileAccess.file_exists(ruta)
	if _slot_existia:
		_slot_original = FileAccess.get_file_as_bytes(ruta)
	_tree.change_scene_to_file(MENU)
	if not await _esperar_menu():
		_finalizar()
		return
	var menu: Control = _tree.current_scene
	_comprobar(menu.listo, "Inicialización Popochiu desde menú")
	_comprobar(menu.jugar.has_focus(), "Foco de teclado en Jugar")
	_comprobar(menu.continuar.visible == _slot_existia, "Continuar depende de slot1")
	_comprobar(not E.in_room and G.is_blocked, "Menú bloquea interacción de habitación")
	_comprobar(menu._nuna.sprite_frames.get_frame_count(&"default") == 2, "Animación frontal autónoma")
	_comprobar(Validador.validar(null) != "", "JSON nulo inválido")
	_comprobar(Validador.validar([]) != "", "JSON array inválido")
	_comprobar(Validador.validar({"player": {}}) != "", "Jugador incompleto inválido")
	_comprobar(Validador.leer_slot(987654).error != "", "Slot inexistente informa error")
	if "--menu-only" in OS.get_cmdline_user_args():
		_finalizar()
		return
	# Slot1 queda restaurado byte a byte, incluso si una comprobación falla.
	_slot_tocado = true
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	archivo.store_string("{JSON roto")
	archivo.close()
	menu._al_continuar()
	_comprobar(not menu.mensaje.text.is_empty() and not menu.ocupado, "Carga inválida informa y permite reintentar")
	_comprobar(_tree.current_scene == menu and not E.in_room, "Carga inválida no abandona menú")
	menu._al_jugar()
	if not await _esperar_habitacion():
		_finalizar()
		return
	_comprobar(_tree.current_scene.scene_file_path == "res://game/rooms/habitacion_101/room_habitacion_101.tscn", "Jugar abre room101")
	_comprobar(is_instance_valid(C.player) and C.player.is_inside_tree(), "Jugador inicializado en Popochiu")
	var posicion := C.player.global_position
	E.save_game(1, "Prueba menú (restaurada al terminar)")
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	_comprobar(Validador.validar(datos) == "", "Guardado Popochiu válido")
	print("MENU NATIVE SAVE KEYS: ", datos.keys())
	var minimo: Dictionary = datos.duplicate(true)
	for seccion in ["characters", "inventory_items", "dialogs"]:
		minimo.erase(seccion)
	_comprobar(Validador.validar(minimo) == "", "Guardado nativo acepta secciones vacías omitidas")
	var corrupto: Dictionary = datos.duplicate(true)
	corrupto.player.room = "NoExiste"
	_comprobar(Validador.validar(corrupto) != "", "Habitación inexistente rechazada")
	corrupto = datos.duplicate(true)
	corrupto.rooms = []
	_comprobar(Validador.validar(corrupto) != "", "Estados inválidos rechazados")
	corrupto = datos.duplicate(true)
	corrupto.player.position.x = "roto"
	_comprobar(Validador.validar(corrupto) != "", "Coordenadas inválidas rechazadas")
	corrupto = datos.duplicate(true)
	corrupto.character_inventories = {datos.player.id: [false]}
	_comprobar(Validador.validar(corrupto) != "", "Inventario malformado rechazado")
	# Simula volver al menú sin destruir las instancias persistentes del motor.
	R.current.exit_room()
	_tree.change_scene_to_file(MENU)
	if not await _esperar_menu():
		_finalizar()
		return
	menu = _tree.current_scene
	_comprobar(menu.continuar.visible, "Continuar visible con slot1 válido")
	menu._al_continuar()
	if await _esperar_habitacion():
		_comprobar(C.player.global_position.is_equal_approx(posicion), "Continuar restaura posición")
		_comprobar(E.loaded_game.is_empty(), "Carga completa desbloquea room_readied")
		await _regresion_reiniciar()
	_finalizar()


func _regresion_reiniciar() -> void:
	var ramon: Node2D = R.current.get_prop("Ramon")
	var item: PopochiuInventoryItem = I.get_item_instance("Ovillo")
	Globals.otorgar_sello(&"menu_regresion")
	R.current.state.intentos_ramon = 7
	ramon.set("nombrado", true)
	I.set_item_in_inventory_bg(item, true)
	_comprobar(Globals.sellos > 0 and not Globals.sellos_obtenidos.is_empty(), "Misión completada poblada antes de reiniciar")
	_comprobar(not C.player.inventory.is_empty() and item.ever_collected, "Inventario poblado antes de reiniciar")
	E.save_game(1, "Prueba menú (restaurada al terminar)")
	_comprobar(Validador.leer_slot(1).error == "", "Guardado nativo poblado válido")
	R.current.exit_room()
	_tree.change_scene_to_file(MENU)
	if not await _esperar_menu():
		return
	_tree.current_scene._al_continuar()
	if not await _esperar_habitacion():
		return
	_comprobar(Globals.sellos_obtenidos.has("menu_regresion"), "Continuar restaura misión/sellos")
	_comprobar(C.player.inventory.has("Ovillo") and I.get_item_instance("Ovillo").quantity_owned == 1, "Continuar restaura inventario poblado")
	_comprobar(R.current.state.intentos_ramon == 7 and R.current.get_prop("Ramon").get("nombrado"), "Continuar restaura estado y nombre de Ramón")
	R.current.exit_room()
	_tree.change_scene_to_file(MENU)
	if not await _esperar_menu():
		return
	_tree.current_scene._al_jugar()
	if not await _esperar_habitacion():
		return
	_comprobar(Globals.sellos == 0 and Globals.sellos_obtenidos.is_empty(), "Nueva partida limpia misión/sellos")
	_comprobar(C.player.inventory.is_empty(), "Nueva partida limpia inventario background")
	var item_actual: PopochiuInventoryItem = I.get_item_instance("Ovillo")
	_comprobar(item_actual.quantity_owned == 0 and not item_actual.ever_collected, "Nueva partida limpia cantidades e historial")
	_comprobar(R.current.state.intentos_ramon == 0, "Nueva partida limpia intentos de Ramón")
	_comprobar(not R.current.get_prop("Ramon").get("nombrado"), "Nueva partida limpia nombre de Ramón")
	print("MENU RESET STATE: quantity=", item_actual.quantity_owned, " ever_collected=", item_actual.ever_collected)
	print("MENU RESET REGRESSION: misión/inventario/Ramón comprobados")


func _esperar_menu() -> bool:
	for _frame in range(400):
		await _tree.process_frame
		if is_instance_valid(_tree.current_scene) and _tree.current_scene.get("listo") == true:
			return true
	_comprobar(false, "Timeout inicializando menú")
	return false


func _esperar_habitacion() -> bool:
	for _frame in range(1800):
		await _tree.process_frame
		if is_instance_valid(R.current) and E.in_room and R.current.is_current:
			return true
	print("MENU TIMEOUT: in_room=", E.in_room, " current=", R.current, " loaded=", not E.loaded_game.is_empty(), " is_current=", R.current.is_current if is_instance_valid(R.current) else false)
	_comprobar(false, "Timeout cargando habitación")
	return false


func _comprobar(condicion: bool, descripcion: String) -> void:
	if not condicion:
		_fallos.append(descripcion)
		push_error("MENU TEST: " + descripcion)


func _finalizar() -> void:
	if _slot_tocado:
		var ruta := PopochiuSaveLoad.SAVE_GAME_PATH % 1
		if _slot_existia:
			var archivo := FileAccess.open(ruta, FileAccess.WRITE)
			archivo.store_buffer(_slot_original)
			archivo.close()
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	if _fallos.is_empty():
		if "--menu-only" in OS.get_cmdline_user_args():
			print("MENU TEST OK: diseño, teclado, inicialización y validador")
		else:
			print("MENU TEST OK: diseño, teclado, inválidos, nueva partida y continuar slot1")
		_tree.quit(0)
	else:
		print("MENU TEST FAILED: ", _fallos)
		_tree.quit(1)

