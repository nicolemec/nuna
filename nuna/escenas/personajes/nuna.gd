class_name Nuna
extends Node2D
## Nuna flota en línea recta hacia un punto.
## No tiene colisiones: atraviesa paredes y muebles.

signal llego  ## Avisa cuando termina de moverse
signal dialogo_solicitado(texto: String, id: int)
signal dialogo_finalizado(id: int)

const RUTA_PNG := "res://arte/nuna/nuna.png"

@onready var sprite: AnimatedSprite2D = $Sprite

var destino: Vector2
var moviendose: bool = false
var tiempo: float = 0.0
var sprite_y_base: float = 0.0
var _flotacion_activa: bool = true
var _orientacion_fondo: bool = false
var _orientacion_lateral: bool = false
var _interaccion_lateral: bool = false

var _id_dialogo: int = 0
var _aviso_dialogo_sin_ui: bool = false


func _ready() -> void:
	destino = global_position
	sprite_y_base = sprite.position.y
	var frames: SpriteFrames = AsepriteCargador.crear_desde_tira(
		RUTA_PNG,
		Ajustes.NUNA_FRAME_ANCHO,
		Ajustes.NUNA_FRAME_ALTO,
		Ajustes.NUNA_ETIQUETAS,
		Ajustes.NUNA_FPS,
		Ajustes.ANIMS_SIN_LOOP,
		Ajustes.NUNA_DURACIONES_MS
	)
	if frames != null:
		sprite.sprite_frames = frames
		print("Animaciones de Nuna: ", frames.get_animation_names())
	_reproducir(Ajustes.ANIM_FLOTA_FRENTE)


## Le dice a Nuna que flote hasta "punto".
func ir_a(punto: Vector2) -> void:
	destino = punto
	moviendose = true
	var diferencia: Vector2 = destino - global_position
	if absf(diferencia.x) < Ajustes.NUNA_UMBRAL_ORIENTACION:
		_orientacion_lateral = false
		_orientacion_fondo = diferencia.y < -Ajustes.NUNA_UMBRAL_ORIENTACION
		sprite.flip_h = false
		_reproducir(_animacion_flote_actual())
	else:
		_orientacion_lateral = true
		_orientacion_fondo = false
		_mirar_hacia(diferencia.x)
		_reproducir(Ajustes.ANIM_FLOTA_DERECHA)


## Orienta a Nuna hacia un objeto.
func mirar_a(posicion: Vector2) -> void:
	var diferencia: Vector2 = posicion - global_position
	var domina_vertical: bool = absf(diferencia.y) > absf(diferencia.x)
	if domina_vertical:
		_interaccion_lateral = false
		_orientacion_lateral = false
		_orientacion_fondo = diferencia.y < 0.0
		sprite.flip_h = false
	else:
		_interaccion_lateral = true
		_orientacion_lateral = true
		_orientacion_fondo = false
		_mirar_hacia(diferencia.x)


## Reproduce la interacción y después vuelve al reposo frontal.
func interactuar() -> void:
	_flotacion_activa = false
	sprite.position.y = sprite_y_base
	var animacion: StringName = Ajustes.ANIM_INTERACTUA_FRENTE
	if _interaccion_lateral:
		animacion = Ajustes.ANIM_INTERACTUA_LATERAL
	if not _preparar_animacion_finita(animacion):
		_volver_a_reposo_frontal()
		return
	sprite.stop()
	sprite.play(animacion)
	await sprite.animation_finished
	_volver_a_reposo_frontal()


## Reproduce el intento fallido de alcanzar algo; no mueve el nodo raíz.
func mini_salto() -> void:
	_flotacion_activa = false
	sprite.position.y = sprite_y_base
	if not _preparar_animacion_finita(Ajustes.ANIM_MINI_SALTO):
		_volver_a_reposo_frontal()
		return
	sprite.flip_h = false
	sprite.stop()
	sprite.play(Ajustes.ANIM_MINI_SALTO)
	await sprite.animation_finished
	_volver_a_reposo_frontal()


## Placeholder hasta que el asset vuelva a incluir el tag dormiditu.
func dormir() -> void:
	_flotacion_activa = false
	sprite.position.y = sprite_y_base
	_reproducir(Ajustes.ANIM_FLOTA_FRENTE)
	await get_tree().create_timer(Ajustes.NUNA_DORMIR_SEGUNDOS).timeout
	_volver_a_reposo_frontal()


## Solicita un diálogo a la UI y espera su duración habitual.
func decir(texto: String, segundos: float = 2.5) -> void:
	if texto == "":
		return
	_id_dialogo += 1
	var mi_id: int = _id_dialogo
	var pausa_previa: bool = GameState.pausado
	GameState.pausado = true

	if get_signal_connection_list(&"dialogo_solicitado").is_empty():
		if not _aviso_dialogo_sin_ui:
			push_warning("Nuna no tiene una UI conectada para mostrar diálogos.")
			_aviso_dialogo_sin_ui = true
	else:
		dialogo_solicitado.emit(texto, mi_id)

	await get_tree().create_timer(segundos).timeout
	dialogo_finalizado.emit(mi_id)

	if mi_id == _id_dialogo:
		GameState.pausado = pausa_previa


func _process(delta: float) -> void:
	tiempo += delta
	if _flotacion_activa:
		var flote: float = round(
			sin(tiempo * Ajustes.NUNA_FLOTE_VELOCIDAD)
			* Ajustes.NUNA_FLOTE_ALTURA
		)
		sprite.position.y = sprite_y_base + flote
	else:
		sprite.position.y = sprite_y_base

	# Movimiento en línea recta hacia el destino
	if moviendose:
		global_position = global_position.move_toward(destino, Ajustes.NUNA_VELOCIDAD * delta)
		if global_position.distance_to(destino) <= Ajustes.NUNA_DISTANCIA_LLEGADA:
			global_position = destino
			moviendose = false
			_volver_a_reposo_frontal()
			llego.emit()


func _animacion_flote_actual() -> StringName:
	if _orientacion_fondo:
		return Ajustes.ANIM_FLOTA_ESPALDA
	if _orientacion_lateral:
		return Ajustes.ANIM_FLOTA_DERECHA
	return Ajustes.ANIM_FLOTA_FRENTE


func _preparar_animacion_finita(nombre: StringName) -> bool:
	if sprite.sprite_frames == null:
		push_warning("No se puede reproducir '%s': SpriteFrames no está asignado" % nombre)
		return false
	if not sprite.sprite_frames.has_animation(nombre):
		push_warning("No existe la animación '%s'; se vuelve a la flotación" % nombre)
		return false
	if sprite.sprite_frames.get_animation_loop(nombre):
		push_warning("La animación '%s' tiene loop y no puede usarse como interacción finita" % nombre)
		return false
	return true


func _volver_a_reposo_frontal() -> void:
	_orientacion_fondo = false
	_orientacion_lateral = false
	_interaccion_lateral = false
	sprite.flip_h = false
	sprite.position.y = sprite_y_base
	_flotacion_activa = true
	_reproducir(Ajustes.ANIM_FLOTA_FRENTE)


func volver_a_reposo_frontal() -> void:
	_volver_a_reposo_frontal()


## Espeja el sprite según hacia dónde va.
func _mirar_hacia(diferencia_x: float) -> void:
	if absf(diferencia_x) < Ajustes.NUNA_UMBRAL_ORIENTACION:
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
		push_warning("No existe la animación '%s'. Se vuelve al reposo frontal." % nombre)
		if nombre != Ajustes.ANIM_FLOTA_FRENTE:
			_volver_a_reposo_frontal()
		return
	if sprite.animation != nombre or not sprite.is_playing():
		sprite.play(nombre)
