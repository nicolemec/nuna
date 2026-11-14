extends PopochiuGraphicInterface

const Guardado := preload("res://game/menu/menu_guardado.gd")

var ui: InterfazUI
var historial: Array[String] = []
var dialogo_actual := ""
var puede_continuar := false
var ultimo_aviso := ""
var _dialogo_id := 0
var _pausa_antes_dialogo := false
var _habitacion_visible := false
var _menu: PanelContainer
var _inventario_nativo: Control
## Los pips de Nuna al hablar.
var _voz: VozNuna
## Un tic retro en cada clic.
var _clic: AudioStreamPlayer


func _ready() -> void:
	super()
	ui = InterfazUI.new()
	add_child(ui)
	_voz = VozNuna.new()
	_voz.name = "VozNuna"
	add_child(_voz)
	_clic = AudioStreamPlayer.new()
	_clic.name = "Clic"
	_clic.stream = Chip.clic()
	_clic.volume_db = -12.0
	_clic.max_polyphony = 1
	add_child(_clic)
	ui.accion_elegida.connect(func (verbo): await R.current.ejecutar_accion(String(verbo)))
	$TiempoDialogo.timeout.connect(completar_dialogo.bind(true))
	$HabilitarContinuar.timeout.connect(func (): puede_continuar = true)
	C.tree_exiting.connect(_liberar_personajes_sin_sala)
	C.character_spoke.connect(_mostrar_dialogo)
	C.character_stopped_talking.connect(func (_character): completar_dialogo(true))
	Globals.progreso_cambiado.connect(actualizar_progreso)
	_inventario_nativo = Control.new()
	_inventario_nativo.name = "InventarioNativo"
	_inventario_nativo.hide()
	add_child(_inventario_nativo)
	for path in PopochiuResources.get_section("inventory_items"):
		var data: PopochiuInventoryItemData = load(path)
		var item := I.get_item_instance(data.script_name)
		_inventario_nativo.add_child(item)
	I.item_added.connect(_item_added)
	I.item_removed.connect(_item_removed)
	_crear_menu_partida()
	mostrar_habitacion(false)


func _liberar_personajes_sin_sala() -> void:
	# Popochiu creates the PC before entering a Room; a menu-only session leaves it unparented.
	for character in C.get_characters().values():
		if is_instance_valid(character) and character.get_parent() == null:
			character.free()


func _item_added(item: PopochiuInventoryItem, character: PopochiuCharacter) -> void:
	Globals.inventario_cambiado.emit()
	_inventory_add_done.call_deferred(item, character)


func _inventory_add_done(item: PopochiuInventoryItem, character: PopochiuCharacter) -> void:
	I.item_add_done.emit(item, character)


func _item_removed(item: PopochiuInventoryItem, character: PopochiuCharacter) -> void:
	Globals.inventario_cambiado.emit()
	_inventory_remove_done.call_deferred(item, character)


func _inventory_remove_done(item: PopochiuInventoryItem, character: PopochiuCharacter) -> void:
	I.item_remove_done.emit(item, character)


func mostrar_habitacion(activa: bool, con_hud := true) -> void:
	_habitacion_visible = activa
	ui.visible = activa
	ui.mostrar_hud(con_hud)
	if activa:
		ui.mostrar_exploracion()
		actualizar_progreso()
	else:
		_menu.hide()


func actualizar_progreso() -> void:
	if not is_instance_valid(ui):
		return
	ui._actualizar_sellos(Globals.sellos)
	ui._actualizar_bruma(Globals.bruma)
	ui._actualizar_vela(Ajustes.LUMI_HABITACION_ID, Globals.vela_101)
	ui._actualizar_inventario()


func _ejecutar(verbo: String) -> void:
	await R.current.ejecutar_accion(verbo)


func _on_blocked(_props := {}) -> void:
	if is_instance_valid(ui):
		ui.establecer_acciones_habilitadas(false)


func _on_unblocked() -> void:
	if is_instance_valid(ui):
		var seleccion_valida: bool = is_instance_valid(R.current) and R.current.has_method("_seleccion_es_valida") and R.current._seleccion_es_valida()
		ui.establecer_acciones_habilitadas(seleccion_valida)


func _mostrar_dialogo(_character: PopochiuCharacter, texto: String) -> void:
	_dialogo_id += 1
	if _character == C.player:
		_voz.decir(texto)
	_pausa_antes_dialogo = Globals.pausado
	Globals.pausado = true
	dialogo_actual = texto
	historial.append(texto)
	ui.mostrar_dialogo(texto, _dialogo_id)
	puede_continuar = false
	$HabilitarContinuar.start(0.4)
	$TiempoDialogo.start(maxf(2.0, texto.length() * 0.055))
	G.dialog_line_started.emit()


func _input(event: InputEvent) -> void:
	if not dialogo_actual.is_empty() and puede_continuar and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		completar_dialogo()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_clic.play()
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if not dialogo_actual.is_empty() and puede_continuar:
			get_viewport().set_input_as_handled()
			completar_dialogo()
	elif event is InputEventKey and event.pressed and not event.echo and _habitacion_visible:
		if event.keycode == KEY_ESCAPE:
			if _menu.visible:
				cerrar_menu()
			elif not G.is_blocked and not R.current.ocupado:
				abrir_menu()
		elif event.keycode == KEY_F5:
			guardar_partida()
		elif event.keycode == KEY_F9:
			cargar_partida()
		else:
			return
		get_viewport().set_input_as_handled()


## Hace sonar una línea con la voz de quien la dice, sin mostrarla en la consola
## (por ejemplo, los carteles de la ceremonia: "CEREMONIA: ¡Felicitaciones!").
func voz(texto: String) -> void:
	_voz.decir(texto)


func completar_dialogo(force := false) -> void:
	if dialogo_actual.is_empty() or (not force and not puede_continuar):
		return
	$TiempoDialogo.stop()
	$HabilitarContinuar.stop()
	_voz.callar()
	dialogo_actual = ""
	Globals.pausado = _pausa_antes_dialogo
	ui.finalizar_dialogo(_dialogo_id)
	G.dialog_line_finished.emit()


func _crear_menu_partida() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 60
	add_child(capa)
	_menu = PanelContainer.new()
	_menu.position = Vector2(85, 35)
	_menu.custom_minimum_size = Vector2(150, 110)
	var orden := OrdenTrabajo.new()
	_menu.theme = orden._crear_tema()
	orden.free()
	capa.add_child(_menu)
	var lista := VBoxContainer.new()
	_menu.add_child(lista)
	for datos in [["Volver al juego", cerrar_menu], ["Guardar (F5)", guardar_partida], ["Cargar (F9)", cargar_partida], ["Menú principal", volver_al_menu]]:
		var boton := Button.new()
		boton.text = datos[0]
		boton.pressed.connect(datos[1])
		lista.add_child(boton)
	_menu.hide()


func partida_pausada() -> bool:
	return _menu.visible


func abrir_menu() -> void:
	if G.is_blocked or R.current.ocupado:
		return
	if C.player.is_moving:
		C.player.stop_walking()
	Globals.pausado = true
	G.block()
	_menu.show()


func cerrar_menu() -> void:
	if not _menu.visible:
		return
	_menu.hide()
	Globals.pausado = false
	G.unblock()


func guardar_partida(slot := 1) -> bool:
	if not _habitacion_visible or R.current.ocupado or not dialogo_actual.is_empty() or (G.is_blocked and not _menu.visible):
		return false
	if R.current.get("permite_guardar") == false:
		cerrar_menu()
		ultimo_aviso = "Durante la intro no se puede guardar."
		ui.mostrar_accion(ultimo_aviso)
		return false
	cerrar_menu()
	E.save_game(slot, "Habitación 101 - %d/3 sellos" % Globals.sellos)
	var guardado := FileAccess.file_exists("user://save_%d.json" % slot)
	ultimo_aviso = "Partida guardada." if guardado else "No se pudo guardar la partida."
	ui.mostrar_accion(ultimo_aviso)
	return guardado


func cargar_partida(slot := 1) -> bool:
	if not _habitacion_visible or R.current.ocupado or not dialogo_actual.is_empty() or (G.is_blocked and not _menu.visible):
		return false
	var resultado: Dictionary = Guardado.leer_slot(slot)
	if not String(resultado.error).is_empty():
		ultimo_aviso = resultado.error
		ui.mostrar_accion(ultimo_aviso)
		return false
	cerrar_menu()
	E.load_game(slot)
	return true


func volver_al_menu() -> void:
	cerrar_menu()
	if is_instance_valid(R.current):
		await R.current.exit_room()
	mostrar_habitacion(false)
	E.in_room = false
	get_tree().change_scene_to_file("res://game/menu/menu_inicio.tscn")
