class_name InterfazUI
extends CanvasLayer
## HUD superior y consola inferior de la habitación.
## Los controles se construyen por código.

signal accion_elegida(verbo: StringName)

const CASILLEROS: int = 2
const COLOR_CASILLERO := Color(0.12, 0.12, 0.14)
const COLOR_SELLO_VACIO := Color(0.30, 0.30, 0.34)
const COLOR_SELLO_LLENO := Color.WHITE
const COLOR_TEXTO_SECUNDARIO := Color(0.55, 0.55, 0.58)
const COLOR_DESACTIVADO := Color(0.42, 0.42, 0.46)
const COLOR_CONSOLA := Color(0.0, 0.0, 0.0, 1.0)  # negro sólido: el juego no se ve detrás
const COLOR_BORDE_SELLO := Color.WHITE
const COLOR_BRUMA := Color(0.62, 0.48, 0.88)
const COLOR_MIEDO := Color(0.96, 0.63, 0.25)
const TEXTO_EXPLORACION: String = "Explorá el cuarto. Hacé clic en un objeto."
const ACCIONES: Array[StringName] = [&"mirar", &"agarrar", &"perturbar"]

var _linea: Label
var _letra_chica: Label
var _texto_base: String = ""
## Texto de la consola cuando no hay nada seleccionado; la habitación lo va cambiando según el progreso.
var _texto_guia: String = TEXTO_EXPLORACION
var _texto_hover: String = ""
var _botones: Dictionary = {}
var _prefijos_opciones: Dictionary = {}
var _textos_opciones: Dictionary = {}
var _opciones_hover: Dictionary = {}
var _casilleros: Array[Label] = []
var _sellos_hud: Array[ColorRect] = []
var _sellos_cuaderno: Array[ColorRect] = []
var _inventario_visual: HBoxContainer
var _verbos: HBoxContainer
var _consola: ColorRect
var _hud: ColorRect
var _casillero_cuaderno: ColorRect
var _bruma: ProgressBar
var _etiqueta_bruma: Label
var _vela: ProgressBar
var _fuente_hud: Font
var _fuente_dialogo: Font
var _fuente_fallback: Font
var _aviso_fallback_emitido: bool = false
var _id_dialogo_actual: int = -1
var _hay_objeto_seleccionado: bool = false
var _dialogo_activo: bool = false
var _certificacion_activa: bool = false
var _acciones_habilitadas: bool = false
var _acciones_disponibles: Dictionary = {}


func _ready() -> void:
	_fuente_hud = _cargar_fuente(Ajustes.UI_FUENTE_HUD)
	_fuente_dialogo = _cargar_fuente(Ajustes.UI_FUENTE_DIALOGO)
	if _fuente_dialogo is FontFile:
		# Pixel art: sin suavizado para que las letras queden nítidas.
		_fuente_dialogo.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_fuente_dialogo.hinting = TextServer.HINTING_NONE
		_fuente_dialogo.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	_crear_hud_superior()
	_crear_consola_inferior()
	_refrescar_linea()

	Globals.inventario_cambiado.connect(_actualizar_inventario)
	Globals.sellos_cambiados.connect(_actualizar_sellos)
	Globals.bruma_cambiada.connect(_actualizar_bruma)
	Globals.vela_cambiada.connect(_actualizar_vela)
	_actualizar_inventario()
	_actualizar_sellos(Globals.sellos)
	_actualizar_bruma(Globals.bruma)
	_actualizar_vela(Ajustes.LUMI_HABITACION_ID, Globals.vela_de(Ajustes.LUMI_HABITACION_ID))


# ---------- Lo que llama la habitación ----------

func mostrar_accion(texto: String) -> void:
	_texto_base = texto
	_refrescar_linea()


func mostrar_exploracion() -> void:
	_hay_objeto_seleccionado = false
	_acciones_disponibles.clear()
	_texto_base = _texto_guia
	_texto_hover = ""
	_linea.visible = true
	_letra_chica.visible = false
	_verbos.visible = false
	_actualizar_layout_consola()
	_refrescar_linea()
	_actualizar_opciones()


## Cambia la pista de la consola (lo que se ve cuando no hay objeto seleccionado).
func establecer_guia(texto: String) -> void:
	_texto_guia = texto
	if not _hay_objeto_seleccionado and not _certificacion_activa and not _dialogo_activo:
		_texto_base = _texto_guia
		_refrescar_linea()


func mostrar_objeto(
	nombre: String,
	puede_mirar: bool,
	puede_agarrar: bool,
	puede_perturbar: bool
) -> void:
	_hay_objeto_seleccionado = true
	_acciones_disponibles = {
		Globals.MIRAR: puede_mirar,
		Globals.AGARRAR: puede_agarrar,
		Globals.PERTURBAR: puede_perturbar,
	}
	_texto_hover = ""
	_texto_base = "%s - Elegí una acción" % nombre.to_upper()
	_linea.visible = true
	_letra_chica.visible = false
	_verbos.visible = not _certificacion_activa
	_actualizar_layout_consola()
	_refrescar_linea()
	_actualizar_opciones()


## Muestra u oculta la barra superior (inventario, sellos, bruma, miedo).
## La intro la oculta: ahí todavía no hay turno ni huésped.
func mostrar_hud(visible_hud: bool) -> void:
	if is_instance_valid(_hud):
		_hud.visible = visible_hud
		if visible_hud:
			# Si antes se mostró solo la Bruma (intro), vuelve a verse todo.
			for hijo in _hud.get_children():
				var parte := hijo as CanvasItem
				if parte != null:
					parte.modulate.a = 1.0


## Intro: cuando Nuna recibe el adelanto aparece solo el marcador de Bruma (lo demás de la
## barra llega con el cuaderno). La barra se llena desde cero y titila.
func presentar_bruma(segundos := 1.2) -> void:
	if not is_instance_valid(_hud) or not is_instance_valid(_bruma):
		return
	for hijo in _hud.get_children():
		var parte := hijo as CanvasItem
		if parte != null and parte != _bruma and parte != _etiqueta_bruma:
			parte.modulate.a = 0.0
	_hud.visible = true
	_bruma.value = 0.0
	var tw := create_tween()
	tw.tween_property(_bruma, "value", Globals.bruma, segundos).set_trans(Tween.TRANS_SINE)
	for i in 3:
		tw.tween_property(_bruma, "modulate", Color(2.0, 2.0, 2.0), 0.15)
		tw.tween_property(_bruma, "modulate", Color.WHITE, 0.15)
	await tw.finished


## Hace titilar el casillero del cuaderno (cuando el viejo se lo entrega a Nuna en la intro).
func resaltar_cuaderno() -> void:
	if not is_instance_valid(_casillero_cuaderno):
		return
	var tw := create_tween()
	for i in 4:
		tw.tween_property(_casillero_cuaderno, "modulate", Color(2.2, 2.2, 2.2), 0.18)
		tw.tween_property(_casillero_cuaderno, "modulate", Color.WHITE, 0.18)
	await tw.finished


func establecer_acciones_habilitadas(habilitadas: bool) -> void:
	_acciones_habilitadas = habilitadas
	_actualizar_opciones()


func mostrar_dialogo(texto: String, id: int) -> void:
	_id_dialogo_actual = id
	_dialogo_activo = true
	_certificacion_activa = false
	_letra_chica.visible = false
	_verbos.visible = false  # la frase puede ocupar dos líneas
	_actualizar_layout_consola()
	_linea.visible = true
	_linea.text = texto
	_actualizar_opciones()


func finalizar_dialogo(id: int) -> void:
	if id == _id_dialogo_actual:
		call_deferred("_finalizar_dialogo_diferido", id)


func mostrar_certificacion(
	etiqueta: String,
	letra_chica: String,
	segundos: float = Ajustes.UI_CONSOLA_DURACION_CERTIFICACION_MIN_SEGUNDOS
) -> void:
	if _certificacion_activa:
		push_warning("Ya hay una certificación visible en la consola.")
		return
	var pausa_previa: bool = Globals.pausado
	_certificacion_activa = true
	_dialogo_activo = false
	_id_dialogo_actual = -1
	_actualizar_layout_consola()
	_linea.visible = true
	_linea.text = etiqueta
	_linea.add_theme_font_size_override("font_size", Ajustes.UI_CONSOLA_DIALOGO_FUENTE)
	_letra_chica.text = letra_chica
	_letra_chica.visible = true
	_verbos.visible = false
	_actualizar_opciones()
	Globals.pausado = true
	await get_tree().create_timer(
		maxf(segundos, Ajustes.UI_CONSOLA_DURACION_CERTIFICACION_MIN_SEGUNDOS)
	).timeout
	Globals.pausado = pausa_previa
	_certificacion_activa = false
	_letra_chica.visible = false
	if _hay_objeto_seleccionado:
		_verbos.visible = true
		_refrescar_linea()
	else:
		_verbos.visible = false
		_texto_base = _texto_guia
		_refrescar_linea()
	_actualizar_layout_consola()
	_actualizar_opciones()


func _finalizar_dialogo_diferido(id: int) -> void:
	if id != _id_dialogo_actual or _certificacion_activa:
		return
	_dialogo_activo = false
	_id_dialogo_actual = -1
	_letra_chica.visible = false
	if not _hay_objeto_seleccionado:
		_texto_base = _texto_guia
	_refrescar_linea()
	_actualizar_layout_consola()
	_actualizar_opciones()


func _emitir_accion(verbo: StringName) -> void:
	if _hay_objeto_seleccionado and _acciones_habilitadas and not _dialogo_activo:
		accion_elegida.emit(verbo)


func _actualizar_prefijo(verbo: StringName, esta_sobre: bool) -> void:
	_opciones_hover[verbo] = esta_sobre
	_actualizar_opciones()


func _actualizar_opciones() -> void:
	for verbo in ACCIONES:
		var boton: Button = _botones[verbo]
		var disponible: bool = _hay_objeto_seleccionado and _acciones_disponibles.get(verbo, false)
		boton.visible = disponible and _verbos.visible
		boton.disabled = not _acciones_habilitadas or _dialogo_activo or _certificacion_activa
		var texto: Label = _textos_opciones[verbo]
		var prefijo: Label = _prefijos_opciones[verbo]
		if boton.disabled:
			texto.add_theme_color_override("font_color", COLOR_DESACTIVADO)
			prefijo.add_theme_color_override("font_color", COLOR_DESACTIVADO)
		else:
			texto.add_theme_color_override("font_color", Color.WHITE)
			var color_prefijo: Color = Color.WHITE if _opciones_hover[verbo] else COLOR_TEXTO_SECUNDARIO
			prefijo.add_theme_color_override("font_color", color_prefijo)


# ---------- Construcción ----------

func _crear_hud_superior() -> void:
	var hud := ColorRect.new()
	hud.position = Ajustes.UI_HUD_POS
	hud.size = Ajustes.UI_HUD_TAMANO
	hud.color = Ajustes.UI_HUD_FONDO
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.z_index = 10
	_aplicar_fuente(hud, _fuente_hud)
	_hud = hud

	var etiqueta_inventario := _crear_label("INVENTARIO", Ajustes.UI_HUD_FUENTE)
	etiqueta_inventario.position = Ajustes.UI_HUD_INVENTARIO_ETIQUETA_POS
	etiqueta_inventario.size = Ajustes.UI_HUD_INVENTARIO_ETIQUETA_TAMANO
	etiqueta_inventario.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud.add_child(etiqueta_inventario)

	var etiqueta_sellos := _crear_label("SELLOS", Ajustes.UI_HUD_FUENTE)
	etiqueta_sellos.position = Ajustes.UI_HUD_SELLOS_ETIQUETA_POS
	etiqueta_sellos.size = Ajustes.UI_HUD_SELLOS_ETIQUETA_TAMANO
	etiqueta_sellos.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud.add_child(etiqueta_sellos)

	var casilleros_sellos := HBoxContainer.new()
	casilleros_sellos.position = Ajustes.UI_HUD_SELLOS_POS
	casilleros_sellos.size = Ajustes.UI_HUD_SELLOS_TAMANO
	casilleros_sellos.add_theme_constant_override("separation", Ajustes.UI_HUD_SELLO_SEPARACION)
	casilleros_sellos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aplicar_fuente(casilleros_sellos, _fuente_hud)
	for i in Globals.SELLOS_TOTALES:
		var borde := ColorRect.new()
		borde.color = COLOR_BORDE_SELLO
		borde.custom_minimum_size = Ajustes.UI_HUD_SELLO_TAMANO
		borde.size = Ajustes.UI_HUD_SELLO_TAMANO
		borde.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_aplicar_fuente(borde, _fuente_hud)
		var relleno := ColorRect.new()
		relleno.position = Vector2.ONE * Ajustes.UI_HUD_BORDE_SELLO
		relleno.size = Ajustes.UI_HUD_SELLO_TAMANO - Vector2.ONE * Ajustes.UI_HUD_BORDE_SELLO * 2.0
		relleno.color = COLOR_SELLO_VACIO
		relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_aplicar_fuente(relleno, _fuente_hud)
		borde.add_child(relleno)
		casilleros_sellos.add_child(borde)
		_sellos_hud.append(relleno)
	hud.add_child(casilleros_sellos)

	_inventario_visual = _crear_inventario()
	_inventario_visual.position = Ajustes.UI_HUD_INVENTARIO_POS
	_inventario_visual.size = Ajustes.UI_HUD_INVENTARIO_TAMANO
	hud.add_child(_inventario_visual)

	var etiqueta_bruma := _crear_label("BRUMA", Ajustes.UI_HUD_FUENTE)
	etiqueta_bruma.position = Ajustes.UI_HUD_BRUMA_ETIQUETA_POS
	etiqueta_bruma.size = Ajustes.UI_HUD_BRUMA_ETIQUETA_TAMANO
	etiqueta_bruma.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud.add_child(etiqueta_bruma)
	_etiqueta_bruma = etiqueta_bruma
	_bruma = ProgressBar.new()
	_bruma.min_value = 0
	_bruma.max_value = 100
	_bruma.show_percentage = false
	_bruma.custom_minimum_size = Ajustes.UI_HUD_BARRA_TAMANO
	_bruma.position = Ajustes.UI_HUD_BRUMA_POS
	_bruma.size = Ajustes.UI_HUD_BARRA_TAMANO
	_bruma.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aplicar_fuente(_bruma, _fuente_hud)
	var fondo_bruma := StyleBoxFlat.new()
	fondo_bruma.bg_color = COLOR_CASILLERO
	var relleno_bruma := StyleBoxFlat.new()
	relleno_bruma.bg_color = COLOR_BRUMA
	_bruma.add_theme_stylebox_override("background", fondo_bruma)
	_bruma.add_theme_stylebox_override("fill", relleno_bruma)
	hud.add_child(_bruma)

	var etiqueta_miedo := _crear_label("MIEDO", Ajustes.UI_HUD_FUENTE)
	etiqueta_miedo.position = Ajustes.UI_HUD_MIEDO_ETIQUETA_POS
	etiqueta_miedo.size = Ajustes.UI_HUD_MIEDO_ETIQUETA_TAMANO
	etiqueta_miedo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud.add_child(etiqueta_miedo)
	_vela = ProgressBar.new()
	_vela.min_value = 0
	_vela.max_value = Ajustes.VELA_MAXIMA
	_vela.show_percentage = false
	_vela.custom_minimum_size = Ajustes.UI_HUD_BARRA_TAMANO
	_vela.position = Ajustes.UI_HUD_MIEDO_POS
	_vela.size = Ajustes.UI_HUD_BARRA_TAMANO
	_vela.mouse_filter = Control.MOUSE_FILTER_PASS
	_vela.mouse_entered.connect(_hover_vela)
	_vela.mouse_exited.connect(_poner_hover.bind(""))
	_aplicar_fuente(_vela, _fuente_hud)
	var fondo_vela := StyleBoxFlat.new()
	fondo_vela.bg_color = COLOR_CASILLERO
	var relleno_vela := StyleBoxFlat.new()
	relleno_vela.bg_color = COLOR_MIEDO
	_vela.add_theme_stylebox_override("background", fondo_vela)
	_vela.add_theme_stylebox_override("fill", relleno_vela)
	hud.add_child(_vela)
	add_child(hud)


func _crear_consola_inferior() -> void:
	# La consola ocupa y=148–180. Verificar filtraciones antes de modificar el límite lógico UI_Y.
	_consola = ColorRect.new()
	_consola.position = Ajustes.UI_CONSOLA_EXPANDIDA_POS
	_consola.size = Ajustes.UI_CONSOLA_EXPANDIDA_TAMANO
	_consola.color = COLOR_CONSOLA
	_consola.mouse_filter = Control.MOUSE_FILTER_STOP
	_consola.z_index = 20

	var borde_superior := ColorRect.new()
	borde_superior.size = Vector2(
		Ajustes.UI_CONSOLA_EXPANDIDA_TAMANO.x,
		Ajustes.UI_CONSOLA_BORDE_SUPERIOR_ALTO
	)
	borde_superior.color = Color(0.28, 0.28, 0.32)
	borde_superior.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_consola.add_child(borde_superior)

	_linea = _crear_label("", Ajustes.UI_CONSOLA_FUENTE)
	_linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_linea.position = Ajustes.UI_CONSOLA_TEXTO_POS
	_linea.size = Ajustes.UI_CONSOLA_TEXTO_TAMANO
	_linea.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_linea.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_linea.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_linea.max_lines_visible = 2
	_linea.add_theme_font_size_override("font_size", Ajustes.UI_CONSOLA_DIALOGO_FUENTE)
	_linea.add_theme_constant_override("line_spacing", -4)
	_aplicar_fuente(_linea, _fuente_dialogo)
	_consola.add_child(_linea)

	_letra_chica = _crear_label("", Ajustes.UI_CONSOLA_LETRA_CHICA_FUENTE)
	_letra_chica.position = Ajustes.UI_CONSOLA_LETRA_CHICA_POS
	_letra_chica.size = Ajustes.UI_CONSOLA_LETRA_CHICA_TAMANO
	_letra_chica.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_letra_chica.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_letra_chica.add_theme_color_override("font_color", COLOR_TEXTO_SECUNDARIO)
	_aplicar_fuente(_letra_chica, _fuente_hud)
	_letra_chica.visible = false
	_consola.add_child(_letra_chica)

	_verbos = _crear_verbos()
	_verbos.position = Ajustes.UI_CONSOLA_OPCIONES_POS
	_verbos.size = Ajustes.UI_CONSOLA_OPCIONES_TAMANO
	_verbos.visible = false
	_consola.add_child(_verbos)
	add_child(_consola)


func _crear_verbos() -> HBoxContainer:
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", int(Ajustes.UI_CONSOLA_SEPARACION_ACCIONES))
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(ACCIONES.size()):
		var verbo: StringName = ACCIONES[i]
		var b := Button.new()
		b.text = ""
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(Ajustes.UI_CONSOLA_ACCION_ANCHO, Ajustes.UI_CONSOLA_OPCIONES_TAMANO.y)
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_disabled_color", COLOR_DESACTIVADO)
		_aplicar_fuente(b, _fuente_hud)
		var estilo_transparente := _crear_estilo_boton(Color(0, 0, 0, 0))
		b.add_theme_stylebox_override("normal", estilo_transparente)
		b.add_theme_stylebox_override("hover", estilo_transparente)
		b.add_theme_stylebox_override("pressed", estilo_transparente)
		b.add_theme_stylebox_override("hover_pressed", estilo_transparente)
		b.add_theme_stylebox_override("disabled", estilo_transparente)
		b.add_theme_stylebox_override("focus", estilo_transparente)

		var contenido := HBoxContainer.new()
		contenido.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		contenido.add_theme_constant_override(
			"separation",
			int(Ajustes.UI_CONSOLA_SEPARACION_CONTENIDO_ACCION)
		)
		contenido.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var prefijo := _crear_label(">", 8)
		prefijo.custom_minimum_size = Vector2(
			Ajustes.UI_CONSOLA_ACCION_PREFIJO_ANCHO,
			Ajustes.UI_CONSOLA_OPCIONES_TAMANO.y
		)
		prefijo.add_theme_color_override("font_color", COLOR_TEXTO_SECUNDARIO)
		contenido.add_child(prefijo)
		var texto := _crear_label(
			"(%d) %s" % [i + 1, String(Globals.NOMBRES_VERBOS[verbo]).to_upper()],
			Ajustes.UI_CONSOLA_FUENTE
		)
		texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		contenido.add_child(texto)
		b.add_child(contenido)

		b.pressed.connect(_emitir_accion.bind(verbo))
		b.mouse_entered.connect(_actualizar_prefijo.bind(verbo, true))
		b.mouse_exited.connect(_actualizar_prefijo.bind(verbo, false))
		caja.add_child(b)
		_botones[verbo] = b
		_prefijos_opciones[verbo] = prefijo
		_textos_opciones[verbo] = texto
		_opciones_hover[verbo] = false
	return caja


func _crear_estilo_boton(fondo: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.set_border_width_all(0)
	estilo.set_content_margin_all(0)
	estilo.set_content_margin(SIDE_LEFT, 2)
	estilo.set_content_margin(SIDE_RIGHT, 2)
	return estilo


func _crear_inventario() -> HBoxContainer:
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", Ajustes.UI_HUD_CASILLERO_SEPARACION)
	caja.custom_minimum_size = Ajustes.UI_HUD_INVENTARIO_TAMANO
	caja.size = Ajustes.UI_HUD_INVENTARIO_TAMANO
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aplicar_fuente(caja, _fuente_hud)
	for i in range(CASILLEROS + 1):
		var es_cuaderno: bool = i == 0
		var casillero := ColorRect.new()
		casillero.color = COLOR_CASILLERO
		casillero.custom_minimum_size = Ajustes.UI_HUD_CASILLERO_TAMANO
		casillero.size = Ajustes.UI_HUD_CASILLERO_TAMANO
		casillero.mouse_filter = Control.MOUSE_FILTER_STOP
		_aplicar_fuente(casillero, _fuente_hud)
		if es_cuaderno:
			_casillero_cuaderno = casillero
			casillero.mouse_entered.connect(_hover_cuaderno)
		else:
			casillero.mouse_entered.connect(_hover_casillero.bind(i - 1))
			casillero.gui_input.connect(_seleccionar_inventario.bind(i - 1))
			var letra := _crear_label("", 8)
			letra.set_anchors_preset(Control.PRESET_FULL_RECT)
			letra.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_aplicar_fuente(letra, _fuente_hud)
			casillero.add_child(letra)
			_casilleros.append(letra)
		if es_cuaderno:
			var letra_cuaderno := _crear_label("C", 8)
			letra_cuaderno.set_anchors_preset(Control.PRESET_FULL_RECT)
			letra_cuaderno.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_aplicar_fuente(letra_cuaderno, _fuente_hud)
			casillero.add_child(letra_cuaderno)
		casillero.mouse_exited.connect(_poner_hover.bind(""))
		caja.add_child(casillero)
	return caja


func _crear_label(texto: String, tam: int) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aplicar_fuente(l, _fuente_hud)
	return l


func _aplicar_fuente(control: Control, fuente: Font) -> void:
	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if fuente != null:
		control.add_theme_font_override("font", fuente)


func _cargar_fuente(ruta: String) -> Font:
	var fuente: Font = null
	if ResourceLoader.exists(ruta):
		fuente = load(ruta) as Font
	if fuente != null:
		return fuente
	push_warning("No se encontró la fuente '%s'; se intentará usar el fallback." % ruta)
	if _fuente_fallback == null:
		if ResourceLoader.exists(Ajustes.UI_FUENTE_FALLBACK):
			_fuente_fallback = load(Ajustes.UI_FUENTE_FALLBACK) as Font
	if _fuente_fallback == null and not _aviso_fallback_emitido:
		push_warning(
			"No se encontró la fuente fallback '%s'; se usará la fuente predeterminada de Godot."
			% Ajustes.UI_FUENTE_FALLBACK
		)
		_aviso_fallback_emitido = true
	return _fuente_fallback


# ---------- Actualización ----------

func _actualizar_inventario() -> void:
	var inventario := Globals.obtener_inventario()
	for i in _casilleros.size():
		if i < inventario.size():
			_casilleros[i].text = Globals.nombre_objeto(inventario[i]).left(1)
		else:
			_casilleros[i].text = ""


func _actualizar_sellos(cantidad: int) -> void:
	for i in _sellos_hud.size():
		_sellos_hud[i].color = COLOR_SELLO_LLENO if i < cantidad else COLOR_SELLO_VACIO
	for i in _sellos_cuaderno.size():
		_sellos_cuaderno[i].color = COLOR_SELLO_LLENO if i < cantidad else COLOR_SELLO_VACIO


func _actualizar_bruma(valor: float) -> void:
	_bruma.value = valor


func _actualizar_vela(habitacion_id: StringName, valor: float) -> void:
	if habitacion_id == Ajustes.LUMI_HABITACION_ID:
		_vela.value = valor


# ---------- Línea de acción y hover ----------

func _poner_hover(texto: String) -> void:
	if _dialogo_activo or _hay_objeto_seleccionado:
		return
	_texto_hover = texto
	_refrescar_linea()


func _hover_casillero(i: int) -> void:
	var inventario := Globals.obtener_inventario()
	if i < inventario.size():
		_poner_hover(Globals.nombre_objeto(inventario[i]))
	else:
		_poner_hover("")


func _seleccionar_inventario(event: InputEvent, indice: int) -> void:
	if G.is_blocked or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		I.set_active_item(null)
	elif event.button_index == MOUSE_BUTTON_LEFT:
		var inventario := Globals.obtener_inventario()
		if indice < inventario.size():
			I.set_active_item(I.get_item_instance(String(inventario[indice]).to_pascal_case()))


func _hover_cuaderno() -> void:
	_poner_hover("Cuaderno de certificación")


func _hover_vela() -> void:
	_poner_hover(Ajustes.UI_HUD_TEXTO_HOVER_MIEDO)


func _refrescar_linea() -> void:
	if _dialogo_activo or _certificacion_activa:
		return
	var t: String = _texto_hover if _texto_hover != "" else _texto_base
	if _linea.text != t:
		_linea.text = t


func _actualizar_layout_consola() -> void:
	var expandida: bool = _hay_objeto_seleccionado or _dialogo_activo or _certificacion_activa
	# El fondo negro ocupa siempre toda la franja inferior: así nunca queda gris debajo del cuarto.
	_consola.position = Ajustes.UI_CONSOLA_EXPANDIDA_POS
	_consola.size = Ajustes.UI_CONSOLA_EXPANDIDA_TAMANO
	if expandida:
		_linea.position = Ajustes.UI_CONSOLA_TEXTO_POS
		_linea.size = Ajustes.UI_CONSOLA_TEXTO_TAMANO
	else:
		# Sin nada seleccionado, la guía queda centrada en la franja.
		_linea.position = Vector2(
			Ajustes.UI_CONSOLA_TEXTO_POS.x,
			floorf((Ajustes.UI_CONSOLA_EXPANDIDA_TAMANO.y - Ajustes.UI_CONSOLA_TEXTO_COMPACTO_TAMANO.y) / 2.0)
		)
		_linea.size = Ajustes.UI_CONSOLA_TEXTO_COMPACTO_TAMANO
	_verbos.visible = _hay_objeto_seleccionado and not _certificacion_activa and not _dialogo_activo
