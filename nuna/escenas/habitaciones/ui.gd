class_name InterfazUI
extends CanvasLayer
## Barra de verbos y línea de acción. Todo se arma por código.

var _linea: Label
var _botones: Dictionary = {}


func _ready() -> void:
	# Barra de botones, abajo a la izquierda
	var barra := HBoxContainer.new()
	barra.position = Vector2(4, 156)
	barra.add_theme_constant_override("separation", 3)
	add_child(barra)

	var grupo := ButtonGroup.new()  # así solo un verbo queda apretado a la vez
	for verbo in GameState.NOMBRES_VERBOS:
		var b := Button.new()
		b.text = GameState.NOMBRES_VERBOS[verbo]
		b.toggle_mode = true
		b.button_group = grupo
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(44, 14)
		b.add_theme_font_size_override("font_size", 8)
		b.pressed.connect(GameState.elegir_verbo.bind(verbo))
		barra.add_child(b)
		_botones[verbo] = b
	_botones[GameState.verbo_actual].button_pressed = true

	# Línea de acción, a la derecha: "Mirar lámpara"
	_linea = Label.new()
	_linea.position = Vector2(170, 158)
	_linea.size = Vector2(146, 14)
	_linea.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_linea.add_theme_font_size_override("font_size", 8)
	_linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_linea)


func mostrar_accion(texto: String) -> void:
	if _linea.text != texto:
		_linea.text = texto
