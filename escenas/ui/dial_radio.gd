class_name DialRadio
extends CanvasLayer
## Panel del dial de Ramón (Prueba 2). Muestra el código, el abecedario con ←←← y cinco estaciones.
## Emite elegido(n) con el número de estación, o elegido(0) si se cerró con un clic afuera.

signal elegido(numero: int)

const CODIGO := "FXDWUR"
const ABECEDARIO := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const ESTACIONES := 5

const COLOR_PANEL := Color(0.02, 0.02, 0.025, 0.96)
const COLOR_BORDE := Color(0.55, 0.50, 0.68)  # violeta grisáceo, como la consola
const COLOR_TEXTO := Color.WHITE
const COLOR_SECUNDARIO := Color(0.55, 0.55, 0.58)
const COLOR_CODIGO := Color(0.96, 0.63, 0.25)

var _fondo: ColorRect
var _botones: Array[Button] = []
var _bloqueado: bool = false


func _ready() -> void:
	layer = 45

	# Clic afuera del panel = cerrar.
	_fondo = ColorRect.new()
	_fondo.color = Color(0, 0, 0, 0.35)
	_fondo.position = Vector2.ZERO
	_fondo.size = Vector2(320, 180)
	_fondo.gui_input.connect(_al_clic_afuera)
	add_child(_fondo)

	var panel := PanelContainer.new()
	panel.theme = _crear_tema()
	panel.custom_minimum_size = Vector2(200, 0)
	add_child(panel)
	panel.resized.connect(func(): panel.position = ((Vector2(320, 140) - panel.size) / 2.0).floor() + Vector2(0, 18))

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	panel.add_child(caja)

	caja.add_child(_label("RAMÓN · SINTONÍA", COLOR_SECUNDARIO))
	caja.add_child(_label("Código:  " + CODIGO, COLOR_CODIGO))
	caja.add_child(_label(ABECEDARIO, COLOR_TEXTO))
	caja.add_child(_label("← ← ←  (cuenta hacia atrás)", COLOR_SECUNDARIO))

	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 6)
	caja.add_child(fila)
	for i in ESTACIONES:
		var numero: int = i + 1
		var b := Button.new()
		b.text = str(numero)
		b.custom_minimum_size = Vector2(20, 14)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): _elegir(numero))
		fila.add_child(b)
		_botones.append(b)

	caja.add_child(_label("Clic afuera para cerrar", COLOR_SECUNDARIO))


## Marca una estación ya probada: queda gris pero se puede volver a elegir.
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


func cerrar() -> void:
	queue_free()


func _elegir(numero: int) -> void:
	if not _bloqueado:
		elegido.emit(numero)


func _al_clic_afuera(event: InputEvent) -> void:
	var boton := event as InputEventMouseButton
	if _bloqueado or boton == null or not boton.pressed:
		return
	elegido.emit(0)
	queue_free()


func _label(texto: String, color: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	return l


func _crear_tema() -> Theme:
	var t := Theme.new()
	if ResourceLoader.exists(Ajustes.UI_FUENTE_DIALOGO):
		t.default_font = load(Ajustes.UI_FUENTE_DIALOGO)
	t.default_font_size = 8
	var panel := StyleBoxFlat.new()
	panel.bg_color = COLOR_PANEL
	panel.border_color = COLOR_BORDE
	panel.set_border_width_all(1)
	panel.set_content_margin_all(5)
	t.set_stylebox("panel", "PanelContainer", panel)
	for estado in ["normal", "hover", "pressed", "disabled"]:
		var c := StyleBoxFlat.new()
		c.bg_color = Color(0.12, 0.12, 0.14) if estado != "hover" else Color(0.30, 0.26, 0.40)
		c.border_color = COLOR_BORDE
		c.set_border_width_all(1)
		t.set_stylebox(estado, "Button", c)
	t.set_color("font_color", "Button", COLOR_TEXTO)
	t.set_color("font_hover_color", "Button", COLOR_TEXTO)
	t.set_color("font_disabled_color", "Button", COLOR_SECUNDARIO)
	return t
