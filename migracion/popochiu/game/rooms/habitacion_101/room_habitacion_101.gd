@tool
extends PopochiuRoom

const Data := preload("room_habitacion_101_state.gd")
const BAUTISMOS := {
	&"radio": "¡Hola, radio! Te llamaré Ramón.",
	&"ventana": "¡Hola, cortina! Te llamaré Doña Cortina.",
	&"ovillo": "¡Hola, ovillo! Te llamaré Ovi.",
}
const FRASES_PROGRESO := ["", "¡Sello uno! Faltan dos.", "¡Dos de tres! ¡Ya casi!", "¡Tres sellos! ¡Ya soy casi profesional!"]
## Dónde queda Ovi cuando Nuna lo usa en la ventana, y cuánto sube Nuna al pararse encima.
const OVI_POS_VENTANA := Vector2(219, 132)
const OVI_ALTURA := 14.0
var state: Data = load("res://game/rooms/habitacion_101/room_habitacion_101.tres")
var ocupado := false
var objeto_seleccionado: ObjetoInteractivo


func _enter_tree() -> void:
	super()
	# La 101 usa capas fijas como el prototipo, no profundidad automática por Y.
	y_sort_enabled = false
	$Props.y_sort_enabled = false
	$Characters.y_sort_enabled = false


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or ocupado or G.is_blocked:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT or E.hovered:
		return
	var destino: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	if destino.y >= Ajustes.UI_Y or not is_instance_valid(C.player):
		return
	_cancelar_seleccion()
	E.clicked = null
	I.set_active_item(null)
	if C.player.is_moving:
		C.player.stop_walking()
	C.player.walk(destino)


func _on_room_entered() -> void:
	if state.visited_first_time:
		C.player.position = Vector2(36, 140)
	$Props/Lumi.combo_sombra_activado.connect(_on_combo_sombra_activado)
	$Props/Lumi.susto_chico.connect($Props/Huesped.temblar)
	$Props/Lumi.fogonazo_realizado.connect($Props/Huesped.asustarse)
	$Props/Ramon.comenzo_a_sonar.connect($Props/Huesped.temblar)
	_restaurar_visual()


func _on_restore_from_savegame() -> void:
	_restaurar_visual()


func _restaurar_visual() -> void:
	ocupado = false
	objeto_seleccionado = null
	$Props/Ramon.sonar() if state.ramon_sonando else $Props/Ramon.mostrar_quieto()
	$Props/Cortina.bailar() if state.cortina_bailando else $Props/Cortina.mostrar_quieta()
	$Props/Lumi.restaurar()
	$Props/Puerta.mostrar_cerrada()
	for obj: ObjetoInteractivo in get_props():
		obj.restaurar_posicion()
		obj.visible = not obj.recogido
		obj.description = obj.nombre_visible()
		if not obj.visible and obj.is_in_group("interactivos"):
			obj.remove_from_group("interactivos")
	if state.ovi_en_ventana:
		_fijar_ovi_en_ventana()
	G.gui.mostrar_habitacion(true)
	_actualizar_guia()


func seleccionar_objeto(obj: ObjetoInteractivo) -> void:
	if ocupado or G.is_blocked or not obj.visible:
		return
	objeto_seleccionado = obj
	_mostrar_contexto_seleccionado()


func objeto_en(punto: Vector2) -> ObjetoInteractivo:
	var elegido: ObjetoInteractivo = null
	var area := INF
	for obj: ObjetoInteractivo in get_props():
		if state.ovi_en_ventana and obj == $Props/Ovillo:
			continue
		if obj.visible and obj.contiene(punto) and obj.tamano.x * obj.tamano.y < area:
			elegido = obj
			area = obj.tamano.x * obj.tamano.y
	return elegido


func seleccionar_ramon() -> void:
	seleccionar_objeto($Props/Ramon)


func usar_objeto(item: PopochiuInventoryItem, objetivo: ObjetoInteractivo) -> void:
	if ocupado or G.is_blocked:
		return
	seleccionar_objeto(objetivo)
	if item.script_name == "Ovillo" and objetivo == $Props/Cortina and objetivo.nombrado:
		await ejecutar_accion("perturbar")
	else:
		ocupado = true
		await E.queue([func (): await _decir("Primero conocé la cortina." if not objetivo.nombrado else "No me ayuda con eso.")])
		ocupado = false


func _seleccion_es_valida() -> bool:
	return is_instance_valid(objeto_seleccionado) and objeto_seleccionado.visible and not Globals.tiene(objeto_seleccionado.id)


func ejecutar_accion(verbo: String) -> void:
	if ocupado or G.is_blocked or not _seleccion_es_valida() or verbo not in ["mirar", "agarrar", "perturbar"]:
		return
	var obj := objeto_seleccionado
	if (verbo == "agarrar" and not obj.puede_agarrar) or (verbo == "perturbar" and not obj.puede_perturbar):
		return
	ocupado = true
	if C.player.is_moving:
		C.player.stop_walking()
	await E.queue([
		C.player.queue_walk(obj.punto_de_uso()),
		func (): await C.player.interactuar(obj.global_position),
		func (): await _resolver_accion(obj, StringName(verbo)),
	])
	ocupado = false
	_actualizar_guia()
	_mostrar_contexto_seleccionado()


func _resolver_accion(obj: ObjetoInteractivo, verbo: StringName) -> void:
	var sellos_antes: int = Globals.sellos
	if obj is Ramon and verbo == Globals.PERTURBAR and obj.nombrado:
		await _perturbar_ramon(obj)
	elif obj is VentanaAnimada and obj.nombrado and (verbo == Globals.PERTURBAR or Globals.tiene(&"ovillo")):
		await _perturbar_ventana(obj)
	elif obj is Lumi:
		var frases: Array[String] = obj.resolver_accion(verbo, state.cortina_bailando)
		for i in range(frases.size()):
			await _decir(frases[i])
			if obj.certificacion_pendiente_despues_de_frase(i):
				await G.gui.ui.mostrar_certificacion(Lumi.FRASE_ETIQUETA, Lumi.FRASE_LETRA_CHICA)
		obj.completar_dialogo()
		await obj.esperar_bloqueo()
	else:
		if verbo == Globals.MIRAR and not obj.nombrado and BAUTISMOS.has(obj.id):
			await _decir(BAUTISMOS[obj.id])
		if verbo == Globals.AGARRAR:
			await I.get_item_instance(String(obj.id).to_pascal_case()).add()
			if not Globals.tiene(obj.id):
				return
		await _decir(obj.ejecutar(verbo))
		if obj.id == &"ovillo" and Globals.tiene(&"ovillo"):
			await _decir("¡Contigo llego a la ventana, Ovi!")
			_brillar($Props/Cortina)
	obj.description = obj.nombre_visible()
	if Globals.sellos > sellos_antes:
		await _decir(FRASES_PROGRESO[Globals.sellos])
		if Globals.sellos >= Globals.SELLOS_TOTALES:
			await _mision_cumplida()


func _perturbar_ramon(ramon: Ramon) -> void:
	if Globals.sellos_obtenidos.has("ramon"):
		await _decir("Ramón ya cantó su parte.")
		return
	Globals.iniciar_goteo()
	state.intentos_ramon += 1
	if state.intentos_ramon == 1:
		ramon._sacudir()
		await _decir("¡Otra vez, Ramón! ¡No se descansa!")
		return
	await ramon.sintonizar()
	state.ramon_sonando = true
	await _decir("¡Ramón canta! ¡Qué miedo!")
	Globals.aumentar_vela(20.0)
	Globals.otorgar_sello(&"ramon")


func _perturbar_ventana(ventana: VentanaAnimada) -> void:
	if state.cortina_bailando:
		await _decir("Ya está bailando. Falta luz.")
		return
	if Globals.tiene(&"ovillo"):
		await _usar_ovi_en_ventana(ventana)
		return
	Globals.iniciar_goteo()
	state.saltos_ventana += 1
	Globals.cambiar_bruma(-2.0)
	await C.player.mini_salto()
	match state.saltos_ventana:
		1: await _decir("¡Hop! …¡Hop! Uf… los profesionales flotan más alto, ¿no?")
		2: await _decir("Todavía soy un fantasma bebé…")
		_:
			if $Props/Ovillo.visible:
				C.player.mirar_a($Props/Ovillo.global_position)
				_brillar($Props/Ovillo)
			await _decir("Si tuviera un escaloncito…")


## Pregunta si usar a Ovi; si dice que sí, Ovi queda en el piso, Nuna se sube y perturba la cortina.
func _usar_ovi_en_ventana(ventana: VentanaAnimada) -> void:
	var usar: bool = await PreguntaSiNo.preguntar(self, "¿Usar a Ovi?")
	if not usar:
		await _decir("Mejor la guardo para después.")
		return
	Globals.iniciar_goteo()
	await _decir("Ovi, ¿me das una mano?")
	await Globals.quitar_objeto(&"ovillo")
	await _poner_ovi_en_ventana()
	await C.player.subir_a(OVI_POS_VENTANA, OVI_ALTURA)
	await C.player.interactuar(ventana.global_position)
	ventana.bailar()
	state.cortina_bailando = true
	$Props/Huesped.temblar()
	await _decir("¡Doña Cortina baila sola!")
	Globals.aumentar_vela(15.0)
	Globals.otorgar_sello(&"ventana")
	await C.player.bajar_a(OVI_POS_VENTANA + Vector2(-18, 6))


func _poner_ovi_en_ventana() -> void:
	state.ovi_en_ventana = true
	_fijar_ovi_en_ventana()
	var ovi: ObjetoInteractivo = $Props/Ovillo
	ovi.position.y = OVI_POS_VENTANA.y - 8.0
	var tw := create_tween()
	tw.tween_property(ovi, "position:y", OVI_POS_VENTANA.y, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tw.finished


## Ovi queda visible en el piso, bajo la ventana, pero ya no se puede clickear.
func _fijar_ovi_en_ventana() -> void:
	var ovi: ObjetoInteractivo = $Props/Ovillo
	ovi.fijar_anclaje(OVI_POS_VENTANA)
	ovi.visible = true
	ovi.clickable = false
	if ovi.is_in_group("interactivos"):
		ovi.remove_from_group("interactivos")


func _on_combo_sombra_activado() -> void:
	state.sombra_gigante_activada = true
	Globals.llenar_vela(Ajustes.LUMI_HABITACION_ID)


func _texto_guia() -> String:
	if Globals.sellos >= Globals.SELLOS_TOTALES:
		return "¡3 de 3 sellos! Turno cumplido."
	if Globals.tiene(&"ovillo"):
		return "Llevá a Ovi a la ventana."
	if $Props/Lumi.estado == Lumi.Estado.NIVEL_3:
		return "Lumi brilla fuerte. Mirala de nuevo."
	if state.intentos_ramon == 1 and not Globals.sellos_obtenidos.has("ramon"):
		return "Ramón no arrancó. Perturbalo otra vez."
	if state.saltos_ventana > 0 and not state.cortina_bailando:
		return "La ventana está alta. Buscá algo para subirte."
	if not ($Props/Lumi.nombrado or $Props/Ramon.nombrado or $Props/Cortina.nombrado):
		return "Hacé clic en un objeto y miralo para conocerlo."
	if Globals.sellos == 0:
		return "Perturbá lo que conociste para asustar a la huésped."
	return "%d de 3 sellos. ¡Seguí asustando!" % Globals.sellos


func _actualizar_guia() -> void:
	G.gui.ui.establecer_guia(_texto_guia())


func _mostrar_contexto_seleccionado() -> void:
	if not _seleccion_es_valida():
		_cancelar_seleccion()
		return
	G.gui.ui.mostrar_objeto(objeto_seleccionado.nombre_visible(), true, objeto_seleccionado.puede_agarrar, objeto_seleccionado.puede_perturbar)
	G.gui.ui.establecer_acciones_habilitadas(not ocupado and not G.is_blocked)


func _cancelar_seleccion() -> void:
	objeto_seleccionado = null
	G.gui.ui.mostrar_exploracion()
	G.gui.ui.establecer_acciones_habilitadas(false)


func _on_room_transition_finished() -> void:
	var testing := false
	for flag in ["migration-test", "ramon-test", "full-test"]:
		if "--" + flag not in OS.get_cmdline_user_args():
			continue
		testing = true
		var meta_key: String = flag.replace("-", "_")
		if not get_tree().has_meta(meta_key):
			get_tree().set_meta(meta_key, true)
			var test: Node = load("res://tests/" + meta_key + ".gd").new()
			add_child(test)
			test.run.call_deferred(self)
		break
	if not testing and not state.entrada_completada:
		ocupado = true
		await E.queue([_reproducir_entrada])
		ocupado = false
		_actualizar_guia()


func _reproducir_entrada() -> void:
	Globals.pausado = true
	C.player.hide()
	await $Props/Puerta.abrir()
	C.player.global_position = $Markers/EntradaNuna.global_position
	C.player.show()
	await C.player.walk($Markers/InicioNuna.global_position)
	C.player.volver_a_reposo_frontal()
	await $Props/Puerta.cerrar()
	await _decir("Los profesionales entran por la puerta, ¿no?")
	await G.gui.ui.mostrar_certificacion("Orden de trabajo: asusta a la huésped y gana 3 sellos.", "(Horas extra no remuneradas.)")
	await _decir("DIN: ¡A asustar, equipo! ♥")
	await _decir("¡Tres sellos y soy profesional!")
	state.entrada_completada = true
	Globals.pausado = false


func _mision_cumplida() -> void:
	if state.mision_completada:
		return
	var orden := OrdenTrabajo.new()
	orden.cumplida = true
	add_child(orden)
	await orden.aceptado
	await _decir("DIN: ¡Bien, equipo! ¡Una más! ♥")
	await _decir("¿Una más?…")
	await _decir("Los profesionales siempre se ponen la 10, ¿no?")
	state.mision_completada = true


func _brillar(nodo: CanvasItem) -> void:
	var tw := create_tween()
	for i in 4:
		tw.tween_property(nodo, "modulate", Color(1.8, 1.8, 1.8), 0.15)
		tw.tween_property(nodo, "modulate", Color.WHITE, 0.15)


func _decir(texto: String) -> void:
	if not texto.is_empty():
		await C.player.say(texto)
