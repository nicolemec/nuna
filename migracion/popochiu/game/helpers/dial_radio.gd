class_name DialRadio
extends CanvasLayer
## Panel del dial de Ramón: muestra el código al revés y cinco estaciones.
## Emite elegido(n) con el número de estación, o elegido(0) si se cerró con un clic afuera.

signal elegido(numero: int)

const CODIGO := "ORTAUC"  # al revés: CUATRO
const ESTACIONES := 5
const RUTA_FUENTE := "res://arte/fuentes/monogram-extended.ttf"
const TAM := 16

const COLOR_OSCURO := Color8(34, 32, 52)
const COLOR_GRIS := Color8(155, 173, 183)
const COLOR_CLARO := Color8(203, 219, 252)
const COLOR_AZUL := Color8(48, 96, 130)
const COLOR_CODIGO := Color(0.96, 0.63, 0.25)
const COLOR_PISTA := Color8(120, 170, 210)

## Solo para las pruebas automáticas: estaciones que se eligen solas, en orden (0 = cerrar).
static var respuestas_automaticas: Array = []

var _fondo: ColorRect
var _botones: Array[Button] = []
var _bloqueado := false


func _ready() -> void:
	layer = 45
	_fondo = ColorRect.new()  # clic afuera del panel = cerrar
	_fondo.color = Color(0, 0, 0, 0.35)
	_fondo.size = Vector2(320, 180)
	_fondo.gui_input.connect(_al_clic_afuera)
	add_child(_fondo)

	var panel := PanelContainer.new()
	panel.theme = _crear_tema()
	panel.custom_minimum_size = Vector2(200, 0)
	add_child(panel)
	panel.resized.connect(func(): panel.position = ((Vector2(320, 152) - panel.size) / 2.0).floor())

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", -2)
	panel.add_child(caja)
	caja.add_child(_label("RAMÓN - SINTONÍA", COLOR_GRIS))
	caja.add_child(_label("Código: " + CODIGO, COLOR_CODIGO))
	caja.add_child(_label("Radio Revés: se lee al revés.", COLOR_PISTA))
	caja.add_child(_espacio(4))

	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 6)
	caja.add_child(fila)
	for i in ESTACIONES:
		var numero: int = i + 1
		var b := Button.new()
		b.text = str(numero)
		b.custom_minimum_size = Vector2(22, 16)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_elegir.bind(numero))
		fila.add_child(b)
		_botones.append(b)

	caja.add_child(_espacio(2))
	caja.add_child(_label("clic afuera para cerrar", COLOR_GRIS))
	_responder_solo()


## Marca una estación ya probada: queda más tenue, pero se puede volver a elegir.
func marcar_probada(numero: int) -> void:
	if numero >= 1 and numero <= _botones.size():
		_botones[numero - 1].modulate = Color(1, 1, 1, 0.45)


## Mientras Ramón suena y Nuna habla, el panel no acepta clics
## (y un clic en cualquier lado pasa el diálogo).
func bloquear(valor: bool) -> void:
	_bloqueado = valor
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE if valor else Control.MOUSE_FILTER_STOP
	for b in _botones:
		b.disabled = valor
	if not valor:
		_responder_solo()


func cerrar() -> void:
	queue_free()


func _responder_solo() -> void:
	if respuestas_automaticas.is_empty():
		return
	var numero: int = respuestas_automaticas.pop_front()
	if numero == 0:
		_cerrar_afuera.call_deferred()
	else:
		_elegir.call_deferred(numero)


func _elegir(numero: int) -> void:
	if not _bloqueado:
		elegido.emit(numero)


func _al_clic_afuera(event: InputEvent) -> void:
	var boton := event as InputEventMouseButton
	if _bloqueado or boton == null or not boton.pressed:
		return
	_cerrar_afuera()


func _cerrar_afuera() -> void:
	elegido.emit(0)
	queue_free()


func _label(texto: String, color: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _espacio(alto: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, alto)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _crear_tema() -> Theme:
	var t := Theme.new()
	if ResourceLoader.exists(RUTA_FUENTE):
		var fuente: FontFile = load(RUTA_FUENTE)
		fuente.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		fuente.hinting = TextServer.HINTING_NONE
		fuente.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		t.default_font = fuente
	t.default_font_size = TAM
	t.set_stylebox("panel", "PanelContainer", _caja(COLOR_OSCURO, COLOR_GRIS, 6))
	t.set_stylebox("normal", "Button", _caja(COLOR_OSCURO, COLOR_GRIS, 0))
	t.set_stylebox("hover", "Button", _caja(COLOR_AZUL, COLOR_CLARO, 0))
	t.set_stylebox("pressed", "Button", _caja(COLOR_CLARO, COLOR_CLARO, 0))
	t.set_stylebox("disabled", "Button", _caja(COLOR_OSCURO, COLOR_AZUL, 0))
	t.set_color("font_color", "Button", COLOR_CLARO)
	t.set_color("font_hover_color", "Button", COLOR_CLARO)
	t.set_color("font_pressed_color", "Button", COLOR_OSCURO)
	t.set_color("font_disabled_color", "Button", COLOR_AZUL)
	return t


func _caja(relleno: Color, borde: Color, margen: float) -> StyleBoxFlat:
	var c := StyleBoxFlat.new()
	c.bg_color = relleno
	c.border_color = borde
	c.set_border_width_all(1)
	c.content_margin_left = margen
	c.content_margin_right = margen
	c.content_margin_top = margen - 2 if margen > 0 else 0
	c.content_margin_bottom = margen if margen > 0 else 2
	return c
