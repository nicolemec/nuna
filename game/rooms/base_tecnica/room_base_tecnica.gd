@tool
extends PopochiuRoom

const Data := preload("room_base_tecnica_state.gd")

var state: Data = load("res://game/rooms/base_tecnica/room_base_tecnica.tres")


func _on_room_entered() -> void:
	G.gui.mostrar_habitacion(false)


func _on_room_transition_finished() -> void:
	$Panel/Verificar.pressed.connect(_verificar_secuencia)
	$Panel/Abrir101.pressed.connect(func (): await R.goto_room("Habitacion101"))
	$Panel/Abrir202.pressed.connect(func (): await R.goto_room("Habitacion202"))
	$Panel/Cinematica3.pressed.connect(_ver_cinematica_3)
	$Panel/Estado.text = "Motor listo. Sin contenido narrativo."
	if "--smoke-test" in OS.get_cmdline_user_args():
		var test := load("res://tests/smoke_test.gd").new() as Node
		add_child(test)
		test.run.call_deferred(self)
	elif "--cold-load-test" in OS.get_cmdline_user_args():
		var test := load("res://tests/cold_load_test.gd").new() as Node
		add_child(test)
		test.run.call_deferred()
	elif "--migration-test" in OS.get_cmdline_user_args() or "--ramon-test" in OS.get_cmdline_user_args() or "--full-test" in OS.get_cmdline_user_args():
		$Panel/Abrir101.pressed.emit()


## Atajo de prueba: deja todo como si Nuna terminara la 202 y la lleva a la recepción.
func _ver_cinematica_3() -> void:
	var recepcion: Resource = load("res://game/rooms/recepcion/room_recepcion.tres")
	recepcion.paso = 3
	recepcion.cinematica_2 = true
	recepcion.cinematica_3 = false
	var hab_202: Resource = load("res://game/rooms/habitacion_202/room_habitacion_202.tres")
	hab_202.mision_completada = true
	await R.goto_room("Recepcion")


func _verificar_secuencia() -> void:
	$Panel/Verificar.disabled = true
	$Panel/Estado.text = "Ejecutando secuencia de Popochiu..."
	await E.queue([
		E.queue_wait(0.2),
		func (): $Panel/Estado.text = "Secuencia completada. Base operativa."
	])
	$Panel/Verificar.disabled = false
