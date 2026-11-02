extends CharacterBody2D

@export var velocidad := 120.0
@export var amplitud_flote := 4.0
@export var frecuencia_flote := 2.0

var t := 0.0
@onready var sprite := $Sprite2D

func _physics_process(delta):
	# Sin gravedad: el movimiento es libre en X e Y
	var dir := Input.get_vector("izquierda", "derecha", "arriba", "abajo")
	velocity = dir * velocidad
	move_and_slide()

	# Oscila solo el sprite, no el cuerpo, para que la colisión no tiemble
	t += delta
	sprite.position.y = sin(t * frecuencia_flote) * amplitud_flote
