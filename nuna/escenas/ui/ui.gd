class_name InterfazUI
extends CanvasLayer
## Franja inferior: verbos, verbos con candado, inventario, cuaderno y Bruma.
## Arriba de la franja, la línea de acción ("Mirar lámpara").
## Todo se arma por código.

const CASILLEROS: int = 2
const COLOR_CASILLERO := Color(0.15, 0.15, 0.18)
const COLOR_SELLO_VACIO := Color(0.35, 0.35, 0.4)
const COLOR_SELLO_LLENO := Color(0.85, 0.25, 0.3)

var _linea: Label
var _texto_base: String = ""
var _texto_hover: String = ""
var _botones: Dictionary = {}
var _casilleros: Array[Label] = []
var _sellos: Array[ColorRect] = []
var _bruma: ProgressBar
var _vela: ProgressBar
var _etiqueta_lumi: PanelContainer
var _zona_dialogo: PanelContainer
var _texto_dialogo: Label
var _id_dialogo_actual: int = -1


func _ready() -> void:
	_crear_zona_dialogo()

	# Una fila que ocupa toda la franja; los elementos se acomodan solos
	var fila := HBoxContainer.new()
	fila.position = Vector2(4, Ajustes.UI_CONTROLES_Y)
	fila.size = Vector2(312, Ajustes.UI_CONTROLES_ALTO)
	fila.add_theme_constant_override("separation", 6)
	add_child(fila)

	fila.add_child(_crear_verbos())
	fila.add_child(_crear_bloqueados())
	var hueco := Control.new()  # empuja lo que sigue hacia la derecha
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(hueco)
	fila.add_child(_crear_inventario())
	fila.add_child(_crear_cuaderno())
	fila.add_child(_crear_bruma())
	fila.add_child(_crear_vela())

	_crear_linea()

	GameState.inventario_cambiado.connect(_actualizar_inventario)
	GameState.sellos_cambiados.connect(_actualizar_sellos)
	GameState.bruma_cambiada.connect(_actualizar_bruma)
	GameState.vela_cambiada.connect(_actualizar_vela)
	_actualizar_inventario()
	_actualizar_sellos(GameState.sellos)
	_actualizar_bruma(GameState.bruma)
	_actualizar_vela(Ajustes.LUMI_HABITACION_ID, GameState.vela_de(Ajustes.LUMI_HABITACION_ID))


# ---------- Lo que llama la habitación ----------

func mostrar_accion(texto: String) -> void:
	_texto_base = texto
	_refrescar_linea()


func mostrar_dialogo(texto: String, id: int) -> void:
	_id_dialogo_actual = id
	_texto_dialogo.text = texto
	_zona_dialogo.visible = true


func finalizar_dialogo(id: int) -> void:
	if id == _id_dialogo_actual:
		_zona_dialogo.visible = false
		_id_dialogo_actual = -1


func mostrar_etiqueta_lumi() -> void:
	if _etiqueta_lumi == null:
		_etiqueta_lumi = PanelContainer.new()
		_etiqueta_lumi.position = Ajustes.LUMI_ETIQUETA_POSICION
		_etiqueta_lumi.size = Ajustes.LUMI_ETIQUETA_TAMANO
		_etiqueta_lumi.z_index = 10
		_etiqueta_lumi.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var contenido := VBoxContainer.new()
		contenido.add_theme_constant_override("separation", 1)
		var texto := _crear_label(Lumi.FRASE_ETIQUETA, Ajustes.LUMI_ETIQUETA_TAMANO_TEXTO)
		var letra_chica := _crear_label(Lumi.FRASE_LETRA_CHICA, Ajustes.LUMI_ETIQUETA_TAMANO_LETRA_CHICA)
		contenido.add_child(texto)
		contenido.add_child(letra_chica)
		_etiqueta_lumi.add_child(contenido)
		add_child(_etiqueta_lumi)
	_etiqueta_lumi.visible = true


func ocultar_etiqueta_lumi() -> void:
	if _etiqueta_lumi != null:
		_etiqueta_lumi.visible = false


# ---------- Construcción ----------

func _crear_zona_dialogo() -> void:
	_zona_dialogo = PanelContainer.new()
	_zona_dialogo.position = Vector2(8, 4)
	_zona_dialogo.size = Vector2(304, 28)
	_zona_dialogo.z_index = 100
	_zona_dialogo.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.04, 0.06, 0.12, 0.96)
	estilo.border_color = Color(0.8, 0.85, 1.0, 1.0)
	estilo.set_border_width_all(1)
	estilo.set_content_margin_all(4)
	_zona_dialogo.add_theme_stylebox_override("panel", estilo)

	_texto_dialogo = Label.new()
	_texto_dialogo.custom_minimum_size = Vector2(296, 20)
	_texto_dialogo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto_dialogo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto_dialogo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto_dialogo.max_lines_visible = 2
	_texto_dialogo.add_theme_font_size_override("font_size", 8)
	_texto_dialogo.add_theme_color_override("font_color", Color.WHITE)
	_texto_dialogo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zona_dialogo.add_child(_texto_dialogo)
	_zona_dialogo.visible = false
	add_child(_zona_dialogo)


func _crear_verbos() -> HBoxContainer:
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	caja.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var grupo := ButtonGroup.new()  # solo un verbo apretado a la vez
	for verbo in GameState.NOMBRES_VERBOS:
		var b := Button.new()
		b.text = GameState.NOMBRES_VERBOS[verbo]
		b.toggle_mode = true
		b.button_group = grupo
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 14)
		b.add_theme_font_size_override("font_size", 8)
		b.pressed.connect(GameState.elegir_verbo.bind(verbo))
		caja.add_child(b)
		_botones[verbo] = b
	_botones[GameState.verbo_actual].button_pressed = true
	return caja


func _crear_bloqueados() -> HBoxContainer:
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 1)
	caja.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for nombre_verbo in GameState.VERBOS_BLOQUEADOS:
		var cuadro := ColorRect.new()
		cuadro.color = COLOR_CASILLERO
		cuadro.custom_minimum_size = Vector2(10, 14)
		var signo := _crear_label("?", 8)
		signo.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		signo.set_anchors_preset(Control.PRESET_FULL_RECT)
		cuadro.add_child(signo)
		cuadro.mouse_entered.connect(_poner_hover.bind(nombre_verbo + " · solo profesionales"))
		cuadro.mouse_exited.connect(_poner_hover.bind(""))
		caja.add_child(cuadro)
	return caja


func _crear_inventario() -> HBoxContainer:
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	caja.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in CASILLEROS:
		var casillero := ColorRect.new()
		casillero.color = COLOR_CASILLERO
		casillero.custom_minimum_size = Vector2(16, 16)
		var letra := _crear_label("", 8)
		letra.set_anchors_preset(Control.PRESET_FULL_RECT)
		casillero.add_child(letra)
		casillero.mouse_entered.connect(_hover_casillero.bind(i))
		casillero.mouse_exited.connect(_poner_hover.bind(""))
		caja.add_child(casillero)
		_casilleros.append(letra)
	return caja


func _crear_cuaderno() -> HBoxContainer:
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	caja.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caja.mouse_filter = Control.MOUSE_FILTER_STOP
	caja.mouse_entered.connect(_hover_cuaderno)
	caja.mouse_exited.connect(_poner_hover.bind(""))
	for i in GameState.SELLOS_TOTALES:
		var sello := ColorRect.new()
		sello.custom_minimum_size = Vector2(6, 6)
		sello.color = COLOR_SELLO_VACIO
		sello.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caja.add_child(sello)
		_sellos.append(sello)
	return caja


func _crear_bruma() -> ProgressBar:
	_bruma = ProgressBar.new()
	_bruma.min_value = 0
	_bruma.max_value = 100
	_bruma.show_percentage = false
	_bruma.custom_minimum_size = Vector2(40, 6)
	_bruma.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fondo_barra := StyleBoxFlat.new()
	fondo_barra.bg_color = COLOR_CASILLERO
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = Color(0.6, 0.5, 0.85)  # violeta bruma
	_bruma.add_theme_stylebox_override("background", fondo_barra)
	_bruma.add_theme_stylebox_override("fill", relleno)
	_bruma.mouse_entered.connect(_poner_hover.bind("Bruma"))
	_bruma.mouse_exited.connect(_poner_hover.bind(""))
	return _bruma


func _crear_vela() -> ProgressBar:
	_vela = ProgressBar.new()
	_vela.min_value = 0
	_vela.max_value = Ajustes.VELA_MAXIMA
	_vela.show_percentage = false
	_vela.custom_minimum_size = Vector2(40, 6)
	_vela.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fondo_barra := StyleBoxFlat.new()
	fondo_barra.bg_color = COLOR_CASILLERO
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = Color(0.95, 0.65, 0.25)
	_vela.add_theme_stylebox_override("background", fondo_barra)
	_vela.add_theme_stylebox_override("fill", relleno)
	_vela.mouse_entered.connect(_hover_vela)
	_vela.mouse_exited.connect(_poner_hover.bind(""))
	return _vela


func _crear_linea() -> void:
	_linea = _crear_label("", 8)
	_linea.position = Vector2(0, Ajustes.UI_LINEA_Y)
	_linea.size = Vector2(320, Ajustes.UI_LINEA_ALTO)
	_linea.add_theme_color_override("font_outline_color", Color.BLACK)
	_linea.add_theme_constant_override("outline_size", 3)
	add_child(_linea)


func _crear_label(texto: String, tam: int) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ---------- Actualización ----------

func _actualizar_inventario() -> void:
	for i in _casilleros.size():
		if i < GameState.inventario.size():
			_casilleros[i].text = GameState.nombre_objeto(GameState.inventario[i]).left(1)
		else:
			_casilleros[i].text = ""


func _actualizar_sellos(cantidad: int) -> void:
	for i in _sellos.size():
		_sellos[i].color = COLOR_SELLO_LLENO if i < cantidad else COLOR_SELLO_VACIO


func _actualizar_bruma(valor: float) -> void:
	_bruma.value = valor


func _actualizar_vela(habitacion_id: StringName, valor: float) -> void:
	if habitacion_id == Ajustes.LUMI_HABITACION_ID:
		_vela.value = valor


# ---------- Línea de acción y hover ----------

func _poner_hover(texto: String) -> void:
	_texto_hover = texto
	_refrescar_linea()


func _hover_casillero(i: int) -> void:
	if i < GameState.inventario.size():
		_poner_hover(GameState.nombre_objeto(GameState.inventario[i]))
	else:
		_poner_hover("")


func _hover_cuaderno() -> void:
	_poner_hover("Cuaderno de pruebas: %d/%d sellos" % [GameState.sellos, GameState.SELLOS_TOTALES])


func _hover_vela() -> void:
	_poner_hover("Vela 101: %d/%d" % [int(_vela.value), int(Ajustes.VELA_MAXIMA)])


func _refrescar_linea() -> void:
	var t: String = _texto_hover if _texto_hover != "" else _texto_base
	if _linea.text != t:
		_linea.text = t
