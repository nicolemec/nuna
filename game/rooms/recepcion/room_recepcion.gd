@tool
extends SalaIntro
## TOMA 3 — Recepción: timbre, aparece el viejo, charla, tutorial de la lámpara y a la 101.
## La lámpara usa los verbos de la consola, igual que la 101: primero Mirar, después Perturbar.

const Data := preload("room_recepcion_state.gd")
const RUTA_TIMBRE := "res://audio/sfx/timbre.wav"
const TOMA_CONTRATO := "res://arte/tomas/toma_contrato.png"
const TOMA_REGISTRO := "res://arte/tomas/toma_registro.png"  ## 2 cuadros: vacío y firmado
const TOMA_CUADERNO := "res://arte/tomas/toma_cuaderno.png"
## Zonas donde el jugador hace clic dentro de las tomas (en píxeles del dibujo, 320x152).
const ZONA_FIRMA := Rect2i(112, 103, 118, 15)        # la línea "Firma:" del contrato
const CRUZ_FIRMA := Vector2i(160, 104)
const ZONA_NOMBRE := Rect2i(24, 107, 88, 17)         # la línea vacía del registro
const ZONA_TERROR := Rect2i(97, 118, 142, 15)        # "Terror" en el cuaderno

enum Paso { TIMBRE, MIRAR_LAMPARA, PERTURBAR_LAMPARA, TERMINADO }

var state: Data = load("res://game/rooms/recepcion/room_recepcion.tres")


func _on_room_entered() -> void:
	# Después de la 101 Nuna ya no lleva birrete (lo lee super() al entrar).
	nuna_con_birrete = state.paso != Paso.TERMINADO
	super()
	C.player.position = $Markers/Puerta101.position if _vuelve_de_la_101() else $Markers/Entrada.position
	if state.paso == Paso.TERMINADO:
		G.gui.ui.mostrar_hud(true)
	var timbre: ZonaIntro = $Props/Timbre
	timbre.recortar_de($Background.texture)
	if state.paso == Paso.TIMBRE:
		_habilitar(timbre)
	else:
		_retirar(timbre)
	_retirar($Props/Lampara)
	# La llave 101 ya se entregó si la intro pasó ese punto.
	$LlaveroSinLlave.visible = state.paso == Paso.TERMINADO
	$Llave101.hide()
	if ResourceLoader.exists(RUTA_TIMBRE):
		$SonidoTimbre.stream = load(RUTA_TIMBRE)


func _on_room_transition_finished() -> void:
	if _vuelve_de_la_101():
		await _cinematica_2()
		return
	ocupado = true
	_actualizar_guia()
	await C.player.walk($Markers/Mostrador.position)
	C.player.volver_a_reposo_frontal()
	await _decir("¿Hola? ¿Hay alguien?")
	ocupado = false
	_actualizar_guia()


func _texto_guia() -> String:
	if state.cinematica_2:
		return "Fin del turno 1. La 202 todavía está en obra."
	match state.paso:
		Paso.TIMBRE:
			return "Hay un timbre en el mostrador."
		Paso.MIRAR_LAMPARA:
			return "Hacé clic en la lámpara y elegí Mirar."
		Paso.PERTURBAR_LAMPARA:
			return "Hacé clic en Doña Luz y elegí Perturbar."
	return ""


func _resolver_accion(obj: ObjetoInteractivo, verbo: StringName) -> void:
	match obj.id:
		&"timbre":
			await _tocar_timbre(obj as ZonaIntro)
		&"lampara":
			await _usar_lampara(obj as LamparaRecepcion, verbo)


# ---------- 5.1 Timbre y encuentro con el viejo ----------

func _tocar_timbre(timbre: ZonaIntro) -> void:
	if state.paso != Paso.TIMBRE:
		return
	_retirar(timbre)
	$SonidoTimbre.play()
	await timbre.saltar()
	await E.wait(0.8)
	await _llega_el_viejo()
	await _charla_nombre()
	await _charla_trabajo()
	await _pedir_lampara()


func _llega_el_viejo() -> void:
	var viejo: ViejoRecepcion = $Viejo
	await mover_camara_a($Markers/PuertaViejo.position.x, 1.6)
	await viejo.aparecer($Markers/PuertaViejo.position)
	await viejo.suspirar()
	# Flota hasta el mostrador y la cámara lo acompaña.
	var destino: float = $Markers/ViejoMostrador.position.x
	var tw := create_tween().set_parallel()
	Pixel.mover(tw, viejo, "position:x", destino, 3.0)
	Pixel.mover(tw, E.camera, "position:x", (destino + C.player.global_position.x) / 2.0, 3.0)
	await tw.finished
	await devolver_camara(0.5)
	C.player.mirar_a(viejo.global_position)


func _charla_nombre() -> void:
	await _viejo("¿Sí?")
	await _decir("¡Hola! ¡Vengo por el trabajo!")
	await _viejo("Qué entusiasmo. Ya se te va a pasar.")
	await _decir("¡Quiero ser aprendiz!")
	await _viejo("Ajá. ¿Nombre?")
	await _decir("...")
	await _viejo("Tu nombre. Necesito anotarlo.")
	await _decir("No sé.")
	await _viejo("¿Cómo que no sabés? Todo el mundo tiene un nombre.")
	await _decir("¡Ah! ¿Y cómo sé cuál es el mío?")
	await _viejo("No sé, muchacho. Generalmente te enterás antes de llegar acá.")
	await E.wait(1.5)  # el viejo lo mira unos segundos
	await _viejo("Bueno. Después vemos eso.")
	await _firmar_contrato()


## Nuna firma el contrato y el registro, y recibe su primera Bruma: deja de desvanecerse.
## Las tomas (arte/tomas/) se muestran a pantalla completa mientras sigue el diálogo.
func _firmar_contrato() -> void:
	await _viejo("Firmá acá.")
	var toma := await Toma.mostrar(self, TOMA_CONTRATO)
	await _decir("¿Con qué nombre?")
	await _viejo("Poné una cruz.")
	await toma.esperar_clic(ZONA_FIRMA, "Hacé clic en la línea para firmar.")
	toma.dibujar_cruz(CRUZ_FIRMA)
	await E.wait(0.5)
	await _decir("¿Y qué beneficios hay en el reverso?")
	await _viejo("No des vuelta la hoja.")
	await toma.cerrar()
	await C.player.walk($Markers/Libro.position)
	await C.player.interactuar($Markers/Libro.position + Vector2(0, -60))
	toma = await Toma.mostrar(self, TOMA_REGISTRO, 0)
	# Acá Nuna se pone nombre solo: si nadie lo nombró, se nombra él.
	await _decir("Acá sí va un nombre, ¿no?")
	await _viejo("Poné cualquiera. Nadie lo lee.")
	await toma.esperar_clic(ZONA_NOMBRE, "Hacé clic en la línea para escribir un nombre.")
	await _decir("Mmm…")
	toma.cuadro(1)  # aparece "NUNA" escrito en el registro
	toma._rascar()
	await E.wait(0.6)
	await _decir("¡Nuna!")
	await _viejo("¿Nuna?")
	await _decir("No sé de dónde salió. Pero me queda bien.")
	await _viejo("Nuna. Aprendiz. Anotado.")
	await _viejo("Y esta es la cuota de hoy.")
	await _decir("¿Velas?")
	await _viejo("Una por habitación. Se encienden con el miedo de los huéspedes.")
	await _decir("¡Qué lindas! ¿Y qué se quema?")
	await _viejo("Tu tiempo. Cada susto te cuesta un rato de eternidad.")
	await _decir("¡Pero si tengo toda la eternidad!")
	await _viejo("Eso dicen todos los aprendices.")
	await _decir("¿Y los sellos?")
	await _viejo("Los sellos son tuyos. Las velas, de Gerencia.")
	await toma.cerrar()
	await _absorber_bruma()
	await _decir("¡Ah! ¡Me siento… entero!")
	await _viejo("Es el adelanto. Después se descuenta.")


func _absorber_bruma() -> void:
	# Aparece el marcador de Bruma arriba y se llena mientras Nuna vuelve a ser opaco.
	G.gui.ui.presentar_bruma(1.4)
	# Vuelve a ser opaco de a poco y al final da un destello.
	var tw := create_tween()
	tw.tween_method(_poner_alfa_nuna.bind(false), C.player.modulate.a, 1.0, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(C.player, "modulate", Color(1.8, 1.8, 2.2, 1.0), 0.25)
	tw.tween_property(C.player, "modulate", Color.WHITE, 0.45)
	await tw.finished
	_poner_alfa_nuna(1.0)


# ---------- 5.2 El trabajo ----------

func _charla_trabajo() -> void:
	await _viejo("El trabajo es bastante simple. Tenés que asustar a los huéspedes.")
	await _decir("¡¿En serio?!")
	await _viejo("Sí. Para eso están los hoteles.")
	await _decir("¡Qué emocionante! ¿Y cómo se hace?")
	await _viejo("En cada habitación hay objetos.")
	await _viejo("Los mirás, los agarrás, los perturbás... Lo de siempre.")
	await _decir("¿Y las herramientas? ¿Me dan cadenas? ¿Una sábana?")
	await _viejo("La empresa no da insumos.")
	await _viejo("Lo que encuentres en una habitación, guardalo. Capaz te sirve para asustar en otra.")
	await _decir("¡Reciclaje fantasma!")
	await _viejo("Se llama arreglarse con lo que hay.")
	await _decir("¿Y volar? ¿Atravesar paredes?")
	await _viejo("Eso es para los que tienen años de casa. Vos todavía flotás a ras del piso.")
	await _viejo("Si algo te queda alto, buscate un escalón.")
	await _decir("¿Y con eso consigo Bruma?")
	await _viejo("Una parte. El resto va para Gerencia.")
	await _decir("¿Gerencia también es un fantasma?")
	await _viejo("Peor.")
	await E.wait(1.0)
	await _viejo("El tiempo es Bruma, aprendiz.")
	await _viejo("Ah. Y si escuchás un «din», es para vos.")
	await _decir("¿Un «din»? ¿Quién?")
	await _viejo("Ya te vas a dar cuenta. Habla mucho y no escucha nada.")


# ---------- 5.3 Tutorial: la lámpara ----------

func _pedir_lampara() -> void:
	await _viejo("Mirá esa lámpara.")
	state.paso = Paso.MIRAR_LAMPARA
	_habilitar($Props/Lampara)


func _usar_lampara(lampara: LamparaRecepcion, verbo: StringName) -> void:
	if verbo == Globals.MIRAR:
		if state.paso != Paso.MIRAR_LAMPARA:
			await _decir(lampara.ejecutar(verbo))
			return
		lampara.ejecutar(verbo)  # queda "conocida": ahora se puede perturbar
		await _decir("¡Es preciosa!")
		# Nuna se puso nombre solo, así que les pone nombre a las cosas que conoce.
		await _decir("A vos tampoco te pusieron nombre, ¿no? Te voy a llamar Doña Luz.")
		await _viejo("Es una lámpara.")
		await _viejo("Tocala.")
		state.paso = Paso.PERTURBAR_LAMPARA
		return
	if verbo != Globals.PERTURBAR:
		return
	if not lampara.nombrado:
		await _decir(lampara.ejecutar(verbo))  # "¡Ay, todavía no nos presentamos!"
		return
	_retirar(lampara)
	await lampara.parpadear()
	await _decir("¡Oh! ¡La hice temblar!")
	await _viejo("Sí. Perturbala. Eso es lo que tenés que hacer.")
	await _decir("¡Puedo hacer eso!")
	await _viejo("Ya veremos.")
	await _entregar_cuaderno_y_llave()
	state.paso = Paso.TERMINADO
	await _enviar_a_la_101()


# ---------- Cuaderno de certificación y llave ----------
## El viejo explica los sellos en general; cada habitación explica sus tareas en su orden de trabajo.

func _entregar_cuaderno_y_llave() -> void:
	await E.wait(0.4)
	await _viejo("Tomá. Tu cuaderno de certificación.")
	# Desde acá se ve la barra de arriba completa (la Bruma ya apareció con el adelanto).
	G.gui.ui.mostrar_hud(true)
	G.gui.actualizar_progreso()
	await G.gui.ui.resaltar_cuaderno()
	var toma := await Toma.mostrar(self, TOMA_CUADERNO)
	await _decir("¡Mi primer cuaderno!")
	await _viejo("Cada susto bien hecho, un sello.")
	await _viejo("Con sellos subís de nivel.")
	await toma.esperar_clic(ZONA_TERROR, "Hacé clic en el nivel más alto.")
	await _decir("¡Algún día voy a llegar a Terror!")
	await _viejo("Primero llegá al amanecer.")
	await _decir("¿Y si junto muchos sellos?")
	await _viejo("Te dan más habitaciones.")
	await toma.cerrar()
	await _viejo("Y la llave. Si la perdés, se descuenta de tu Bruma.")
	await _sacar_llave()


## La llave 101 sale del llavero (el gancho queda vacío) y va hasta Nuna.
func _sacar_llave() -> void:
	var llave: Sprite2D = $Llave101
	$LlaveroSinLlave.show()
	llave.show()
	var destino: Vector2 = C.player.global_position + Vector2(-3, -20)
	var tw := create_tween()
	Pixel.mover(tw, llave, "position", destino, 0.7)
	tw.tween_property(llave, "modulate:a", 0.0, 0.25)
	await tw.finished
	llave.hide()


# ---------- 5.4 A la 101 ----------

func _enviar_a_la_101() -> void:
	await E.wait(0.6)
	await _viejo("Bueno. Habitación 101.")
	await _decir("¿Ya?")
	await _viejo("¿Qué esperabas? ¿Una ceremonia?")
	await _decir("¡No! ¡Bueno... un poco!")
	await _viejo("Andá. Y tratá de no desvanecerte antes de terminar el turno.")
	$Viejo.desaparecer()
	await C.player.mini_salto()
	await C.player.walk($Markers/Puerta101.position)
	C.player.mirar_a(C.player.global_position + Vector2(0, -20))  # de espaldas, hacia la puerta
	await E.wait(0.4)
	# En la 101, Nuna vuelve a su sprite sin birrete (character_nuna.gd lo decide al entrar).
	_ir_a("Habitacion101")


# ---------- Cinemática 2: vuelta de la 101, Din y la jubilación ----------

func _vuelve_de_la_101() -> bool:
	return state.paso == Paso.TERMINADO and Globals.sellos >= Globals.SELLOS_TOTALES and not state.cinematica_2


func _cinematica_2() -> void:
	ocupado = true
	_actualizar_guia()
	await C.player.walk($Markers/Mostrador.position)
	C.player.volver_a_reposo_frontal()
	await _decir("¡Volví! ¡Con tres sellos!")
	$SonidoTimbre.play()
	await E.wait(0.8)
	await _llega_el_viejo()
	await _decir("¡Lo logré! ¡Asusté a una persona!")
	await _viejo("Ajá. Tres sellos. No está mal.")
	await _decir("¿Y ahora qué hago?")
	await _viejo("Lo mismo, pero mejor.")
	await _decir("¿Y cuándo sé que lo estoy haciendo mejor?")
	await _viejo("Cuando te lo diga Din.")
	await _decir("¿Din? ¿El «din» que sonaba en la 101?")
	# Din no tiene cuerpo: habla por el timbre.
	$SonidoTimbre.play()
	await E.wait(0.5)
	await _decir("DIN: ¡Felicitaciones, Nuna! Superaste el período de inducción. ♥")
	await _decir("DIN: Próxima prioridad: la 202. ¡El tiempo es Bruma!")
	await _decir("¿El timbre habla?")
	await _viejo("Ese es Din. Tu supervisor.")
	await _decir("¿Y dónde está?")
	await _viejo("En todos lados. En ninguno. Habla, no escucha.")
	await _decir("¿Vos lo viste alguna vez?")
	await _viejo("No preguntes cosas que no te van a pagar.")
	await E.wait(0.8)
	await _decir("¿Sabías que la señora de la 101 se llama Ofelia? ¡Está jubilada!")
	await _decir("¿Los fantasmas nos jubilamos?")
	await E.wait(0.6)
	await _viejo("Je.")
	await _viejo("Hacía siglos que no me reía.")
	await _viejo("Los de tu promoción no se jubilan. Ni vivos ni muertos.")
	await _decir("¡Ah! Como una leyenda urbana.")
	await G.gui.ui.mostrar_certificacion("Jubilación: leyenda urbana.", "(Como nosotros.)")
	await _viejo("Mañana, la 202. Un muchacho. No duerme mucho.")
	await _decir("¿Por qué no duerme?")
	await _viejo("Porque trabaja.")
	await _decir("¿Y cuándo trabaja?")
	await _viejo("Cuando no duerme.")
	await _decir("¡Ah! ¡Duerme poco porque trabaja mucho!")
	await _viejo("Vas aprendiendo.")
	await $Viejo.desaparecer()
	await E.wait(0.6)
	await G.gui.ui.mostrar_certificacion("Hoy aprendí a perturbar y que a Lumi hay que cuidarla…", "(…y que la jubilación es una leyenda.)")
	state.cinematica_2 = true
	ocupado = false
	_actualizar_guia()


## Una línea del viejo: mueve la boca mientras se ve el texto.
func _viejo(texto: String) -> void:
	$Viejo.hablar(true)
	await _decir("VIEJO: " + texto)
	$Viejo.hablar(false)


# ---------- Saltar ----------

func _intro_en_curso() -> bool:
	return state.paso != Paso.TERMINADO


func _sala_siguiente() -> String:
	return "Habitacion101"


func _completar_esta_sala() -> void:
	state.paso = Paso.TERMINADO
	_poner_alfa_nuna(1.0)
