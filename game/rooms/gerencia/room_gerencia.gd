@tool
extends PopochiuRoom
## FINAL — La Gerencia y la Gran Máquina. No se tocan objetos: es pura charla.
## Nuna entra por la misma puerta de la 101, lee su expediente, ve la máquina por la puerta
## entreabierta, descubre que Din está hecho de frases recicladas y completa la ficha:
##   · «Todavía no lo sé» → la máquina no puede procesarlo, Nuna se sienta, el viejo baja la
##     palanca del mostrador y terminan los dos en el banco de afuera (final principal).
##   · Firmar el ascenso → Nuna atiende la recepción y repite las frases del viejo (alternativo).
## Los "planos" son imágenes fijas a pantalla completa (como las tomas): la máquina,
## el mostrador de la recepción y el banco de la calle.

const Data := preload("room_gerencia_state.gd")
const RUTA_MAQUINA := "res://arte/backgrounds/maquina.png"
const RUTA_MAQUINA_ANIM := "res://arte/objetos/maquina_anim.png"  # 3 cuadros de 161 x 128
const RUTA_RECEPCION := "res://arte/backgrounds/recepcion_hotel_bg.png"
const RUTA_CALLE := "res://arte/backgrounds/calle.png"
const RUTA_NUNA_PNG := "res://arte/nuna/nuna.png"
const RUTA_NUNA_JSON := "res://arte/nuna/nuna.json"
const RUTA_TIMBRE := "res://audio/sfx/timbre.wav"
const RUTA_FUENTE := "res://arte/fuentes/monogram-extended.ttf"
const MENU := "res://game/menu/menu_inicio.tscn"
## Recortes de 320 de ancho de los fondos largos.
const X_RECEPCION := 140  # el mostrador y el lugar del viejo
const X_CALLE := 20       # el banco donde estaba el fantasma (x = 180 en la calle)
## Colores del cartel final (los mismos del teatro).
const COLOR_TITULO := Color8(251, 242, 54)
const COLOR_FRASE := Color8(203, 219, 252)
const COLOR_LETRA_CHICA := Color8(155, 173, 183)
const COLOR_SOMBRA := Color8(34, 32, 52)

var state: Data = load("res://game/rooms/gerencia/room_gerencia.tres")
var ocupado := true
var objeto_seleccionado: ObjetoInteractivo
var _timbre: AudioStreamPlayer
var _plano: CanvasLayer
var _maquina: AnimatedSprite2D
## Lo que Nuna anotó en el cuaderno antes de subir (sin las tarjetas de la Gerencia).
var _notas_previas: Array = []


# ---------- Entrar ----------

func _on_room_entered() -> void:
	Musica.tocar(&"habitacion")
	if Globals.get("notas") != null:
		_notas_previas = Globals.notas.duplicate()
	Globals.pausado = true  # en la Gerencia no se gasta bruma: acá ya no hay turno
	G.gui.mostrar_habitacion(true)
	G.gui.ui.establecer_guia("")
	C.player.hide()
	C.player.position = $Markers/Afuera.position
	$Props/Puerta.clickable = false
	$Props/Puerta.mostrar_cerrada()
	_timbre = AudioStreamPlayer.new()
	if ResourceLoader.exists(RUTA_TIMBRE):
		_timbre.stream = load(RUTA_TIMBRE)
	_timbre.volume_db = -10.0
	_timbre.bus = InterfazUI.bus_voces()
	add_child(_timbre)


func _on_room_transition_finished() -> void:
	C.player.poner_birrete(false)  # en las habitaciones Nuna ya no lleva birrete
	G.block()
	await _entrar()
	await _expediente()
	await _la_maquina()
	await _din_somos_nosotros()
	var firma: bool = await _la_ficha()
	state.final_bueno = not firma
	if firma:
		await _final_firmar()
	else:
		await _final_sentarse()
		await _el_viejo_sube()
		await _la_palanca()
		await _el_banco()
	state.final_visto = true
	await _cartel_final(firma)
	Globals.pausado = false
	G.unblock()
	if is_instance_valid(G.gui) and G.gui.has_method("volver_al_menu"):
		G.gui.volver_al_menu()
	else:
		get_tree().change_scene_to_file(MENU)


## Igual que la 101: la puerta se abre, Nuna cruza desde afuera del cuadro y la puerta se cierra.
func _entrar() -> void:
	await $Props/Puerta.abrir()
	C.player.show()
	await _cruzar(C.player, $Markers/EnLaPuerta.position)
	await C.player.walk($Markers/Inicio.position)
	C.player.volver_a_reposo_frontal()
	await $Props/Puerta.cerrar()
	await _decir("¿Hola? ¿Señor Gerente? ¿Señora Gerenta? ¿Alguien que gerencie?")
	await E.wait(1.0)
	await _decir("…No hay nadie.")
	await _decir("Es igualita a la pieza de Bruno. Pero sin Bruno. Y sin colores.")
	await C.player.walk($Markers/Escritorio.position)
	C.player.volver_a_reposo_frontal()
	await _decir("Un escritorio vacío y una silla vacía. Acá no trabaja nadie.")
	await _decir("Qué raro. Abajo todos trabajan para Gerencia… y Gerencia no está.")


# ---------- El expediente ----------

func _expediente() -> void:
	await C.player.walk($Markers/Archivos.position)
	C.player.mirar_a(C.player.global_position + Vector2(-20, -30))
	await _decir("¡Archivos! Uno dice «NUNA». ¡Tengo un archivo! ¡Soy importante!")
	await G.gui.ui.mostrar_certificacion("EXPEDIENTE · NUNA (aprendiz)", "(Habitaciones completadas: 3. Sustos registrados: 9.)")
	await _decir("¿Nueve sustos? A ver…")
	await _decir("Ofelia sonrió. Bruno se asustó por haberse dormido, no por mí.")
	await _decir("Y Vale lloró y se rió a la vez.")
	await _decir("El Registro dice que eran sustos. ¿Me equivoqué yo o el Registro?")
	await G.gui.ui.mostrar_certificacion("Eficiencia: 87%. Tiempo improductivo: 0%.", "(¡Felicitaciones! Nunca descansaste.)")
	await _decir("¿Cero? ¡Pero si me senté en el banco de la calle!")
	await _decir("Ah, no. Eso fue antes de firmar. Lo de antes no cuenta.")
	await G.gui.ui.mostrar_certificacion("Nombre original: NO REGISTRADO.", "(Gustos personales: NO REGISTRADO.)")
	await _decir("¿Gustos personales? ¡Me gustan un montón de cosas!")
	await _decir("Ramón. Lumi. Ovi. La taza con dientes. El placard explosivo.")
	await _decir("…No entran. El casillero es para números.")
	await G.gui.ui.mostrar_certificacion("Identidad: en proceso de estandarización.", "(Le faltan dos sellos para ser alguien.)")


# ---------- La puerta entreabierta: la Gran Máquina ----------

func _la_maquina() -> void:
	await _din("¡Llegaste, Nuna! ♥ Pasá. La evaluación es por acá.")
	await _decir("¡Din! ¿Por fin te voy a conocer? ¿Sos alto? ¿Tenés cadenas?")
	await _din("¡Gracias por tu respuesta! ♥")
	await C.player.walk($Markers/PuertaMaquina.position)
	C.player.mirar_a(C.player.global_position + Vector2(20, -20))
	await _decir("La voz sale de esta puerta. Hay luz violeta… y bruma.")
	await _decir("Como en el tubo de la recepción.")
	await _decir("Permiso…")
	await _abrir_plano_maquina()
	await E.wait(1.5)
	await _decir("…")
	await _decir("Es la máquina que me escupió. Y los caños… son los tubos de abajo.")
	await _decir("Entran frascos de bruma. Ese de ahí… ¡es el susto de Ofelia! Tiene canción de cuna.")
	await _decir("Y salen velas. Velas cortitas. Como la que dejé en el mostrador.")
	await _decir("Hay fantasmas empujando las palancas. ¡Hola! ¿Ustedes también son aprendices?")
	await E.wait(1.0)
	await _decir("No me escuchan. Están muy ocupados empujando.")
	await _decir("Ese de ahí casi no se ve. Como Don Banco antes de irse.")
	await _decir("En la 202 anoté: «No aprendí para qué junto bruma».")
	await _decir("…Ahora sí. Para esto.")


func _din_somos_nosotros() -> void:
	await _decir("¿Y Din? Si es el jefe, tiene que estar por acá.")
	await _decir("Ahí… ¡un timbre! Un timbre pegado a la máquina. Como el del mostrador.")
	await _din("¡Tres sellos y soy profesional! ♥")
	await _decir("¡Eh! Eso lo dije yo. En la 101.")
	await _din("No preguntes cosas que no te van a pagar. ♥")
	await _decir("Y esa es del viejo.")
	await _din("Los profesionales siempre se ponen la 10, ¿no? ♥")
	await _decir("…Esa también es mía.")
	await E.wait(0.8)
	await _decir("Por eso Din nunca escucha: no tiene orejas. Solo repite.")
	await _decir("Din está hecho de lo que dijimos nosotros. Y la máquina anda porque la empujamos.")
	await _decir("…Yo también la empujé. Nueve sustos.")


# ---------- La ficha ----------

## Devuelve true si Nuna firma el ascenso (final alternativo).
func _la_ficha() -> bool:
	await _din("Para el ascenso falta un solo campo: OBJETIVO PERSONAL. ♥")
	await _din("Solo se aceptan números. Sugerencia: 110%. ♥")
	await G.gui.ui.mostrar_certificacion("OBJETIVO PERSONAL: __________", "(Formato aceptado: números. Firma al pie.)")
	await _decir("Mi objetivo personal…")
	await _decir("Al principio era juntar sellos. Ya los junté todos.")
	await _decir("Y no sé para qué. Bueno: sí sé. Para la máquina.")
	await _decir("Pero eso es el objetivo de la máquina, no el mío.")
	await _decir("Tengo que elegir.")
	var con := "Con el delineador." if Globals.tiene_extra("delineador") else "Con el dedo, en la bruma."
	var eleccion := EleccionFicha.new()
	eleccion.opciones = [
		["FIRMAR EL ASCENSO", "Objetivo: 110%.", "Te ascienden. Turno eterno."],
		["ESCRIBIR «TODAVÍA NO LO SÉ»", con, "No es un número."],
	]
	add_child(eleccion)
	var opcion: int = await eleccion.elegido
	eleccion.queue_free()
	return opcion == 0


# ---------- Final principal: «Todavía no lo sé» ----------

func _final_sentarse() -> void:
	if Globals.tiene_extra("delineador"):
		await _decir("Con el delineador de Vale. Sirve para escribir cosas que no se borran.")
	else:
		await _decir("Con el dedo, en la bruma del vidrio. Letra grande, para que se lea bien.")
	await G.gui.ui.mostrar_certificacion("OBJETIVO PERSONAL: Todavía no lo sé.", "(No es un número.)")
	await _decir("Es la verdad. Es lo más verdadero que escribí en todo el turno.")
	await _din("ERROR: NO MEDIBLE. ♥")
	await _din("Procesando… ♥")
	# La máquina intenta clasificar el cuaderno de Nuna: nombres, dibujos, preguntas.
	var muestras: Array = ["Ramón, Lumi, Doña Cortina, Ovi.", "Ofelia sonrió."]
	for i in _notas_previas.size():
		var nota: String = _notas_previas[_notas_previas.size() - 1 - i]
		# Solo lo que escribió Nuna (no los carteles de Din ni las tarjetas en mayúsculas).
		if nota.begins_with("DIN") or nota == nota.to_upper() or nota.length() > 70:
			continue
		muestras.push_front(nota)
		if muestras.size() >= 4:
			break
	await _decir("Te ayudo: te leo mi cuaderno, así sabés quién soy.")
	for nota in muestras.slice(0, 3):
		await G.gui.ui.mostrar_certificacion("CLASIFICANDO: «%s»" % nota, "(Resultado: NO MEDIBLE.)")
	await _din("Procesando… ♥")
	await _decir("Tarda. Mientras procesa… me siento un ratito.")
	_frenar_maquina(0.5)
	await _decir("En el piso. Sin perturbar, sin poseer, sin aparecer. Nada.")
	await _din("¿Seguís ahí? ♥")
	await _decir("Sigo acá.")
	await _din("¿Seguís ahí? ♥")
	await _decir("Sí. Pero no estoy haciendo nada.")
	_frenar_maquina(0.2)
	await _decir("Si no hago nada, no asusto. Si no asusto, no hay bruma.")
	await _decir("Y sin bruma la máquina no come.")
	await _din("¿Seguís a… ♥")
	await E.wait(1.2)
	await _decir("…Se calló.")
	await _decir("La máquina sabe qué hacer con el apuro. No sabe qué hacer con la calma.")
	# Vuelve a la oficina: Nuna en el piso, al lado de la puerta entreabierta.
	await _cerrar_plano()
	C.player.position = $Markers/PuertaMaquina.position + Vector2(0, 4)
	C.player.volver_a_reposo_frontal()
	await E.wait(1.0)


## El ruido de arriba se cortó por primera vez en siglos: el viejo sube a ver qué pasa.
func _el_viejo_sube() -> void:
	var viejo := ViejoRecepcion.new()
	add_child(viejo)
	move_child(viejo, $Characters.get_index())
	await viejo.aparecer(Vector2(200, 146))
	await _viejo(viejo, "Se cortó el ruido de arriba. En siglos nunca se cortó.")
	await _viejo(viejo, "…Pibe. ¿Qué hacés en el piso?")
	await _decir("Nada.")
	await _viejo(viejo, "¿Nada?")
	await _decir("Nada de nada. ¿Querés probar? Es más fácil de lo que parece.")
	await viejo.suspirar()
	await _viejo(viejo, "Hace siglos que no hago nada.")
	await _viejo(viejo, "Antes tenía un cuaderno. Como el tuyo. Con dibujitos y nombres.")
	await _decir("¿Y qué pasó?")
	await _viejo(viejo, "Lo llené de sellos. No quedó lugar para lo otro.")
	await E.wait(0.8)
	await _viejo(viejo, "El primer día me mostraron una palanca. Abajo del mostrador.")
	await _viejo(viejo, "«No la toques nunca», me dijeron. Y nunca tuve tiempo ni de mirarla.")
	await _decir("¿Y hoy tenés tiempo?")
	await _viejo(viejo, "…Hoy la máquina está quieta. Hoy sí.")
	await _viejo(viejo, "Esperame acá.")
	await viejo.desaparecer()
	viejo.queue_free()


## El viejo baja a la recepción, corre papeles y polvo del mostrador y baja la palanca.
func _la_palanca() -> void:
	await _cambiar_plano(_plano_fondo(RUTA_RECEPCION, X_RECEPCION))
	var viejo := ViejoRecepcion.new()
	_plano.add_child(viejo)
	viejo.set_process(false)
	var papeles := Node2D.new()
	_plano.add_child(papeles)
	for i in 7:
		var hoja := ColorRect.new()
		hoja.size = Vector2(randi_range(5, 9), 2)
		hoja.color = Color8(232, 222, 196) if i % 2 == 0 else Color8(196, 184, 160)
		hoja.position = Vector2(112 + i * 3, 88 - (i % 3))
		papeles.add_child(hoja)
	var palanca := Palanca.new()
	palanca.position = Vector2(128, 97)
	palanca.visible = false
	_plano.add_child(palanca)
	await viejo.aparecer(Vector2(150, 146))
	await _viejo(viejo, "Papeles. Polvo. Más papeles. Un formulario de 1800…")
	var tw := create_tween().set_parallel()
	for hoja in papeles.get_children():
		Pixel.mover(tw, hoja, "position", hoja.position + Vector2(randi_range(-30, -10), randi_range(40, 56)), 0.5)
	await tw.finished
	palanca.visible = true
	await _viejo(viejo, "Ahí estás.")
	await _viejo(viejo, "Siempre estuvo acá. Al alcance de la mano.")
	await E.wait(0.6)
	palanca.bajar()
	_clonc()
	await E.wait(0.4)
	# Arriba, la máquina se apaga: la misma animación, quieta y oscura.
	await _mostrar_maquina_de_cerca()
	if is_instance_valid(_maquina):
		_maquina.stop()
		_maquina.frame = 0
		_maquina.modulate = Color(0.45, 0.4, 0.55)
	await E.wait(1.0)
	await _decir("…Se apagó.")
	await _decir("Din no dice nada. Es la primera vez que no dice nada.")
	await _decir("Los fantasmas soltaron las palancas. Uno se está estirando.")


func _el_banco() -> void:
	await _cambiar_plano(_plano_fondo(RUTA_CALLE, X_CALLE))
	G.gui.ui.mostrar_hud(false)
	var nuna := _sprite_nuna()
	nuna.position = Vector2(146, 110)  # sentada en el banco
	_plano.add_child(nuna)
	var viejo := ViejoRecepcion.new()
	_plano.add_child(viejo)
	viejo.set_process(false)
	await viejo.aparecer(Vector2(214, 146))  # de pie, al lado del banco
	viejo._sprite.flip_h = true  # mira hacia Nuna
	viejo._sprite.position.x = ViejoRecepcion.X_MIRA_IZQUIERDA
	await E.wait(1.0)
	await _decir("¿Y ahora qué hacemos?")
	await _viejo(viejo, "No sé.")
	await _decir("¿Y eso está bien?")
	await _viejo(viejo, "Por ahora.")
	await _viejo(viejo, "Mañana a la mañana vencen los sellos. Y la máquina arranca de nuevo.")
	await _decir("Pero ahora es de noche.")
	await _viejo(viejo, "Ahora es de noche.")
	await E.wait(1.5)
	await _decir("En este banco conocí a Don Banco. Le puse el nombre por el banco.")
	await _viejo(viejo, "Le ponés nombre a todo.")
	await _decir("A todo lo que me importa.")
	await E.wait(1.0)
	await _viejo(viejo, "…¿Y el banco? ¿Cómo se llama?")
	await _decir("Todavía no lo sé. ¿Y vos?")
	await E.wait(2.5)


# ---------- Final alternativo: firmar ----------

func _final_firmar() -> void:
	await _decir("Firmo. Total, nadie lee las fichas. Y 110 es más que 100.")
	await G.gui.ui.mostrar_certificacion("OBJETIVO PERSONAL: 110%. ASCENSO APROBADO.", "(Puesto: Recepción. Turno: eterno.)")
	await _din("¡Felicitaciones! ♥ Tu nueva prioridad es esperar.")
	await _cambiar_plano(_plano_fondo(RUTA_RECEPCION, X_RECEPCION))
	var nuna := _sprite_nuna()
	nuna.position = Vector2(156, 78)  # detrás del mostrador: asoma de la cintura para arriba
	_plano.add_child(nuna)
	var frente := Sprite2D.new()  # el frente del mostrador, por delante de Nuna
	frente.centered = false
	frente.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var recorte := AtlasTexture.new()
	recorte.atlas = load(RUTA_RECEPCION)
	recorte.region = Rect2(X_RECEPCION, 96, 320, 56)
	frente.texture = recorte
	frente.position = Vector2(0, 96)
	_plano.add_child(frente)
	await E.wait(1.0)
	_timbre.play()
	var nuevo := _sprite_nuna()
	nuevo.modulate = Color(1.0, 0.95, 0.7)  # recién graduado: todavía brilla
	nuevo.position = Vector2(-20, 125)
	_plano.add_child(nuevo)
	await _cruzar(nuevo, Vector2(110, 125))
	await _decir("APRENDIZ: ¡Hola! ¡Vengo por el trabajo! ¿Me dan cadenas? ¿Una sábana?")
	await _decir("La empresa no da insumos.")
	await _decir("APRENDIZ: ¿Y cuándo voy a poder descansar?")
	await E.wait(0.8)
	await _decir("No preguntes cosas que no te van a pagar.")
	await E.wait(1.2)
	await _decir("…¿Eso lo dije yo?")
	await E.wait(1.5)


# ---------- Cartel final (el mismo del teatro) ----------

func _cartel_final(con_letra_chica: bool) -> void:
	var capa := CanvasLayer.new()
	capa.layer = 70
	add_child(capa)
	var fondo := ColorRect.new()
	fondo.color = Color.BLACK
	fondo.size = Vector2(320, 180)
	fondo.modulate.a = 0.0
	capa.add_child(fondo)
	await _fundir(fondo, 1.0)
	await E.wait(0.8)
	var titulo := _cartel(capa, "¡FELICITACIONES!", 46, 32, COLOR_TITULO)
	await _fundir(titulo, 1.0)
	G.gui.voz("CEREMONIA: Felicitaciones")
	await E.wait(1.2)
	var frase := _cartel(capa, "Tu descanso eterno comienza ahora." + ("*" if con_letra_chica else ""), 82, 16, COLOR_FRASE)
	await _fundir(frase, 1.0)
	await E.wait(2.4)
	if con_letra_chica:
		var chica := _cartel(capa, "*Sujeto a cumplimiento de cuota.", 104, 16, COLOR_LETRA_CHICA)
		await _fundir(chica, 1.0)
		await E.wait(2.4)
	await E.wait(1.5)
	var fin := _cartel(capa, "CASI HUMANO", 140, 16, COLOR_LETRA_CHICA)
	await _fundir(fin, 1.0)
	await E.wait(3.0)


func _cartel(capa: CanvasLayer, texto: String, y: int, tamano: int, color: Color) -> Label:
	var cartel := Label.new()
	cartel.text = texto
	cartel.position = Vector2(0, y)
	cartel.size = Vector2(320, tamano + 4)
	cartel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cartel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cartel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(RUTA_FUENTE):
		cartel.add_theme_font_override("font", load(RUTA_FUENTE))
	cartel.add_theme_font_size_override("font_size", tamano)
	cartel.add_theme_color_override("font_color", color)
	cartel.add_theme_color_override("font_shadow_color", COLOR_SOMBRA)
	cartel.add_theme_constant_override("shadow_offset_x", 0)
	cartel.add_theme_constant_override("shadow_offset_y", 1 if tamano <= 16 else 2)
	cartel.modulate.a = 0.0
	capa.add_child(cartel)
	return cartel


## Tres escalones de transparencia (pixel art: nada de fundidos suaves).
func _fundir(nodo: CanvasItem, hasta: float) -> void:
	var desde := nodo.modulate.a
	for escalon in [0.34, 0.67, 1.0]:
		if not is_instance_valid(nodo):
			return
		nodo.modulate.a = lerpf(desde, hasta, escalon)
		await get_tree().create_timer(0.1).timeout


# ---------- Planos ----------

## La máquina siempre se ve animada (la animación de 3 cuadros), nunca el fondo quieto.
func _abrir_plano_maquina() -> void:
	await _mostrar_maquina_de_cerca()


## Primer plano de la máquina: la animación de 3 cuadros sobre negro.
func _mostrar_maquina_de_cerca() -> void:
	if not ResourceLoader.exists(RUTA_MAQUINA_ANIM):
		return
	var capa := _plano_vacio()
	var frames := AsepriteCargador.crear_desde_tira(RUTA_MAQUINA_ANIM, 161, 128, {"anda": [0, 2]}, 6.0)
	if frames == null:
		return
	_maquina = AnimatedSprite2D.new()
	_maquina.sprite_frames = frames
	_maquina.centered = false
	_maquina.position = Vector2(80, 14)
	_maquina.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	capa.add_child(_maquina)
	_maquina.play(&"anda")
	await _cambiar_plano(capa)


func _frenar_maquina(velocidad: float) -> void:
	if is_instance_valid(_maquina):
		_maquina.speed_scale = velocidad
		if velocidad <= 0.2:
			_maquina.modulate = Color(0.8, 0.75, 0.85)


func _plano_vacio() -> CanvasLayer:
	var capa := CanvasLayer.new()
	capa.layer = 9  # como las tomas: debajo de la consola
	var fondo := ColorRect.new()
	fondo.color = Color.BLACK
	fondo.size = Vector2(320, 152)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(fondo)
	return capa


func _plano_fondo(ruta: String, desde_x: int) -> CanvasLayer:
	var capa := CanvasLayer.new()
	capa.layer = 9
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(ruta):
		var recorte := AtlasTexture.new()
		recorte.atlas = load(ruta)
		recorte.region = Rect2(desde_x, 0, 320, 152)
		sprite.texture = recorte
	capa.add_child(sprite)
	return capa


func _cerrar_plano() -> void:
	var vacio := CanvasLayer.new()
	await _cambiar_plano(vacio)
	vacio.queue_free()


## Corte con un fundido a negro en tres escalones.
func _cambiar_plano(nuevo: CanvasLayer) -> void:
	var negro := CanvasLayer.new()
	negro.layer = 10
	var rect := ColorRect.new()
	rect.color = Color.BLACK
	rect.size = Vector2(320, 152)
	rect.modulate.a = 0.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	negro.add_child(rect)
	add_child(negro)
	await _fundir(rect, 1.0)
	if is_instance_valid(_plano):
		_plano.queue_free()
	_plano = nuevo
	add_child(_plano)
	await E.wait(0.2)
	await _fundir(rect, 0.0)
	negro.queue_free()


func _sprite_nuna() -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.sprite_frames = SpriteJson.cargar(RUTA_NUNA_JSON, RUTA_NUNA_PNG, {}, [])
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"flota_frente"):
		sprite.play(&"flota_frente")
	return sprite


## Mueve a Nuna (o un sprite) cruzando el borde del cuadro, sin el límite de la pantalla.
func _cruzar(quien: Node2D, destino: Vector2) -> void:
	var sprite: AnimatedSprite2D = quien if quien is AnimatedSprite2D else quien.get_node_or_null("AnimatedSprite2D")
	if sprite != null and sprite.sprite_frames != null:
		sprite.flip_h = destino.x < quien.position.x
		if sprite.sprite_frames.has_animation(&"flota_derecha"):
			sprite.play(&"flota_derecha")
	var tw := create_tween()
	tw.tween_property(quien, "position", destino, absf(destino.x - quien.position.x) / 40.0)
	await tw.finished
	if quien == C.player:
		C.player.sync_buffered_position()
		C.player.volver_a_reposo_frontal()
	elif sprite != null and sprite.sprite_frames.has_animation(&"flota_frente"):
		sprite.flip_h = false
		sprite.play(&"flota_frente")


# ---------- Voces ----------

func _decir(texto: String) -> void:
	if not texto.is_empty():
		await C.player.say(texto)


func _din(texto: String) -> void:
	_timbre.play()
	await _decir("DIN: " + texto)


func _viejo(viejo: ViejoRecepcion, texto: String) -> void:
	viejo.hablar(true)
	await _decir("VIEJO: " + texto)
	viejo.hablar(false)


func _clonc() -> void:
	var sonido := AudioStreamPlayer.new()
	sonido.stream = Chip.wav(Chip.mezclar(
		Chip.nota(&"ruido", 300.0, 0.7, 0.3, 0.0, 0.25, 0.0, 0.0, 1.0),
		Chip.nota(&"triangulo", 70.0, 0.7, 0.35, 0.0, 0.3, 0.0, 0.0, 1.0)))
	sonido.volume_db = -6.0
	add_child(sonido)
	sonido.play()
	await E.wait(0.6)
	sonido.queue_free()


# ---------- Lo que pide la interfaz (acá no se toca nada) ----------

func seleccionar_objeto(_obj: ObjetoInteractivo) -> void:
	pass


func objeto_en(_punto: Vector2) -> ObjetoInteractivo:
	return null


func ejecutar_accion(_verbo: String) -> void:
	pass


func usar_objeto(_item: PopochiuInventoryItem, _objetivo: ObjetoInteractivo) -> void:
	pass


## La palanca vieja del mostrador: bronce, arriba o abajo. Dibujada con píxeles.
class Palanca extends Node2D:
	var abajo := false

	func bajar() -> void:
		abajo = true
		queue_redraw()

	func _draw() -> void:
		var oscuro := Color8(70, 46, 30)
		var bronce := Color8(196, 150, 72)
		var brillo := Color8(240, 206, 120)
		draw_rect(Rect2(-5, -1, 11, 4), Color.BLACK)
		draw_rect(Rect2(-4, 0, 9, 2), oscuro)
		draw_rect(Rect2(-3, 0, 7, 1), bronce)
		if abajo:
			draw_rect(Rect2(1, -3, 10, 3), Color.BLACK)
			draw_rect(Rect2(2, -2, 8, 1), bronce)
			draw_rect(Rect2(9, -5, 5, 5), Color.BLACK)
			draw_rect(Rect2(10, -4, 3, 3), brillo)
		else:
			draw_rect(Rect2(-1, -13, 3, 13), Color.BLACK)
			draw_rect(Rect2(0, -12, 1, 12), bronce)
			draw_rect(Rect2(-2, -18, 5, 5), Color.BLACK)
			draw_rect(Rect2(-1, -17, 3, 3), brillo)


## La decisión del final, bien grande: dos tarjetas lado a lado. Clic o teclas 1 y 2.
class EleccionFicha extends CanvasLayer:
	signal elegido(indice: int)

	const COLOR_FONDO := Color(0.03, 0.02, 0.06, 0.92)
	const COLOR_TITULO := Color8(251, 242, 54)
	const COLOR_TEXTO := Color8(203, 219, 252)
	const COLOR_GRIS := Color8(155, 173, 183)

	var opciones: Array = []
	var _listo := false

	func _ready() -> void:
		layer = 45
		var tema: Theme
		var orden := OrdenTrabajo.new()
		tema = orden._crear_tema()
		orden.free()
		var fondo := ColorRect.new()
		fondo.color = COLOR_FONDO
		fondo.size = Vector2(320, 152)
		fondo.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(fondo)
		var titulo := _label("TU FICHA - OBJETIVO PERSONAL", COLOR_TITULO, tema)
		titulo.position = Vector2(0, 10)
		var sub := _label("Elegí una de las dos:", COLOR_GRIS, tema)
		sub.position = Vector2(0, 26)
		for i in opciones.size():
			var datos: Array = opciones[i]
			var tarjeta := Button.new()
			tarjeta.theme = tema
			tarjeta.focus_mode = Control.FOCUS_NONE
			tarjeta.position = Vector2(10 + i * 154, 48)
			tarjeta.size = Vector2(146, 84)
			tarjeta.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tarjeta.pressed.connect(_responder.bind(i))
			add_child(tarjeta)
			var caja := VBoxContainer.new()
			caja.position = Vector2(6, 6)
			caja.size = Vector2(134, 72)
			caja.alignment = BoxContainer.ALIGNMENT_CENTER
			caja.add_theme_constant_override("separation", 2)
			caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tarjeta.add_child(caja)
			var numero := _label("(%d)" % (i + 1), COLOR_GRIS, tema, 134)
			caja.add_child(numero)
			var nombre := _label(datos[0], COLOR_TITULO, tema, 134)
			caja.add_child(nombre)
			for linea in datos.slice(1):
				caja.add_child(_label(linea, COLOR_TEXTO, tema, 134))
		if PreguntaSiNo.respuesta_automatica != null:
			_responder.call_deferred(int(PreguntaSiNo.respuesta_automatica))

	func _unhandled_key_input(event: InputEvent) -> void:
		var tecla := event as InputEventKey
		if tecla == null or not tecla.pressed or tecla.echo:
			return
		for i in opciones.size():
			if tecla.keycode == KEY_1 + i or tecla.keycode == KEY_KP_1 + i:
				_responder(i)

	func _responder(indice: int) -> void:
		if _listo:
			return
		_listo = true
		elegido.emit(indice)

	func _label(texto: String, color: Color, tema: Theme, ancho := 320.0) -> Label:
		var l := Label.new()
		l.text = texto
		l.theme = tema
		l.size = Vector2(ancho, 14)
		l.custom_minimum_size = Vector2(ancho, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", color)
		l.add_theme_constant_override("line_spacing", -4)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ancho >= 320.0:
			add_child(l)
		return l
