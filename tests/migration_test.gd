extends Node


func _ready() -> void:
	get_tree().create_timer(12.0).timeout.connect(func ():
		push_error("MIGRATION FAIL: timeout")
		get_tree().quit(1)
	)


func run(room: PopochiuRoom) -> void:
	if R.current != room or C.player == null or not room.has_character("Nuna"):
		_fail("Habitacion o personaje no registrados")
		return
	var sprite := C.player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var frames := sprite.sprite_frames
	if frames == null or frames.get_frame_count("flota_frente") != 2 or frames.get_frame_count("flota_derecha") != 3:
		_fail("Animaciones importadas incorrectamente")
		return
	if room.get_node("Background").texture.get_size() != Vector2(320, 152):
		_fail("El fondo no conserva su resolucion")
		return
	await get_tree().physics_frame
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(160, 138)
	event.global_position = event.position
	get_viewport().push_input(event, true)
	await get_tree().process_frame
	if not C.player.is_moving:
		_fail("El clic no inicio movimiento")
		return
	await C.player.movement_ended
	await get_tree().physics_frame
	if C.player.position.distance_to(Vector2(160, 138)) > 2.0:
		print("Click arrival: ", C.player.position, " mouse: ", room.get_local_mouse_position())
		_fail("Nuna no llego al destino del clic")
		return
	await C.player.walk(Vector2(400, 200))
	await get_tree().physics_frame
	if C.player.position.distance_to(Vector2(308, 148)) > 2.0:
		_fail("No se conservaron los limites de movimiento")
		return
	if get_tree().root.has_node("GameState"):
		_fail("Se mezclaron los controladores del prototipo y Popochiu")
		return
	print("MIGRATION PASS: fondo, SpriteFrames Aseprite, personaje Popochiu, clic y limites")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("MIGRATION FAIL: " + message)
	get_tree().quit(1)
