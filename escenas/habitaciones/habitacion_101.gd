extends Node2D
## Habitación 101 · prototipo gris.
## Clic en el piso = moverse; clic en un objeto = mostrar sus acciones.

@onready var nuna: Nuna = $Nuna
@onready var marcador: ColorRect = $Marcador
@onready var ui: InterfazUI = $UI
@onready var huesped: Huesped101 = get_node_or_null("Cama") as Huesped101

var objeto_seleccionado: ObjetoInteractivo = null
var objeto_pendiente: ObjetoInteractivo = null  # el objeto hacia el que va Nuna
var verbo_pendiente: StringName = &""
var ocupado: bool = false
var cortina_bailando: bool = false
var sombra_gigante_activada: bool = false
var _entrada_en_progreso: bool = false
var _intentos_ramon: int = 0
var _saltos_ventana: int = 0

const PREFIJO_DIN: String = "DIN: "
const ORDEN_TRABAJO: String = "Orden de trabajo: asusta a la huésped y gana 3 sellos."
const ORDEN_LETRA_CHICA: String = "(Horas extra no remuneradas.)"
const VELA_RAMON: float = 20.0
const VELA_CORTINA: float = 15.0
## Primera mirada: Nuna bautiza al objeto antes de su frase de siempre.
const BAUTISMOS: Dictionary = {
	&"radio": "¡Hola, radio! Te llamaré Ramón.",
	&"ventana": "¡Hola, cortina! Te llamaré Doña Cortina.",
	&"ovillo": "¡Hola, ovillo! Te llamaré Ovi.",
}
const FRASES_PROGRESO: Array[String] = [
	"",
	"¡Sello uno! Faltan dos.",
	"¡Dos de tres! ¡Ya casi!",
	"¡Tres sellos! ¡Ya soy casi profesional!",
]


func _ready() -> void:
	marcador.visible = false
	if huesped == null:
		push_warning("El nodo 'Cama' no tiene asignado el script Huesped101; las reacciones visuales no se conectarán.")
	nuna.llego.connect(_on_nuna_llego)
	nuna.dialogo_solicitado.connect(ui.mostrar_dialogo)
	nuna.dialogo_finalizado.connect(ui.finalizar_dialogo)
	ui.accion_elegida.connect(_ejecutar_accion_sobre_seleccion)
	ui.mostrar_exploracion()
	ui.establecer_acciones_habilitadas(false)
	for nodo in get_tree().get_nodes_in_group("interactivos"):
		var obj := nodo as ObjetoInteractivo
		if obj != null:
			obj.mirado.connect(_on_objeto_mirado)
			obj.perturbado.connect(_on_objeto_perturbado)
			obj.agarrado.connect(_on_objeto_agarrado)
			if obj is Lumi:
				var lumi := obj as Lumi
				lumi.combo_sombra_activado.connect(_on_combo_sombra_activado)
				if huesped != null:
					lumi.susto_chico.connect(huesped.temblar)
					lumi.fogonazo_realizado.connect(huesped.asustarse)
			elif obj is Ramon and huesped != null:
				var ramon := obj as Ramon
				# Reacción temporal para probar el feedback visual antes de tener el dial.
				ramon.comenzo_a_sonar.connect(huesped.temblar)
	_crear_lista_tareas()
	ocupado = true
	GameState.pausado = true
	_entrada_en_progreso = true
	call_deferred("_reproducir_entrada")


func _process(_delta: float) -> void:
	if not ocupado and objeto_seleccionado != null and not _seleccion_es_valida():
		_cancelar_seleccion()


func _unhandled_input(event: InputEvent) -> void:
	if ocupado:
		return
	# --- Teclas de prueba (se borran más adelante) ---
	var tecla := event as InputEventKey
	if tecla != null and tecla.pressed and not tecla.echo:
		if tecla.keycode == KEY_ESCAPE:
			_cancelar_seleccion()
		elif tecla.keycode == KEY_1:
			GameState.sumar_sello()
		elif tecla.keycode == KEY_2:
			GameState.cambiar_bruma(-10.0)
		elif tecla.keycode == KEY_3:
			GameState.cambiar_bruma(10.0)
		return

	var boton := event as InputEventMouseButton
	# Clic derecho: muestra la coordenada en Salida (para medir el fondo)
	if boton != null and boton.pressed and boton.button_index == MOUSE_BUTTON_RIGHT:
		print("Coordenada: ", get_global_mouse_position().round())
		return
	if boton == null or not boton.pressed or boton.button_index != MOUSE_BUTTON_LEFT:
		return

	var clic: Vector2 = get_global_mouse_position()
	if clic.y >= Ajustes.UI_Y:
		return  # clic en la franja de interfaz

	var obj: ObjetoInteractivo = _objeto_en(clic)
	if obj != null:
		objeto_seleccionado = obj
		_mostrar_contexto_seleccionado()
	else:
		_cancelar_seleccion()
		var destino := Vector2(
			clampf(clic.x, Ajustes.LIMITE_X_MIN, Ajustes.LIMITE_X_MAX),
			clampf(clic.y, Ajustes.PISO_Y_MIN, Ajustes.PISO_Y_MAX)
		)
		_mover_nuna(destino)


func _ejecutar_accion_sobre_seleccion(verbo: StringName) -> void:
	if ocupado:
		return
	if not _seleccion_es_valida():
		_cancelar_seleccion()
		return
	if not _accion_disponible(objeto_seleccionado, verbo):
		return

	ocupado = true
	objeto_pendiente = objeto_seleccionado
	verbo_pendiente = verbo
	ui.establecer_acciones_habilitadas(false)
	_mover_nuna(objeto_pendiente.punto_de_uso())


func _mover_nuna(destino: Vector2) -> void:
	nuna.ir_a(destino)
	marcador.position = destino - marcador.size / 2.0
	marcador.visible = true


func _on_nuna_llego() -> void:
	if _entrada_en_progreso:
		return
	marcador.visible = false
	if objeto_pendiente == null:
		return
	var obj: ObjetoInteractivo = objeto_pendiente
	if not is_instance_valid(obj) or not obj.is_inside_tree():
		ocupado = false
		_cancelar_seleccion()
		return
	objeto_pendiente = null
	var sellos_antes: int = GameState.sellos
	nuna.mirar_a(obj.global_position)
	await nuna.interactuar()
	if obj is Ramon and verbo_pendiente == GameState.PERTURBAR and obj.nombrado:
		await _perturbar_ramon(obj as Ramon)
	elif obj is VentanaAnimada and obj.nombrado and (verbo_pendiente == GameState.PERTURBAR or GameState.tiene(&"ovillo")):
		await _perturbar_ventana(obj as VentanaAnimada)
	elif obj is Lumi:
		var lumi := obj as Lumi
		var frases: Array[String] = lumi.resolver_accion(verbo_pendiente, cortina_bailando)
		for i in range(frases.size()):
			await nuna.decir(frases[i])
			if lumi.certificacion_pendiente_despues_de_frase(i):
				await ui.mostrar_certificacion(
					Lumi.FRASE_ETIQUETA,
					Lumi.FRASE_LETRA_CHICA
				)
		lumi.completar_dialogo()
		await lumi.esperar_bloqueo()
	else:
		if verbo_pendiente == GameState.MIRAR and not obj.nombrado and BAUTISMOS.has(obj.id):
			await nuna.decir(BAUTISMOS[obj.id])
		var frase: String = obj.ejecutar(verbo_pendiente)
		await nuna.decir(frase)
		if obj.id == &"ovillo" and GameState.tiene(&"ovillo"):
			await nuna.decir("¡Contigo llego a la ventana, Ovi!")
			_brillar(get_node_or_null("Ventana"))
	if GameState.sellos > sellos_antes and GameState.sellos < FRASES_PROGRESO.size():
		await nuna.decir(FRASES_PROGRESO[GameState.sellos])
		if GameState.sellos >= GameState.SELLOS_TOTALES:
			await _mision_cumplida()
	ocupado = false
	_actualizar_guia()
	if _seleccion_es_valida():
		_mostrar_contexto_seleccionado()
	else:
		_cancelar_seleccion()


func _reproducir_entrada() -> void:
	objeto_seleccionado = null
	objeto_pendiente = null
	verbo_pendiente = &""
	marcador.visible = false
	ui.mostrar_exploracion()

	var marcador_entrada := get_node_or_null("EntradaNuna") as Marker2D
	var marcador_inicio := get_node_or_null("InicioNuna") as Marker2D
	var posicion_entrada: Vector2 = nuna.global_position
	if marcador_entrada != null:
		posicion_entrada = marcador_entrada.global_position
	else:
		push_warning("Falta el Marker2D 'EntradaNuna'; se usará la posición actual de Nuna.")

	var posicion_inicio: Vector2 = posicion_entrada + Vector2(35.0, 0.0)
	if marcador_inicio != null:
		posicion_inicio = marcador_inicio.global_position
	else:
		push_warning("Falta el Marker2D 'InicioNuna'; se usará EntradaNuna + Vector2(35, 0).")

	var puerta := get_node_or_null("Puerta") as PuertaAnimada
	nuna.visible = false
	if puerta != null:
		puerta.mostrar_cerrada()
		await puerta.abrir()
	else:
		push_warning("El nodo 'Puerta' no tiene asignado el script PuertaAnimada.")

	nuna.global_position = posicion_entrada
	nuna.visible = true
	nuna.ir_a(posicion_inicio)
	await nuna.llego
	nuna.volver_a_reposo_frontal()

	if puerta != null:
		await puerta.cerrar()
	await nuna.decir("Los profesionales entran por la puerta, ¿no?")
	# La orden de trabajo usa el mismo panel que las etiquetas: promesa arriba, letra chica abajo.
	await ui.mostrar_certificacion(ORDEN_TRABAJO, ORDEN_LETRA_CHICA)
	await _decir_din("¡A asustar, equipo! ♥")
	await nuna.decir("¡Tres sellos y soy profesional!")
	_finalizar_entrada()


func _finalizar_entrada() -> void:
	_entrada_en_progreso = false
	ocupado = false
	GameState.pausado = false
	nuna.visible = true
	ui.establecer_acciones_habilitadas(true)
	_actualizar_guia()


func _mostrar_contexto_seleccionado() -> void:
	if not _seleccion_es_valida():
		_cancelar_seleccion()
		return
	ui.mostrar_objeto(
		objeto_seleccionado.nombre_visible(),
		true,
		objeto_seleccionado.puede_agarrar,
		objeto_seleccionado.puede_perturbar
	)
	ui.establecer_acciones_habilitadas(not ocupado)


func _cancelar_seleccion() -> void:
	objeto_seleccionado = null
	objeto_pendiente = null
	verbo_pendiente = &""
	ui.mostrar_exploracion()
	ui.establecer_acciones_habilitadas(false)


func _seleccion_es_valida() -> bool:
	return (
		is_instance_valid(objeto_seleccionado)
		and objeto_seleccionado.is_inside_tree()
		and objeto_seleccionado.visible
		and objeto_seleccionado.is_in_group("interactivos")
		and not GameState.tiene(objeto_seleccionado.id)
	)


func _accion_disponible(obj: ObjetoInteractivo, verbo: StringName) -> bool:
	if verbo == GameState.MIRAR:
		return true
	if verbo == GameState.AGARRAR:
		return obj.puede_agarrar
	if verbo == GameState.PERTURBAR:
		return obj.puede_perturbar
	return false


func _on_objeto_agarrado(obj: ObjetoInteractivo) -> void:
	GameState.agregar_objeto(obj.id, obj.nombre)


func _on_objeto_mirado(_obj: ObjetoInteractivo) -> void:
	pass


func _on_objeto_perturbado(_obj: ObjetoInteractivo) -> void:
	pass


func _on_combo_sombra_activado() -> void:
	sombra_gigante_activada = true
	GameState.llenar_vela(Ajustes.LUMI_HABITACION_ID)


## Prueba 2 (versión prototipo): Ramón arranca al segundo intento.
func _perturbar_ramon(ramon: Ramon) -> void:
	if GameState.sellos_obtenidos.has(&"ramon"):
		await nuna.decir("Ramón ya cantó su parte.")
		return
	GameState.iniciar_goteo()
	_intentos_ramon += 1
	if _intentos_ramon == 1:
		ramon._sacudir()
		await nuna.decir("¡Otra vez, Ramón! ¡No se descansa!")
		return
	ramon.sintonizar()  # al sonar, la señora tiembla
	await nuna.decir("¡Ramón canta! ¡Qué miedo!")
	GameState.aumentar_vela(Ajustes.LUMI_HABITACION_ID, VELA_RAMON)
	GameState.otorgar_sello(&"ramon")


## Prueba 3 (versión prototipo): sin Ovi no llega; con Ovi en el inventario, abre.
func _perturbar_ventana(ventana: VentanaAnimada) -> void:
	if cortina_bailando:
		await nuna.decir("Ya está bailando. Falta luz.")
		return
	GameState.iniciar_goteo()
	if GameState.tiene(&"ovillo"):
		await nuna.decir("Ovi, ¿me das una mano?")
		GameState.quitar_objeto(&"ovillo")
		ventana.bailar()
		cortina_bailando = true
		if huesped != null:
			huesped.temblar()
		await nuna.decir("¡Doña Cortina baila sola!")
		GameState.aumentar_vela(Ajustes.LUMI_HABITACION_ID, VELA_CORTINA)
		GameState.otorgar_sello(&"ventana")
		return
	_saltos_ventana += 1
	GameState.cambiar_bruma(-2.0)
	await nuna.mini_salto()
	match _saltos_ventana:
		1:
			await nuna.decir("¡Hop! …¡Hop! Uf… los profesionales flotan más alto, ¿no?")
		2:
			await nuna.decir("Todavía soy un fantasma bebé…")
		_:
			var ovi := get_node_or_null("Ovillo") as Node2D
			if ovi != null and ovi.visible:
				nuna.mirar_a(ovi.global_position)
				_brillar(ovi)
			await nuna.decir("Si tuviera un escaloncito…")


## La consola de abajo dice cuál es el próximo paso, según cómo va la partida.
func _actualizar_guia() -> void:
	ui.establecer_guia(_texto_guia())


func _texto_guia() -> String:
	var sellos: int = GameState.sellos
	if sellos >= GameState.SELLOS_TOTALES:
		return "¡3 de 3 sellos! Turno cumplido."
	if GameState.tiene(&"ovillo"):
		return "Llevá a Ovi a la ventana."
	var lumi := get_node_or_null("Lampara") as Lumi
	if lumi != null and lumi.estado == Lumi.Estado.NIVEL_3:
		return "Lumi brilla fuerte. Mirala de nuevo."
	if _intentos_ramon == 1 and not GameState.sellos_obtenidos.has(&"ramon"):
		return "Ramón no arrancó. Perturbalo otra vez."
	if _saltos_ventana > 0 and not GameState.sellos_obtenidos.has(&"ventana"):
		return "La ventana está alta. Buscá algo para subirte."
	var alguno_mirado := false
	for nombre in ["Lampara", "Radio", "Ventana"]:
		var obj := get_node_or_null(nombre) as ObjetoInteractivo
		if obj != null and obj.nombrado:
			alguno_mirado = true
	if not alguno_mirado:
		return "Hacé clic en un objeto y miralo para conocerlo."
	if sellos == 0:
		return "Perturbá lo que conociste para asustar a la huésped."
	return "%d de 3 sellos. ¡Seguí asustando!" % sellos


## Lista de tareas debajo del HUD: una por prueba.
func _crear_lista_tareas() -> void:
	var lista := ListaTareas.new()
	add_child(lista)
	for datos in [["Lampara", &"lumi", "Lámpara"], ["Radio", &"ramon", "Radio"], ["Ventana", &"ventana", "Cortina"]]:
		var obj := get_node_or_null(datos[0]) as ObjetoInteractivo
		if obj != null:
			lista.agregar(obj, datos[1], datos[2])


## Con los tres sellos vuelve la orden de trabajo, sellada.
func _mision_cumplida() -> void:
	var orden := OrdenTrabajo.new()
	orden.cumplida = true
	add_child(orden)
	await orden.aceptado
	await _decir_din("¡Bien, equipo! ¡Una más! ♥")
	await nuna.decir("¿Una más?…")
	await nuna.decir("Los profesionales siempre se ponen la 10, ¿no?")


## Hace parpadear un objeto para señalarlo.
func _brillar(nodo: CanvasItem) -> void:
	if nodo == null:
		return
	var tw := create_tween()
	for i in 4:
		tw.tween_property(nodo, "modulate", Color(1.8, 1.8, 1.8), 0.15)
		tw.tween_property(nodo, "modulate", Color.WHITE, 0.15)


## Din habla desde ninguna parte, en la misma caja de diálogo.
func _decir_din(texto: String) -> void:
	await nuna.decir(PREFIJO_DIN + texto)


## Devuelve el objeto que está bajo el punto, o null si no hay ninguno.
func _objeto_en(punto: Vector2) -> ObjetoInteractivo:
	var lista: Array[Node] = get_tree().get_nodes_in_group("interactivos")
	var objeto_mas_chico: ObjetoInteractivo = null
	var area_menor: float = INF
	for i in range(lista.size() - 1, -1, -1):
		var o := lista[i] as ObjetoInteractivo
		if o != null and o.contiene(punto):
			var area: float = o.tamano.x * o.tamano.y
			if area < area_menor:
				area_menor = area
				objeto_mas_chico = o
	return objeto_mas_chico
