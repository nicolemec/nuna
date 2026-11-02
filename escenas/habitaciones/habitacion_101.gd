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
	nuna.mirar_a(obj.global_position)
	await nuna.interactuar()
	if obj is Lumi:
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
		var frase: String = obj.ejecutar(verbo_pendiente)
		await nuna.decir(frase)
	ocupado = false
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
	_finalizar_entrada()


func _finalizar_entrada() -> void:
	_entrada_en_progreso = false
	ocupado = false
	GameState.pausado = false
	nuna.visible = true
	ui.establecer_acciones_habilitadas(true)


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
