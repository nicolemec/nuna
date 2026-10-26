class_name Nuna
extends Node2D
## Nuna flota en línea recta hacia un punto.
## No tiene colisiones: atraviesa paredes y muebles.

signal llego  ## Avisa cuando termina de moverse (lo usaremos con los verbos)

const RUTA_PNG := "res://arte/nuna/nuna.png"

@onready var sprite: AnimatedSprite2D = $Sprite

var destino: Vector2
var moviendose: bool = false
var tiempo: float = 0.0
var sprite_y_base: float = 0.0


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


## Reproduce una animación. Si no existe, usa la primera que haya
## (así Nuna nunca queda invisible por un nombre mal escrito).
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
