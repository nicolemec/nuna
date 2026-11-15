class_name LaptopBruno
extends ObjetoAnimado
## La laptop de Bruno: normal → recalienta → humo → quemada (como Lumi en la 101).
## Por ahora se quema al perturbarla; cuando exista el reloj, la sala lo cambia
## por el puzzle de "PARA AYER" (ver el documento, sello 1 de la 202).

signal se_quemo

enum Estado { NORMAL, QUEMANDOSE, QUEMADA }
var estado: Estado = Estado.NORMAL


func reaccionar() -> void:
	if estado != Estado.NORMAL:
		_sacudir()
		return
	estado = Estado.QUEMANDOSE
	reproducir(&"recalienta")
	await _anim.animation_looped
	reproducir(&"humo")
	await _anim.animation_looped
	await _anim.animation_looped
	quemar()


func quemar() -> void:
	estado = Estado.QUEMADA
	anim_reposo = &"quemada"
	reproducir(&"quemada")
	_anim.sprite_frames.set_animation_loop(&"quemada", false)
	frase_mirar = "La pantalla quedó negra y brilla como un espejo… ¡Ahí estoy yo!"
	se_quemo.emit()


func _on_vuelta() -> void:
	if estado == Estado.NORMAL:
		super()
