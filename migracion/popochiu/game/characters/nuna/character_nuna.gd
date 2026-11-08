@tool
extends PopochiuCharacter

const Data := preload("character_nuna_state.gd")
var state: Data = load("res://game/characters/nuna/character_nuna.tres")
var _animation := "flota_frente"
var _tiempo_flote := 0.0
var _flotacion_activa := true
@onready var _sprite_base: Vector2 = $AnimatedSprite2D.position


func _process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint():
		return
	_tiempo_flote += delta
	var flote := roundf(sin(_tiempo_flote * Ajustes.NUNA_FLOTE_VELOCIDAD) * Ajustes.NUNA_FLOTE_ALTURA) if _flotacion_activa else 0.0
	$AnimatedSprite2D.position = _sprite_base + Vector2(0, flote)


func walk(target_pos: Vector2) -> void:
	var destination := Vector2(clampf(target_pos.x, 12.0, 308.0), clampf(target_pos.y, 128.0, 148.0))
	await super(destination)


func _play_walk(target_pos: Vector2) -> void:
	var direction := target_pos - position
	if absf(direction.x) > 0.5:
		_animation = "flota_derecha"
		$AnimatedSprite2D.flip_h = direction.x < 0.0
	else:
		_animation = "flota_espalda" if direction.y < 0.0 else "flota_frente"
		$AnimatedSprite2D.flip_h = false
	$AnimatedSprite2D.play(_animation)


func _play_idle() -> void:
	_animation = "flota_frente"
	$AnimatedSprite2D.flip_h = false
	$AnimatedSprite2D.play(_animation)


func _play_talk() -> void:
	_play_idle()


func mirar_a(objeto: Vector2) -> void:
	_play_walk(objeto)


func mini_salto() -> void:
	_flotacion_activa = false
	$AnimatedSprite2D.position = _sprite_base
	$AnimatedSprite2D.flip_h = false
	$AnimatedSprite2D.sprite_frames.set_animation_loop("mini_salto_frente", false)
	$AnimatedSprite2D.play("mini_salto_frente")
	await $AnimatedSprite2D.animation_finished
	volver_a_reposo_frontal()


func volver_a_reposo_frontal() -> void:
	_flotacion_activa = true
	_animation = "flota_frente"
	$AnimatedSprite2D.flip_h = false
	_play_idle()


func interactuar(objeto: Vector2) -> void:
	_flotacion_activa = false
	$AnimatedSprite2D.position = _sprite_base
	var direction := objeto - position
	var lateral := absf(direction.x) >= absf(direction.y)
	var animation := "interactua_lateral" if lateral else "interactua_frente"
	$AnimatedSprite2D.flip_h = lateral and direction.x < 0.0
	$AnimatedSprite2D.sprite_frames.set_animation_loop(animation, false)
	$AnimatedSprite2D.play(animation)
	await $AnimatedSprite2D.animation_finished
	volver_a_reposo_frontal()
