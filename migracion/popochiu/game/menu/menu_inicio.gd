extends Control
## Menú de Nuna: independiente del personaje y de los subsistemas originales.
## Globals.reiniciar() restaura dominio, inventarios y estados Popochiu sincrónicamente.

const ESCENA_JUEGO := "res://game/rooms/habitacion_101/room_habitacion_101.tscn"
const RUTA_FONDO := "res://arte/menu/fondo_menu.png"
const RUTA_FUENTE := "res://arte/fuentes/monogram-extended.ttf"
const RUTA_NUNA := "res://arte/nuna/nuna.png"
const RUTA_NUNA_DATOS := "res://arte/nuna/nuna.json"
const SLOT := 1
const Validador = preload("res://game/menu/menu_guardado.gd")
const COLOR_OSCURO := Color8(34, 32, 52)
const COLOR_AZUL := Color8(48, 96, 130)
const COLOR_GRIS := Color8(155, 173, 183)
const COLOR_CLARO := Color8(203, 219, 252)

var listo := false
var ocupado := false
var jugar: Button
var continuar: Button
var mensaje: Label
var _botones: Array[Button] = []
var _lienzo: Control
var _nuna: AnimatedSprite2D
var _tiempo := 0.0


func _ready() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 11 # Sobre el HUD, debajo de las transiciones de Popochiu.
	add_child(capa)
	_lienzo = Control.new()
	_lienzo.size = Vector2(320, 180)
	_lienzo.theme = _crear_tema()
	_lienzo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	capa.add_child(_lienzo)
	get_viewport().size_changed.connect(_centrar)
	_centrar()

	var fondo := TextureRect.new()
	fondo.texture = load(RUTA_FONDO)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lienzo.add_child(fondo)

	var titulo := Label.new()
	titulo.text = "CASI HUMANO"
	titulo.position = Vector2(0, 12)
	titulo.size = Vector2(320, 30)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 32)
	titulo.add_theme_color_override("font_color", COLOR_CLARO)
	titulo.add_theme_color_override("font_shadow_color", COLOR_OSCURO)
	titulo.add_theme_constant_override("shadow_offset_x", 0)
	titulo.add_theme_constant_override("shadow_offset_y", 2)
	_lienzo.add_child(titulo)
	_crear_nuna()

	var botones := VBoxContainer.new()
	botones.position = Vector2(126, 104)
	botones.size = Vector2(68, 0)
	botones.add_theme_constant_override("separation", 4)
	_lienzo.add_child(botones)
	jugar = _crear_boton("Jugar", botones, _al_jugar)
	continuar = _crear_boton("Continuar", botones, _al_continuar)
	continuar.visible = FileAccess.file_exists(PopochiuSaveLoad.SAVE_GAME_PATH % SLOT)
	if not OS.has_feature("web"):
		_crear_boton("Salir", botones, func (): get_tree().quit())

	mensaje = Label.new()
	mensaje.position = Vector2(8, 164)
	mensaje.size = Vector2(304, 16)
	mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mensaje.add_theme_font_size_override("font_size", 16)
	mensaje.add_theme_color_override("font_color", COLOR_CLARO)
	_lienzo.add_child(mensaje)
	_set_ocupado(true)
	_ocultar_hud()
	# E._ready() termina después de un frame (inventarios y estados iniciales).
	for _frame in range(300):
		await get_tree().process_frame
		if is_instance_valid(G.gui) and not R.rooms_states.is_empty():
			listo = true
			break
	_ocultar_hud()
	G.block()
	E.in_room = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not listo:
		mensaje.text = "No se pudo inicializar el juego."
		for boton in _botones:
			if boton.text == "Salir":
				boton.disabled = false
				boton.grab_focus()
		return
	_set_ocupado(false)
	jugar.grab_focus()


func _process(delta: float) -> void:
	_tiempo += delta
	if is_instance_valid(_nuna):
		_nuna.position.y = 90 + roundf(sin(_tiempo * 3.0) * 2.0)


func _centrar() -> void:
	_lienzo.position = ((get_viewport_rect().size - _lienzo.size) / 2.0).floor()


func _ocultar_hud() -> void:
	var gui: PopochiuGraphicInterface = G.gui if is_instance_valid(G.gui) else E.gui
	if is_instance_valid(gui):
		if gui.has_method("mostrar_habitacion"):
			gui.call("mostrar_habitacion", false)
		else:
			gui.hide()


func _crear_nuna() -> void:
	var datos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RUTA_NUNA_DATOS))
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", 1.0)
	var textura: Texture2D = load(RUTA_NUNA)
	for etiqueta: Dictionary in datos.meta.frameTags:
		if etiqueta.name != "flota_frente":
			continue
		for indice in range(int(etiqueta.from), int(etiqueta.to) + 1):
			var frame: Dictionary = datos.frames[indice]
			var atlas := AtlasTexture.new()
			atlas.atlas = textura
			atlas.region = Rect2(frame.frame.x, frame.frame.y, frame.frame.w, frame.frame.h)
			frames.add_frame(&"default", atlas, float(frame.duration) / 1000.0)
	_nuna = AnimatedSprite2D.new()
	_nuna.sprite_frames = frames
	_nuna.position = Vector2(160, 90)
	_lienzo.add_child(_nuna)
	_nuna.play()


func _crear_boton(texto: String, contenedor: Container, accion: Callable) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(68, 16)
	contenedor.add_child(boton)
	boton.pressed.connect(accion)
	_botones.append(boton)
	return boton


func _crear_tema() -> Theme:
	var tema_menu := Theme.new()
	var fuente: FontFile = load(RUTA_FUENTE).duplicate()
	fuente.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	fuente.hinting = TextServer.HINTING_NONE
	fuente.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	tema_menu.default_font = fuente
	tema_menu.default_font_size = 16
	tema_menu.set_stylebox("normal", "Button", _caja(COLOR_OSCURO, COLOR_GRIS))
	tema_menu.set_stylebox("hover", "Button", _caja(COLOR_AZUL, COLOR_CLARO))
	tema_menu.set_stylebox("focus", "Button", _caja(COLOR_AZUL, COLOR_CLARO))
	tema_menu.set_stylebox("pressed", "Button", _caja(COLOR_CLARO, COLOR_CLARO))
	tema_menu.set_color("font_color", "Button", COLOR_GRIS)
	tema_menu.set_color("font_hover_color", "Button", COLOR_CLARO)
	tema_menu.set_color("font_focus_color", "Button", COLOR_CLARO)
	tema_menu.set_color("font_pressed_color", "Button", COLOR_OSCURO)
	return tema_menu


func _caja(relleno: Color, borde: Color) -> StyleBoxFlat:
	var caja := StyleBoxFlat.new()
	caja.bg_color = relleno
	caja.border_color = borde
	caja.set_border_width_all(1)
	caja.content_margin_top = 0
	caja.content_margin_bottom = 2
	return caja


func _set_ocupado(valor: bool) -> void:
	ocupado = valor
	for boton in _botones:
		boton.disabled = valor


func _al_jugar() -> void:
	if ocupado or not listo:
		return
	_set_ocupado(true)
	Globals.reiniciar()
	E.loaded_game = {}
	_abrir_habitacion(ESCENA_JUEGO)


func _al_continuar() -> void:
	if ocupado or not listo:
		return
	_set_ocupado(true)
	var resultado: Dictionary = Validador.leer_slot(SLOT)
	if not resultado.error.is_empty():
		_error_carga(resultado.error)
		return
	# E.load_game() usa R.goto_room(), que requiere una habitación actual.
	# La restauración pública de estados seguida del cambio directo conserva
	# el ciclo room_readied/game_loaded/_on_restore_from_savegame del motor.
	Globals.reiniciar()
	E.loaded_game = PopochiuSaveLoad.new().load_game(SLOT)
	if E.loaded_game.is_empty():
		_error_carga("No se pudo cargar la partida.")
		return
	# El GUI base emite feedback dentro de game_loaded, antes del await del motor.
	# El callback estático sobrevive al menú y completa únicamente este arranque.
	E.game_loaded.connect(Validador.completar_carga_desde_menu, CONNECT_ONE_SHOT)
	E.game_load_started.emit()
	_abrir_habitacion(resultado.scene)


func _abrir_habitacion(ruta: String) -> void:
	G.block()
	E.camera.restore_default_limits()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var error := get_tree().change_scene_to_file(ruta)
	if error != OK:
		E.loaded_game = {}
		_error_carga("No se pudo abrir la habitación.")


func _error_carga(texto: String) -> void:
	if E.game_loaded.is_connected(Validador.completar_carga_desde_menu):
		E.game_loaded.disconnect(Validador.completar_carga_desde_menu)
	mensaje.text = texto
	E.in_room = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_ocultar_hud()
	_set_ocupado(false)
	jugar.grab_focus()
