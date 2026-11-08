extends PopochiuInventoryItem

var _reiniciando_coleccion := false


func reiniciar_coleccion() -> void:
	_reiniciando_coleccion = true
	ever_collected = false
	_reiniciando_coleccion = false


func set_ever_collected(value: bool) -> void:
	# Collection is permanent within a game, but a new game starts a new lifetime.
	if _reiniciando_coleccion:
		ever_collected = value
	else:
		super(value)
