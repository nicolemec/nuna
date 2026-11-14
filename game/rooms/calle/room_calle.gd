@tool
extends SalaIntro
## TOMA 2 — Calle: Nuna recorre la ciudad fantasma. La cámara lo sigue en X.
## Interacciones opcionales: el fantasma del banco y tres carteles.
## Obligatoria: el anuncio de aprendices, que habilita la puerta del hotel.

const Data := preload("room_calle_state.gd")
## Segundos entre la charla y la desaparición del fantasma del banco (pedido: entre 5 y 10).
const FANTASMA_ESPERA := 6.0
const FRASES_CARTELES := {
	&"cartel_vagando": "¡Ah! ¿También hay que tener casa después de muerto?",
	&"cartel_eternidad": "¿Se puede llegar tarde a la eternidad? ¡Pensé que por fin tenía tiempo!",
	&"cartel_bruma": "¡Qué bien! ¿Hay gimnasios para fantasmas?",
}
## El anuncio se lee en la consola, como las etiquetas de la 101: [texto, letra chica].
## Va en dos partes porque la etiqueta grande entra en una sola línea.
const ANUNCIO := [
	["HOTEL: SE BUSCAN APRENDICES", "Comenzá tu eternidad con nosotros."],
	["Capacitación incluida.", "Disponibilidad inmediata."],
]

var state: Data = load("res://game/rooms/calle/room_calle.tres")
## Nuna se desvanece a medida que avanza por la calle (sin Bruma no se sostiene).
## Nunca recupera opacidad acá: aunque vuelva hacia el hotel, sigue igual de transparente.
const ALFA_MINIMA := 0.35
const DESVANECE_DESDE_X := 80.0
const DESVANECE_HASTA_X := 620.0
## Cuando baja de esta opacidad, Nuna lo nota (una sola vez).
const ALFA_AVISO := 0.6

var _alfa := 1.0
var _aviso_dado := false
var _tiempo := 0.0


func _on_room_entered() -> void:
	super()
	C.player.position = $Markers/SalidaTeatro.position
	_alfa = _alfa_nuna()
	$Props/PuertaHotel.recortar_de($Background.texture)
	if state.fantasma_desaparecido:
		$Props/Fantasma.visible = false
		_retirar($Props/Fantasma)
	else:
		$Props/Fantasma.resaltar = true
	$Props/PuertaHotel.resaltar = state.anuncio_leido
	_actualizar_guia()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _saliendo or not is_instance_valid(C.player):
		return
	_tiempo += delta
	var avance := clampf((C.player.global_position.x - DESVANECE_DESDE_X) / (DESVANECE_HASTA_X - DESVANECE_DESDE_X), 0.0, 1.0)
	_alfa = minf(_alfa, lerpf(1.0, ALFA_MINIMA, avance))
	C.player.set_meta("alfa_intro", _alfa)
	# Cuanto más transparente, más titila.
	var titileo := (1.0 - _alfa) * 0.08 * sin(_tiempo * 9.0)
	C.player.modulate.a = clampf(_alfa + titileo, 0.0, 1.0)
	if not _aviso_dado and _alfa <= ALFA_AVISO and not ocupado and not C.player.is_moving:
		_aviso_dado = true
		_avisar_desvanecimiento()


func _avisar_desvanecimiento() -> void:
	ocupado = true
	_actualizar_guia()
	await _decir("Uy… ¿Me estoy borrando?")
	ocupado = false
	_actualizar_guia()


func _on_room_transition_finished() -> void:
	ocupado = true
	_actualizar_guia()
	await C.player.walk($Markers/InicioNuna.position)
	C.player.volver_a_reposo_frontal()
	ocupado = false
	_actualizar_guia()


func _texto_guia() -> String:
	if state.anuncio_leido:
		return "Volvé a la entrada del hotel."
	return "Explorá la calle. Hacé clic para caminar."


func _resolver_accion(obj: ObjetoInteractivo, _verbo: StringName) -> void:
	obj.nombrado = true
	match obj.id:
		&"fantasma":
			await _hablar_con_fantasma(obj as FantasmaBanco)
		&"cartel_vagando", &"cartel_eternidad", &"cartel_bruma":
			await _decir(FRASES_CARTELES[obj.id])
		&"anuncio":
			await _leer_anuncio()
		&"puerta_hotel":
			await _puerta_hotel()


func _hablar_con_fantasma(fantasma: FantasmaBanco) -> void:
	if state.fantasma_hablo:
		await _decir("¿Hola? ¿Señor?")
		return
	state.fantasma_hablo = true
	fantasma.resaltar = false
	await _decir("FANTASMA: No todos los espíritus llegan a ser leyendas.")
	await _decir("¿Y cómo se hace?")
	# No responde. Se desvanece un rato después, aunque Nuna siga caminando.
	get_tree().create_timer(FANTASMA_ESPERA).timeout.connect(_desvanecer_fantasma)


func _desvanecer_fantasma() -> void:
	var fantasma: FantasmaBanco = $Props/Fantasma
	if objeto_seleccionado == fantasma:
		_cancelar_seleccion()
	await fantasma.desaparecer()
	_retirar(fantasma)
	state.fantasma_desaparecido = true
	await _reaccionar_a_la_desaparicion()


## Nuna se da cuenta de que el fantasma ya no está. Espera a que termine lo que esté
## haciendo (otra charla, un cartel) para no pisarle el diálogo.
func _reaccionar_a_la_desaparicion() -> void:
	for _intento in range(600):  # hasta ~10 s
		if _saliendo or not is_inside_tree():
			return
		if not ocupado and not G.is_blocked:
			break
		await get_tree().process_frame
	if _saliendo or ocupado or G.is_blocked:
		return
	ocupado = true
	_actualizar_guia()
	G.gui.ui.establecer_acciones_habilitadas(false)
	if C.player.is_moving:
		C.player.stop_walking()
	await _decir("Uf… ¿Qué le habrá pasado?")
	ocupado = false
	_actualizar_guia()


func _leer_anuncio() -> void:
	for parte: Array in ANUNCIO:
		await G.gui.ui.mostrar_certificacion(parte[0], parte[1])
	if state.anuncio_leido:
		return
	await _decir("¡Aprendiz! ¡Yo puedo ser aprendiz!")
	await _decir("La flecha apunta para atrás… ¡El hotel!")
	state.anuncio_leido = true
	_habilitar($Props/PuertaHotel)


func _puerta_hotel() -> void:
	if not state.anuncio_leido:
		await _decir("Un hotel. No tengo reserva… ni equipaje.")
		return
	_retirar($Props/PuertaHotel)
	C.player.mirar_a(C.player.global_position + Vector2(0, -20))  # de espaldas, hacia la puerta
	await E.wait(0.4)
	_ir_a("Recepcion")


# ---------- Saltar ----------

func _sala_siguiente() -> String:
	return "Recepcion"


## Llega a la recepción medio borroso, como si hubiera caminado toda la calle.
func _completar_esta_sala() -> void:
	state.anuncio_leido = true
	_alfa = minf(_alfa, ALFA_MINIMA)
	_poner_alfa_nuna(_alfa)
