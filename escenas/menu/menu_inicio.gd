extends Control
## Pantalla de inicio. Todo se arma por código, igual que la UI.
## Fondo: arte/menu/fondo_menu.png (320x180). Se puede redibujar en Aseprite
## con el mismo nombre y tamaño, y se actualiza solo.

const ESCENA_JUEGO := "res://escenas/habitaciones/habitacion_101.tscn"
const ESCENA_NUNA := "res://escenas/personajes/nuna.tscn"
const RUTA_FONDO := "res://arte/menu/fondo_menu.png"
const RUTA_FUENTE := "res://arte/fuentes/monogram-extended.ttf"
const TITULO := "CASI HUMANO"

# Colores tomados de la paleta de Nuna
const COLOR_OSCURO := Color8(34, 32, 52)
const COLOR_AZUL := Color8(48, 96, 130)
const COLOR_GRIS := Color8(155, 173, 183)
const COLOR_CLARO := Color8(203, 219, 252)

# Monogram se ve nítida en múltiplos de 16
const TAM_TITULO := 32
const TAM_BOTON := 16


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = _crear_tema()

	# Fondo
	var fondo := TextureRect.new()
	fondo.texture = load(RUTA_FONDO)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)

	# Título con sombra
	var titulo := Label.new()
	titulo.text = TITULO
	titulo.position = Vector2(0, 12)
	titulo.size = Vector2(320, 30)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", TAM_TITULO)
	titulo.add_theme_color_override("font_color", COLOR_CLARO)
	titulo.add_theme_color_override("font_shadow_color", COLOR_OSCURO)
	titulo.add_theme_constant_override("shadow_offset_x", 0)
	titulo.add_theme_constant_override("shadow_offset_y", 2)
	add_child(titulo)

	# Nuna flotando en el centro
	var nuna: Node2D = load(ESCENA_NUNA).instantiate()
	nuna.position = Vector2(160, 98)
	add_child(nuna)

	# Botones
	var botones := VBoxContainer.new()
	botones.position = Vector2(126, 104)
	botones.size = Vector2(68, 0)
	botones.add_theme_constant_override("separation", 4)
	add_child(botones)

	var jugar := _crear_boton("Jugar", botones)
	jugar.pressed.connect(_al_jugar)

	# En la versión web, "Salir" no sirve: se oculta
	if not OS.has_feature("web"):
		var salir := _crear_boton("Salir", botones)
		salir.pressed.connect(_al_salir)

	jugar.grab_focus()  # así funciona también con teclado (Enter)


func _crear_boton(texto: String, contenedor: Container) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(68, 16)
	contenedor.add_child(b)
	return b


## Tema del menú: fuente pixel y botones con la paleta del juego.
func _crear_tema() -> Theme:
	var t := Theme.new()

	if ResourceLoader.exists(RUTA_FUENTE):
		var fuente: FontFile = load(RUTA_FUENTE)
		fuente.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		fuente.hinting = TextServer.HINTING_NONE
		fuente.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		t.default_font = fuente
	else:
		push_warning("No encontré la fuente: " + RUTA_FUENTE)
	t.default_font_size = TAM_BOTON

	t.set_stylebox("normal", "Button", _caja(COLOR_OSCURO, COLOR_GRIS))
	t.set_stylebox("hover", "Button", _caja(COLOR_AZUL, COLOR_CLARO))
	t.set_stylebox("focus", "Button", _caja(COLOR_AZUL, COLOR_CLARO))
	t.set_stylebox("pressed", "Button", _caja(COLOR_CLARO, COLOR_CLARO))
	t.set_color("font_color", "Button", COLOR_GRIS)
	t.set_color("font_hover_color", "Button", COLOR_CLARO)
	t.set_color("font_focus_color", "Button", COLOR_CLARO)
	t.set_color("font_pressed_color", "Button", COLOR_OSCURO)
	return t


func _caja(relleno: Color, borde: Color) -> StyleBoxFlat:
	var c := StyleBoxFlat.new()
	c.bg_color = relleno
	c.border_color = borde
	c.set_border_width_all(1)
	c.content_margin_top = 0
	c.content_margin_bottom = 2
	return c


func _al_jugar() -> void:
	get_tree().change_scene_to_file(ESCENA_JUEGO)


func _al_salir() -> void:
	get_tree().quit()
