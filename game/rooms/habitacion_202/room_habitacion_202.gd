@tool
extends PopochiuRoom
## Habitación 202: Bruno. Mismo esquema que la 101 (clic para caminar, elegir objeto,
## Mirar/Agarrar/Perturbar). Igual que en la 101: primero hay que Mirar (presentarse)
## antes de Agarrar, Perturbar o Poseer un objeto.
## Sellos: la compu (minijuego de mails), la cafetera (minijuego de la receta) y el
## reloj a las 3 (después de leer el DEADLINE del calendario).
## Acto 1: cada puzzle resuelto llena MEDIO sello (Bruno se mueve pero no se despierta).
## Acto 2: con los tres medios sellos, Din manda POSEER (beta) por el teléfono de Bruno.
## Poseer cada uno de esos tres objetos completa su sello; la tercera posesión despierta a Bruno.

const Data := preload("room_habitacion_202_state.gd")
const FRASES_PROGRESO := ["", "¡Sello uno! Faltan dos.", "¡Dos de tres! ¡Ya casi!", "¡Tres sellos!"]
const MIEDO_PRIMER_SUSTO := 5.0
const MIEDO_RESPUESTA := 8.0
const MIEDO_SELLO := 20.0
const COSTO_ERROR := 2.0
const RECETA := {"cafe": 9, "agua": 3, "azucar": 8}
const FRASES_MEDIO := [
	"",
	"¡Medio sello! Se movió… pero sigue roncando.",
	"Otro medio sello. ¿Este muchacho no se despierta con nada?",
	"Tres medios sellos… y sigue dormido. Está más cansado que un fantasma.",
]
## Lo que pasa al poseer cada objeto. "dice" es el objeto hablando en lógica fantasma.
const POSESIONES := {
	"Laptop": {"sello": &"laptop_202", "dice": "COMPU: Visto a las 3:14.", "nuna": "Hasta quemada le marca el visto."},
	"Cafetera": {"sello": &"cafetera_202", "dice": "DOÑA CAFETERA: Una más y te alcanza. TAZA: ¡Sonreí, que es parte del trabajo!", "nuna": "¡Le sirve café a uno que duerme y la taza le sonríe! Es más exigente que Din."},
	"Reloj": {"sello": &"reloj_202", "dice": "TIC: Ya es mañana.", "nuna": "Brrr. Eso me dio miedo hasta a mí."},
}
const FRASES_ENTRAR := ["¡Allá voy! Adentro…", "Permiso… me meto un ratito.", "La última. Respiro hondo… bueno, no respiro."]
const COLOR_POSESION := Color(0.78, 0.55, 1.0)
const RUTA_CONTRATO := "res://arte/objetos/contrato_202.png"

var state: Data = load("res://game/rooms/habitacion_202/room_habitacion_202.tres")
var ocupado := false
var objeto_seleccionado: ObjetoInteractivo
var _saliendo := false
var _cafetera_hablo := false
var _taza_pidio_sonrisa := false
var _tirones_cajon := 0


func _enter_tree() -> void:
	super()
	y_sort_enabled = false
	$Props.y_sort_enabled = false
	$Characters.y_sort_enabled = false


## Con un objeto del inventario en la mano (USAR), el clic sobre un objeto del cuarto lo usa
## ahí. Se resuelve acá, antes que nada, para no depender del "hover" de Popochiu
## (con la taza arriba del escritorio el clic a veces no le llegaba a la taza).
func _input(event: InputEvent) -> void:
	if I.active == null or ocupado or G.is_blocked:
		return
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.position.y < Ajustes.UI_HUD_TAMANO.y or event.position.y >= Ajustes.UI_Y:
		return  # clic en el HUD de arriba o en la consola: eso lo maneja la interfaz
	var punto: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	var objetivo := objeto_en(punto)
	if objetivo == null:
		return
	get_viewport().set_input_as_handled()
	var item: PopochiuInventoryItem = I.active
	I.set_active_item(null)
	await usar_objeto(item, objetivo)


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
	# Si se abre la 202 directo (para probar), la recepción no sabe que la historia avanzó:
	# la dejamos como si Nuna ya hubiera hecho la intro y la 101.
	var recepcion: Resource = load("res://game/rooms/recepcion/room_recepcion.tres")
	if recepcion.paso != 3:
		recepcion.paso = 3
		recepcion.cinematica_2 = true
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
	G.gui.ui.mostrar_medios_sellos(0)


func _on_restore_from_savegame() -> void:
	_restaurar_visual()


func _restaurar_visual() -> void:
	ocupado = false
	objeto_seleccionado = null
	for obj: ObjetoInteractivo in get_props():
		obj.restaurar_posicion()
		obj.visible = not obj.recogido
		obj.description = obj.nombre_visible()
	$Props/Puerta.mostrar_cerrada()
	if state.laptop_quemada:
		$Props/Laptop.quemar()
	if state.taza_con_dientes:
		_poner_dientes_a_taza()
	if state.mision_completada:
		$Props/Bruno.asustarse()
		if Globals.tiene_extra("ratoncito") and has_node("Props/Ratoncito"):
			$Props/Ratoncito.hide()
	G.gui.mostrar_habitacion(true)
	G.gui.ui.mostrar_medios_sellos(_puzzles_resueltos())
	_actualizar_guia()


func _on_room_transition_finished() -> void:
	C.player.poner_birrete(false)  # en las habitaciones Nuna ya no lleva birrete
	if not state.entrada_completada:
		state.entrada_completada = true
		ocupado = true
		# Sin E.queue: si la fila de Popochiu quedó trabada (por ejemplo al saltar algo antes),
		# la entrada no se cuelga.
		E.playing_queue = false
		G.block()
		# Nuna ya está adentro (sin la entrada caminando por la puerta).
		$Props/Puerta.mostrar_cerrada()
		C.player.volver_a_reposo_frontal()
		# Igual que en la 101: unas tarjetas de Din con lo justo para arrancar.
		await DialogoPopup.mostrar(self, [
			["NUNA", "¡La 202! Acá vive alguien que no duerme mucho."],
			["DIN", "Orden de trabajo: despertá al huésped y ganá 3 sellos.", "(Horas extra no remuneradas. Otra vez.)"],
			["DIN", "Paso 1: presentate. MIRÁ cada cosa: un objeto que no te conoce no se asusta. ♥"],
			["DIN", "Paso 2: PERTURBÁ lo que más le importa al muchacho. Cada susto que no lo despierta vale MEDIO sello.", "(Pistas: la compu, el café y la hora.)"],
			["DIN", "Paso 3: con tres medios sellos te mando una actualización. Con eso lo despertás. ♥"],
			["DIN", "¿Trajiste algo de la 101? INVENTARIO, elegí el objeto, USAR, y clic donde lo querés usar.", "(Clic derecho lo guarda. La empresa no da insumos.)"],
			["DIN", "Si el huésped no se despierta, es un problema de actitud. Tuya. ♥"],
			["NUNA", "¡Tres sellos y a otra cosa!"],
		])
		G.unblock()
		ocupado = false
		_actualizar_guia()


## Igual que en la 101: se abre la puerta, entra Nuna y se cierra.
func _reproducir_entrada() -> void:
	Globals.pausado = true
	C.player.hide()
	await $Props/Puerta.abrir()
	C.player.global_position = $Markers/EntradaNuna.global_position
	C.player.show()
	await C.player.walk($Markers/InicioNuna.global_position)
	C.player.volver_a_reposo_frontal()
	await $Props/Puerta.cerrar()
	Globals.pausado = false


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
	if not objetivo.nombrado:
		await _decir("Primero me presento. ¡Hola! Ya vuelvo con esto.")
	elif item.script_name == "Dentadura" and objetivo == $Props/Taza and not state.taza_con_dientes:
		await C.player.walk(objetivo.punto_de_uso())
		await _poner_sonrisa_en_taza()
	elif item.script_name == "Dentadura":
		await _decir("¿La sonrisa acá? Mmm… ¿dónde se habrá olvidado de sonreír este muchacho?")
	else:
		await _decir("No me ayuda con eso.")
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
	if _saliendo:
		G.block()
		return
	ocupado = false
	_actualizar_guia()
	_mostrar_contexto_seleccionado()


func _resolver_accion(obj: ObjetoInteractivo, verbo: StringName) -> void:
	var sellos_antes: int = Globals.sellos
	if obj == $Props/Puerta and verbo == Globals.MIRAR:
		obj.nombrado = true
		if state.mision_completada:
			await _salir_de_la_202()
		else:
			await _decir("¡Señor Puerta! Todavía no salgo: me faltan sellos.")
	elif obj == $Props/Escritorio and verbo == Globals.MIRAR:
		await _decir(obj.ejecutar(verbo))
		await _cajon_escritorio()
	elif obj == $Props/Calendario and verbo == Globals.MIRAR:
		var frase: String = obj.ejecutar(verbo)
		await _ver_calendario()
		await _decir(frase)
	elif verbo != Globals.MIRAR and not obj.nombrado:
		# Regla de la casa (igual que en la 101): primero te presentás.
		await _decir("¡Ay, todavía no nos presentamos! Primero lo miro.")
	elif obj == $Props/Taza and obj.nombrado and _falta_sonrisa():
		# Mismo atajo que Ovi en la 101: tocar la taza (ya presentada) ofrece la sonrisa
		# sin pasar por el inventario. El inventario sigue funcionando igual.
		await _ofrecer_sonrisa()
	elif verbo == Globals.PERTURBAR and not obj.puede_perturbar:
		await _decir(obj.frase_perturbar if not obj.frase_perturbar.is_empty() else "Mejor no lo molesto.")
	elif verbo == Globals.PERTURBAR:
		await _perturbar(obj)
	else:
		await _decir(obj.ejecutar(verbo))
		if obj == $Props/Taza and verbo == Globals.MIRAR and not state.taza_con_dientes:
			await _pista_taza()
	obj.description = obj.nombre_visible()
	if Globals.sellos > sellos_antes:
		await _decir(FRASES_PROGRESO[Globals.sellos])
		if Globals.sellos >= Globals.SELLOS_TOTALES:
			await _mision_cumplida()


func _perturbar(obj: ObjetoInteractivo) -> void:
	if _se_puede_poseer(obj) and obj == $Props/Cafetera and _falta_sonrisa():
		# Doña Cafetera quiere servirle a una taza que sonría (la sonrisa de la 101).
		_taza_pidio_sonrisa = true
		$Props/Cafetera._sacudir()
		await _decir("DOÑA CAFETERA: ¿Y a quién le sirvo? Esa taza tiene cara de lunes.")
		await _decir("«Sonreír es parte del trabajo», dice la taza… y no sonríe nada.")
		await _decir("¡Yo tengo una sonrisa! La de la 101. Voy a tocar la taza…")
		_brillar($Props/Taza)
		return
	if _se_puede_poseer(obj):
		await _poseer(obj)
		return
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
	if obj == $Props/Bruno or obj == $Props/Puerta or state.perturbados.has(String(obj.name)):
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
	state.laptop_quemada = true
	await _decir("¡Se quemó por trabajar sin parar! Igual que Lumi.")
	$Props/Bruno.temblar()
	Globals.aumentar_vela(MIEDO_SELLO)
	await _medio_sello()


# ---------- Minijuego 2: el café del deadline ----------

func _minijuego_cafetera() -> void:
	await _decir("Tiene una receta pegada. ¡Le preparo el café del deadline!")
	if not _cafetera_hablo:
		_cafetera_hablo = true
		await _decir("DOÑA CAFETERA: Glu-glu… La receta no lo dice todo, corazón.")
		await _decir("DOÑA CAFETERA: Lo que falta, buscalo en la habitación.")
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
		# El panel muestra en rojo qué regla falló; Nuna lo comenta y pierde bruma.
		var regla := ""
		var comentario := ""
		if cafe + agua > CafeteraPanel.MAXIMO:
			regla = "café + agua da %d, y la jarra lleva %d justas." % [cafe + agua, CafeteraPanel.MAXIMO]
			comentario = "¡Rebalsa! Eso no entra en la jarra."
		elif cafe + agua < CafeteraPanel.MAXIMO:
			regla = "café + agua da %d. Faltan medidas: la jarra lleva %d justas." % [cafe + agua, CafeteraPanel.MAXIMO]
			comentario = "La jarra quedó a medias."
		elif cafe < agua * 3:
			regla = "muy aguado. Tiene que ser 3 de café por cada 1 de agua."
			comentario = "Muy aguado. Bruno ni se mosquea."
		elif cafe > agua * 3:
			regla = "muy fuerte. Tiene que ser 3 de café por cada 1 de agua, ni más ni menos."
			comentario = "¡Demasiado fuerte! Ni la cafetera se lo banca."
		elif azucar != RECETA.azucar:
			state.errores_azucar += 1
			regla = "el café está perfecto, pero el azúcar no. Es 1 por cada noche sin dormir."
			comentario = "El azúcar no da. ¿Cuántas noches lleva sin dormir?"
			if state.errores_azucar >= 2:
				regla += " ¿Dónde fue tachando las noches?"
				comentario = "Algo en la pared lleva la cuenta de sus noches…"
		else:
			listo = true
		if not listo:
			panel.mostrar_error(regla)
			await _equivocarse(comentario)
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
	await _medio_sello()


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
	await _medio_sello()


# ---------- Final de la 202 ----------

func _mision_cumplida() -> void:
	if state.mision_completada:
		return
	state.mision_completada = true
	Globals.llenar_vela(Ajustes.LUMI_HABITACION_ID)
	$Props/Bruno.asustarse()
	await get_tree().create_timer(1.0).timeout
	await _decir("BRUNO: ¡¿LAS 3?! ¡LA PRESENTACIÓN!")
	await _decir("¡Se despertó! ¿Para quién es la presentación?")
	await _decir("BRUNO (a nadie): Para el cliente… del jefe de mi jefe.")
	await _decir("¿Y vos qué ganás?")
	await _decir("BRUNO (a nadie): Que mañana me den otra.")
	await _decir("¿Y adónde llegás con todo eso?")
	await _decir("BRUNO (a nadie): …Al viernes.")
	$Props/Telefono.reproducir(&"vibra")
	await _decir("Le vibra el teléfono…")
	await G.gui.ui.mostrar_certificacion("«Gracias por tu propuesta. Esta vez elegimos a otro perfil. ¡Éxitos!»", "(Enviado a las 3:00.)")
	$Props/Telefono.mostrar_reposo()
	await _decir("No fue el fantasma. Fue darlo todo y que igual no alcance.")
	await _decir("Bruno se quemó como la compu. A la compu la pueden cambiar.")
	await _decir("Yo junto bruma para la máquina. Él junta horas para… ¿la máquina de otro?")
	await _decir("DIN: ¡Turno cumplido, equipo! ♥")
	await _llevarse_ratoncito()
	_brillar($Props/Puerta)


## Lo que Nuna se lleva de la 202: el Ratoncito Inquieto (va a los extras del inventario).
func _llevarse_ratoncito() -> void:
	if Globals.tiene_extra("ratoncito") or not has_node("Props/Ratoncito"):
		return
	var raton = $Props/Ratoncito
	await C.player.walk(raton.punto_de_uso() if raton is ObjetoInteractivo else raton.global_position)
	await _decir("¿Y este? El Ratoncito Inquieto: mueve el mouse para que parezca que alguien trabaja.")
	await _decir("Bruno ya no lo necesita. Me lo llevo: la empresa no da insumos.")
	for i in 3:
		raton.visible = not raton.visible
		await get_tree().create_timer(0.1).timeout
	raton.hide()
	Globals.agregar_extra("ratoncito")
	G.gui.ui.resaltar_cuaderno()
	await _decir("Ahora vive en mi inventario.")


## Con el turno cumplido, la puerta lleva de vuelta a la recepción (cinemática 3).
func _salir_de_la_202() -> void:
	var salir: bool = await PreguntaSiNo.preguntar(self, "¿Volver a la recepción?")
	if not salir:
		await _decir("Un ratito más con Bruno.")
		return
	await _decir("¡Chau, Bruno! ¡Chau, Compu, Tic y Doña Cafetera!")
	await $Props/Puerta.abrir()
	await C.player.walk($Markers/EntradaNuna.global_position)
	C.player.hide()
	await $Props/Puerta.cerrar()
	C.player.show()
	_saliendo = true
	_cancelar_seleccion()
	R.goto_room("Recepcion")


func _brillar(nodo: CanvasItem) -> void:
	# Pista "mirá acá": el objeto vibra (antes brillaba; así no cambian los colores del pixel art).
	if nodo.has_method("vibrar_pista"):
		nodo.vibrar_pista()
	elif nodo.has_method("_sacudir"):
		nodo._sacudir()


# ---------- Guía y consola ----------

## El cajón del escritorio: atascado como los sueños del muchacho. Al segundo tirón sale
## el contrato de pasantía (la toma contrato_202).
func _cajon_escritorio() -> void:
	_tirones_cajon += 1
	match _tirones_cajon:
		1:
			$Props/Escritorio._sacudir()
			await _decir("El cajón está atascado. Como los sueños del muchacho.")
		2:
			$Props/Escritorio._sacudir()
			await _decir("Un tironcito más… ¡Salió! Hay un papel arrugado.")
			var toma := await _mostrar_contrato()
			await _decir("¿Contrato de pasantía? ¡Y tiene doce rayitas! Lo renovaron doce veces.")
			await _decir("¿Tres años de pasantía? Eso no es una pasantía. Es una forma de vida.")
			await _decir("«Gran oportunidad de crecimiento». ¿Crecer hasta dónde? ¿Hasta el viernes?")
			if toma != null:
				await toma.cerrar()
		_:
			var toma := await _mostrar_contrato()
			await _decir("Ya sé lo que dice: «gran oportunidad». Hace tres años.")
			if toma != null:
				await toma.cerrar()


## El contrato de pasantía (arte/objetos/contrato_202.png). Si la imagen no está, va en texto.
func _mostrar_contrato() -> Toma:
	if ResourceLoader.exists(RUTA_CONTRATO) or FileAccess.file_exists(RUTA_CONTRATO):
		return await Toma.mostrar(self, RUTA_CONTRATO)
	await G.gui.ui.mostrar_certificacion("CONTRATO DE PASANTÍA · 3 meses · Renovable · Sin aportes.", "(«¡Gran oportunidad de crecimiento!» Renovado 12 veces, hace 3 años.)")
	return null


## La cafetera solo pide la sonrisa si Nuna la trajo (si la dejó en la 101, no se traba).
func _falta_sonrisa() -> bool:
	return not state.taza_con_dientes and Globals.tiene(&"dentadura")


func _pista_taza() -> void:
	if Globals.tiene(&"dentadura"):
		await _decir("«Sonreír es parte del trabajo», dice. Y no sonríe ni un poquito.")
		await _decir("Yo tengo una sonrisa en el inventario… Si la vuelvo a tocar, se la presto.")
		_brillar($Props/Taza)
	else:
		await _decir("«Sonreír es parte del trabajo». Qué taza más seria.")


## Pregunta como en la 101 («¿Usar a Ovi?»). Si dice que sí, la sonrisa pasa a la taza.
func _ofrecer_sonrisa() -> void:
	var usar: bool = await PreguntaSiNo.preguntar(self, "¿Prestarle la sonrisa a la taza?")
	if not usar:
		await _decir("Mejor la guardo para después.")
		return
	await _poner_sonrisa_en_taza()


func _poner_sonrisa_en_taza() -> void:
	await _decir("¡Don Mordisquito, te presento a la taza!")
	state.taza_con_dientes = true
	_poner_dientes_a_taza()
	await Globals.quitar_objeto(&"dentadura")  # la sonrisa ahora vive en la taza
	await _decir("Ahora sí: «Sonreír es parte del trabajo».")
	if state.poseer_desbloqueado and not state.poseidos.has("Cafetera"):
		await _decir("Doña Cafetera ya tiene a quién servirle.")


func _poner_dientes_a_taza() -> void:
	$Props/Taza.anim_reposo = &"con_dientes"
	$Props/Taza.mostrar_reposo()


func _texto_guia() -> String:
	if state.mision_completada:
		return "¡Turno cumplido! Mirá la puerta para volver a la recepción."
	if state.poseer_desbloqueado:
		if state.poseidos.is_empty() and not _taza_pidio_sonrisa:
			return "Paso 3: ¡POSEER! Elegí la compu, la cafetera o el reloj y tocá Poseer."
		if _taza_pidio_sonrisa and _falta_sonrisa():
			return "A la taza le falta una sonrisa. Tocá la taza (o usá la sonrisa desde el inventario)."
		return "Poseé la compu, la cafetera y el reloj (%d de 3)." % state.poseidos.size()
	if state.mails_resueltos > 0 and not state.laptop_quemada:
		return "La compu todavía aguanta. Seguí contestando sus mails."
	if $Props/Calendario.nombrado and not state.alarma_sonada:
		return "El DEADLINE es a las 3. ¿Y si el reloj se entera?"
	if $Props/Cafetera.nombrado and not state.cafe_listo:
		return "La cafetera tiene una receta pegada. Perturbala para preparar café."
	if _cuantos_nombrados() < 4:
		return "Paso 1: mirá todo. Presentate con cada objeto del cuarto."
	return "Paso 2: perturbá la compu, la cafetera y el reloj. Medios sellos: %d de 3." % _puzzles_resueltos()


func _cuantos_nombrados() -> int:
	var n := 0
	for obj: ObjetoInteractivo in get_props():
		if obj.nombrado:
			n += 1
	return n


func _actualizar_guia() -> void:
	G.gui.ui.establecer_guia(_texto_guia())


func _mostrar_contexto_seleccionado() -> void:
	if not _seleccion_es_valida():
		_cancelar_seleccion()
		return
	G.gui.ui.mostrar_objeto(objeto_seleccionado.nombre_visible(), true, objeto_seleccionado.puede_agarrar, objeto_seleccionado.puede_perturbar)
	G.gui.ui.renombrar_accion(Globals.PERTURBAR, "Poseer" if _se_puede_poseer(objeto_seleccionado) else "")
	G.gui.ui.establecer_acciones_habilitadas(not ocupado and not G.is_blocked)


func _cancelar_seleccion() -> void:
	objeto_seleccionado = null
	G.gui.ui.mostrar_exploracion()
	G.gui.ui.establecer_acciones_habilitadas(false)


func _decir(texto: String) -> void:
	if not texto.is_empty():
		await C.player.say(texto)


# ---------- Medios sellos y posesión ----------

func _puzzles_resueltos() -> int:
	return int(state.laptop_quemada) + int(state.cafe_listo) + int(state.alarma_sonada)


## Un puzzle resuelto llena medio sello. Con los tres, Din manda POSEER.
func _medio_sello() -> void:
	var n := _puzzles_resueltos()
	G.gui.ui.mostrar_medios_sellos(n)
	await _decir(FRASES_MEDIO[clampi(n, 0, 3)])
	if n == 1:
		await _decir("DIN: Medio sello. Lo asustaste, pero no se enteró. ♥")
	if n >= 3 and not state.poseer_desbloqueado:
		await _desbloquear_poseer()
	_actualizar_guia()


func _desbloquear_poseer() -> void:
	await get_tree().create_timer(0.6).timeout
	$Props/Telefono.reproducir(&"vibra")
	await _decir("Le vibra el teléfono al muchacho…")
	await G.gui.ui.mostrar_certificacion("DIN: Actualización disponible: POSEER (beta).", "(Al continuar aceptás los términos y condiciones.)")
	$Props/Telefono.mostrar_reposo()
	await _decir("¿Din me escribe al teléfono de un humano?")
	await _decir("DIN: Optimizamos recursos. ♥")
	await _decir("¿Y qué dicen los términos y condiciones?")
	await _decir("DIN: Que sí. ♥")
	await _decir("DIN: Metete adentro de un objeto. Si se mueve solo, el humano se despierta.")
	await _decir("DIN: Si no se despierta, es un problema de actitud. ♥")
	state.poseer_desbloqueado = true
	await _decir("¡Puedo poseer! La compu, la cafetera y el reloj ya lo pusieron nervioso.")
	await _decir("Ahora, ¡desde adentro!")


func _se_puede_poseer(obj: ObjetoInteractivo) -> bool:
	return state.poseer_desbloqueado and not state.mision_completada \
			and POSESIONES.has(String(obj.name)) and not state.poseidos.has(String(obj.name))


## Nuna se mete en el objeto: el objeto se pone violeta y se transforma (estilo Terrortown).
func _poseer(obj: ObjetoInteractivo) -> void:
	var nombre := String(obj.name)
	var datos: Dictionary = POSESIONES[nombre]
	await _decir(FRASES_ENTRAR[clampi(state.poseidos.size(), 0, 2)])
	await _parpadear_nuna(false)
	obj.modulate = COLOR_POSESION
	var efecto: Tween
	match nombre:
		"Laptop":
			efecto = _efecto_compu(obj)
		"Cafetera":
			efecto = _efecto_cafetera(obj)
			if state.taza_con_dientes:
				$Props/Taza.reproducir(&"castanetea")
		"Reloj":
			efecto = _efecto_reloj(obj)
	await get_tree().create_timer(0.6).timeout
	await _decir(datos.dice)
	if efecto != null and efecto.is_valid():
		efecto.kill()
	obj.modulate = Color.WHITE
	obj.scale = Vector2.ONE
	obj.restaurar_posicion()
	if obj is ObjetoAnimado:
		obj.mostrar_reposo()
	if nombre == "Cafetera":
		$Props/Taza.mostrar_reposo()
	await _parpadear_nuna(true)
	state.poseidos.append(nombre)
	await _decir(datos.nuna)
	Globals.aumentar_vela(MIEDO_SELLO)
	# Bruno se va despertando según cuántas posesiones van (no según cuál objeto).
	match state.poseidos.size():
		1:
			$Props/Bruno.temblar()
			await _decir("BRUNO (dormido): …sí, jefe… ya lo mando…")
			await _decir("¡Contesta dormido! ¿Le pagarán las horas soñadas?")
		2:
			$Props/Bruno.temblar()
			await _decir("BRUNO (dormido): …cinco minutitos más… de trabajar…")
			await _decir("Ni con un fantasma adentro de sus cosas se despierta.")
			await _decir("Está más cansado que yo, y yo no duermo desde que me morí.")
	# La tercera la cuenta _mision_cumplida: ahí se despierta.
	Globals.otorgar_sello(datos.sello)


## Nuna parpadea cuadro a cuadro al entrar o salir del objeto.
func _parpadear_nuna(termina_visible: bool) -> void:
	for i in 4:
		C.player.visible = not C.player.visible
		await get_tree().create_timer(0.07).timeout
	C.player.visible = termina_visible


## La compu quemada muerde: la tapa se achica y se estira como una boca.
func _efecto_compu(obj: ObjetoInteractivo) -> Tween:
	var tw := create_tween().set_loops()
	tw.tween_callback(func(): obj.scale = Vector2(1.0, 0.75))
	tw.tween_interval(0.12)
	tw.tween_callback(func(): obj.scale = Vector2(1.1, 1.1))
	tw.tween_interval(0.12)
	tw.tween_callback(func(): obj.scale = Vector2.ONE)
	tw.tween_interval(0.3)
	return tw


## La cafetera salta hacia la cama (estirándose al saltar) y vuelve.
func _efecto_cafetera(obj: ObjetoInteractivo) -> Tween:
	var base: Vector2 = obj.position
	var tw := create_tween().set_loops()
	for paso in [1, 2, 3, 2, 1, 0]:
		var x: float = base.x - paso * 6.0
		tw.tween_callback(func():
			obj.position = Vector2(x, base.y - 4.0)
			obj.scale = Vector2(0.85, 1.25)
		)
		tw.tween_interval(0.1)
		tw.tween_callback(func():
			obj.position = Vector2(x, base.y)
			obj.scale = Vector2(1.15, 0.85)
		)
		tw.tween_interval(0.1)
	return tw


## El reloj crece al doble y tiembla mientras suena.
func _efecto_reloj(obj: ObjetoInteractivo) -> Tween:
	var base: Vector2 = obj.position
	if obj is ObjetoAnimado:
		obj.reproducir(&"alarma")
	var tw := create_tween().set_loops()
	tw.tween_callback(func():
		obj.scale = Vector2(2, 2)
		obj.position = base + Vector2(1, 0)
	)
	tw.tween_interval(0.06)
	tw.tween_callback(func(): obj.position = base + Vector2(-1, 0))
	tw.tween_interval(0.06)
	return tw


# ---------- El almanaque de cerca ----------

func _ver_calendario() -> void:
	Globals.pausado = true
	var hoja := HojaCalendario.new()
	add_child(hoja)
	await hoja.cerrado
	Globals.pausado = false


## Primer plano del almanaque, dibujado pixel a pixel: hay que contar las noches tachadas.
class HojaCalendario extends Panel202:
	const PRIMER_TACHADO := 6
	const NOCHES := 8
	const DIA_DEADLINE := 14
	const CELDA := Vector2(20, 14)

	func _armar() -> void:
		caja.add_child(_label("ALMANAQUE DE BRUNO", COLOR_GRIS))
		var hoja := Control.new()
		hoja.custom_minimum_size = Vector2(CELDA.x * 7 + 1, CELDA.y * 3 + 1)
		hoja.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hoja.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hoja.draw.connect(_dibujar.bind(hoja))
		caja.add_child(hoja)
		caja.add_child(_label("DEADLINE 3:00", COLOR_ROJO))
		var fila := HBoxContainer.new()
		fila.alignment = BoxContainer.ALIGNMENT_CENTER
		fila.add_child(_boton("Listo", _listo, 60))
		caja.add_child(fila)

	func _listo() -> void:
		cerrado.emit()
		queue_free()

	func _dibujar(hoja: Control) -> void:
		var fuente: Font = hoja.get_theme_font("font", "Label")
		for d in 21:
			var dia := d + 1
			var esquina := Vector2((d % 7) * CELDA.x, (d / 7) * CELDA.y)
			_marco(hoja, esquina, CELDA, COLOR_AZUL)
			hoja.draw_string(fuente, esquina + Vector2(3, 11), str(dia), HORIZONTAL_ALIGNMENT_LEFT, -1, TAM, COLOR_CLARO)
			if dia >= PRIMER_TACHADO and dia < PRIMER_TACHADO + NOCHES:
				# Una cruz roja pixel a pixel encima del número.
				for k in 10:
					hoja.draw_rect(Rect2(esquina + Vector2(5 + k, 2 + k), Vector2.ONE), COLOR_ROJO)
					hoja.draw_rect(Rect2(esquina + Vector2(14 - k, 2 + k), Vector2.ONE), COLOR_ROJO)
			if dia == DIA_DEADLINE:
				_marco(hoja, esquina + Vector2.ONE, CELDA - Vector2(2, 2), COLOR_ROJO)
				_marco(hoja, esquina + Vector2(2, 2), CELDA - Vector2(4, 4), COLOR_ROJO)

	## Un borde de 1 pixel hecho con rectángulos llenos (nítido, sin suavizado).
	func _marco(hoja: Control, pos: Vector2, tam: Vector2, color: Color) -> void:
		hoja.draw_rect(Rect2(pos, Vector2(tam.x, 1)), color)
		hoja.draw_rect(Rect2(pos + Vector2(0, tam.y - 1), Vector2(tam.x, 1)), color)
		hoja.draw_rect(Rect2(pos, Vector2(1, tam.y)), color)
		hoja.draw_rect(Rect2(pos + Vector2(tam.x - 1, 0), Vector2(1, tam.y)), color)
