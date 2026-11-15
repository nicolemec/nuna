class_name PuertaHabitacion
extends ObjetoAnimado
## Puerta animada de una habitación, igual que la de la 101: cerrada, abre, abierta, cierra.
## abrir() y cerrar() esperan a que termine la animación.


func _ready() -> void:
	super._ready()
	for anim in [&"abre", &"cierra"]:
		if tiene_animacion(anim):
			_anim.sprite_frames.set_animation_loop(anim, false)


func mostrar_cerrada() -> void:
	anim_reposo = &"cerrada"
	reproducir(&"cerrada")


func abrir() -> void:
	if reproducir(&"abre"):
		await _anim.animation_finished
	anim_reposo = &"abierta"
	reproducir(&"abierta")


func cerrar() -> void:
	if reproducir(&"cierra"):
		await _anim.animation_finished
	mostrar_cerrada()


func _on_terminada() -> void:
	pass
