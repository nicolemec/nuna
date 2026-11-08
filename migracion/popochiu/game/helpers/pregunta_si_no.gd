class_name PreguntaSiNo
extends CanvasLayer
## Pregunta Sí/No en la consola inferior, con el mismo estilo que los verbos.
## Uso: var si: bool = await PreguntaSiNo.preguntar(self, "¿Usar a Ovi?")

signal respondido(si: bool)

const COLOR_FONDO := Color(0.01, 0.01, 0.012, 0.98)
const COLOR_SECUNDARIO := Color(0.55, 0.55, 0.58)

## Solo para las pruebas automáticas: si es true o false, responde sola.
static var respuesta_automatica: Variant = null

var _texto := ""
var _fuente: Font
var _respondida := false


static func preguntar(padre: Node, texto: String) -> bool:
	var pregunta := PreguntaSiNo.new()
	pregunta._texto = texto
	padre.add_child(pregunta)
	var si: bool = await pregunta.respondido
	pregunta.queue_free()
	return si


func _ready() -> void:
	layer = 70
	if respuesta_automatica != null:
		_responder.call_deferred(bool(respuesta_automatica))
	if ResourceLoader.exists(Ajustes.UI_FUENTE_HUD):
		_fuente = load(Ajustes.UI_FUENTE_HUD) as Font

	var fondo := ColorRect.new()
	fondo.color = COLOR_FONDO
	fondo.position = Ajustes.UI_CONSOLA_EXPANDIDA_POS
	fondo.size = Ajustes.UI_CONSOLA_EXPANDIDA_TAMANO
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fondo)

	var titulo := _label(_texto.to_upper(), Color.WHITE)
	titulo.position = Ajustes.UI_CONSOLA_TEXTO_POS
	titulo.size = Ajustes.UI_CONSOLA_TEXTO_TAMANO
	fondo.add_child(titulo)

	var opciones := HBoxContainer.new()
	opciones.position = Ajustes.UI_CONSOLA_OPCIONES_POS
	opciones.size = Ajustes.UI_CONSOLA_OPCIONES_TAMANO
	opciones.add_theme_constant_override("separation", int(Ajustes.UI_CONSOLA_SEPARACION_ACCIONES))
	opciones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo.add_child(opciones)
	opciones.add_child(_boton("(1) SÍ", true))
	opciones.add_child(_boton("(2) NO", false))


func _unhandled_key_input(event: InputEvent) -> void:
	var tecla := event as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	match tecla.keycode:
		KEY_1, KEY_KP_1:
			_responder(true)
		KEY_2, KEY_KP_2:
			_responder(false)


func _responder(si: bool) -> void:
	if _respondida:
		return
	_respondida = true
	get_viewport().set_input_as_handled()
	respondido.emit(si)


func _boton(texto: String, valor: bool) -> Button:
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
	fila.add_child(etiqueta)
	b.add_child(fila)

	b.mouse_entered.connect(func (): prefijo.add_theme_color_override("font_color", Color.WHITE))
	b.mouse_exited.connect(func (): prefijo.add_theme_color_override("font_color", COLOR_SECUNDARIO))
	b.pressed.connect(_responder.bind(valor))
	return b


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
