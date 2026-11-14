class_name Toma
extends CanvasLayer
## Un plano a pantalla completa (320x152) que se muestra durante un diálogo:
## el contrato, el registro, el cuaderno. La consola de abajo sigue visible
## y los diálogos avanzan como siempre.
## Uso:
##   var toma := await Toma.mostrar(self, "res://arte/tomas/toma_contrato.png")
##   await _decir("...")
##   await toma.cerrar()
## Si la imagen tiene varios cuadros en una tira horizontal, toma.cuadro(1) cambia de cuadro.
## Para que el jugador participe:
##   await toma.esperar_clic(Rect2i(112, 103, 116, 14), "Hacé clic en la línea para firmar.")
## La zona titila con un marco hasta que el jugador hace clic adentro.
##   toma.dibujar_cruz(Vector2i(165, 104))  # una X de tinta, como firma

const ANCHO := 320
const ALTO := 152
const FUNDIDO := 0.35
const COLOR_MARCO := Color8(251, 242, 54)
const COLOR_TINTA := Color8(34, 32, 52)

signal _zona_tocada

var _imagen: TextureRect
var _atlas: AtlasTexture
var _hud_previo := true
var _zona := Rect2i()
var _esperando := false
var _garabato: AudioStreamPlayer


static func mostrar(padre: Node, ruta_png: String, cuadro_inicial := 0) -> Toma:
	var toma := Toma.new()
	padre.add_child(toma)
	toma._preparar(ruta_png, cuadro_inicial)
	await toma._fundir(1.0)
	return toma


func _preparar(ruta_png: String, cuadro_inicial: int) -> void:
	# Debajo de la interfaz (capa 10): la consola de diálogo queda por encima.
	layer = 9
	var textura: Texture2D = load(ruta_png)
	_atlas = AtlasTexture.new()
	_atlas.atlas = textura
	# La región va antes que la textura: sin región, el atlas mide toda la tira (640 px
	# en el registro) y el cuadro se estiraba al doble de ancho.
	_atlas.region = Rect2(cuadro_inicial * ANCHO, 0, ANCHO, ALTO)
	_imagen = TextureRect.new()
	_imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagen.stretch_mode = TextureRect.STRETCH_SCALE
	_imagen.texture = _atlas
	_imagen.position = Vector2.ZERO
	_imagen.size = Vector2(ANCHO, ALTO)
	_imagen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_imagen.modulate.a = 0.0
	add_child(_imagen)
	cuadro(cuadro_inicial)
	# La barra de arriba taparía el dibujo.
	if is_instance_valid(G.gui) and is_instance_valid(G.gui.ui):
		_hud_previo = G.gui.ui._hud.visible if is_instance_valid(G.gui.ui._hud) else true
		G.gui.ui.mostrar_hud(false)


func cuadro(indice: int) -> void:
	_atlas.region = Rect2(indice * ANCHO, 0, ANCHO, ALTO)


## Espera un clic dentro de la zona (en píxeles del dibujo, 320x152).
func esperar_clic(zona: Rect2i, pista := "") -> void:
	_zona = zona
	var marco := _crear_marco(zona)
	add_child(marco)
	if not pista.is_empty() and is_instance_valid(G.gui):
		G.gui.ui.establecer_guia(pista)
	_esperando = true
	_titilar(marco)
	await _zona_tocada
	_esperando = false
	marco.queue_free()
	if not pista.is_empty() and is_instance_valid(G.gui):
		G.gui.ui.establecer_guia("")


## Una cruz de tinta de 9x9 píxeles con la esquina en la posición indicada.
func dibujar_cruz(esquina: Vector2i) -> void:
	var imagen := Image.create(9, 9, false, Image.FORMAT_RGBA8)
	for i in 9:
		imagen.set_pixel(i, i, COLOR_TINTA)
		imagen.set_pixel(8 - i, i, COLOR_TINTA)
		if i < 8:  # trazo un poco más grueso, como birome
			imagen.set_pixel(i + 1, i, COLOR_TINTA)
	var cruz := TextureRect.new()
	cruz.texture = ImageTexture.create_from_image(imagen)
	cruz.position = esquina
	cruz.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cruz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_imagen.add_child(cruz)
	_rascar()


## El ruidito de la lapicera.
func _rascar() -> void:
	if _garabato == null:
		_garabato = AudioStreamPlayer.new()
		_garabato.stream = Chip.garabato()
		_garabato.volume_db = -10.0
		add_child(_garabato)
	_garabato.play()


func _input(event: InputEvent) -> void:
	if not _esperando:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if Rect2(_zona).grow(2).has_point(event.position):
			_zona_tocada.emit()


func _crear_marco(zona: Rect2i) -> Control:
	var marco := Control.new()
	marco.position = zona.position
	marco.size = zona.size
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for lado in [
		Rect2(0, 0, zona.size.x, 1),
		Rect2(0, zona.size.y - 1, zona.size.x, 1),
		Rect2(0, 0, 1, zona.size.y),
		Rect2(zona.size.x - 1, 0, 1, zona.size.y),
	]:
		var linea := ColorRect.new()
		linea.color = COLOR_MARCO
		linea.position = lado.position
		linea.size = lado.size
		linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marco.add_child(linea)
	return marco


## Prende y apaga el marco a saltos.
func _titilar(marco: Control) -> void:
	while _esperando and is_instance_valid(marco):
		marco.visible = not marco.visible
		await get_tree().create_timer(0.35).timeout


func cerrar() -> void:
	await _fundir(0.0)
	if is_instance_valid(G.gui) and is_instance_valid(G.gui.ui):
		G.gui.ui.mostrar_hud(_hud_previo)
	queue_free()


func _fundir(alfa: float) -> void:
	var tw := create_tween()
	tw.tween_property(_imagen, "modulate:a", alfa, FUNDIDO)
	await tw.finished
