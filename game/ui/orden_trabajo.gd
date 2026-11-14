class_name OrdenTrabajo
extends CanvasLayer
## Tarjeta de instrucciones al entrar a la 101. El juego espera hasta que se toca «¡Acepto!».

signal aceptado

const RUTA_FUENTE := "res://arte/fuentes/monogram-extended.ttf"
const TAM := 16  # Monogram se ve nítida en múltiplos de 16

const COLOR_OSCURO := Color8(34, 32, 52)
const COLOR_GRIS := Color8(155, 173, 183)
const COLOR_CLARO := Color8(203, 219, 252)
const COLOR_AZUL := Color8(48, 96, 130)

const TITULO := "ORDEN DE TRABAJO - HABITACIÓN 101"
const LINEAS: Array[String] = [
	"Asustá a la huésped y ganá 3 sellos.",
	"1. MIRÁ cada objeto: Nuna le pone nombre.",
	"2. PERTURBÁ la lámpara, la radio y la cortina.",
	"3. ¿No llegás? Buscá ayuda en la habitación.",
	"La Bruma baja con el tiempo. ¡No te detengas! ♥",
]
const LETRA_CHICA := "(Al aceptar, renunciás a tu descanso.)"

const COLOR_SELLO := Color8(172, 50, 50)
const LINEAS_CUMPLIDA: Array[String] = [
	"Asustá a la huésped y ganá 3 sellos.",
	"✓ Lumi  ✓ Ramón  ✓ Doña Cortina",
	"Rendimiento: excelente.",
	"Mañana, la cuota será más alta. ♥",
]
const LETRA_CHICA_CUMPLIDA := "(Los sellos vencen al amanecer.)"

## true: la orden vuelve al final, con el sello CUMPLIDO.
var cumplida: bool = false


func _ready() -> void:
	layer = 50
	var fondo := ColorRect.new()  # oscurece el juego y bloquea los clics
	fondo.color = Color(0, 0, 0, 0.55)
	fondo.size = Vector2(320, 180)
	add_child(fondo)

	var panel := PanelContainer.new()
	panel.theme = _crear_tema()
	panel.position = Vector2(12, 0)
	panel.custom_minimum_size = Vector2(296, 0)
	add_child(panel)
	panel.resized.connect(func(): panel.position.y = floorf((180.0 - panel.size.y) / 2.0))

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", -2)
	panel.add_child(caja)

	var titulo := _label(TITULO, COLOR_CLARO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(titulo)
	caja.add_child(_espacio(4))
	for linea in (LINEAS_CUMPLIDA if cumplida else LINEAS):
		caja.add_child(_label(linea, COLOR_GRIS))

	caja.add_child(_espacio(8))
	var boton := Button.new()
	boton.text = "¡Una más!" if cumplida else "¡Acepto!"
	boton.custom_minimum_size = Vector2(70, 16)
	boton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boton.pressed.connect(_al_aceptar)
	caja.add_child(boton)
	boton.grab_focus()  # también se acepta con Enter

	caja.add_child(_espacio(2))
	var chica := _label(LETRA_CHICA_CUMPLIDA if cumplida else LETRA_CHICA, COLOR_AZUL)
	chica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(chica)

	if cumplida:
		var sello := Label.new()
		sello.text = "CUMPLIDO"
		sello.theme = panel.theme
		sello.add_theme_font_size_override("font_size", 32)
		sello.add_theme_color_override("font_color", COLOR_SELLO)
		var borde := StyleBoxFlat.new()
		borde.bg_color = Color(0, 0, 0, 0)
		borde.border_color = COLOR_SELLO
		borde.set_border_width_all(2)
		borde.content_margin_left = 4
		borde.content_margin_right = 4
		borde.content_margin_bottom = 2
		sello.add_theme_stylebox_override("normal", borde)
		sello.rotation = -0.2
		sello.position = Vector2(200, 88)
		add_child(sello)
		sello.scale = Vector2(2, 2)
		create_tween().tween_property(sello, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


func _al_aceptar() -> void:
	aceptado.emit()
	queue_free()


func _label(texto: String, color: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_color_override("font_color", color)
	return l


func _espacio(alto: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, alto)
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
	t.set_stylebox("focus", "Button", _caja(COLOR_AZUL, COLOR_CLARO, 0))
	t.set_stylebox("pressed", "Button", _caja(COLOR_CLARO, COLOR_CLARO, 0))
	t.set_color("font_color", "Button", COLOR_GRIS)
	t.set_color("font_hover_color", "Button", COLOR_CLARO)
	t.set_color("font_focus_color", "Button", COLOR_CLARO)
	t.set_color("font_pressed_color", "Button", COLOR_OSCURO)
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
