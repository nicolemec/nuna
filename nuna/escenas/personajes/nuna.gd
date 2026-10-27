class_name Nuna
extends Node2D
## Nuna flota en línea recta hacia un punto.
## No tiene colisiones: atraviesa paredes y muebles.

signal llego  ## Avisa cuando termina de moverse

const RUTA_PNG := "res://arte/nuna/nuna.png"

@onready var sprite: AnimatedSprite2D = $Sprite

var destino: Vector2
var moviendose: bool = false
var tiempo: float = 0.0
var sprite_y_base: float = 0.0

var _globo: Label = null
var _id_globo: int = 0


func _ready() -> void:
	destino = global_position
	sprite_y_base = sprite.position.y
	var frames: SpriteFrames = AsepriteCargador.crear_desde_tira(RUTA_PNG, Ajustes.NUNA_FRAME_ANCHO, Ajustes.NUNA_FRAME_ALTO, Ajustes.NUNA_ETIQUETAS, Ajustes.NUNA_FPS, Ajustes.ANIMS_SIN_LOOP)
	if frames != null:
		sprite.sprite_frames = frames
		print("Animaciones de Nuna: ", frames.get_animation_names())
	_reproducir(Ajustes.ANIM_QUIETO)


## Le dice a Nuna que flote hasta "punto".
func ir_a(punto: Vector2) -> void:
	destino = punto
	moviendose = true
	_mirar_hacia(destino.x - global_position.x)
	_reproducir(Ajustes.ANIM_MOVIENDO)


## Se da vuelta hacia una posición x (por ejemplo, la de un objeto).
func mirar_a(x: float) -> void:
	_mirar_hacia(x - global_position.x)


## Reproduce la animación de interactuar y después vuelve a quieto.
func interactuar() -> void:
	_reproducir(Ajustes.ANIM_INTERACTUAR)
	await sprite.animation_finished
	if not moviendose:
		_reproducir(Ajustes.ANIM_QUIETO)


## Muestra un globo de texto sobre la cabeza de Nuna.
func decir(texto: String, segundos: float = 2.5) -> void:
	if texto == "":
		return
	if _globo == null:
		_globo = Label.new()
		_globo.add_theme_font_size_override("font_size", 8)
		_globo.add_theme_color_override("font_color", Color.BLACK)
		var fondo := StyleBoxFlat.new()
		fondo.bg_color = Color(1, 1, 1, 0.9)
		fondo.set_content_margin_all(2)
		fondo.set_corner_radius_all(2)
		_globo.add_theme_stylebox_override("normal", fondo)
		_globo.z_index = 20
		add_child(_globo)
	_globo.text = texto
	_globo.reset_size()
	# Centrar el globo sin que se salga de la pantalla
	var ancho: float = _globo.size.x
	var izquierda: float = clampf(global_position.x - ancho / 2.0, 2.0, 318.0 - ancho)
	_globo.position = Vector2(izquierda - global_position.x, -26.0 - _globo.size.y)
	_globo.visible = true
	# Ocultarlo después de unos segundos (si no apareció otro globo antes)
	_id_globo += 1
	var mi_id: int = _id_globo
	await get_tree().create_timer(segundos).timeout
	if mi_id == _id_globo:
		_globo.visible = false


func _process(delta: float) -> void:
	# Flote: sube y baja 1 píxel, aunque esté quieto
	tiempo += delta
	var flote: float = round(sin(tiempo * Ajustes.NUNA_FLOTE_VELOCIDAD) * Ajustes.NUNA_FLOTE_ALTURA)
	sprite.position.y = sprite_y_base + flote

	# Movimiento en línea recta hacia el destino
	if moviendose:
		global_position = global_position.move_toward(destino, Ajustes.NUNA_VELOCIDAD * delta)
		if global_position.distance_to(destino) <= Ajustes.NUNA_DISTANCIA_LLEGADA:
			global_position = destino
			moviendose = false
			_reproducir(Ajustes.ANIM_QUIETO)
			llego.emit()


## Espeja el sprite según hacia dónde va.
func _mirar_hacia(diferencia_x: float) -> void:
	if absf(diferencia_x) < 0.5:
		return
	var va_a_la_izquierda: bool = diferencia_x < 0
	if Ajustes.NUNA_SPRITE_MIRA_A_LA_DERECHA:
		sprite.flip_h = va_a_la_izquierda
	else:
		sprite.flip_h = not va_a_la_izquierda


## Reproduce una animación. Si no existe, usa la primera que haya.
func _reproducir(nombre: StringName) -> void:
	if sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(nombre):
		var disponibles: PackedStringArray = sprite.sprite_frames.get_animation_names()
		if disponibles.is_empty():
			return
		push_warning("No existe la animación '%s'. Uso '%s'. Revisa ajustes.gd" % [nombre, disponibles[0]])
		nombre = StringName(disponibles[0])
	if sprite.animation != nombre or not sprite.is_playing():
		sprite.play(nombre)
