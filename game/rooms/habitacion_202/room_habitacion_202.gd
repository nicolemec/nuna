@tool
extends PopochiuRoom
## Habitación 202: Bruno. Mismo esquema que la 101 (clic para caminar, elegir objeto,
## Mirar/Agarrar/Perturbar). Nuna ya aprendió a presentarse en la 101: acá puede perturbar
## sin mirar primero, y la guía muestra el objetivo en lugar del tutorial.
## Sellos: la compu (minijuego de mails), la cafetera (minijuego de la receta) y el
## reloj a las 3 (después de leer el DEADLINE del calendario).

const Data := preload("room_habitacion_202_state.gd")
const FRASES_PROGRESO := ["", "¡Sello uno! Faltan dos.", "¡Dos de tres! ¡Ya casi!", "¡Tres sellos!"]
const MIEDO_PRIMER_SUSTO := 5.0
const MIEDO_RESPUESTA := 8.0
const MIEDO_SELLO := 20.0
const COSTO_ERROR := 2.0
const RECETA := {"cafe": 9, "agua": 3, "azucar": 8}

var state: Data = load("res://game/rooms/habitacion_202/room_habitacion_202.tres")
var ocupado := false
var objeto_seleccionado: ObjetoInteractivo


func _enter_tree() -> void:
	super()
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
	Musica.tocar(&"habitacion")
	C.player.position = $Markers/InicioNuna.position
	$Props/Laptop.se_quemo.connect(func (): state.laptop_quemada = true)
	if not state.entrada_completada:
		_empezar_turno()
	_restaurar_visual()


## Turno nuevo: los sellos y el miedo son de cada habitación.
func _empezar_turno() -> void:
	Globals.sellos = 0
	Globals.sellos_obtenidos.clear()
	Globals.sellos_cambiados.emit(0)
	Globals.vela_101 = 0.0
	Globals.aumentar_vela(0.0)
	Globals.iniciar_goteo()


func _on_restore_from_savegame() -> void:
	_restaurar_visual()


func _restaurar_visual() -> void:
	ocupado = false
	objeto_seleccionado = null
	for obj: ObjetoInteractivo in get_props():
		obj.restaurar_posicion()
		obj.visible = not obj.recogido
		obj.description = obj.nombre_visible()
	if state.laptop_quemada:
		$Props/Laptop.quemar()
	if state.taza_con_dientes:
		_poner_dientes_a_taza()
	if state.mision_completada:
		$Props/Bruno.asustarse()
	G.gui.mostrar_habitacion(true)
	_actualizar_guia()


func _on_room_transition_finished() -> void:
	if not state.entrada_completada:
		state.entrada_completada = true
		ocupado = true
		await E.queue([
			func (): await _decir("¡La 202! Acá vive alguien que no duerme mucho."),
			func (): await _decir("DIN: ¡Nuevo turno, equipo! Tres sellos y a otra cosa. ♥"),
		])
		ocupado = false
		_actualizar_guia()


func seleccionar_objeto(obj: ObjetoInteractivo) -> void:
	if ocupado or G.is_blocked or not obj.visible:
		return
	objeto_seleccionado = obj
	_mostrar_contexto_seleccionado()


## El objeto más chico bajo el punto (así la laptop gana sobre el escritorio).
func objeto_en(punto: Vector2) -> ObjetoInteractivo:
	var elegido: ObjetoInteractivo = null
	var area := INF
	for obj: ObjetoInteractivo in get_props():
		if obj.visible and obj.contiene(punto) and obj.tamano.x * obj.tamano.y < area:
			elegido = obj
			area = obj.tamano.x * obj.tamano.y
	return elegido


func usar_objeto(item: PopochiuInventoryItem, objetivo: ObjetoInteractivo) -> void:
	if ocupado or G.is_blocked:
		return
	seleccionar_objeto(objetivo)
	ocupado = true
	if item.script_name == "Dentadura" and objetivo == $Props/Taza and not state.taza_con_dientes:
		await E.queue([
			C.player.queue_walk(objetivo.punto_de_uso()),
			func (): await _decir("¡Don Mordisquito, te presento a la taza!"),
		])
		state.taza_con_dientes = true
		_poner_dientes_a_taza()
		await _decir("Ahora sí: «Sonreír es parte del trabajo».")
	else:
		await E.queue([func (): await _decir("No me ayuda con eso.")])
	ocupado = false
	_actualizar_guia()


func _seleccion_es_valida() -> bool:
	return is_instance_valid(objeto_seleccionado) and objeto_seleccionado.visible


func ejecutar_accion(verbo: String) -> void:
	if ocupado or G.is_blocked or not _seleccion_es_valida() or verbo not in ["mirar", "agarrar", "perturbar"]:
		return
	var obj := objeto_seleccionado
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
	if verbo == Globals.PERTURBAR:
		await _perturbar(obj)
	else:
		await _decir(obj.ejecutar(verbo))
	obj.description = obj.nombre_visible()
	if Globals.sellos > sellos_antes:
		await _decir(FRASES_PROGRESO[Globals.sellos])
		if Globals.sellos >= Globals.SELLOS_TOTALES:
			await _mision_cumplida()


func _perturbar(obj: ObjetoInteractivo) -> void:
	if obj == $Props/Laptop and not state.laptop_quemada:
		await _minijuego_laptop()
		return
	if obj == $Props/Cafetera and not state.cafe_listo:
		await _minijuego_cafetera()
		return
	if obj == $Props/Reloj and not state.alarma_sonada and $Props/Calendario.nombrado:
		await _alarma_deadline()
		return
	if obj is ObjetoAnimado:
		obj.reaccionar()
	_sumar_miedo_primera_vez(obj)
	if obj == $Props/Reloj and not state.alarma_sonada:
		await _decir("¡Las agujas van para atrás! ¿Qué hora le importará al muchacho?")
		return
	if obj == $Props/Taza and state.taza_con_dientes:
		$Props/Taza.reproducir(&"castanetea")
		await _decir("¡Castañetea! Pero sin vapor no asusta tanto.")
		$Props/Taza.mostrar_reposo()
		return
	await _decir(obj.frase_perturbar if not obj.frase_perturbar.is_empty() else "¡Buu!")


## El primer susto de cada objeto suma un poquito de miedo.
func _sumar_miedo_primera_vez(obj: ObjetoInteractivo) -> void:
	if obj == $Props/Bruno or state.perturbados.has(String(obj.name)):
		return
	state.perturbados.append(String(obj.name))
	Globals.aumentar_vela(MIEDO_PRIMER_SUSTO)


func _equivocarse(frase: String) -> void:
	Globals.cambiar_bruma(-COSTO_ERROR)
	await _decir(frase)
	await _decir("Uy, eso me costó bruma.")


# ---------- Minijuego 1: la bandeja de entrada de la compu ----------

func _minijuego_laptop() -> void:
	await _decir("Tiene mails sin leer. ¡Los contesto yo! Al pie de la letra, como corresponde.")
	Globals.pausado = true
	var panel := BandejaLaptop.new()
	add_child(panel)
	panel.cerrado.connect(func (): panel.elegido.emit(-1))
	while state.mails_resueltos < BandejaLaptop.MAILS.size():
		panel.mostrar(state.mails_resueltos)
		var respuesta: int = await panel.elegido
		if respuesta < 0:
			break
		var mail: Dictionary = BandejaLaptop.MAILS[state.mails_resueltos]
		panel.bloquear(true)
		if respuesta == mail.correcta:
			state.mails_resueltos += 1
			$Props/Laptop._sacudir()
			Globals.aumentar_vela(MIEDO_RESPUESTA)
			$Props/Bruno.temblar()
			await _decir(mail.ok)
		else:
			await _equivocarse(mail.mal[respuesta])
		panel.bloquear(false)
	Globals.pausado = false
	if state.mails_resueltos < BandejaLaptop.MAILS.size():
		await _decir("La dejo para después. Total, la compu nunca se va a dormir.")
		return
	panel.cerrar()
	$Props/Laptop.reaccionar()
	await get_tree().create_timer(2.2).timeout
	await _decir("¡Se quemó por trabajar sin parar! Igual que Lumi.")
	$Props/Bruno.temblar()
	Globals.aumentar_vela(MIEDO_SELLO)
	Globals.otorgar_sello(&"laptop_202")


# ---------- Minijuego 2: el café del deadline ----------

func _minijuego_cafetera() -> void:
	await _decir("Tiene una receta pegada. ¡Le preparo el café del deadline!")
	Globals.pausado = true
	var panel := CafeteraPanel.new()
	add_child(panel)
	var listo := false
	panel.cerrado.connect(func (): panel.preparado.emit(-1, -1, -1))
	while not listo:
		var resultado: Array = await _esperar_preparado(panel)
		if resultado[0] < 0:
			break
		panel.bloquear(true)
		var cafe: int = resultado[0]
		var agua: int = resultado[1]
		var azucar: int = resultado[2]
		if cafe + agua > CafeteraPanel.MAXIMO:
			await _equivocarse("¡Rebalsa! Eso no entra en la jarra.")
		elif cafe + agua < CafeteraPanel.MAXIMO:
			await _equivocarse("La jarra quedó a medias. La receta dice 12 justas.")
		elif cafe < agua * 3:
			await _equivocarse("Muy aguado. Bruno ni se mosquea.")
		elif cafe > agua * 3:
			await _equivocarse("¡Demasiado fuerte! Ni la cafetera se lo banca.")
		elif azucar != RECETA.azucar:
			await _equivocarse("El azúcar no da. ¿Cuántas noches lleva sin dormir? Algo tachó…")
		else:
			listo = true
		panel.bloquear(false)
	Globals.pausado = false
	if not listo:
		await _decir("Después termino el café. El muchacho igual no se va a dormir.")
		return
	panel.cerrar()
	state.cafe_listo = true
	$Props/Cafetera.anim_reposo = &"vapor"
	$Props/Cafetera.reproducir(&"vapor")
	await _decir("¡Café cargadísimo! Echa tanto vapor que hace temblar todo.")
	if state.taza_con_dientes:
		$Props/Taza.reproducir(&"castanetea")
		await _decir("¡Y la taza castañetea con el vapor! Parece que habla…")
	else:
		$Props/Taza._sacudir()
		await _decir("La taza tiembla con el vapor. Si tuviera dientes, castañetearía…")
	$Props/Bruno.temblar()
	Globals.aumentar_vela(MIEDO_SELLO)
	Globals.otorgar_sello(&"cafetera_202")


func _esperar_preparado(panel: CafeteraPanel) -> Array:
	var resultado: Array = []
	var guardar := func (c: int, a: int, z: int): resultado.assign([c, a, z])
	panel.preparado.connect(guardar, CONNECT_ONE_SHOT)
	await panel.preparado
	return resultado


# ---------- Sello 3: el reloj a las 3 ----------

func _alarma_deadline() -> void:
	state.alarma_sonada = true
	$Props/Reloj.reproducir(&"gira_atras")
	await _decir("Si el DEADLINE es a las 3… ¡pongo el reloj a las 3!")
	$Props/Reloj.reproducir(&"alarma")
	await _decir("¡RIIING! ¡Llegó la línea muerta!")
	$Props/Reloj.mostrar_reposo()
	$Props/Bruno.temblar()
	Globals.aumentar_vela(MIEDO_SELLO)
	Globals.otorgar_sello(&"reloj_202")


# ---------- Final de la 202 ----------

func _mision_cumplida() -> void:
	if state.mision_completada:
		return
	state.mision_completada = true
	Globals.llenar_vela(Ajustes.LUMI_HABITACION_ID)
	$Props/Bruno.asustarse()
	await get_tree().create_timer(1.6).timeout
	await _decir("¡Bruno se sentó en la cama!")
	$Props/Telefono.reproducir(&"vibra")
	await _decir("Le vibra el teléfono…")
	await G.gui.ui.mostrar_certificacion("«Gracias por tu propuesta. Esta vez elegimos a otro perfil. ¡Éxitos!»", "(Enviado a las 3:00.)")
	$Props/Telefono.mostrar_reposo()
	await _decir("No fue el fantasma. Fue darlo todo y que igual no alcance.")
	await _decir("Bruno se quemó como la compu. A la compu la pueden cambiar.")
	await _decir("DIN: ¡Turno cumplido, equipo! ♥")


# ---------- Guía y consola ----------

func _poner_dientes_a_taza() -> void:
	$Props/Taza.anim_reposo = &"con_dientes"
	$Props/Taza.mostrar_reposo()


func _texto_guia() -> String:
	if state.mision_completada:
		return "¡Turno cumplido en la 202!"
	if state.mails_resueltos > 0 and not state.laptop_quemada:
		return "La compu todavía aguanta. Seguí contestando sus mails."
	if $Props/Calendario.nombrado and not state.alarma_sonada:
		return "El DEADLINE es a las 3. ¿Y si el reloj se entera?"
	if $Props/Cafetera.nombrado and not state.cafe_listo:
		return "La cafetera tiene una receta pegada. Perturbala para preparar café."
	return "%d de 3 sellos. ¡Asustá a Bruno!" % Globals.sellos


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


func _decir(texto: String) -> void:
	if not texto.is_empty():
		await C.player.say(texto)
