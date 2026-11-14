class_name ViejoRecepcion
extends Node2D
## El fantasma veterano de la recepción. No es clickeable: solo aparece, habla y se va.
## Usa arte/viejo/viejo.png (+ .json): neutral, habla, suspira, desaparece, aparece.
## El punto (0, 0) del nodo son sus pies.

const RUTA_PNG := "res://arte/viejo/viejo.png"
const RUTA_JSON := "res://arte/viejo/viejo.json"
const SIN_LOOP := ["suspira", "desaparece", "aparece"]
## El dibujo original mira a la derecha. Con estos desplazamientos el cuerpo queda
## en el mismo lugar mire para donde mire (cuadros de 62 px, cuerpo centrado en x = 16).
const X_MIRA_DERECHA := -16.0
const X_MIRA_IZQUIERDA := -45.0

var _sprite: AnimatedSprite2D


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.centered = false
	_sprite.position = Vector2(-16, -81)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.sprite_frames = SpriteJson.cargar(RUTA_JSON, RUTA_PNG, {}, SIN_LOOP)
	add_child(_sprite)
	hide()


## Siempre mira hacia Nuna (espejado si Nuna está a la izquierda).
func _process(_delta: float) -> void:
	if not visible or not is_instance_valid(C.player):
		return
	var a_la_izquierda := C.player.global_position.x < global_position.x
	_sprite.flip_h = a_la_izquierda
	_sprite.position.x = X_MIRA_IZQUIERDA if a_la_izquierda else X_MIRA_DERECHA


func aparecer(en: Vector2) -> void:
	position = en
	show()
	_sprite.play(&"aparece")
	await _sprite.animation_finished
	_sprite.play(&"neutral")


func desaparecer() -> void:
	_sprite.play(&"desaparece")
	await _sprite.animation_finished
	hide()


func suspirar() -> void:
	_sprite.play(&"suspira")
	await _sprite.animation_finished
	_sprite.play(&"neutral")


func hablar(activo: bool) -> void:
	_sprite.play(&"habla" if activo else &"neutral")


## Flota hasta x (no tiene animación de caminar: es un fantasma).
func flotar_a(x: float, segundos: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "position:x", x, segundos).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
