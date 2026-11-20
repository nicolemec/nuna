class_name CursorPixel
## Cursor pixel art de Nuna, con los tonos violetas del juego.
## Reemplaza las animaciones del cursor de Popochiu sin editar el addon.

const O := Color8(28, 16, 40)     # contorno
const L := Color8(236, 228, 250)  # lavanda clara
const M := Color8(176, 146, 226)  # violeta medio
const V := Color8(124, 88, 196)   # violeta fuerte

const FLECHA := [
	"O.......",
	"OO......",
	"OLO.....",
	"OLLO....",
	"OLLLO...",
	"OLLLMO..",
	"OLLLLMO.",
	"OLLMOOOO",
	"OLOOLO..",
	"OO..OLO.",
	".....O..",
]

## Sobre algo clickeable: la flecha se tiñe de violeta y aparece un destello.
const FLECHA_ACTIVA := [
	"O.....L.",
	"OO...LLL",
	"OLO...L.",
	"OLMO....",
	"OLMMO...",
	"OLMMVO..",
	"OLMMMVO.",
	"OLMVOOOO",
	"OLOOMO..",
	"OO..OMO.",
	".....O..",
]

const RELOJ_1 := [
	"OOOOO",
	"OLLLO",
	".OMO.",
	"..O..",
	".OLO.",
	"OLLLO",
	"OOOOO",
]

const RELOJ_2 := [
	"OOOOO",
	"OLLLO",
	".OLO.",
	"..O..",
	".OMO.",
	"OMMMO",
	"OOOOO",
]


static func aplicar() -> void:
	var arbol := Engine.get_main_loop() as SceneTree
	var cursor := arbol.root.get_node_or_null("Cursor") as PopochiuCursor
	if cursor == null:
		return
	var colores := {"O": O, "L": L, "M": M, "V": V}
	var normal := _textura(FLECHA, colores)
	var activa := _textura(FLECHA_ACTIVA, colores)
	var vacia := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))

	var frames := SpriteFrames.new()
	for anim in ["normal", "gui", "idle", "down", "left", "right", "up"]:
		_agregar(frames, anim, [normal], 1.0)
	for anim in ["active", "look", "search", "talk", "use"]:
		_agregar(frames, anim, [activa], 1.0)
	_agregar(frames, "wait", [_textura(RELOJ_1, colores), _textura(RELOJ_2, colores)], 2.0)
	_agregar(frames, "none", [vacia], 1.0)

	var modelo := AnimatedSprite2D.new()
	modelo.sprite_frames = frames
	modelo.centered = false  # la punta de la flecha queda justo en el mouse
	modelo.offset = Vector2.ZERO
	var anim_actual: StringName = cursor.main_cursor.animation
	cursor.replace_frames(modelo)
	modelo.free()
	cursor.main_cursor.play(anim_actual if frames.has_animation(anim_actual) else &"normal")


static func _agregar(frames: SpriteFrames, anim: StringName, texturas: Array, fps: float) -> void:
	if not frames.has_animation(anim):
		frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, true)
	for t in texturas:
		frames.add_frame(anim, t)


static func _textura(filas: Array, colores: Dictionary) -> ImageTexture:
	var img := Image.create(filas[0].length(), filas.size(), false, Image.FORMAT_RGBA8)
	for y in filas.size():
		var fila: String = filas[y]
		for x in fila.length():
			var c := fila[x]
			if colores.has(c):
				img.set_pixel(x, y, colores[c])
	return ImageTexture.create_from_image(img)


## Mano para los botones (la misma de la manito del juego, en gui.gd).
const MANO := [
	"..OO.......",
	".OLLO......",
	".OLLO......",
	".OLLOOOO...",
	".OLLOLLOOO.",
	".OLLOLLOLLO",
	"OOLLLLLLLLO",
	"OLOLLLLLLLO",
	"OLLLLLLLLLO",
	".OLLLLLLLMO",
	".OLLLLLLMO.",
	"..OLLLLLMO.",
	"..OOOOOOO..",
]


## En pantallas donde se ve el mouse del sistema (el menú de inicio, los créditos),
## lo reemplaza por la flecha pixel art del juego, agrandada al tamaño de la ventana.
## Sobre los botones aparece la manito. Se vuelve a calcular si cambia el tamaño.
static func aplicar_al_sistema() -> void:
	var arbol := Engine.get_main_loop() as SceneTree
	var ventana := arbol.root
	_poner_cursores_sistema(ventana)
	if not ventana.size_changed.is_connected(_poner_cursores_sistema.bind(ventana)):
		ventana.size_changed.connect(_poner_cursores_sistema.bind(ventana))


static func _poner_cursores_sistema(ventana: Window) -> void:
	var escala := maxi(1, floori(float(ventana.size.y) / 180.0))
	var colores := {"O": O, "L": L, "M": M, "V": V}
	Input.set_custom_mouse_cursor(_agrandada(FLECHA, colores, escala), Input.CURSOR_ARROW, Vector2.ZERO)
	Input.set_custom_mouse_cursor(_agrandada(MANO, colores, escala), Input.CURSOR_POINTING_HAND, Vector2(2, 0) * escala)
	Input.set_custom_mouse_cursor(_agrandada(FLECHA, colores, escala), Input.CURSOR_IBEAM, Vector2.ZERO)


static func _agrandada(filas: Array, colores: Dictionary, escala: int) -> ImageTexture:
	var img := _textura(filas, colores).get_image()
	img.resize(img.get_width() * escala, img.get_height() * escala, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)
