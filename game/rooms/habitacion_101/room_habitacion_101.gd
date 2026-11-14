@tool
extends PopochiuRoom

const Data := preload("room_habitacion_101_state.gd")
const BAUTISMOS := {
	&"radio": "¡Hola, radio! Te voy a llamar Ramón.",
	&"ventana": "¡Hola, cortina! Te voy a llamar Doña Cortina.",
	&"ovillo": "¡Hola, ovillo! Te voy a llamar Ovi.",
}
const FRASES_PROGRESO := ["", "¡Sello uno! Faltan dos.", "¡Dos de tres! ¡Ya casi!", "¡Tres sellos! ¡Ya soy casi profesional!"]
## Dónde queda Ovi cuando Nuna lo usa en la ventana, y cuánto sube Nuna al pararse encima.
const OVI_POS_VENTANA := Vector2(219, 132)
const OVI_ALTURA := 14.0
## Ramón: la etiqueta trae el código al revés (ORTAUC = CUATRO).
## Las estaciones son un día de trabajo (Mérito, Ocupada, Feriado, Hora Extra) y Ofelia las
## escuchó 45 años: ya no la despiertan. Solo la Radio Revés llega: pasa su vida para atrás,
## hasta la canción de cuna. Es la única frecuencia que no transmite Din (ver el documento).
const ETIQUETA_RAMON := "¡Sintonizá ORTAUC y llegás!"
const LETRA_CHICA_RAMON := "(Radio Revés: se lee al revés. Din no llega hasta acá.)"
const ESTACION_CORRECTA := 4
const COSTO_ESTACION_EQUIVOCADA := 2.0
## Lumi: adivinanza sobre la bruma (el sueldo de los fantasmas).
const OPCIONES_ADIVINANZA := ["La bruma", "El miedo", "Un sello"]
const COSTO_ADIVINANZA_ERRADA := 2.0
const VELA_ADIVINANZA := 30.0
const VELADOR_ABIERTO_PNG := "res://arte/objetos/velador_abierto.png"
## Debajo de la dentadura: el recibo de jubilación de Ofelia y la tarifa del hotel.
## Si existe la toma (2 cuadros de 320x152: recibo y tarifa), se muestra a pantalla completa;
## si no, las mismas frases van en la tarjeta de la consola.
const TOMA_RECIBO := "res://arte/tomas/toma_recibo.png"
const RECIBO_ETIQUETA := "RECIBO DE JUBILACIÓN. Ofelia. 45 años de aportes."
const RECIBO_LETRA_CHICA := "(Monto: casi nada.)"
const TARIFA_ETIQUETA := "HOTEL. Estadía permanente: tarifa jubilados."
const TARIFA_LETRA_CHICA := "(Incluye: cama, desayuno y silencio.)"
var state: Data = load("res://game/rooms/habitacion_101/room_habitacion_101.tres")
var ocupado := false
var objeto_seleccionado: ObjetoInteractivo
var _estaciones_probadas: Array[int] = []
var _dial_abierto := false
var _saliendo := false
var _textura_velador_cerrado: Texture2D
var _textura_velador_abierto: Texture2D


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
	Musica.tocar(&"habitacion")
	if state.visited_first_time:
		C.player.position = Vector2(36, 140)
	$Props/Lumi.combo_sombra_activado.connect(_on_combo_sombra_activado)
	$Props/Lumi.susto_chico.connect($Props/Huesped.temblar)
	# Ofelia solo tiembla con cada susto; salta de la cama con el tercer sello.
	$Props/Lumi.fogonazo_realizado.connect($Props/Huesped.temblar)
	$Props/Ramon.comenzo_a_sonar.connect($Props/Huesped.temblar)
	_restaurar_visual()


func _on_restore_from_savegame() -> void:
	_restaurar_visual()


func _restaurar_visual() -> void:
	ocupado = false
	objeto_seleccionado = null
	$Props/Ramon.sonar(true) if state.ramon_sonando else $Props/Ramon.mostrar_quieto()
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
	_mostrar_cajon(state.cajon_abierto)
	if state.recibo_leido:
		_presentar_ofelia()
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
	if _saliendo:
		# Durante el cambio de sala la GUI sigue bloqueada (E.queue la desbloquea al terminar).
		G.block()
		return
	ocupado = false
	_actualizar_guia()
	_mostrar_contexto_seleccionado()


func _resolver_accion(obj: ObjetoInteractivo, verbo: StringName) -> void:
	var sellos_antes: int = Globals.sellos
	if obj is Ramon and verbo == Globals.PERTURBAR and obj.nombrado:
		await _perturbar_ramon(obj)
	elif obj is VentanaAnimada and obj.nombrado and (verbo == Globals.PERTURBAR or Globals.tiene(&"ovillo")):
		await _perturbar_ventana(obj)
	elif obj == $Props/Velador and verbo == Globals.MIRAR:
		await _mirar_velador(obj)
	elif obj == $Props/Puerta and verbo == Globals.MIRAR and state.mision_completada:
		await _salir_de_la_101()
	elif obj is Lumi and verbo == Globals.MIRAR and _lumi_tiene_adivinanza(obj):
		await _adivinanza_lumi(obj)
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
		var primera_mirada: bool = verbo == Globals.MIRAR and not obj.nombrado
		await _decir(obj.ejecutar(verbo))
		if primera_mirada and obj is Ramon:
			# La etiqueta de Ramón trae la pista del dial en la letra chica.
			await G.gui.ui.mostrar_certificacion(ETIQUETA_RAMON, LETRA_CHICA_RAMON)
			await _decir("¿ORTAUC? ¡Qué estación más rara!")
		if obj.id == &"ovillo" and Globals.tiene(&"ovillo"):
			await _decir("¡Contigo llego a la ventana, Ovi!")
			_brillar($Props/Cortina)
		if obj.id == &"dentadura" and Globals.tiene(&"dentadura"):
			await _leer_recibo()
	obj.description = obj.nombre_visible()
	if Globals.sellos > sellos_antes:
		if Globals.sellos >= Globals.SELLOS_TOTALES:
			await _ofelia_salta()
		await _decir(FRASES_PROGRESO[Globals.sellos])
		if Globals.sellos >= Globals.SELLOS_TOTALES:
			await _mision_cumplida()


func _perturbar_ramon(ramon: Ramon) -> void:
	if Globals.sellos_obtenidos.has("ramon"):
		await _decir("Ramón ya cantó su parte.")
		return
	Globals.iniciar_goteo()
	await _abrir_dial(ramon)


## El dial de Ramón: se prueban estaciones hasta acertar o cerrar con un clic afuera.
func _abrir_dial(ramon: Ramon) -> void:
	var pausa_previa: bool = Globals.pausado
	Globals.pausado = true  # la bruma no gotea con el panel abierto
	_dial_abierto = true
	_actualizar_guia()
	var dial := DialRadio.new()
	add_child(dial)
	for n in _estaciones_probadas:
		dial.marcar_probada(n)
	while true:
		var numero: int = await dial.elegido
		if numero == 0:
			break
		dial.bloquear(true)
		var resuelto: bool = await _sintonizar_estacion(ramon, numero)
		if resuelto:
			dial.cerrar()
			break
		if not _estaciones_probadas.has(numero):
			_estaciones_probadas.append(numero)
		dial.marcar_probada(numero)
		dial.bloquear(false)
	_dial_abierto = false
	Globals.pausado = pausa_previa


## Qué pasa con cada estación. Devuelve true si es la correcta.
func _sintonizar_estacion(ramon: Ramon, numero: int) -> bool:
	var a_la_primera: bool = state.intentos_ramon == 0
	state.intentos_ramon += 1
	if numero != ESTACION_CORRECTA:
		ramon.estatica()
		await get_tree().create_timer(0.35).timeout
		ramon.reproducir_estacion(numero)  # suena mientras Nuna habla
	match numero:
		1:  # Radio Mérito
			ramon._sacudir()
			await _decir("RAMÓN: ¡Si cumplís, llegás! ¡Si cumplís, llegás!")
			$Props/Huesped.roncar(2.0)
			await _decir("Zzz… %s ronca. Esa la escuchó toda la vida." % _mayuscula(_ella()))
			Globals.cambiar_bruma(-COSTO_ESTACION_EQUIVOCADA)
		2:  # Radio Ocupada
			ramon._sacudir()
			await _decir("RAMÓN: Su llamada es importante para nosotros…")
			await _decir("%s se da vuelta. Ni se enteró." % _mayuscula(_ella()))
			Globals.cambiar_bruma(-COSTO_ESTACION_EQUIVOCADA)
		3:  # Radio Feriado: no cuesta nada, pero tampoco rinde
			await _decir("RAMÓN: …")
			await _decir("¿Feriado? ¿Y eso qué es?")
		ESTACION_CORRECTA:  # Radio Revés
			await ramon.sintonizar()  # estática, y al sonar Ofelia tiembla
			state.ramon_sonando = true
			await _decir("RAMÓN: ♪ oñin etemréud, oñin etemréud ♪")
			if a_la_primera:
				await _decir("¡A la primera!")
				Globals.cambiar_bruma(5.0)
			await _decir("%s (dormida): …¿Mamá?" % _hablante())
			await _decir("¡Una canción de cuna al revés! ¡Qué miedo!")
			await _decir("Lo que más asusta es oír tu vida para atrás.")
			Globals.aumentar_vela(20.0)
			Globals.otorgar_sello(&"ramon")
			return true
		5:  # Radio Hora Extra
			ramon._sacudir()
			await _decir("RAMÓN: ¡Un ratito más! ¡Un ratito más!")
			await _decir("%s: Cinco minutitos más…" % _hablante())
			Globals.cambiar_bruma(-COSTO_ESTACION_EQUIVOCADA)
	return false


## Lumi propone la adivinanza cuando ya se presentó y todavía no dio su sello.
func _lumi_tiene_adivinanza(lumi: Lumi) -> bool:
	# Solo con Lumi apagada: encendida, mirarla muestra cuánto falta para leer lo grabado.
	return lumi.mirada_inicial and lumi.estado == Lumi.Estado.APAGADA \
		and not Globals.sellos_obtenidos.has("lumi")


func _adivinanza_lumi(lumi: Lumi) -> void:
	await _decir("LUMI: ¡Psst, aprendiz! Si adivinás, te ilumino el turno.")
	await _decir("LUMI: Se gana asustando, se gasta esperando…")
	await _decir("LUMI: …y sin ella no hay sueldo. ¿Qué soy?")
	var respuesta: int = await PreguntaSiNo.elegir(self, "¿Qué es?", OPCIONES_ADIVINANZA)
	if respuesta != 0:
		Globals.iniciar_goteo()
		Globals.cambiar_bruma(-COSTO_ADIVINANZA_ERRADA)
		await _decir("LUMI: Frío, frío… Pista: se te escapa sola cada ratito.")
		await _decir("Uy, eso me costó bruma.")
		return
	await _decir("¡La bruma! ¡Mi sueldo de fantasma!")
	await _decir("LUMI: ¡Correcto! Que no se te escape.")
	lumi.resolver_adivinanza()  # Lumi se enciende y Ofelia tiembla
	Globals.aumentar_vela(VELA_ADIVINANZA)
	Globals.otorgar_sello(&"lumi")
	await _decir("¡Lumi brilla y %s tiembla!" % _ella())


## Mirar el velador abre el cajón; volver a mirarlo lo cierra.
func _mirar_velador(velador: ObjetoInteractivo) -> void:
	var primera_vez: bool = not velador.nombrado
	velador.ejecutar(Globals.MIRAR)
	if state.cajon_abierto:
		_mostrar_cajon(false)
		await _decir("Lo cierro, por las dudas.")
		return
	if primera_vez:
		await _decir(velador.frase_mirar)
	_mostrar_cajon(true)
	if $Props/Dentadura.recogido or Globals.tiene(&"dentadura"):
		await _decir("Solo queda el recibo de Ofelia. Lo dejo donde estaba." if state.recibo_leido else "Vacío. La sonrisa ya viene conmigo.")
	else:
		await _decir("¡Una sonrisa escondida en el cajón!")
		await _decir("El viejo dijo que guarde lo que encuentre. Una sonrisa siempre sirve. ¡Me la llevo!")
		_brillar($Props/Dentadura)


## Abre o cierra el cajón: cambia el dibujo del velador y muestra la dentadura adentro.
func _mostrar_cajon(abierto: bool) -> void:
	state.cajon_abierto = abierto
	var velador: ObjetoInteractivo = $Props/Velador
	if _textura_velador_cerrado == null:
		_textura_velador_cerrado = velador.textura
	velador.textura = _textura_velador_cajon_abierto() if abierto else _textura_velador_cerrado
	velador.queue_redraw()
	var dentadura: ObjetoInteractivo = $Props/Dentadura
	var guardada: bool = dentadura.recogido or Globals.tiene(&"dentadura")
	var visible_en_cajon: bool = abierto and not guardada
	dentadura.visible = visible_en_cajon
	dentadura.clickable = visible_en_cajon
	if visible_en_cajon and not dentadura.is_in_group("interactivos"):
		dentadura.add_to_group("interactivos")
	elif not visible_en_cajon and dentadura.is_in_group("interactivos"):
		dentadura.remove_from_group("interactivos")


## Usa velador_abierto.png si existe (exportado desde Aseprite); si no, lo dibuja a partir del cerrado.
func _textura_velador_cajon_abierto() -> Texture2D:
	if _textura_velador_abierto != null:
		return _textura_velador_abierto
	if ResourceLoader.exists(VELADOR_ABIERTO_PNG):
		_textura_velador_abierto = load(VELADOR_ABIERTO_PNG)
		return _textura_velador_abierto
	var img := _textura_velador_cerrado.get_image()
	img.decompress()
	var original := img.duplicate() as Image
	var oscuro := Color8(29, 14, 37)
	var negro := Color8(0, 0, 0)
	var claro := Color8(202, 196, 212)
	for x in range(5, 21):
		for y in range(6, 9):
			img.set_pixel(x, y, oscuro)  # interior del cajón
	for y in range(8, 15):
		for x in range(5, 21):
			img.set_pixel(x, y + 1, original.get_pixel(x, y))  # el frente baja un poco
	for x in range(5, 21):
		img.set_pixel(x, 8, negro)
		img.set_pixel(x, 9, claro if x < 20 else original.get_pixel(x, 9))
	for x in range(4, 22):
		img.set_pixel(x, 16, negro)
	for y in range(8, 17):
		img.set_pixel(4, y, negro)
		img.set_pixel(21, y, negro)
	_textura_velador_abierto = ImageTexture.create_from_image(img)
	return _textura_velador_abierto


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
		2: await _decir("Todavía floto a ras del piso… Soy un fantasma bebé.")
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
	if state.cajon_abierto and not Globals.tiene(&"dentadura"):
		return "Llevate la sonrisa del cajón: la vas a necesitar."
	if Globals.sellos >= Globals.SELLOS_TOTALES:
		if not Globals.tiene(&"dentadura"):
			return "¡3 de 3 sellos! Antes de irte, llevate la sonrisa del velador."
		return "¡Turno cumplido! Mirá la puerta para volver a la recepción."
	if _dial_abierto:
		return "Leé el código de Ramón al revés."
	if Globals.tiene(&"ovillo"):
		return "Llevá a Ovi a la ventana."
	var lumi: Lumi = $Props/Lumi
	if lumi.estado in [Lumi.Estado.NIVEL_1, Lumi.Estado.NIVEL_2] and not Globals.sellos_obtenidos.has("lumi"):
		return "Lumi tiene algo grabado. Perturbala otra vez para leerlo."
	if lumi.mirada_inicial and lumi.estado == Lumi.Estado.APAGADA and not Globals.sellos_obtenidos.has("lumi") \
			and Globals.sellos_obtenidos.size() == 2:
		return "Falta Lumi: perturbala varias veces seguidas."
	if lumi.estado == Lumi.Estado.NIVEL_3:
		return "Lumi está al máximo. Mirala para que descanse."
	if state.intentos_ramon > 0 and not Globals.sellos_obtenidos.has("ramon"):
		return "Ramón sigue sin sintonizar. Perturbalo y probá otra estación."
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
	# La charla de entrada va en una ventana aparte; después todo sigue en la consola.
	await DialogoPopup.mostrar(self, [
		["NUNA", "Los profesionales entran por la puerta, ¿no?"],
		["ORDEN DE TRABAJO", "Asustá a la huésped y ganá 3 sellos.", "(Horas extra no remuneradas.)"],
		["DIN", "¡A asustar, equipo! ♥"],
		["NUNA", "¡Tres sellos y soy profesional!"],
	])
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
	if not Globals.tiene(&"dentadura"):
		await _decir("Antes de irme… ¿no me olvido de algo?")
		_brillar($Props/Velador)


## Debajo de la dentadura está el recibo de jubilación de la huésped: así se llama Ofelia.
func _leer_recibo() -> void:
	if state.recibo_leido:
		return
	await _decir("¡Ey! Debajo de la sonrisa hay unos papeles.")
	var toma: Toma = null
	if ResourceLoader.exists(TOMA_RECIBO) or FileAccess.file_exists(TOMA_RECIBO):
		toma = await Toma.mostrar(self, TOMA_RECIBO, 0)
	else:
		await G.gui.ui.mostrar_certificacion(RECIBO_ETIQUETA, RECIBO_LETRA_CHICA)
	await _decir("¿Jubilación? ¡Viene de júbilo! ¡Debe ser lo más lindo del mundo!")
	await _decir("Ofelia… ¡La señora se llama Ofelia!")
	await _decir("Cuarenta y cinco años trabajando…")
	await _decir("¿Y el monto? A ver con la lupa…")
	await _decir("¿Eso es todo? ¡Uff! ¿Y con tan poquito le alcanza?")
	if toma != null:
		if toma._atlas.atlas.get_width() >= Toma.ANCHO * 2:
			toma.cuadro(1)
	else:
		await G.gui.ui.mostrar_certificacion(TARIFA_ETIQUETA, TARIFA_LETRA_CHICA)
	await _decir("…y con lo que le pagan, vive en el hotel.")
	await _decir("Incluye cama, desayuno y silencio. ¿Y el almuerzo? ¿Y la cena?")
	await _decir("Ah, ya entiendo: desayuna tanto que le dura hasta el día siguiente.")
	await _decir("Trabajó toda la vida y ganó una cama.")
	if toma != null:
		await toma.cerrar()
	state.recibo_leido = true
	_presentar_ofelia()
	await _decir("Cuando yo me jubile, ¿qué me van a dar? ¿Una nube?")


## La huésped deja de ser "cama": desde el recibo, Nuna sabe su nombre.
func _presentar_ofelia() -> void:
	var huesped: ObjetoInteractivo = $Props/Huesped
	huesped.nombre = "Ofelia"
	huesped.nombrado = true
	huesped.frase_mirar = "Ofelia duerme. Cuarenta y cinco años… se merece la siesta."
	huesped.description = huesped.nombre_visible()


## Con el turno cumplido, la puerta lleva de vuelta a la recepción (cinemática 2).
func _salir_de_la_101() -> void:
	if not Globals.tiene(&"dentadura"):
		if state.cajon_abierto:
			await _decir("¡Ay, me olvido la sonrisa! Sin sonrisa no se sale a trabajar.")
			_brillar($Props/Dentadura)
		else:
			await _decir("Todavía no… Me parece que el velador guarda algo.")
			_brillar($Props/Velador)
		return
	var salir: bool = await PreguntaSiNo.preguntar(self, "¿Volver a la recepción?")
	if not salir:
		await _decir("Un ratito más con Ofelia.")
		return
	await _decir("¡Chau, Ofelia! ¡Chau, Lumi, Ramón, Doña Cortina!")
	await $Props/Puerta.abrir()
	await C.player.walk($Markers/EntradaNuna.global_position)
	C.player.hide()
	await $Props/Puerta.cerrar()
	C.player.show()
	_saliendo = true
	_cancelar_seleccion()
	R.goto_room("Recepcion")


## El tercer sello: el único susto grande. Ofelia salta de la cama y grita.
func _ofelia_salta() -> void:
	await get_tree().create_timer(0.3).timeout
	$Props/Huesped.asustarse()
	await get_tree().create_timer(1.9).timeout
	await _decir("¡%s saltó de la cama!" % _mayuscula(_ella()))


## Cómo llama Nuna a la huésped: "la señora" hasta leer el recibo, después "Ofelia".
func _ella() -> String:
	return "Ofelia" if state.recibo_leido else "la señora"


## Cómo aparece en los diálogos cuando habla dormida.
func _hablante() -> String:
	return "OFELIA" if state.recibo_leido else "SEÑORA"


func _mayuscula(texto: String) -> String:
	return texto.left(1).to_upper() + texto.substr(1)


func _brillar(nodo: CanvasItem) -> void:
	var tw := create_tween()
	for i in 4:
		tw.tween_property(nodo, "modulate", Color(1.8, 1.8, 1.8), 0.15)
		tw.tween_property(nodo, "modulate", Color.WHITE, 0.15)


func _decir(texto: String) -> void:
	if not texto.is_empty():
		await C.player.say(texto)
