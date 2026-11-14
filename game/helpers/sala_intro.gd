@tool
class_name SalaIntro
extends PopochiuRoom
## Base de las salas de la intro: Teatro, Calle y Recepción.
## Usa el mismo esquema que room_habitacion_101.gd (clic para caminar, seleccionar un
## objeto, elegir un verbo en la consola), pero sin sellos, bruma ni huésped.
## Las zonas con accion_directa (carteles, puertas, timbre) responden con un solo clic.

## Nuna lleva birrete en toda la intro (lo lee character_nuna.gd al entrar a la sala).
var nuna_con_birrete := true
## La intro es corta y no se guarda a mitad de camino (lo consulta gui.gd).
var permite_guardar := false
## Línea del piso: en la intro Nuna solo se mueve a izquierda y derecha.
@export var piso_y := 146.0
## Muestra la consola de abajo (diálogos y verbos). El teatro no la usa.
@export var con_consola := true

var ocupado := false
var objeto_seleccionado: ObjetoInteractivo
var _saliendo := false


func _enter_tree() -> void:
	super()
	# Igual que la 101: capas fijas, no profundidad automática por Y.
	y_sort_enabled = false
	$Props.y_sort_enabled = false
	$Characters.y_sort_enabled = false


## Popochiu centra las salas anchas alrededor de la pantalla; acá el fondo empieza en x = 0.
func setup_camera() -> void:
	E.camera.limit_left = 0
	E.camera.limit_right = maxi(width, 320)
	E.camera.limit_top = 0
	E.camera.limit_bottom = 180


func _on_room_entered() -> void:
	_ocultar_mouse_del_sistema()
	Musica.tocar(&"intro")
	ocupado = false
	objeto_seleccionado = null
	G.gui.mostrar_habitacion(con_consola, false)
	C.player.poner_birrete(nuna_con_birrete)
	_poner_alfa_nuna(_alfa_nuna(), false)
	C.camera_owner = C.player
	if con_consola:
		_cancelar_seleccion()
		_actualizar_guia()


## En la intro la cámara se mueve, y el "hover" de Popochiu puede quedar pegado a un objeto
## que ya pasó (los clics no respondían). Por eso acá el clic se resuelve directo: si cae
## dentro del rectángulo de un objeto, se selecciona; si no, Nuna camina.
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or ocupado or G.is_blocked:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var destino: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	if destino.y >= Ajustes.UI_Y or not is_instance_valid(C.player):
		return
	# Que no lo procese también el clic de Popochiu (llegaría dos veces).
	get_viewport().set_input_as_handled()
	var obj := objeto_en(destino)
	if obj != null:
		E.clicked = null
		seleccionar_objeto(obj)
		return
	_cancelar_seleccion()
	E.clicked = null
	I.set_active_item(null)
	if C.player.is_moving:
		C.player.stop_walking()
	C.player.walk(Vector2(destino.x, piso_y))


## Solo se ve el cursor del juego (el violeta). El del sistema vuelve a aparecer a veces
## al cambiar de ventana, así que se oculta otra vez al entrar a la sala y al volver el foco.
func _ocultar_mouse_del_sistema() -> void:
	if not Engine.is_editor_hint():
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_MOUSE_ENTER:
		_ocultar_mouse_del_sistema()


# ---------- Lo que llaman los objetos (mismo contrato que la 101) ----------

func seleccionar_objeto(obj: ObjetoInteractivo) -> void:
	if ocupado or G.is_blocked or not obj.visible or not obj.clickable:
		return
	objeto_seleccionado = obj
	if obj is ZonaIntro and obj.accion_directa:
		await ejecutar_accion(Globals.MIRAR)
	else:
		_mostrar_contexto_seleccionado()


func objeto_en(punto: Vector2) -> ObjetoInteractivo:
	var elegido: ObjetoInteractivo = null
	var area := INF
	for obj in get_props():
		if not obj is ObjetoInteractivo or not obj.visible or not obj.clickable:
			continue
		if obj.contiene(punto) and obj.tamano.x * obj.tamano.y < area:
			elegido = obj
			area = obj.tamano.x * obj.tamano.y
	return elegido


func usar_objeto(_item: PopochiuInventoryItem, objetivo: ObjetoInteractivo) -> void:
	seleccionar_objeto(objetivo)


func _seleccion_es_valida() -> bool:
	return is_instance_valid(objeto_seleccionado) and objeto_seleccionado.visible and objeto_seleccionado.clickable


func ejecutar_accion(verbo: String) -> void:
	if ocupado or G.is_blocked or not _seleccion_es_valida():
		return
	var obj := objeto_seleccionado
	if (verbo == Globals.AGARRAR and not obj.puede_agarrar) or (verbo == Globals.PERTURBAR and not obj.puede_perturbar):
		return
	ocupado = true
	_actualizar_guia()
	G.gui.ui.establecer_acciones_habilitadas(false)
	if C.player.is_moving:
		C.player.stop_walking()
	await E.queue([
		C.player.queue_walk(obj.punto_de_uso()),
		func (): await C.player.interactuar(obj.global_position),
		func (): await _resolver_accion(obj, StringName(verbo)),
	])
	if _saliendo:
		# E.queue desbloquea la GUI al terminar: durante el cambio de sala tiene que seguir bloqueada.
		G.block()
		return
	ocupado = false
	_actualizar_guia()
	if obj is ZonaIntro and obj.accion_directa:
		_cancelar_seleccion()
	else:
		_mostrar_contexto_seleccionado()


## Cada sala decide qué pasa. Por defecto, lo mismo que en la 101.
func _resolver_accion(obj: ObjetoInteractivo, verbo: StringName) -> void:
	await _decir(obj.ejecutar(verbo))


# ---------- Consola ----------

## La línea guía de la consola cuando no hay nada seleccionado.
func _texto_guia() -> String:
	return ""


## Mientras pasa algo (una charla, una acción), la consola no muestra instrucciones:
## si no, la del paso anterior quedaba colgada entre línea y línea.
func _actualizar_guia() -> void:
	if con_consola:
		G.gui.ui.establecer_guia("" if ocupado else _texto_guia())


func _mostrar_contexto_seleccionado() -> void:
	if not _seleccion_es_valida():
		_cancelar_seleccion()
		return
	G.gui.ui.mostrar_objeto(objeto_seleccionado.nombre_visible(), true, objeto_seleccionado.puede_agarrar, objeto_seleccionado.puede_perturbar)
	G.gui.ui.establecer_acciones_habilitadas(not ocupado and not G.is_blocked)


func _cancelar_seleccion() -> void:
	objeto_seleccionado = null
	if con_consola:
		G.gui.ui.mostrar_exploracion()
		G.gui.ui.establecer_acciones_habilitadas(false)


## Nuna habla. Las líneas de otros personajes van con prefijo, como en la 101 ("LUMI: …").
func _decir(texto: String) -> void:
	if not texto.is_empty():
		await C.player.say(texto)


## Pasa a otra sala. Sin await: esta sala se libera durante el cambio.
func _ir_a(sala: String) -> void:
	_saliendo = true
	ocupado = true
	_cancelar_seleccion()
	R.goto_room(sala)


# ---------- Bruma de Nuna ----------
## Sin Bruma, Nuna se va desvaneciendo. La transparencia viaja entre salas
## como metadato del personaje (Popochiu reutiliza la misma instancia).

func _alfa_nuna() -> float:
	return C.player.get_meta("alfa_intro", 1.0)


func _poner_alfa_nuna(alfa: float, guardar := true) -> void:
	C.player.modulate.a = alfa
	if guardar:
		C.player.set_meta("alfa_intro", alfa)


# ---------- Cámara ----------

## Lleva la cámara hasta x sin mover a Nuna (para mostrar algo que pasa lejos).
func mover_camara_a(x: float, segundos: float) -> void:
	C.camera_owner = null
	var tw := create_tween()
	Pixel.mover(tw, E.camera, "position:x", x, segundos)
	await tw.finished


## La cámara vuelve a seguir a Nuna.
func devolver_camara(segundos := 0.6) -> void:
	await mover_camara_a(C.player.global_position.x, segundos)
	C.camera_owner = C.player


## Saca un objeto de juego (deja de ser clickeable).
func _retirar(obj: ObjetoInteractivo) -> void:
	obj.clickable = false
	if obj is ZonaIntro:
		obj.resaltar = false
	if obj.is_in_group("interactivos"):
		obj.remove_from_group("interactivos")
	if objeto_seleccionado == obj:
		_cancelar_seleccion()


## Vuelve a habilitar un objeto y lo hace latir para que se note.
func _habilitar(obj: ObjetoInteractivo) -> void:
	obj.clickable = true
	if obj is ZonaIntro:
		obj.resaltar = true
	if not obj.is_in_group("interactivos"):
		obj.add_to_group("interactivos")
