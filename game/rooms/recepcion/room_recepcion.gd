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
## toma_cuaderno.png tiene 3 cuadros: 0 vacío, 1 con los 3 sellos, 2 Manifestación aprobada.
const ZONA_SELLOS := Rect2i(194, 56, 32, 12)          # los 3 sellos al lado de "Manifestación"

## Cinemática 2 (jugable). El arte nuevo está en arte/objetos/ (cada uno con su .aseprite).
const RUTA_VELA_CORTA := "res://arte/objetos/vela_corta-anim.png"  # 2 cuadros de 8x10 (llama)
const RUTA_LLAVE_202 := "res://arte/objetos/llave_202.png"
const RUTA_TUBO := "res://arte/objetos/tubo.png"
const RUTA_CARTEL_202 := "res://arte/objetos/cartel_202.png"
const POS_GANCHO_101 := Vector2(215, 39)
## Cuánta Bruma se descuenta del adelanto que le dieron al firmar.
const DESCUENTO_ADELANTO := 20.0
## Cuando exista la 202 (Lorena), Nuna sube directo desde el cartel de la escalera.
const SALA_202 := "Habitacion202"
const ESCENA_202 := "res://game/rooms/habitacion_202/room_habitacion_202.tscn"
## Cinemática 3: si existen estas tomas se muestran; si no, el texto va en la tarjeta de la consola.
const TOMA_CERTIFICADO_APARICION := "res://arte/tomas/toma_certificado_aparicion.png"
const TOMA_REGISTRO_DESAPARECIDOS := "res://arte/tomas/toma_registro_desaparecidos.png"
## El fantasma de la calle, ahora trabajando en la recepción, cada vez más transparente.
const RUTA_FANTASMA := "res://arte/fantasmaextra.png"
const POS_FANTASMA := Vector2(385, 116)

enum Paso { TIMBRE, MIRAR_LAMPARA, PERTURBAR_LAMPARA, TERMINADO }
## Pasos de la cinemática 2. Cada uno espera que el jugador haga clic en algo.
enum PasoC2 { NADA, TIMBRE, VELA, DIN, CHARLA, TUBO, LLAVE, ESCALERA, FIN }

signal _opcion_elegida(indice: int)

var _c2 := PasoC2.NADA
var _vela_corta: Sprite2D
var _tubo: Sprite2D
var _fantasma: Sprite2D

var state: Data = load("res://game/rooms/recepcion/room_recepcion.tres")


func _on_room_entered() -> void:
	# Después de la 101 Nuna ya no lleva birrete (lo lee super() al entrar).
	nuna_con_birrete = state.paso != Paso.TERMINADO
	super()
	if _vuelve_de_la_101():
		C.player.position = $Markers/Puerta101.position
	elif _vuelve_de_la_202():
		C.player.position = $Markers/Escalera.position  # baja de la 202 por la escalera
	else:
		C.player.position = $Markers/Entrada.position
	if _vuelve_de_la_202() or state.cinematica_3:
		_poner_fantasma(0.15 if state.cinematica_3 else 0.45)
	C.player.show()  # la 101 la escondió al cruzar la puerta
	if _vuelve_de_la_101():
		C.player.modulate.a = 0.0  # aparece de a poco en la puerta 101
	if state.paso == Paso.TERMINADO:
		G.gui.ui.mostrar_hud(true)
	var timbre: ZonaIntro = $Props/Timbre
	timbre.recortar_de($Background.texture)
	if state.paso == Paso.TIMBRE:
		_habilitar(timbre)
	else:
		_retirar(timbre)
	_retirar($Props/Lampara)
	# Lo de la cinemática 2 solo se puede tocar cuando llega su paso.
	for zona in [$Props/Mostrador, $Props/Tubo, $Props/Llavero, $Props/Cartel202]:
		_retirar(zona)
	$Props/Mostrador.recortar_de($Background.texture)
	$Props/Llavero.recorte = $LlaveroSinLlave.texture  # late el gancho vacío
	_sprite_en($Props/Cartel202, RUTA_CARTEL_202)
	# La llave 101 está afuera del llavero entre la intro y la vuelta de la 101.
	$LlaveroSinLlave.visible = state.paso == Paso.TERMINADO and not state.cinematica_2
	$Llave101.hide()
	if ResourceLoader.exists(RUTA_TIMBRE):
		$SonidoTimbre.stream = load(RUTA_TIMBRE)


func _on_room_transition_finished() -> void:
	if _vuelve_de_la_101():
		await _cinematica_2()
		return
	if _vuelve_de_la_202():
		await _cinematica_3()
		return
	ocupado = true
	_actualizar_guia()
	await C.player.walk($Markers/Mostrador.position)
	C.player.volver_a_reposo_frontal()
	await _decir("¿Hola? ¿Hay alguien?")
	ocupado = false
	_actualizar_guia()


func _texto_guia() -> String:
	match _c2:
		PasoC2.TIMBRE:
			return "Tocá el timbre para llamar al viejo."
		PasoC2.VELA:
			return "Dejá la vela de la 101 sobre el mostrador."
		PasoC2.DIN:
			return "¡El timbre suena solo! Atendelo."
		PasoC2.TUBO:
			return "Poné la vela en el tubo."
		PasoC2.LLAVE:
			return "Colgá la llave 101 en el llavero."
		PasoC2.ESCALERA:
			return "Subí a la 202: hacé clic en el cartel."
	if state.cinematica_3:
		return "Fin del turno 2. La 303 todavía está en obra."
	if state.cinematica_2:
		return "Próxima prioridad: la 202."
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
			if _c2 == PasoC2.NADA:
				await _tocar_timbre(obj as ZonaIntro)
			else:
				await _c2_timbre(obj as ZonaIntro)
		&"lampara":
			await _usar_lampara(obj as LamparaRecepcion, verbo)
		&"mostrador":
			await _c2_dejar_vela()
		&"tubo":
			await _c2_tubo()
		&"llavero":
			await _c2_colgar_llave()
		&"cartel_202":
			await _c2_escalera()


# ---------- 5.1 Timbre y encuentro con el viejo ----------

func _tocar_timbre(timbre: ZonaIntro) -> void:
	if state.paso != Paso.TIMBRE:
		return
	_retirar(timbre)
	await _tocar_el_timbre(timbre)
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


# ---------- Cinemática 2 (jugable): vuelta de la 101 ----------
## Orden: timbre → vela al mostrador → cuaderno y descuento → Din por el timbre →
## charla (Ofelia, la sonrisa, Ramón) → la vela por el tubo → llaves → escalera a la 202.
## Cada paso deja algo latiendo y espera el clic del jugador (_texto_guia dice qué hacer).

func _vuelve_de_la_101() -> bool:
	return state.paso == Paso.TERMINADO and Globals.sellos >= Globals.SELLOS_TOTALES and not state.cinematica_2


func _cinematica_2() -> void:
	ocupado = true
	_actualizar_guia()
	# Sale por la puerta de la 101.
	var tw := create_tween()
	tw.tween_property(C.player, "modulate:a", 1.0, 0.4)
	await tw.finished
	await C.player.walk($Markers/Mostrador.position)
	C.player.volver_a_reposo_frontal()
	await _decir("¡Volví! ¡Con tres sellos!")
	await _decir("¿Hola? ¿No hay nadie?")
	_c2 = PasoC2.TIMBRE
	_habilitar($Props/Timbre)
	ocupado = false
	_actualizar_guia()


func _c2_timbre(timbre: ZonaIntro) -> void:
	if _c2 == PasoC2.TIMBRE:
		_retirar(timbre)
		await _tocar_el_timbre(timbre)
		await E.wait(0.8)
		await _llega_el_viejo()
		await _decir("¡Lo logré! ¡Asusté a una persona!")
		await _viejo("Ajá. ¿Y la vela?")
		await _decir("¡Acá la tengo!")
		_c2 = PasoC2.VELA
		_habilitar($Props/Mostrador)
	elif _c2 == PasoC2.DIN:
		_retirar(timbre)
		_c2 = PasoC2.CHARLA  # corta el timbre que sonaba solo
		await _saltito()
		await _c2_din()


# ---------- La vela, el cuaderno y el descuento ----------

func _c2_dejar_vela() -> void:
	var mostrador: ZonaIntro = $Props/Mostrador
	_retirar(mostrador)
	await _decir("La vela de la 101. ¡Llenita de miedo!")
	await _poner_vela_en(mostrador)
	# La vela de arriba (MIEDO) se vacía: ya se entregó.
	Globals.aumentar_vela(Ajustes.LUMI_HABITACION_ID, -100.0)
	await _decir("¿Eh? ¿Tan poquito duró?")
	await _viejo("Te avisé. Cada susto te cuesta un rato de eternidad.")
	await _decir("¿Y cuánto tiempo gasté?")
	await _viejo("Un turno entero. Un pedacito de para siempre.")
	await _decir("Bueno… me queda un montón.")
	await _viejo("Eso también lo dicen todos.")
	await _c2_cuaderno()
	await _viejo("Ah. Y te buscan.")
	_c2 = PasoC2.DIN
	_habilitar($Props/Timbre)
	_timbre_solo()


## La vela corta sale de Nuna y se apoya en el mostrador, con la llamita prendida.
func _poner_vela_en(mostrador: ZonaIntro) -> void:
	_vela_corta = Sprite2D.new()
	_vela_corta.texture = Toma.cargar_textura(RUTA_VELA_CORTA)
	_vela_corta.hframes = 2
	_vela_corta.centered = false
	_vela_corta.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vela_corta.position = C.player.global_position + Vector2(-4, -30)
	add_child(_vela_corta)
	var llama := Timer.new()
	llama.wait_time = 0.25
	llama.autostart = true
	llama.timeout.connect(func (): _vela_corta.frame = 1 - _vela_corta.frame)
	_vela_corta.add_child(llama)
	var destino: Vector2 = mostrador.position + Vector2(-4, -10)
	var tw := create_tween()
	Pixel.mover(tw, _vela_corta, "position", destino, 0.6)
	await tw.finished


func _c2_cuaderno() -> void:
	await _viejo("A ver el cuaderno.")
	await G.gui.ui.resaltar_cuaderno()
	var toma := await Toma.mostrar(self, TOMA_CUADERNO, 1)
	await _viejo("Mostrame los sellos.")
	await toma.esperar_clic(ZONA_SELLOS, "Hacé clic en tus tres sellos.")
	await _decir("¡Lumi, Ramón y la cortina!")
	await _viejo("Mmm. Prolijos.")
	toma.cuadro(2)  # tilde en el casillero y el candado abierto
	toma._rascar()
	await E.wait(0.5)
	await _viejo("Manifestación: aprobada.")
	await _decir("¡Se abrió el candado!")
	await _viejo("Ahora, el adelanto de Bruma.")
	await toma.cerrar()
	Globals.cambiar_bruma(-DESCUENTO_ADELANTO)
	G.gui.actualizar_progreso()
	await _decir("¡Eh! ¡Me bajó la Bruma!")
	await _viejo("Te dije que se descontaba.")
	await _decir("¿Y los sellos no suman?")
	await _viejo("Suman. Y el adelanto resta. Así se llega a fin de mes.")
	await _decir("Los fantasmas no tenemos meses.")
	await _viejo("Por eso nunca se llega.")


## Din llama: el timbre salta y suena solo hasta que Nuna lo atiende.
func _timbre_solo() -> void:
	var timbre: ZonaIntro = $Props/Timbre
	while _c2 == PasoC2.DIN:
		$SonidoTimbre.play()
		timbre.saltar()
		await get_tree().create_timer(1.6).timeout


# ---------- Din ----------

func _c2_din() -> void:
	await _decir("¿Hola?")
	await _din("¡Felicitaciones, Nuna! Superaste el período de inducción. ♥")
	await _decir("¿Quién habla?")
	await _din("Tu opinión es muy importante para nosotros.")
	await _decir("¿El timbre habla?")
	await _viejo("Ese es Din. Tu supervisor.")
	await _decir("¿El «din» que sonaba en la 101?")
	await _viejo("El mismo.")
	await _din("Próxima prioridad: la 202. ¡El tiempo es Bruma!")
	await _decir("¡Hola, Din! ¿Dónde estás?")
	await _din("¡Gracias por tu respuesta! ♥")
	await _viejo("En todos lados. En ninguno. Habla, no escucha.")
	await _decir("¿Vos lo viste alguna vez?")
	await _viejo("No preguntes cosas que no te van a pagar.")
	await E.wait(0.6)
	await _c2_charla()


## Din no tiene cuerpo: habla por el timbre.
func _din(texto: String) -> void:
	$SonidoTimbre.play()
	$Props/Timbre.saltar()
	await _decir("DIN: " + texto)


# ---------- Charla: el jugador elige de qué hablar ----------
## Ofelia es obligatoria (trae la certificación de la jubilación); las otras dos, no.

func _c2_charla() -> void:
	var temas := {
		"ofelia": "Ofelia y su jubilación",
		"sonrisa": "La sonrisa del cajón",
		"ramon": "Ramón, la radio",
	}
	var hablados: Array = []
	while hablados.size() < temas.size():
		var claves: Array = temas.keys().filter(func (k): return not hablados.has(k))
		var textos: Array = claves.map(func (k): return temas[k])
		if hablados.has("ofelia"):
			textos.append("Nada más")
		var elegido: int = await _elegir("¿De qué le hablás?", textos)
		if elegido >= claves.size():
			break
		var tema: String = claves[elegido]
		hablados.append(tema)
		match tema:
			"ofelia":
				await _charla_ofelia()
			"sonrisa":
				await _charla_sonrisa()
			"ramon":
				await _charla_ramon()
	await _viejo("Bueno. La vela.")
	await _bajar_tubo()
	await _decir("¡Un tubo!")
	await _viejo("Poné la vela ahí.")
	_c2 = PasoC2.TUBO
	_habilitar($Props/Tubo)


func _charla_ofelia() -> void:
	await _decir("¿Sabías que la señora de la 101 se llama Ofelia? ¡Está jubilada!")
	await _decir("Trabajó toda la vida, y lo que cobra le alcanza para el desayuno del hotel.")
	await _viejo("Y ni el desayuno completo, seguro.")
	await _decir("¿Los fantasmas nos jubilamos?")
	await E.wait(0.6)
	await _viejo("Je.")
	await _viejo("Hacía siglos que no me reía.")
	await _viejo("Los de tu promoción no se jubilan. Ni vivos ni muertos.")
	await _decir("¡Ah! Como una leyenda urbana.")
	await G.gui.ui.mostrar_certificacion("Jubilación: leyenda urbana.", "(Como nosotros.)")


func _charla_sonrisa() -> void:
	if Globals.tiene(&"dentadura"):
		await _decir("¡Me traje una sonrisa de la 101!")
		await _viejo("Bien. Te dije: la empresa no da insumos.")
		await _decir("¿Y dónde la uso?")
		await _viejo("Donde alguien se haya olvidado de sonreír. En este hotel sobran.")
	else:
		await _decir("En la 101 había una sonrisa en un cajón…")
		await _viejo("¿Y no la trajiste?")
		await _decir("Me la olvidé.")
		await _viejo("Mal. Acá nadie te repone nada.")


func _charla_ramon() -> void:
	await _decir("La radio de la 101 se llama Ramón. ¡Pasa canciones al revés!")
	await _viejo("Las radios viejas son así. Se acuerdan de todo, pero al revés.")
	await _decir("¿Como vos?")
	await _viejo("Como todos los que llevamos años en este hotel.")


## Un cartelito con opciones (mismo estilo que el botón de saltar). Devuelve la elegida.
func _elegir(titulo: String, opciones: Array) -> int:
	var capa := CanvasLayer.new()
	capa.layer = 64
	add_child(capa)
	var orden := OrdenTrabajo.new()
	var tema: Theme = orden._crear_tema()
	orden.free()
	var panel := PanelContainer.new()
	panel.theme = tema
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 2)
	panel.add_child(lista)
	var etiqueta := Label.new()
	etiqueta.text = titulo
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lista.add_child(etiqueta)
	for i in opciones.size():
		var boton := Button.new()
		boton.text = opciones[i]
		boton.focus_mode = Control.FOCUS_NONE
		var indice := i
		boton.pressed.connect(func (): _opcion_elegida.emit(indice))
		lista.add_child(boton)
	capa.add_child(panel)
	panel.modulate.a = 0.0
	await get_tree().process_frame
	# Centrado sobre la sala, arriba de la consola.
	panel.position = ((Vector2(320, Ajustes.UI_Y) - panel.size) / 2.0).floor()
	panel.modulate.a = 1.0
	var elegido: int = await _opcion_elegida
	capa.queue_free()
	return elegido


# ---------- El tubo: la vela se va para arriba ----------

## El tubo baja del techo con un golpe.
func _bajar_tubo() -> void:
	var zona: ZonaIntro = $Props/Tubo
	_tubo = _sprite_en(zona, RUTA_TUBO)
	var final_y := _tubo.position.y
	_tubo.position.y = final_y - _tubo.texture.get_height()
	var tw := create_tween()
	tw.tween_property(_tubo, "position:y", final_y, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tw.finished


func _c2_tubo() -> void:
	var zona: ZonaIntro = $Props/Tubo
	_retirar(zona)
	await _decir("Chau, vela.")
	# La vela va hasta la boca del tubo, se achica y la Bruma sube.
	var boca: Vector2 = zona.position + Vector2(-4, -6)
	var tw := create_tween()
	Pixel.mover(tw, _vela_corta, "position", boca, 0.6)
	tw.tween_property(_vela_corta, "modulate:a", 0.0, 0.2)
	await tw.finished
	_vela_corta.queue_free()
	await _subir_bruma(zona)
	await _decir("¿Y a dónde va?")
	await _viejo("Arriba.")
	await _decir("¿Qué hay arriba?")
	await _viejo("Gerencia. Y la máquina.")
	await _decir("¿Qué máquina?")
	await _viejo("La que no para nunca. Come lo que vos juntás.")
	await _decir("¿Mi Bruma?")
	await _viejo("El miedo de ellos. Y tu tiempo.")
	await E.wait(0.8)
	await _decir("…")
	await _viejo("Ahora, la llave de la 101. Colgala en su gancho.")
	_c2 = PasoC2.LLAVE
	_habilitar($Props/Llavero)


## Una bolita de Bruma sube por el tubo con un "fuuup".
func _subir_bruma(zona: ZonaIntro) -> void:
	var sonido := AudioStreamPlayer.new()
	sonido.stream = Chip.wav(Chip.mezclar(
		Chip.nota(&"ruido", 3000.0, 0.7, 0.35, 0.05, 0.3, 0.0, 0.0, 2.5),
		Chip.nota(&"triangulo", 220.0, 0.7, 0.4, 0.01, 0.2, 0.0, 0.0, 4.0)))
	add_child(sonido)
	sonido.play()
	var bruma := ColorRect.new()
	bruma.color = Color(0.62, 0.48, 0.88, 0.9)
	bruma.size = Vector2(4, 4)
	bruma.position = zona.position + Vector2(-2, -12)
	add_child(bruma)
	var tw := create_tween()
	Pixel.mover(tw, bruma, "position:y", -6.0, 0.8)
	await tw.finished
	bruma.queue_free()
	await E.wait(0.4)
	sonido.queue_free()


# ---------- Llaves y escalera ----------

func _c2_colgar_llave() -> void:
	_retirar($Props/Llavero)
	# La llave 101 sale de Nuna y vuelve a su gancho.
	var llave: Sprite2D = $Llave101
	llave.position = C.player.global_position + Vector2(-3, -20)
	llave.modulate.a = 1.0
	llave.show()
	var tw := create_tween()
	Pixel.mover(tw, llave, "position", POS_GANCHO_101, 0.7)
	await tw.finished
	$LlaveroSinLlave.hide()
	llave.hide()  # el fondo ya tiene la llave dibujada en el gancho
	await _decir("Gracias, 101.")
	await _viejo("Y esta es la tuya ahora. La 202.")
	await _recibir_llave_202()
	await _decir("¡Mi segunda llave!")
	await _viejo("Si la perdés…")
	await _decir("…se descuenta de mi Bruma. Ya sé.")
	await _viejo("La 202. Un muchacho. No duerme mucho.")
	await _decir("¿Por qué no duerme?")
	await _viejo("Porque trabaja.")
	await _decir("¿Y cuándo trabaja?")
	await _viejo("Cuando no duerme.")
	await _decir("¡Ah! ¡Duerme poco porque trabaja mucho!")
	await _viejo("Vas aprendiendo.")
	await _viejo("La escalera está a la derecha. Subí.")
	await $Viejo.desaparecer()
	_c2 = PasoC2.ESCALERA
	_habilitar($Props/Cartel202)


## La llave 202 flota desde el viejo hasta Nuna.
func _recibir_llave_202() -> void:
	var llave := Sprite2D.new()
	llave.texture = Toma.cargar_textura(RUTA_LLAVE_202)
	llave.centered = false
	llave.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	llave.position = $Viejo.position + Vector2(-4, -40)
	add_child(llave)
	var tw := create_tween()
	Pixel.mover(tw, llave, "position", C.player.global_position + Vector2(-3, -20), 0.8)
	tw.tween_property(llave, "modulate:a", 0.0, 0.25)
	await tw.finished
	llave.queue_free()


func _c2_escalera() -> void:
	_retirar($Props/Cartel202)
	await C.player.walk($Markers/Escalera.position)
	C.player.mirar_a(C.player.global_position + Vector2(0, -20))  # de espaldas, hacia arriba
	await G.gui.ui.mostrar_certificacion("Hoy aprendí a perturbar y que a Lumi hay que cuidarla…", "(…y que la jubilación es una leyenda.)")
	state.cinematica_2 = true
	_c2 = PasoC2.FIN
	if ResourceLoader.exists(ESCENA_202):
		_ir_a(SALA_202)
		return
	await _decir("Mmm… La 202 todavía está en obra.")


# ---------- Cinemática 3: vuelta de la 202, los que no llegaron ----------

func _vuelve_de_la_202() -> bool:
	if not state.cinematica_2 or state.cinematica_3:
		return false
	var estado_202: Resource = load("res://game/rooms/habitacion_202/room_habitacion_202.tres")
	return estado_202 != null and estado_202.get("mision_completada") == true


func _cinematica_3() -> void:
	ocupado = true
	_actualizar_guia()
	await C.player.walk($Markers/Mostrador.position)
	C.player.volver_a_reposo_frontal()
	await _decir("¡Volví de la 202!")
	await _saltito()  # sigue sin llegar bien al timbre
	$SonidoTimbre.play()
	await E.wait(0.8)
	await _llega_el_viejo()
	await _decir("¡Tengo otra certificación!")
	await _mostrar_certificado_aparicion()
	await _viejo("Bien. Ya podés considerarte un espíritu competente.")
	await _decir("¿Y qué pasa cuando soy competente?")
	await _viejo("Te dan más trabajo.")
	await _decir("¡Qué emocionante!")
	await _viejo("No te emociones.")
	# Nuna mira el Registro y encuentra la columna que nadie mira.
	await C.player.walk($Markers/Libro.position)
	await C.player.interactuar($Markers/Libro.position + Vector2(0, -60))
	var toma: Toma = null
	if ResourceLoader.exists(TOMA_REGISTRO_DESAPARECIDOS):
		toma = await Toma.mostrar(self, TOMA_REGISTRO_DESAPARECIDOS, 0)
	else:
		await G.gui.ui.mostrar_certificacion("REGISTRO · Espíritus desaparecidos", "(La lista sigue en la página siguiente. Y en la otra.)")
	await _decir("¿Qué significa esta columna? «Espíritus desaparecidos».")
	await _viejo("Los que no llegaron.")
	await _decir("¿A dónde?")
	await _viejo("A ninguna parte.")
	if toma != null:
		await toma.cerrar()
	# Din interrumpe por el timbre. Mientras habla, el fantasma de atrás se apaga un poco más.
	$SonidoTimbre.play()
	await E.wait(0.5)
	_atenuar_fantasma(0.25)
	await _decir("DIN: Recordatorio: tu eficiencia está 4% por debajo del promedio de tu promoción. ♥")
	await _decir("DIN: ¡Vos podés!")
	await _decir("¿Tengo una promoción? No conozco a nadie.")
	await $Viejo.desaparecer()
	await E.wait(0.4)
	# El fantasma de la calle: trabaja acá, cada vez más transparente, y no contesta.
	await C.player.walk(Vector2(POS_FANTASMA.x - 10, 146))
	if _fantasma != null:
		C.player.mirar_a(_fantasma.global_position + Vector2(15, 15))
	await _decir("Hola… ¿Vos también sos aprendiz? ¿Cómo te llamás?")
	await E.wait(1.2)
	await _decir("…")
	_atenuar_fantasma(0.15)
	await _decir("No contesta. Casi no se lo ve.")
	await E.wait(0.6)
	await G.gui.ui.mostrar_certificacion("Llevo 6 velas trabajando. Aprendí a aparecerme y que la compu se quemó como Bruno.", "(A la compu la pueden cambiar. No aprendí: para qué junto bruma.)")
	state.cinematica_3 = true
	ocupado = false
	_actualizar_guia()


func _mostrar_certificado_aparicion() -> void:
	if ResourceLoader.exists(TOMA_CERTIFICADO_APARICION):
		var toma := await Toma.mostrar(self, TOMA_CERTIFICADO_APARICION)
		await E.wait(1.5)
		await toma.cerrar()
	else:
		await G.gui.ui.mostrar_certificacion("CERTIFICADO DE APARICIÓN · Nuna, aprendiz.", "(Válido solo en superficies que reflejan.)")


func _poner_fantasma(alfa: float) -> void:
	if not ResourceLoader.exists(RUTA_FANTASMA):
		return
	var recorte := AtlasTexture.new()
	recorte.atlas = load(RUTA_FANTASMA)
	recorte.region = Rect2(0, 0, 30, 30)
	_fantasma = Sprite2D.new()
	_fantasma.name = "FantasmaRecepcion"
	_fantasma.texture = recorte
	_fantasma.centered = false
	_fantasma.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fantasma.position = POS_FANTASMA
	_fantasma.modulate.a = alfa
	add_child(_fantasma)
	move_child(_fantasma, $Characters.get_index())
	# Parpadea como una señal que se corta.
	var tw := create_tween().set_loops()
	tw.tween_interval(2.4)
	tw.tween_callback(func(): _fantasma.visible = false)
	tw.tween_interval(0.08)
	tw.tween_callback(func(): _fantasma.visible = true)
	tw.tween_interval(0.12)
	tw.tween_callback(func(): _fantasma.visible = false)
	tw.tween_interval(0.06)
	tw.tween_callback(func(): _fantasma.visible = true)


func _atenuar_fantasma(alfa: float) -> void:
	if _fantasma == null:
		return
	create_tween().tween_property(_fantasma, "modulate:a", alfa, 1.2)


## Un dibujo fijo encima del fondo, en el mismo lugar que su zona clickeable.
## La zona usa el mismo dibujo para latir cuando está habilitada.
func _sprite_en(zona: ZonaIntro, ruta: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = Toma.cargar_textura(ruta)
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = zona.position + zona._rect_local().position
	add_child(sprite)
	move_child(sprite, $Background.get_index() + 1)  # detrás de Nuna y del viejo
	zona.recorte = sprite.texture
	return sprite


## Nuna no llega bien al mostrador: cada vez que toca el timbre hace un saltito.
## La primera vez lo dice (así se entiende que en la 101 necesite a Ovi de escalón).
func _tocar_el_timbre(timbre: ZonaIntro) -> void:
	await _saltito()
	$SonidoTimbre.play()
	await timbre.saltar()
	if not state.dijo_timbre_alto:
		state.dijo_timbre_alto = true
		await _decir("Uf, me cuesta llegar tan alto.")


func _saltito() -> void:
	var sprite: AnimatedSprite2D = C.player.get_node("AnimatedSprite2D")
	if sprite.sprite_frames.has_animation(&"mini_salto_frente"):
		await C.player.mini_salto()
	else:
		# Sin birrete puede no estar el cuadro de saltito: hace un salto en el lugar.
		await C.player.subir_a(C.player.position, 6.0)
		await C.player.bajar_a(C.player.position)


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
