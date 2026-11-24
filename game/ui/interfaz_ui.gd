class_name InterfazUI
extends CanvasLayer
## HUD superior y consola inferior de la habitación.
## Los controles se construyen por código.

signal accion_elegida(verbo: StringName)
signal _clic_en_tapa

const CASILLEROS: int = 3  # + el cuaderno = 4 casilleros a la vista
## El inventario va un poco más a la derecha; a su izquierda, el engranaje del sonido.
const POS_INVENTARIO := Vector2(20.0, 18.0)
const POS_ENGRANAJE := Vector2(5.0, 18.0)
## Engranaje de 11x11 dibujado pixel a pixel (# = claro, . = transparente).
const DIBUJO_ENGRANAJE := [
	"....###....",
	".#..###..#.",
	".#########.",
	"..#######..",
	".###...###.",
	"####...####",
	".###...###.",
	"..#######..",
	".#########.",
	".#..###..#.",
	"....###....",
]
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
## Lo que cuenta cada objeto en el inventario abierto (si no está acá, solo se ve el nombre).
const DESCRIPCIONES := {
	"dentadura": "La sonrisa de Ofelia. Sonríe sola. Capaz le sirve a alguien que se olvidó de sonreír.",
	"ovillo": "Ovi. Un escalón de lana.",
	"cuaderno": "Sellos, habilidades y todo lo que anoto. [ABRIR] para verlo.",
	"llave_101": "La llave de la 101. Hay que colgarla al volver.",
	"llave_202": "La llave de la 202. Si la pierdo, se descuenta de mi Bruma.",
	"ratoncito": "El Ratoncito Inquieto de Bruno. Hace como que trabaja.",
	"delineador": "El delineador de Vale. Algo voy a tener que escribir con esto.",
}
const TOMA_CUADERNO := "res://arte/tomas/toma_cuaderno.png"
## Fila de Posesión en toma_cuaderno.png (para escribir "aprobada" cuando corresponde).
const POS_POSESION_APROBADA := Vector2(196, 69)
const COLOR_PANEL := Color(0.0, 0.0, 0.0, 1.0)
const COLOR_PANEL_BORDE := Color.WHITE
const COLOR_FILA_ELEGIDA := Color(0.62, 0.48, 0.88)
## Sonido: un bus para las voces (los pips de Nuna y del viejo) y el timbre.
## La música (y el grito) salen por el bus "Retro" de Musica.
const BUS_VOCES := "Voces"
const NIVELES_DB: Array[float] = [-80.0, -24.0, -18.0, -12.0, -6.0, 0.0]
const NIVEL_MUSICA_INICIAL := 5
const NIVEL_VOCES_INICIAL := 3  # más bajo que antes: el timbre y la voz del viejo sonaban fuerte
const RUTA_SONIDO := "user://sonido.cfg"
## Nombres de los nodos que suenan como "voces y timbre".
const NODOS_DE_VOZ: Array[String] = ["VozNuna", "SonidoTimbre"]

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
## Sellos a medio llenar (la 202: perturbar llena la mitad, poseer la completa).
var _medios_sellos: int = 0
var _mitades_hud: Array[ColorRect] = []
## Inventario abierto (se abre al tocar un casillero o la palabra INVENTARIO).
var _panel_inventario: Control
var _inventario_elegido: int = -1
var _iconos: Array[TextureRect] = []
var _texturas_extra: Dictionary = {}
var _cuaderno_abierto := false
var _panel_credito: Control
## Cartelito que sigue al mouse mientras hay un objeto del inventario en la mano.
var _etiqueta_en_mano: Label
## Volumen.
var _panel_sonido: Control
var _nivel_musica := NIVEL_MUSICA_INICIAL
var _nivel_voces := NIVEL_VOCES_INICIAL


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
	Globals.sin_bruma.connect(_ofrecer_credito)
	_actualizar_inventario()
	_actualizar_sellos(Globals.sellos)
	_actualizar_bruma(Globals.bruma)
	_actualizar_vela(Ajustes.LUMI_HABITACION_ID, Globals.vela_de(Ajustes.LUMI_HABITACION_ID))
	_crear_etiqueta_en_mano()
	_cargar_sonido()
	get_tree().node_added.connect(_al_agregar_nodo)
	_enrutar_voces_existentes.call_deferred()


# ---------- Lo que llama la habitación ----------

func mostrar_accion(texto: String) -> void:
	_texto_base = texto
	_refrescar_linea()


func mostrar_exploracion() -> void:
	renombrar_accion(Globals.PERTURBAR, "")
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


## Cambia el nombre que se ve de un verbo (en la 202, "Perturbar" pasa a "Poseer"
## sobre los objetos que se pueden poseer). Texto vacío = el nombre de siempre.
func renombrar_accion(verbo: StringName, texto: String) -> void:
	if not _textos_opciones.has(verbo):
		return
	var nombre := texto if not texto.is_empty() else String(Globals.NOMBRES_VERBOS[verbo])
	_textos_opciones[verbo].text = "(%d) %s" % [ACCIONES.find(verbo) + 1, nombre.to_upper()]


## Cuántos casilleros de sello se ven llenos hasta la mitad (además de los enteros).
func mostrar_medios_sellos(cantidad: int) -> void:
	_medios_sellos = cantidad
	_actualizar_sellos(Globals.sellos)


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
	Globals.anotar(etiqueta)
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
	etiqueta_inventario.position = Vector2(POS_INVENTARIO.x, Ajustes.UI_HUD_INVENTARIO_ETIQUETA_POS.y)
	etiqueta_inventario.size = Ajustes.UI_HUD_INVENTARIO_ETIQUETA_TAMANO
	etiqueta_inventario.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# La palabra INVENTARIO también abre el inventario.
	etiqueta_inventario.size.x = 46.0
	etiqueta_inventario.mouse_filter = Control.MOUSE_FILTER_STOP
	etiqueta_inventario.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	etiqueta_inventario.gui_input.connect(func (event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			abrir_inventario(-1)
	)
	etiqueta_inventario.mouse_entered.connect(_poner_hover.bind("Abrir el inventario"))
	etiqueta_inventario.mouse_exited.connect(_poner_hover.bind(""))
	hud.add_child(etiqueta_inventario)

	# Botón de volumen: un engranaje a la izquierda del inventario.
	var boton_sonido := TextureRect.new()
	boton_sonido.texture = _crear_engranaje()
	boton_sonido.position = POS_ENGRANAJE
	boton_sonido.size = Vector2(12.0, 12.0)
	boton_sonido.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	boton_sonido.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boton_sonido.modulate = COLOR_TEXTO_SECUNDARIO
	boton_sonido.mouse_filter = Control.MOUSE_FILTER_STOP
	boton_sonido.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	boton_sonido.gui_input.connect(func (event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			abrir_sonido()
	)
	boton_sonido.mouse_entered.connect(func ():
		boton_sonido.modulate = Color.WHITE
		_poner_hover("Sonido: volumen de la música, las voces y el timbre")
	)
	boton_sonido.mouse_exited.connect(func ():
		boton_sonido.modulate = COLOR_TEXTO_SECUNDARIO
		_poner_hover("")
	)
	hud.add_child(boton_sonido)

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
		var mitad := ColorRect.new()
		mitad.size = Vector2(floorf(relleno.size.x / 2.0), relleno.size.y)
		mitad.color = COLOR_SELLO_LLENO
		mitad.visible = false
		mitad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		relleno.add_child(mitad)
		_mitades_hud.append(mitad)
		casilleros_sellos.add_child(borde)
		_sellos_hud.append(relleno)
	hud.add_child(casilleros_sellos)

	_inventario_visual = _crear_inventario()
	_inventario_visual.position = POS_INVENTARIO
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
	_bruma.mouse_filter = Control.MOUSE_FILTER_PASS
	_bruma.mouse_entered.connect(_hover_bruma)
	_bruma.mouse_exited.connect(_poner_hover.bind(""))
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
	borde_superior.color = COLOR_CONSOLA  # negro, igual que la consola (antes era una línea gris)
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
	var ancho := (CASILLEROS + 1) * Ajustes.UI_HUD_CASILLERO_TAMANO.x + CASILLEROS * Ajustes.UI_HUD_CASILLERO_SEPARACION
	caja.custom_minimum_size = Vector2(ancho, Ajustes.UI_HUD_INVENTARIO_TAMANO.y)
	caja.size = caja.custom_minimum_size
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
		casillero.gui_input.connect(_seleccionar_inventario.bind(i))
		casillero.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if es_cuaderno:
			_casillero_cuaderno = casillero
			casillero.mouse_entered.connect(_hover_cuaderno)
		else:
			casillero.mouse_entered.connect(_hover_casillero.bind(i))
			var letra := _crear_label("", 8)
			letra.set_anchors_preset(Control.PRESET_FULL_RECT)
			letra.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_aplicar_fuente(letra, _fuente_hud)
			casillero.add_child(letra)
			_casilleros.append(letra)
			# Dibujito del objeto (si tiene); si no, queda la inicial.
			var icono := TextureRect.new()
			icono.set_anchors_preset(Control.PRESET_FULL_RECT)
			icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
			casillero.add_child(icono)
			_iconos.append(icono)
			casillero.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if es_cuaderno:
			# El dibujito del cuaderno (arte/objetos/cuaderno.png); sin dibujo, la letra C.
			var textura_cuaderno := _textura_de(&"cuaderno")
			if textura_cuaderno != null:
				var icono_cuaderno := TextureRect.new()
				icono_cuaderno.set_anchors_preset(Control.PRESET_FULL_RECT)
				icono_cuaderno.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
				icono_cuaderno.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				icono_cuaderno.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icono_cuaderno.texture = textura_cuaderno
				casillero.add_child(icono_cuaderno)
			else:
				var letra_cuaderno := _crear_label("C", 8)
				letra_cuaderno.set_anchors_preset(Control.PRESET_FULL_RECT)
				letra_cuaderno.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_aplicar_fuente(letra_cuaderno, _fuente_hud)
				casillero.add_child(letra_cuaderno)
		casillero.mouse_exited.connect(_poner_hover.bind(""))
		caja.add_child(casillero)
	return caja


func _crear_engranaje() -> ImageTexture:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in DIBUJO_ENGRANAJE.size():
		var fila: String = DIBUJO_ENGRANAJE[y]
		for x in fila.length():
			if fila[x] == "#":
				img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)


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
	# El casillero 0 es el cuaderno; los demás muestran lo que sigue en la lista.
	var inventario := Globals.inventario_visible().slice(1)
	# Si hay más cosas que casilleros, el último muestra "+": abre el inventario con todo.
	var sobran := inventario.size() > _casilleros.size()
	for i in _casilleros.size():
		var textura: Texture2D = null
		if sobran and i == _casilleros.size() - 1:
			_casilleros[i].text = "+%d" % (inventario.size() - i)
		elif i < inventario.size():
			textura = _textura_de(inventario[i])
			_casilleros[i].text = "" if textura != null else Globals.nombre_objeto(inventario[i]).left(1)
		else:
			_casilleros[i].text = ""
		if i < _iconos.size():
			_iconos[i].texture = textura


func _actualizar_sellos(cantidad: int) -> void:
	for i in _sellos_hud.size():
		_sellos_hud[i].color = COLOR_SELLO_LLENO if i < cantidad else COLOR_SELLO_VACIO
		if i < _mitades_hud.size():
			_mitades_hud[i].visible = i >= cantidad and i < _medios_sellos
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
	var inventario := Globals.inventario_visible()
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
		# Abre el inventario con ese objeto elegido (0 = el cuaderno).
		if indice < Globals.inventario_visible().size():
			abrir_inventario(indice)
		else:
			abrir_inventario(-1)


func _hover_cuaderno() -> void:
	_poner_hover("Cuaderno de certificación (clic para abrir el inventario)")


func _hover_bruma() -> void:
	var texto := "Bruma: %d" % int(Globals.bruma)
	if Globals.deuda > 0.0:
		texto += " · Deuda con la empresa: %d" % int(Globals.deuda)
	_poner_hover(texto)


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


# ---------- Inventario abierto ----------

## Abre el inventario. [param indice] es el objeto que queda elegido (-1: el primero).
func abrir_inventario(indice: int = -1) -> void:
	if G.is_blocked and not is_instance_valid(_panel_inventario):
		return
	cerrar_inventario()
	cerrar_sonido()
	I.set_active_item(null)
	var inventario := Globals.inventario_visible()
	# Sin indicar, queda elegido el primer objeto que no es el cuaderno (si hay).
	if indice < 0:
		indice = 1 if inventario.size() > 1 else 0
	_inventario_elegido = clampi(indice, 0, inventario.size() - 1)
	# El fondo oscuro tapa los clics del cuarto mientras está abierto.
	_panel_inventario = _crear_ventana("INVENTARIO", Vector2(200.0, 128.0))
	_llenar_inventario()


func cerrar_inventario() -> void:
	if is_instance_valid(_panel_inventario):
		_panel_inventario.queue_free()
		_panel_inventario = null


func _llenar_inventario() -> void:
	var caja: VBoxContainer = _panel_inventario.get_meta("contenido")
	for hijo in caja.get_children():
		hijo.queue_free()
	var inventario := Globals.inventario_visible()
	if inventario.size() <= 1:
		caja.add_child(_crear_texto_panel("Solo el cuaderno. La empresa no da insumos.", COLOR_TEXTO_SECUNDARIO))
	for i in inventario.size():
		var id: StringName = inventario[i]
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 4)
		fila.mouse_filter = Control.MOUSE_FILTER_STOP
		fila.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var icono := TextureRect.new()
		icono.custom_minimum_size = Vector2(12, 12)
		icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icono.texture = _textura_de(id)
		icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fila.add_child(icono)
		var nombre := _crear_texto_panel(("> " if i == _inventario_elegido else "  ") + Globals.nombre_objeto(id),
				COLOR_FILA_ELEGIDA if i == _inventario_elegido else Color.WHITE)
		fila.add_child(nombre)
		fila.gui_input.connect(func (event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_inventario_elegido = i
				_llenar_inventario()
		)
		caja.add_child(fila)
	if _inventario_elegido >= 0 and _inventario_elegido < inventario.size():
		var id_elegido: StringName = inventario[_inventario_elegido]
		var texto: String = DESCRIPCIONES.get(String(id_elegido), "")
		if not texto.is_empty():
			var descripcion := _crear_texto_panel(texto, COLOR_TEXTO_SECUNDARIO)
			descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			descripcion.custom_minimum_size = Vector2(188, 0)
			caja.add_child(descripcion)
	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 8)
	if _inventario_elegido >= 0 and _inventario_elegido < inventario.size():
		var id_boton: StringName = inventario[_inventario_elegido]
		if id_boton == &"cuaderno":
			botones.add_child(_crear_boton_panel("ABRIR", abrir_cuaderno))
		botones.add_child(_crear_boton_panel("MIRAR", _mirar_elegido))
		if not Globals.es_extra(id_boton):
			botones.add_child(_crear_boton_panel("USAR", _usar_elegido))
		elif id_boton != &"cuaderno" and is_instance_valid(R.current) and R.current.has_method("usar_extra"):
			# Los extras (delineador, Flacozem…) se usan solo en las salas que saben qué hacer con ellos.
			botones.add_child(_crear_boton_panel("USAR", _usar_elegido))
	botones.add_child(_crear_boton_panel("CERRAR", cerrar_inventario))
	caja.add_child(botones)


## "Usar": el objeto queda en la mano. El próximo clic sobre algo del cuarto lo usa ahí.
func _usar_elegido() -> void:
	var inventario := Globals.inventario_visible()
	if _inventario_elegido < 0 or _inventario_elegido >= inventario.size():
		return
	if Globals.es_extra(inventario[_inventario_elegido]):
		Globals.extra_activo = String(inventario[_inventario_elegido])
		cerrar_inventario()
		establecer_guia("Hacé clic donde quieras usar: %s." % Globals.nombre_objeto(inventario[_inventario_elegido]))
		return
	var item := I.get_item_instance(String(inventario[_inventario_elegido]).to_pascal_case())
	cerrar_inventario()
	I.set_active_item(item)


func _textura_de(id: StringName) -> Texture2D:
	if Globals.es_extra(id):
		var ruta: String = Globals.EXTRAS[String(id)].textura
		if not _texturas_extra.has(ruta):
			_texturas_extra[ruta] = load(ruta) if ResourceLoader.exists(ruta) else null
		return _texturas_extra[ruta]
	var item = I.get_item_instance(String(id).to_pascal_case())
	if item is TextureRect:
		return item.texture
	return null


## "Mirar": Nuna dice algo del objeto.
func _mirar_elegido() -> void:
	var inventario := Globals.inventario_visible()
	if _inventario_elegido < 0 or _inventario_elegido >= inventario.size():
		return
	var id: StringName = inventario[_inventario_elegido]
	var frase: String = Globals.frase_mirar_extra(id)
	if frase.is_empty():
		frase = DESCRIPCIONES.get(String(id), "Mi %s." % Globals.nombre_objeto(id).to_lower())
	if id == &"cuaderno" and not Globals.notas.is_empty():
		frase += " La última nota dice: «%s»" % Globals.notas[-1]
	cerrar_inventario()
	if not is_instance_valid(C.player):
		return
	G.block()
	await C.player.say(frase)
	G.unblock()


# ---------- El cuaderno abierto ----------

## Muestra el cuaderno (la misma toma de la recepción) en el cuadro que corresponde.
## Se cierra con un clic.
func abrir_cuaderno() -> void:
	cerrar_inventario()
	if _cuaderno_abierto or not ResourceLoader.exists(TOMA_CUADERNO) or not is_instance_valid(R.current):
		return
	_cuaderno_abierto = true
	G.block()
	var pausa_previa: bool = Globals.pausado
	Globals.pausado = true
	var recepcion: Resource = load("res://game/rooms/recepcion/room_recepcion.tres")
	var perturbacion_ok: bool = recepcion != null and recepcion.get("cinematica_2") == true
	var posesion_ok: bool = recepcion != null and recepcion.get("cinematica_3") == true
	var cuadro := 2 if perturbacion_ok else (1 if Globals.sellos >= Globals.SELLOS_TOTALES else 0)
	var toma := await Toma.mostrar(R.current, TOMA_CUADERNO, cuadro)
	if posesion_ok:
		var aprobada := _crear_texto_panel("aprobada (beta)", Color8(34, 32, 52))
		aprobada.position = POS_POSESION_APROBADA
		toma.add_child(aprobada)
	establecer_guia("Tu cuaderno. Clic para cerrarlo.")
	# Un clic en cualquier lado lo cierra.
	var tapa := Control.new()
	tapa.set_anchors_preset(Control.PRESET_FULL_RECT)
	tapa.size = Vector2(320, 180)
	tapa.mouse_filter = Control.MOUSE_FILTER_STOP
	tapa.z_index = 40
	add_child(tapa)
	await _esperar_clic(tapa)
	tapa.queue_free()
	await toma.cerrar()
	establecer_guia("")
	Globals.pausado = pausa_previa
	G.unblock()
	_cuaderno_abierto = false


func _esperar_clic(tapa: Control) -> void:
	tapa.gui_input.connect(func (e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_clic_en_tapa.emit()
	)
	await _clic_en_tapa


# ---------- Crédito de Bruma (no se pierde nunca) ----------

## Din ofrece un crédito cuando la bruma llega a cero. Las dos opciones dicen lo mismo.
func _ofrecer_credito() -> void:
	if is_instance_valid(_panel_credito):
		return
	cerrar_inventario()
	_panel_credito = _crear_ventana("DIN · CRÉDITO DE BRUMA ♥", Vector2(220, 104))
	var caja: VBoxContainer = _panel_credito.get_meta("contenido")
	var texto := _crear_texto_panel(
		"¡Detectamos que te estás desvaneciendo! Te prestamos %d de Bruma ya mismo. Devolvés %d con tus próximos sellos."
		% [int(Globals.CREDITO_MONTO), int(Globals.CREDITO_DEVOLUCION)], Color.WHITE)
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.custom_minimum_size = Vector2(208, 0)
	caja.add_child(texto)
	var chica := _crear_texto_panel("(Interés: 50%. Los fantasmas no tienen apuro.)", COLOR_TEXTO_SECUNDARIO)
	caja.add_child(chica)
	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 12)
	botones.add_child(_crear_boton_panel("ACEPTAR", _aceptar_credito))
	botones.add_child(_crear_boton_panel("ACEPTAR", _aceptar_credito))
	caja.add_child(botones)


func _aceptar_credito() -> void:
	if is_instance_valid(_panel_credito):
		_panel_credito.queue_free()
		_panel_credito = null
	Globals.tomar_credito()
	if Globals.creditos == 1 and is_instance_valid(C.player):
		G.block()
		await C.player.say("¡Uf, volví! Pero ahora le debo bruma a la empresa…")
		G.unblock()


# ---------- Objeto en la mano ----------

func _crear_etiqueta_en_mano() -> void:
	_etiqueta_en_mano = _crear_label("", Ajustes.UI_HUD_FUENTE)
	_etiqueta_en_mano.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_etiqueta_en_mano.add_theme_color_override("font_shadow_color", Color.BLACK)
	_etiqueta_en_mano.add_theme_constant_override("shadow_offset_x", 1)
	_etiqueta_en_mano.add_theme_constant_override("shadow_offset_y", 1)
	_etiqueta_en_mano.size = Vector2(160, 10)
	_etiqueta_en_mano.z_index = 30
	_etiqueta_en_mano.hide()
	add_child(_etiqueta_en_mano)


func _process(_delta: float) -> void:
	if not is_instance_valid(_etiqueta_en_mano):
		return
	var item: PopochiuInventoryItem = I.active
	if item == null or is_instance_valid(_panel_inventario):
		_etiqueta_en_mano.hide()
		return
	_etiqueta_en_mano.text = "Usar %s en... (clic derecho: guardar)" % item.description
	var mouse := get_viewport().get_mouse_position()
	_etiqueta_en_mano.position = Vector2(
		clampf(mouse.x + 8.0, 0.0, 320.0 - _etiqueta_en_mano.get_minimum_size().x),
		clampf(mouse.y + 6.0, 36.0, 140.0))
	_etiqueta_en_mano.show()


func _input(event: InputEvent) -> void:
	# Clic derecho en cualquier lado: el objeto vuelve al inventario.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if I.active != null:
			I.set_active_item(null)
			get_viewport().set_input_as_handled()


# ---------- Volumen ----------

func abrir_sonido() -> void:
	if is_instance_valid(_panel_sonido):
		cerrar_sonido()
		return
	cerrar_inventario()
	_panel_sonido = _crear_ventana("SONIDO", Vector2(170.0, 64.0))
	_llenar_sonido()


func cerrar_sonido() -> void:
	if is_instance_valid(_panel_sonido):
		_panel_sonido.queue_free()
		_panel_sonido = null


func _llenar_sonido() -> void:
	var caja: VBoxContainer = _panel_sonido.get_meta("contenido")
	for hijo in caja.get_children():
		hijo.queue_free()
	caja.add_child(_fila_volumen("MÚSICA", _nivel_musica, func (n): _nivel_musica = n))
	caja.add_child(_fila_volumen("VOCES Y TIMBRE", _nivel_voces, func (n): _nivel_voces = n))
	caja.add_child(_crear_boton_panel("CERRAR", cerrar_sonido))


func _fila_volumen(titulo: String, nivel: int, guardar: Callable) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 4)
	var etiqueta := _crear_texto_panel(titulo, Color.WHITE)
	etiqueta.custom_minimum_size = Vector2(70, 0)
	fila.add_child(etiqueta)
	fila.add_child(_crear_boton_panel("-", func ():
		guardar.call(maxi(nivel - 1, 0))
		_aplicar_sonido(true)
		_llenar_sonido()
	))
	var barra := HBoxContainer.new()
	barra.add_theme_constant_override("separation", 1)
	for i in range(1, NIVELES_DB.size()):
		var cuadro := ColorRect.new()
		cuadro.custom_minimum_size = Vector2(5, 7)
		cuadro.color = COLOR_FILA_ELEGIDA if i <= nivel else COLOR_CASILLERO
		cuadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
		barra.add_child(cuadro)
	fila.add_child(barra)
	fila.add_child(_crear_boton_panel("+", func ():
		guardar.call(mini(nivel + 1, NIVELES_DB.size() - 1))
		_aplicar_sonido(true)
		_llenar_sonido()
	))
	return fila


static func bus_voces() -> StringName:
	var indice := AudioServer.get_bus_index(BUS_VOCES)
	if indice == -1:
		AudioServer.add_bus()
		indice = AudioServer.bus_count - 1
		AudioServer.set_bus_name(indice, BUS_VOCES)
		AudioServer.set_bus_send(indice, &"Master")
	return StringName(BUS_VOCES)


func _cargar_sonido() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA_SONIDO) == OK:
		_nivel_musica = clampi(int(cfg.get_value("volumen", "musica", NIVEL_MUSICA_INICIAL)), 0, NIVELES_DB.size() - 1)
		_nivel_voces = clampi(int(cfg.get_value("volumen", "voces", NIVEL_VOCES_INICIAL)), 0, NIVELES_DB.size() - 1)
	_aplicar_sonido(false)


func _aplicar_sonido(guardar: bool) -> void:
	var musica := AudioServer.get_bus_index(Musica.bus_retro())
	if musica >= 0:
		AudioServer.set_bus_volume_db(musica, NIVELES_DB[_nivel_musica])
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus_voces()), NIVELES_DB[_nivel_voces])
	if guardar:
		var cfg := ConfigFile.new()
		cfg.set_value("volumen", "musica", _nivel_musica)
		cfg.set_value("volumen", "voces", _nivel_voces)
		cfg.save(RUTA_SONIDO)


## Las voces (pips de Nuna y del viejo) y el timbre pasan por el bus "Voces".
func _al_agregar_nodo(nodo: Node) -> void:
	if _es_de_voz(nodo):
		_poner_bus_voces.call_deferred(nodo)


func _enrutar_voces_existentes() -> void:
	for nodo in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		if _es_de_voz(nodo):
			_poner_bus_voces(nodo)


func _es_de_voz(nodo: Node) -> bool:
	if not nodo is AudioStreamPlayer:
		return false
	var actual: Node = nodo
	while actual != null:
		if String(actual.name) in NODOS_DE_VOZ:
			return true
		actual = actual.get_parent()
	return false


func _poner_bus_voces(nodo: Node) -> void:
	if is_instance_valid(nodo) and nodo is AudioStreamPlayer:
		(nodo as AudioStreamPlayer).bus = bus_voces()


# ---------- Ventanitas (inventario y sonido) ----------

## Una ventana negra con borde blanco, centrada sobre el cuarto, que tapa los clics del juego.
func _crear_ventana(titulo: String, tamano: Vector2) -> Control:
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.55)
	fondo.position = Vector2.ZERO
	fondo.size = Vector2(320, 180)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	fondo.z_index = 25
	add_child(fondo)
	var borde := ColorRect.new()
	borde.color = COLOR_PANEL_BORDE
	borde.size = tamano + Vector2(2, 2)
	borde.position = (Vector2(320, 180) - borde.size) / 2.0
	borde.position = borde.position.floor()
	fondo.add_child(borde)
	var panel := ColorRect.new()
	panel.color = COLOR_PANEL
	panel.position = Vector2.ONE
	panel.size = tamano
	borde.add_child(panel)
	var caja := VBoxContainer.new()
	caja.position = Vector2(6, 4)
	caja.size = tamano - Vector2(12, 8)
	caja.add_theme_constant_override("separation", 3)
	panel.add_child(caja)
	var cabecera := _crear_texto_panel(titulo, COLOR_TEXTO_SECUNDARIO)
	panel.add_child(cabecera)
	cabecera.position = Vector2(6, 2)
	caja.position.y = 14
	caja.size.y = tamano.y - 18
	fondo.set_meta("contenido", caja)
	return fondo


func _crear_texto_panel(texto: String, color: Color) -> Label:
	var l := _crear_label(texto, Ajustes.UI_HUD_FUENTE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.add_theme_color_override("font_color", color)
	return l


func _crear_boton_panel(texto: String, al_tocar: Callable) -> Label:
	var l := _crear_texto_panel("[" + texto + "]", Color.WHITE)
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	l.mouse_entered.connect(func (): l.add_theme_color_override("font_color", COLOR_FILA_ELEGIDA))
	l.mouse_exited.connect(func (): l.add_theme_color_override("font_color", Color.WHITE))
	l.gui_input.connect(func (event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			al_tocar.call()
	)
	return l
