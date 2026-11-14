class_name PreguntaSiNo
extends CanvasLayer
## Pregunta con opciones en la consola inferior, con el mismo estilo que los verbos.
## Sí/No:     var si: bool = await PreguntaSiNo.preguntar(self, "¿Usar a Ovi?")
## Opciones:  var i: int = await PreguntaSiNo.elegir(self, "¿Qué soy?", ["La bruma", "El miedo"])

signal elegido(indice: int)

const COLOR_FONDO := Color(0.0, 0.0, 0.0, 1.0)
const COLOR_SECUNDARIO := Color(0.55, 0.55, 0.58)

## Solo para las pruebas automáticas: true/false (Sí/No) o el número de opción (0, 1, 2…).
static var respuesta_automatica: Variant = null

var _texto := ""
var _opciones: Array = ["Sí", "No"]
var _fuente: Font
var _respondida := false


static func preguntar(padre: Node, texto: String) -> bool:
	var indice: int = await elegir(padre, texto, ["Sí", "No"])
	return indice == 0


static func elegir(padre: Node, texto: String, opciones: Array) -> int:
	var pregunta := PreguntaSiNo.new()
	pregunta._texto = texto
	pregunta._opciones = opciones
	padre.add_child(pregunta)
	var indice: int = await pregunta.elegido
	pregunta.queue_free()
	return indice


func _ready() -> void:
	layer = 70
	if respuesta_automatica != null:
		var indice: int = (0 if respuesta_automatica else 1) if respuesta_automatica is bool else int(respuesta_automatica)
		_responder.call_deferred(indice)
	if ResourceLoader.exists(Ajustes.UI_FUENTE_HUD):
		_fuente = load(Ajustes.UI_FUENTE_HUD) as Font

	var fondo := ColorRect.new()
	fondo.color = COLOR_FONDO
	fondo.position = Ajustes.UI_CONSOLA_EXPANDIDA_POS
	fondo.size = Ajustes.UI_CONSOLA_EXPANDIDA_TAMANO
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fondo)

	var titulo := _label(_texto, Color.WHITE)
	titulo.position = Ajustes.UI_CONSOLA_TEXTO_POS
	titulo.size = Ajustes.UI_CONSOLA_TEXTO_TAMANO
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_usar_letra_grande(titulo)
	fondo.add_child(titulo)

	var fila := HBoxContainer.new()
	fila.position = Ajustes.UI_CONSOLA_OPCIONES_POS
	fila.size = Ajustes.UI_CONSOLA_OPCIONES_TAMANO
	fila.add_theme_constant_override("separation", int(Ajustes.UI_CONSOLA_SEPARACION_ACCIONES))
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo.add_child(fila)
	for i in _opciones.size():
		fila.add_child(_boton("(%d) %s" % [i + 1, _opciones[i]], i))


func _unhandled_key_input(event: InputEvent) -> void:
	var tecla := event as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	for i in _opciones.size():
		if tecla.keycode == KEY_1 + i or tecla.keycode == KEY_KP_1 + i:
			_responder(i)


func _responder(indice: int) -> void:
	if _respondida:
		return
	_respondida = true
	get_viewport().set_input_as_handled()
	elegido.emit(indice)


func _boton(texto: String, indice: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(Ajustes.UI_CONSOLA_ACCION_ANCHO, Ajustes.UI_CONSOLA_OPCIONES_TAMANO.y)
	var vacio := StyleBoxEmpty.new()
	for estado in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(estado, vacio)

	var fila := HBoxContainer.new()
	fila.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_theme_constant_override("separation", int(Ajustes.UI_CONSOLA_SEPARACION_CONTENIDO_ACCION))
	var prefijo := _label(">", COLOR_SECUNDARIO)
	prefijo.custom_minimum_size = Vector2(Ajustes.UI_CONSOLA_ACCION_PREFIJO_ANCHO, Ajustes.UI_CONSOLA_OPCIONES_TAMANO.y)
	prefijo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fila.add_child(prefijo)
	var etiqueta := _label(texto, Color.WHITE)
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_usar_letra_grande(etiqueta)  # misma letra que la pregunta: las tildes se leen bien
	fila.add_child(etiqueta)
	b.add_child(fila)

	b.mouse_entered.connect(func (): prefijo.add_theme_color_override("font_color", Color.WHITE))
	b.mouse_exited.connect(func (): prefijo.add_theme_color_override("font_color", COLOR_SECUNDARIO))
	b.pressed.connect(_responder.bind(indice))
	return b


func _usar_letra_grande(l: Label) -> void:
	if ResourceLoader.exists(Ajustes.UI_FUENTE_DIALOGO):
		l.add_theme_font_override("font", load(Ajustes.UI_FUENTE_DIALOGO) as Font)
		l.add_theme_font_size_override("font_size", Ajustes.UI_CONSOLA_DIALOGO_FUENTE)


func _label(texto: String, color: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", Ajustes.UI_CONSOLA_FUENTE)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _fuente != null:
		l.add_theme_font_override("font", _fuente)
	return l
