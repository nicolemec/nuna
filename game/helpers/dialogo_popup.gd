class_name DialogoPopup
extends CanvasLayer
## Ventana emergente para conversaciones importantes (por ejemplo, la entrada a la 101).
## Cada línea es [quién habla, texto] o [quién habla, texto, letra chica].
## Avanza con clic, Enter o Espacio. Mismo estilo que la orden de trabajo.
## Uso: await DialogoPopup.mostrar(self, [["NUNA", "¡Hola!"], ["DIN", "¡A trabajar! ♥"]])

signal terminado

const RUTA_FUENTE := "res://arte/fuentes/monogram-extended.ttf"
const TAM := 16
const COLOR_OSCURO := Color8(34, 32, 52)
const COLOR_GRIS := Color8(155, 173, 183)
const COLOR_CLARO := Color8(203, 219, 252)
const COLOR_AZUL := Color8(48, 96, 130)
const COLOR_HABLANTE := Color8(176, 146, 226)
const ESPERA_MINIMA := 0.4  # para no saltear una línea sin querer

## Solo para las pruebas automáticas: si es true, pasa las líneas solo.
static var avanzar_solo := false

var _lineas: Array = []
var _indice := -1
var _hablante: Label
var _texto: Label
var _chica: Label
var _indicador: Label
var _listo_desde := 0


static func mostrar(padre: Node, lineas: Array) -> void:
	var popup := DialogoPopup.new()
	popup._lineas = lineas
	padre.add_child(popup)
	await popup.terminado


func _ready() -> void:
	layer = 50
	var fondo := ColorRect.new()  # oscurece el juego y bloquea los clics
	fondo.color = Color(0, 0, 0, 0.55)
	fondo.size = Vector2(320, 180)
	fondo.gui_input.connect(_al_clic)
	add_child(fondo)

	var panel := PanelContainer.new()
	panel.theme = _crear_tema()
	panel.position = Vector2(24, 0)
	panel.custom_minimum_size = Vector2(272, 0)
	panel.gui_input.connect(_al_clic)
	add_child(panel)
	panel.resized.connect(func(): panel.position.y = floorf((152.0 - panel.size.y) / 2.0))

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", -2)
	panel.add_child(caja)

	_hablante = _label(COLOR_HABLANTE)
	caja.add_child(_hablante)
	_texto = _label(COLOR_CLARO)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.custom_minimum_size = Vector2(260, 0)
	_texto.add_theme_constant_override("line_spacing", -4)
	caja.add_child(_texto)
	_chica = _label(COLOR_AZUL)
	caja.add_child(_chica)
	_indicador = _label(COLOR_GRIS)
	_indicador.text = "clic para seguir >"
	_indicador.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caja.add_child(_indicador)

	_siguiente()


func _process(_delta: float) -> void:
	var listo := Time.get_ticks_msec() >= _listo_desde
	# El indicador aparece cuando ya se puede avanzar y titila suave.
	_indicador.modulate.a = (0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)) if listo else 0.0
	if listo and avanzar_solo:
		_siguiente()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_avanzar()


func _al_clic(event: InputEvent) -> void:
	var clic := event as InputEventMouseButton
	if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT:
		_avanzar()


func _avanzar() -> void:
	if Time.get_ticks_msec() >= _listo_desde:
		_siguiente()


func _siguiente() -> void:
	_indice += 1
	if _indice >= _lineas.size():
		set_process(false)
		terminado.emit()
		queue_free()
		return
	var linea: Array = _lineas[_indice]
	_hablante.text = String(linea[0])
	_hablante.visible = not _hablante.text.is_empty()
	_texto.text = String(linea[1])
	_chica.text = String(linea[2]) if linea.size() > 2 else ""
	_chica.visible = not _chica.text.is_empty()
	_listo_desde = Time.get_ticks_msec() + int(ESPERA_MINIMA * 1000.0)


func _label(color: Color) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _crear_tema() -> Theme:
	var t := Theme.new()
	if ResourceLoader.exists(RUTA_FUENTE):
		var fuente: FontFile = load(RUTA_FUENTE)
		fuente.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		fuente.hinting = TextServer.HINTING_NONE
		fuente.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		t.default_font = fuente
	t.default_font_size = TAM
	var caja := StyleBoxFlat.new()
	caja.bg_color = COLOR_OSCURO
	caja.border_color = COLOR_GRIS
	caja.set_border_width_all(1)
	caja.content_margin_left = 6
	caja.content_margin_right = 6
	caja.content_margin_top = 4
	caja.content_margin_bottom = 4
	t.set_stylebox("panel", "PanelContainer", caja)
	return t
