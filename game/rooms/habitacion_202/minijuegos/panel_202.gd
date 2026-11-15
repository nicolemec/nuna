class_name Panel202
extends CanvasLayer
## Base de los paneles de minijuego de la 202 (mismo estilo que el dial de Ramón).
## Clic afuera del panel = cerrar (emite cerrado).

signal cerrado

## Monogram a 16 (la fuente de la consola): nítida y legible. El panel es ancho
## y de tamaño fijo para que no crezca con los textos largos.
const RUTA_FUENTE := "res://arte/fuentes/monogram-extended.ttf"
const TAM := 16
const COLOR_OSCURO := Color8(34, 32, 52)
const COLOR_GRIS := Color8(155, 173, 183)
const COLOR_CLARO := Color8(203, 219, 252)
const COLOR_AZUL := Color8(48, 96, 130)
const COLOR_NARANJA := Color(0.96, 0.63, 0.25)
const COLOR_PISTA := Color8(120, 170, 210)
const COLOR_ROJO := Color8(217, 87, 99)

var _fondo: ColorRect
var _panel: PanelContainer
var caja: VBoxContainer
var _botones: Array[Button] = []
var _bloqueado := false


func _ready() -> void:
	layer = 45
	_fondo = ColorRect.new()
	_fondo.color = Color(0, 0, 0, 0.35)
	_fondo.size = Vector2(320, 180)
	_fondo.gui_input.connect(_al_clic_afuera)
	add_child(_fondo)
	_panel = PanelContainer.new()
	_panel.theme = _crear_tema()
	_panel.custom_minimum_size = Vector2(300, 0)
	add_child(_panel)
	_panel.resized.connect(func(): _panel.position = Vector2(floorf((320 - _panel.size.x) / 2.0), maxf(2.0, 146.0 - _panel.size.y)))
	caja = VBoxContainer.new()
	caja.add_theme_constant_override("separation", 0)
	_panel.add_child(caja)
	_armar()


## Cada panel arma su contenido acá.
func _armar() -> void:
	pass


func bloquear(valor: bool) -> void:
	_bloqueado = valor
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE if valor else Control.MOUSE_FILTER_STOP
	for b in _botones:
		b.disabled = valor


## Ajusta el panel al contenido nuevo (por ejemplo, al cambiar de mail).
func reacomodar() -> void:
	_panel.reset_size()


func cerrar() -> void:
	queue_free()


func _al_clic_afuera(event: InputEvent) -> void:
	var boton := event as InputEventMouseButton
	if _bloqueado or boton == null or not boton.pressed:
		return
	cerrado.emit()
	queue_free()


func _boton(texto: String, al_tocar: Callable, ancho := 0.0) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if ancho > 0:
		b.custom_minimum_size = Vector2(ancho, 12)
	b.pressed.connect(func(): if not _bloqueado: al_tocar.call())
	_botones.append(b)
	return b


func _label(texto: String, color: Color, centrado := true) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centrado else HORIZONTAL_ALIGNMENT_LEFT
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(286, 0)
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
	c.content_margin_left = maxf(margen, 3)
	c.content_margin_right = maxf(margen, 3)
	c.content_margin_top = margen if margen > 0 else 0
	c.content_margin_bottom = margen if margen > 0 else 1
	return c
