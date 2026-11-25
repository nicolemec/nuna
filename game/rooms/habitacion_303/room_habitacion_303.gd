@tool
extends PopochiuRoom
## Habitación 303: Vale. VERSIÓN GRAY BOX: cajas de colores en lugar de arte.
## Cuando exista el arte, alcanza con poner el fondo en RUTA_FONDO y la "textura" de cada
## objeto en el inspector (el código no cambia).
##
## Un juego por habilidad:
##   Sello 1 (POSEER): Vale está en vivo; solo cuenta lo que entra en cámara (el cuadro REC).
##     Mirar el aro de luz y poseerlo; cada clic lo transforma (rosa, ojo, rojo). Al tercero
##     el chat se asusta y Vale corta el vivo.
##   Sello 2 (APARECER): Vale va al espejo. Nuna aparece en el espejo y la calibración es un
##     juego de memoria de 3 rondas que revela «LA CÁMARA SOLO MIRA DONDE LA APUNTÁS».
##   Sello 3 (PERTURBAR): Vale vuelve al vivo. Perturbar el trípode gira la cámara hacia la
##     mitad real; perturbar el placard: avalancha en vivo.
##   Cierre: Vale se duerme en vivo; Nuna posee el teléfono y sube una foto honesta.

const Data := preload("room_habitacion_303_state.gd")
const RUTA_FONDO := "res://arte/backgrounds/habitacion_303.png"
## El vistazo a la máquina usa su animación (la misma de la Gerencia).
const RUTA_MAQUINA_ANIM := "res://arte/objetos/maquina_anim.png"
const RUTA_CUADROS := "res://arte/objetos/cuadros_303.png"
const FRASES_PROGRESO := ["", "¡Sello uno! Faltan dos.", "¡Dos de tres! ¡Ya casi!", "¡Tres sellos!"]
const MIEDO_PRIMER_SUSTO := 4.0
const MIEDO_SELLO := 20.0
const COSTO_ERROR := 1.0
const COLOR_POSESION := Color(0.78, 0.55, 1.0)
## Lo que ve la cámara del vivo: primero el rincón perfecto; después de girar, el desorden.
const CUADRO_PERFECTO := Rect2(166, 40, 152, 110)  # cama, cuadros, mesa de luz y espejo
const CUADRO_REAL := Rect2(22, 40, 80, 110)        # el placard
## Dónde está Vale según su estado.
const POS_VALE_CAMA := Vector2(214, 117)
const POS_VALE_ESPEJO := Vector2(286, 149)
## Juego de memoria del espejo (0 = FILTRO, 1 = LUZ, 2 = CONTRASTE, 3 = LIKE).
const RONDAS_MEMORIA := [[1, 3], [1, 3, 0], [1, 3, 0, 2]]
const FRASE_MEMORIA := ["LA CÁMARA", "SOLO MIRA", "DONDE LA APUNTÁS"]
const MOSTRAR_ETIQUETAS := true  # nombres sobre las cajas grises (sacar cuando haya arte)

## Textos de cada objeto: [nombre antes de mirar, nombre de Nuna, frase al mirar, al perturbar, al agarrar]
const TEXTOS := {
	"Puerta": ["puerta", "Señor Puerta", "¡Señor Puerta! Versión 303: con aro de luz en la mirilla.", "Mejor no lo molesto.", "Es más grande que yo."],
	"Cama": ["cama", "Sábana Impecable", "Sábanas blancas sin una arruga. Del set: también son alquiladas.", "¡Se arrugó la sábana impecable!", "No entra en el bolsillo."],
	"Vale": ["chica", "Vale", "Vale. Hace vivos desde la cama. No le pagan: le dan «visibilidad».", "Solo objetos, nunca personas. Lo dice el certificado.", "No entra en el bolsillo."],
	"Aro": ["aro de luz", "Santa Aureola", "¡La aureola de un santo! «La mejor versión de tu espanto», decía el cartel.", "", "Si me lo llevo, Vale se queda a oscuras."],
	"Tripode": ["trípode", "Ojo de Vidrio", "El teléfono de Vale, en un trípode. Solo existe lo que entra en el cuadro REC.", "", "Lo necesita para trabajar."],
	"Tocador": ["mesa de luz", "Doña Mesita", "Una mesa de luz llena de cosas para tapar a la persona.", "¡Tiemblan los frasquitos!", "Pesa más que yo."],
	"Espejo": ["espejo", "Espejo Juez", "Un espejo que pone nota: «Piel 6/10». Botones: FILTRO, LUZ, CONTRASTE y LIKE.", "Me califica: «Fantasma 0/10». ¡No me registra!", "Está atornillado. Como sus notas."],
	"Maquillaje": ["maquillaje", "Pintura Tapadora", "Pintura para tapar a la persona.", "¡Se cae un pincel!", "No me va a tapar nada: ya soy transparente."],
	"Delineador": ["delineador", "Delineador", "Un delineador. Sirve para remarcar lo que uno quiere que se vea.", "Rueda un poquito.", "Me lo llevo. Algo voy a tener que escribir."],
	"Flacozem": ["frasquito", "FLACOZEM™", "FLACOZEM™: «¡Hace desaparecer lo que sobra!». ¿Y si lo que sobra soy yo?", "No lo toco ni con un susto.", "Lo escondo. Por las dudas."],
	"Placard": ["placard", "Placard Explosivo", "Ropa con etiqueta: «DEVOLVER EL LUNES». Acá va todo lo que no sale en cámara.", "", "Ni con diez fantasmas."],
}

var state: Data = load("res://game/rooms/habitacion_303/room_habitacion_303.tres")
## Para la cama, Nuna se para adelante (la franja de piso más cercana a la cámara), así no
## queda tapando la cama. Con el resto de los objetos se acerca normal, como en la 101 y la 202.
const PISO_DELANTE := 146.0
var ocupado := false
var objeto_seleccionado: ObjetoInteractivo
var _saliendo := false
var _poseyendo := false  # Nuna está adentro del aro (o del teléfono)
var _rec: Node2D
var _cuadro_actual := CUADRO_PERFECTO
var _rec_visible := true
var _rec_titila := true
var _mirada_vale := 0
var _hablando_telefono := false  # mientras se habla del teléfono aparece el botón REC
var _badge_rec: BadgeREC
## Si el botón REC del diálogo está prendido, el cartelito REC del cuadro se esconde (así no hay dos).
var _badge_on := false
## Lo que dice Vale cuando algo se mueve ADENTRO del cuadro (van rotando).
const FRASES_EN_CUADRO := [
	"VALE (al teléfono): ¿Vieron eso? …Nada, chicos. Es el aire. ¡Sonrían!",
	"VALE (al teléfono): ¡Ay! ¿Se movió? Bueno, ¡es contenido! Comenten «fantasma» si lo vieron.",
	"VALE (al teléfono): Esto no estaba en el guion… Igual queda re auténtico, ¿no?",
	"VALE (al teléfono): Tranqui, chicos, es la conexión. Todo perfecto por acá. ¡Todo perfecto!",
]
var _frase_en_cuadro := 0
var _ratoncito_usado := false  # el Ratoncito ya mantuvo el vivo "activo" en el cierre


func _enter_tree() -> void:
	super()
	y_sort_enabled = false
	$Props.y_sort_enabled = false
	$Characters.y_sort_enabled = false


# ---------- Gray box: fondo dibujado con rectángulos ----------

func _draw() -> void:
	if has_node("Background") and $Background.texture != null:
		return
	draw_rect(Rect2(0, 0, 320, 152), Color(0.13, 0.10, 0.18))           # pared
	draw_rect(Rect2(0, 0, 160, 120), Color(0.30, 0.20, 0.30))            # mitad perfecta (más clara)
	draw_rect(Rect2(0, 120, 320, 32), Color(0.24, 0.17, 0.14))           # piso
	draw_rect(Rect2(159, 0, 2, 120), Color(0.05, 0.04, 0.07))            # la habitación partida
	if Engine.is_editor_hint() or not MOSTRAR_ETIQUETAS:
		return
	var fuente := _fuente()
	for obj in get_props():
		if obj is ObjetoInteractivo and obj.visible:
			var p: Vector2 = obj.position + Vector2(-obj.tamano.x / 2.0, -obj.tamano.y - 2)
			draw_string(fuente, p.floor(), String(obj.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.45))


func _fuente() -> Font:
	if ResourceLoader.exists(Ajustes.UI_FUENTE_HUD):
		return load(Ajustes.UI_FUENTE_HUD)
	return ThemeDB.fallback_font


# ---------- Entrada ----------

## Con un objeto del inventario en la mano, el clic sobre un objeto del cuarto lo usa ahí.
func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or (I.active == null and Globals.extra_activo.is_empty()) or ocupado or G.is_blocked:
		return
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.position.y < Ajustes.UI_HUD_TAMANO.y or event.position.y >= Ajustes.UI_Y:
		return
	var punto: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	var objetivo := objeto_en(punto)
	if objetivo == null:
		Globals.extra_activo = ""  # clic en el piso: lo guarda
		_actualizar_guia()
		return
	get_viewport().set_input_as_handled()
	if not Globals.extra_activo.is_empty():
		var extra := Globals.extra_activo
		Globals.extra_activo = ""
		await usar_extra(extra, objetivo)
		return
	var item: PopochiuInventoryItem = I.active
	I.set_active_item(null)
	await usar_objeto(item, objetivo)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not event is InputEventMouseButton or ocupado or G.is_blocked:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var destino: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	if _poseyendo:
		# Adentro del aro: un clic sobre el aro lo transforma directo (sin depender del botón).
		if destino.y < Ajustes.UI_Y and objeto_en(destino) == $Props/Aro:
			get_viewport().set_input_as_handled()
			objeto_seleccionado = $Props/Aro
			await ejecutar_accion("perturbar")
		return
	if E.hovered:
		return
	if destino.y >= Ajustes.UI_Y or not is_instance_valid(C.player):
		return
	# Si Popochiu no detectó el objeto (zona de clic desfasada), lo buscamos por su rectángulo.
	var obj := objeto_en(destino)
	if obj != null and obj.clickable:
		get_viewport().set_input_as_handled()
		E.clicked = obj
		seleccionar_objeto(obj)
		return
	_cancelar_seleccion()
	E.clicked = null
	I.set_active_item(null)
	if C.player.is_moving:
		C.player.stop_walking()
	C.player.walk(destino)


func _on_room_entered() -> void:
	# Si se abre la 303 directo (para probar), la recepción no sabe que la historia avanzó:
	# la dejamos como si Nuna ya hubiera hecho la intro, la 101 y la 202.
	var recepcion: Resource = load("res://game/rooms/recepcion/room_recepcion.tres")
	if recepcion.paso != 3:
		recepcion.paso = 3
		recepcion.cinematica_2 = true
		recepcion.cinematica_3 = true
	Musica.tocar(&"habitacion")
	if ResourceLoader.exists(RUTA_FONDO):
		$Background.texture = load(RUTA_FONDO)
	if ResourceLoader.exists(RUTA_CUADROS):
		$Cuadros.texture = load(RUTA_CUADROS)
	C.player.position = $Markers/InicioNuna.position
	C.player.show()
	for obj in get_props():
		if obj is ObjetoInteractivo and TEXTOS.has(String(obj.name)):
			var t: Array = TEXTOS[String(obj.name)]
			obj.nombre_desconocido = t[0]
			obj.nombre = t[1]
			obj.frase_mirar = t[2]
			obj.frase_perturbar = t[3]
			obj.frase_agarrar = t[4]
	Globals.extra_activo = ""
	_sincronizar_zonas_clic()
	_crear_rec()
	if not state.entrada_completada:
		_empezar_turno()
	_restaurar_visual()
	queue_redraw()


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
	_poseyendo = false
	objeto_seleccionado = null
	for obj in get_props():
		if obj is ObjetoInteractivo:
			obj.restaurar_posicion()
			obj.visible = not obj.recogido
			obj.description = obj.nombre_visible()
	if Globals.tiene_extra("delineador"):
		$Props/Delineador.hide()
	if state.flacozem_escondido:
		$Props/Flacozem.hide()
	_poner_vale(state.vale_estado)
	if state.sello_placard:
		$Props/Placard.color = Color(0.30, 0.10, 0.12)
		_reposo($Props/Placard, &"abierto")
	_reposo($Props/Aro, &"apagado" if state.sello_aro else &"fria")
	_reposo($Props/Cama, &"arrugada" if state.perturbados.has("Cama") else &"tendida")
	_reposo($Props/Espejo, &"encendido" if state.sello_espejo or state.vale_estado == "espejo" else &"apagado")
	_cuadro_actual = CUADRO_REAL if state.camara_girada else CUADRO_PERFECTO
	_rec_visible = state.vale_estado in ["vivo", "dormida"] and not state.foto_subida
	_actualizar_rec()
	G.gui.mostrar_habitacion(true)
	_actualizar_guia()


func _on_room_transition_finished() -> void:
	C.player.poner_birrete(false)  # en las habitaciones Nuna ya no lleva birrete
	if state.entrada_completada:
		return
	state.entrada_completada = true
	ocupado = true
	E.playing_queue = false
	G.block()
	C.player.volver_a_reposo_frontal()
	await DialogoPopup.mostrar(self, [
		["NUNA", "¡La 303! Hay luz… Alguien está despierto."],
		["DIN", "Orden de trabajo: asustá a la huésped y ganá 3 sellos.", "(Turno en vivo. Sonreí.)"],
		["DIN", "La huésped está transmitiendo. Lo que no sale en cámara, no pasó. ♥", "(El cuadro con REC es lo que ve la cámara.)"],
		["DIN", "Primero MIRÁ: presentate con cada cosa. Después usá todo lo que aprendiste: PERTURBAR y POSEER.", "(Y si te portás bien, una actualización nueva.)"],
		["DIN", "Si no se asusta, es un problema de engagement. Tuyo. ♥"],
		["NUNA", "¡Un vivo! Yo también estuve en vivo una vez. Hace mucho."],
	])
	G.unblock()
	ocupado = false
	_actualizar_guia()


# ---------- Selección y acciones (mismo esquema que la 101 y la 202) ----------

func seleccionar_objeto(obj: ObjetoInteractivo) -> void:
	if ocupado or G.is_blocked or not obj.visible:
		return
	objeto_seleccionado = obj
	_mostrar_contexto_seleccionado()


## El objeto más chico bajo el punto (el delineador gana sobre el tocador).
func objeto_en(punto: Vector2) -> ObjetoInteractivo:
	var elegido: ObjetoInteractivo = null
	var area := INF
	for obj in get_props():
		if obj is ObjetoInteractivo and obj.visible and obj.contiene(punto) and obj.tamano.x * obj.tamano.y < area:
			elegido = obj
			area = obj.tamano.x * obj.tamano.y
	return elegido


func usar_objeto(item: PopochiuInventoryItem, objetivo: ObjetoInteractivo) -> void:
	if ocupado or G.is_blocked:
		return
	seleccionar_objeto(objetivo)
	ocupado = true
	if item.script_name == "Dentadura" and objetivo == $Props/Espejo:
		await _decir("¿Una sonrisa para el espejo? «Sonrisa 10/10». Ojalá me calificara a mí.")
	elif item.script_name == "Dentadura" and objetivo == $Props/Vale:
		await _decir("Ya tiene sonrisa. Una de vivo: le dura lo que dura la transmisión.")
	elif item.script_name == "Ovillo":
		await _decir("Ovi se quedó en la 101. Esto es otra cosa.")
	else:
		await _decir("No me ayuda con eso.")
	ocupado = false
	_actualizar_guia()


## Extras del inventario (delineador, Flacozem): USAR en el inventario y después clic en algo.
func usar_extra(id: String, objetivo: ObjetoInteractivo) -> void:
	if ocupado or G.is_blocked:
		return
	seleccionar_objeto(objetivo)
	ocupado = true
	var nombre := String(objetivo.name)
	if id == "delineador" and nombre == "Espejo":
		if state.sello_espejo:
			await _decir("Le escribo abajo de la nota: «Fantasma 10/10». Por fin alguien me califica bien.")
		elif state.aparicion_desbloqueada and state.vale_estado == "espejo":
			await _decir("Podría escribirle algo… pero mejor que me vea a MÍ. ¡APARECER!")
			_brillar(objetivo)
		else:
			objetivo._sacudir()
			_sumar_miedo_primera_vez(objetivo)
			await _decir("Le dibujo un bigote al Espejo Juez. «Bigote 10/10». ¡Por fin una buena nota!")
			await _decir("Se borra solo. Este espejo no deja que nada quede torcido.")
	elif id == "delineador" and nombre == "Vale":
		await _decir("Solo objetos, nunca personas. Y menos con delineador.")
	elif id == "delineador":
		await _decir("Mejor no rayo nada. Lo guardo para algo importante.")
	elif id == "flacozem" and nombre == "Vale":
		await _decir("No. Este no se lo devuelvo. Ni en chiste.")
	elif id == "flacozem":
		await _decir("No lo dejo en ningún lado. Se queda conmigo, bien guardado.")
	elif id == "ratoncito" and nombre == "Tripode" and state.vale_estado == "dormida" and not state.foto_subida:
		await _ratoncito_en_el_vivo()
	elif id == "ratoncito" and nombre == "Tripode":
		objetivo._sacudir()
		await _decir("Lo apoyo al lado del teléfono: el vivo parece activo aunque nadie haga nada.")
		await _decir("…Como Bruno. Como yo. Mejor me lo llevo de vuelta.")
	elif id == "ratoncito" and nombre == "Vale":
		await _decir("Ella no necesita algo que haga como que trabaja. Ya lo hace sola, todo el día.")
	elif id == "ratoncito":
		await _decir("El Ratoncito hace como que trabaja. Acá no hace falta: todo ya hace como que.")
	elif id.begins_with("llave"):
		await _decir("Es la llave de otra habitación. Acá no abre nada.")
	else:
		await _decir("No me ayuda con eso.")
	ocupado = false
	_actualizar_guia()
	_mostrar_contexto_seleccionado()


func _seleccion_es_valida() -> bool:
	return is_instance_valid(objeto_seleccionado) and objeto_seleccionado.visible


func ejecutar_accion(verbo: String) -> void:
	if ocupado or G.is_blocked or not _seleccion_es_valida() or verbo not in ["mirar", "agarrar", "perturbar"]:
		return
	var obj := objeto_seleccionado
	ocupado = true
	if _poseyendo:
		# Adentro del aro no se camina: cada clic lo transforma.
		if obj == $Props/Aro and verbo == "perturbar":
			await _transformar_aro()
		else:
			await _decir("Estoy adentro del aro. ¡Primero termino acá!")
	else:
		if C.player.is_moving:
			C.player.stop_walking()
		var hasta := obj.punto_de_uso()
		if obj == $Props/Cama:
			hasta.y = PISO_DELANTE
		elif obj == $Props/Puerta:
			hasta.y = 140.0  # junto a la puerta, sobre el piso (no en la línea del fondo)
		await E.queue([
			C.player.queue_walk(hasta),
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
	var nombre := String(obj.name)
	_hablando_telefono = nombre == "Tripode"
	if nombre == "Puerta" and verbo == Globals.MIRAR:
		obj.nombrado = true
		if state.mision_completada:
			await _salir_de_la_303()
		else:
			await _decir("¡Señor Puerta! Todavía no salgo: me faltan sellos.")
	elif verbo == Globals.MIRAR:
		await _mirar(obj)
	elif not obj.nombrado:
		await _decir("¡Ay, todavía no nos presentamos! Primero lo miro.")
	elif verbo == Globals.AGARRAR:
		await _agarrar(obj)
	elif verbo == Globals.PERTURBAR:
		await _tercer_verbo(obj)
	_hablando_telefono = false
	obj.description = obj.nombre_visible()
	if Globals.sellos > sellos_antes:
		await _decir(FRASES_PROGRESO[clampi(Globals.sellos, 0, 3)])
		if Globals.sellos >= Globals.SELLOS_TOTALES:
			await _vale_se_duerme()


func _mirar(obj: ObjetoInteractivo) -> void:
	var nombre := String(obj.name)
	await _decir(obj.ejecutar(Globals.MIRAR))
	match nombre:
		"Vale":
			_mirada_vale += 1
			if _mirada_vale >= 2:
				await _decir("Mira Espectragram: «Gaspar ya tiene su propio castillo embrujado».")
				await _decir("Se compara con gente que no conoce. Con gente que ni existe.")
		"Tripode":
			await _decir("¡REC! Lo que no entra en el cuadro, no existe.")
			if state.sello_espejo and not state.camara_girada:
				await _decir("«La cámara solo mira donde la apuntás»… ¿Y si la apunto para el otro lado?")
		"Placard":
			await _decir("El rincón perfecto también es alquilado. Hasta el aro tiene etiqueta.")
		"Espejo":
			if state.sello_espejo:
				await _decir("Ahora dice: «2 rostros detectados». Uno soy yo.")


func _agarrar(obj: ObjetoInteractivo) -> void:
	var nombre := String(obj.name)
	if nombre == "Delineador":
		await _decir(obj.frase_agarrar)
		obj.hide()
		queue_redraw()
		Globals.agregar_extra("delineador")
		G.gui.ui.resaltar_cuaderno()
		await _decir("Ahora vive en mi inventario.")
	elif nombre == "Flacozem":
		state.flacozem_escondido = true
		obj.hide()
		queue_redraw()
		Globals.agregar_extra("flacozem")
		await _decir("Me lo llevo. Por las dudas. Ni Vale ni yo lo necesitamos.")
	else:
		await _decir(obj.frase_agarrar)


## El tercer botón cambia según el objeto: Perturbar, Poseer, Aparecer o Transformar.
func _tercer_verbo(obj: ObjetoInteractivo) -> void:
	var nombre := String(obj.name)
	match _nombre_tercer_verbo(obj):
		"Poseer":
			if nombre == "Aro":
				await _poseer_aro()
			else:
				await _foto_honesta()
			return
		"Aparecer":
			await _aparecer_en_espejo()
			return
	if not obj.puede_perturbar:
		await _decir(obj.frase_perturbar)
		return
	match nombre:
		"Tripode":
			await _perturbar_tripode()
		"Placard":
			await _perturbar_placard()
		"Aro":
			_reaccionar(obj)
			await _decir("Tiembla un poquito. Tengo que conocerlo mejor… ¿y si me meto adentro?" if not state.sello_aro else "Ya no ilumina igual. Lo dejo descansar.")
		_:
			_reaccionar(obj)
			if nombre == "Cama":
				_reposo(obj, &"arrugada", false)
			_sumar_miedo_primera_vez(obj)
			if state.vale_estado == "vivo" and not _en_cuadro(obj):
				await _decir(obj.frase_perturbar if not obj.frase_perturbar.is_empty() else "¡Buu!")
				await _decir("VALE (al teléfono): ¡Chicos, no pasa nada! Si no sale en cámara, no pasó.")
			elif state.vale_estado == "vivo":
				# Adentro del cuadro REC sí se nota: Vale lo ve en vivo y lo disimula.
				await _decir(obj.frase_perturbar if not obj.frase_perturbar.is_empty() else "¡Buu!")
				await _decir(FRASES_EN_CUADRO[_frase_en_cuadro % FRASES_EN_CUADRO.size()])
				_frase_en_cuadro += 1
			else:
				await _decir(obj.frase_perturbar if not obj.frase_perturbar.is_empty() else "¡Buu!")


func _nombre_tercer_verbo(obj: ObjetoInteractivo) -> String:
	if not is_instance_valid(obj):
		return ""
	match String(obj.name):
		"Aro":
			if _poseyendo:
				return "Transformar"
			if obj.nombrado and not state.sello_aro:
				return "Poseer"
		"Espejo":
			if state.aparicion_desbloqueada and state.vale_estado == "espejo" and not state.sello_espejo:
				return "Aparecer"
		"Tripode":
			if state.vale_estado == "dormida" and not state.foto_subida:
				return "Poseer"
	return ""


# ---------- Sello 1: el aro de luz (Poseer, estilo Haunt the House) ----------

func _poseer_aro() -> void:
	await _decir("¡La mejor versión de mi espanto! Permiso, Santa Aureola… me meto.")
	await _parpadear_nuna(false)
	_poseyendo = true
	_actualizar_medio_sello()
	await _transformar_aro()
	if _poseyendo:
		await _decir("(Seguí haciendo clic en el aro para transformarlo.)")


## Cada clic, una forma nueva: rosa, ojo gigante, rojo que parpadea.
func _transformar_aro() -> void:
	var aro: ObjetoInteractivo = $Props/Aro
	state.aro_forma += 1
	match state.aro_forma:
		1:
			aro.color = Color(1.0, 0.6, 0.85)
			_reposo(aro, &"calida")
			await _decir("CHAT: «¡qué linda luz rosa!»")
			await _decir("¡Les gusta! Otra vez…")
		2:
			aro.color = Color(1.0, 0.85, 0.95)
			if aro is ObjetoAnimado:
				_reposo(aro, &"poseida")
			else:
				aro.scale = Vector2(1.6, 0.6)
			await _decir("CHAT: «¿el aro… parpadeó?»")
			await _decir("¡Soy un ojo gigante! Una más…")
		_:
			aro.scale = Vector2.ONE
			aro.color = Color(1.0, 0.15, 0.15)
			aro.modulate = Color(1.0, 0.35, 0.35)
			var tw := create_tween().set_loops(6)
			tw.tween_callback(func(): aro.visible = not aro.visible)
			tw.tween_interval(0.12)
			await tw.finished
			aro.visible = true
			await _decir("CHAT: «¿¿QUÉ ES ESO ATRÁS??»")
			await _decir("VALE: ¡¿QUÉ ES ESO?! …¡Chau, chicos, chau!")
			_rec_visible = false
			_actualizar_rec()
			aro.color = Color(1.0, 0.95, 0.70)
			aro.modulate = Color.WHITE
			_reposo(aro, &"apagado")
			_poseyendo = false
			await _parpadear_nuna(true)
			state.sello_aro = true
			Globals.aumentar_vela(MIEDO_SELLO)
			Globals.otorgar_sello(&"aro_303")
			await _decir("¡Cortó el vivo!")
			_poner_vale("espejo")
			await _decir("VALE: ¿Salí fea en el susto? Tengo que ver…")
			await _desbloquear_aparicion()


func _desbloquear_aparicion() -> void:
	await get_tree().create_timer(0.5).timeout
	await G.gui.ui.mostrar_certificacion("DIN: Actualización disponible: APARECER (beta).", "(Solo ante alguien despierto y en superficies que reflejan.)")
	await _decir("¿Que me vean? ¡Por fin!")
	await _decir("DIN: Mostrate. Pero bien. ♥")
	state.aparicion_desbloqueada = true
	_brillar($Props/Espejo)


# ---------- Sello 2: el espejo (Aparecer + memoria) ----------

func _aparecer_en_espejo() -> void:
	var espejo: ObjetoInteractivo = $Props/Espejo
	await _decir("Vale está despierta y mirando el espejo. ¡Ahora!")
	await _parpadear_nuna(false)
	if espejo is ObjetoAnimado:
		_reposo(espejo, &"calibrando")
	else:
		espejo.modulate = COLOR_POSESION
	await _decir("ESPEJO: Rostro no calibrado. Calibrando…")
	var panel := PanelMemoria.new()
	panel.frase = FRASE_MEMORIA
	add_child(panel)
	panel.revelar(state.espejo_ronda)
	while state.espejo_ronda < RONDAS_MEMORIA.size():
		var ok: bool = await panel.jugar(RONDAS_MEMORIA[state.espejo_ronda])
		if panel.cancelado:
			break
		if ok:
			state.espejo_ronda += 1
			_actualizar_medio_sello()
			panel.revelar(state.espejo_ronda)
			await get_tree().create_timer(0.7).timeout
		else:
			Globals.cambiar_bruma(-COSTO_ERROR)
			_error_espejo(espejo)
			panel.avisar("¡Desafinó! Otra vez (-%d de bruma)." % int(COSTO_ERROR))
			await get_tree().create_timer(1.0).timeout
	var completo: bool = state.espejo_ronda >= RONDAS_MEMORIA.size()
	if completo:
		panel.avisar("¡Calibrado!")
		await get_tree().create_timer(1.2).timeout
	panel.queue_free()
	espejo.modulate = Color.WHITE
	if not completo:
		_reposo(espejo, &"encendido")
		await _parpadear_nuna(true)
		await _decir("Mejor salgo. Ya vuelvo a calibrarlo.")
		return
	var espejo_anim := espejo as ObjetoAnimado
	if espejo_anim != null and espejo_anim.reproducir(&"nuna_aparece"):
		await get_tree().create_timer(0.47).timeout
		espejo_anim._anim.pause()  # se queda con Nuna sorprendida en el reflejo
	_reposo($Props/Vale, &"espejo_susto")
	await _decir("ESPEJO: 2 rostros detectados. El otro es más auténtico.")
	await _parpadear_nuna(true)
	$Props/Vale.color = Color(1, 1, 1)
	_reposo($Props/Vale, &"espejo_senala")
	await _decir("VALE: …¿Quién? No hay nadie. ¿Más auténtico que yo?")
	state.sello_espejo = true
	Globals.aumentar_vela(MIEDO_SELLO)
	Globals.otorgar_sello(&"espejo_303")
	await _decir("«La cámara solo mira donde la apuntás». Me lo anoto.")
	Globals.anotar("La cámara solo mira donde la apuntás.")
	_poner_vale("vivo")
	_reposo(espejo, &"encendido")
	_rec_visible = true
	_actualizar_rec()
	await _decir("VALE: ¡Perdón, chicos, volví! Problemas técnicos.")
	_brillar($Props/Tripode)


# ---------- Sello 3: la avalancha (Perturbar) ----------

func _perturbar_tripode() -> void:
	var tripode: ObjetoInteractivo = $Props/Tripode
	tripode._sacudir()
	if not state.sello_espejo:
		_sumar_miedo_primera_vez(tripode)
		await _decir("VALE: ¡Ay! Se movió la cámara… ¡Ya está, chicos!")
		await _decir("Lo acomodó enseguida. Todavía no sé para dónde apuntarlo.")
		return
	if state.camara_girada:
		await _decir("Ya mira para el lado del desorden. Que se quede ahí.")
		return
	await _decir("Te empujo despacito… para el otro lado.")
	for i in 4:  # el cuadro REC se corre a saltitos, cuadro a cuadro
		_cuadro_actual = Rect2(CUADRO_PERFECTO.position.lerp(CUADRO_REAL.position, (i + 1) / 4.0), CUADRO_PERFECTO.size.lerp(CUADRO_REAL.size, (i + 1) / 4.0))
		_actualizar_rec()
		await get_tree().create_timer(0.25).timeout
	state.camara_girada = true
	_cuadro_actual = CUADRO_REAL
	_actualizar_rec()
	_actualizar_medio_sello()
	await _decir("Vale no se dio cuenta. La cámara ahora mira la otra mitad.")
	_brillar($Props/Placard)


func _perturbar_placard() -> void:
	var placard: ObjetoInteractivo = $Props/Placard
	if state.sello_placard:
		await _decir("Ya no le entra nada más. Ni a él ni a Vale.")
		return
	if not state.camara_girada:
		_reaccionar(placard)
		_sumar_miedo_primera_vez(placard)
		await _decir("Tiembla… pero si lo abro ahora, no lo ve nadie. La cámara mira para el otro lado.")
		return
	await _decir("¡Placard, es tu momento!")
	placard.color = Color(0.30, 0.10, 0.12)
	var placard_anim := placard as ObjetoAnimado
	if placard_anim != null and placard_anim.reproducir(&"abre"):
		await get_tree().create_timer(0.42).timeout
		placard_anim.reproducir(&"avalancha")
		await get_tree().create_timer(1.0).timeout  # la avalancha ya está dibujada en el placard
	else:
		await _avalancha()  # sin arte: rectangulitos de prueba
	_reposo(placard, &"abierto")
	await _decir("CHAT: «¿¿ESA ES SU PIEZA DE VERDAD??»")
	await _decir("CHAT: «igual que la mía jajaja»")
	_poner_vale("llora_rie")
	await _decir("VALE: …No es mía. Nada de esto es mío.")
	await _decir("Vale llora y se ríe a la vez.")
	await _decir("…Ay. Ella no eligió mostrar esto. ¿Me pasé?")
	await _decir("El chat dice «igual que la mía». ¿Se asustaron o se alegraron?")
	state.sello_placard = true
	Globals.aumentar_vela(MIEDO_SELLO)
	Globals.otorgar_sello(&"placard_303")


## Ropa con etiqueta, cajas y vasos caen dentro del cuadro (gray box: rectangulitos).
func _avalancha() -> void:
	var colores := [Color(0.9, 0.4, 0.5), Color(0.5, 0.7, 0.9), Color(0.95, 0.9, 0.5), Color(0.8, 0.55, 0.3), Color(0.9, 0.9, 0.9)]
	var tw := create_tween().set_parallel()
	for i in 12:
		var r := ColorRect.new()
		r.size = Vector2(randi_range(4, 9), randi_range(3, 6))
		r.color = colores[i % colores.size()]
		r.position = Vector2(randi_range(34, 80), randi_range(50, 110))
		r.z_index = 3
		add_child(r)
		Pixel.mover(tw, r, "position", Vector2(randi_range(28, 100), randi_range(132, 146)), 0.4 + 0.05 * i)
	await tw.finished


# ---------- Cierre: Vale se duerme en vivo y la foto honesta ----------

func _vale_se_duerme() -> void:
	await get_tree().create_timer(0.8).timeout
	_poner_vale("dormida")
	_cuadro_actual = CUADRO_PERFECTO
	_rec_visible = true
	_actualizar_rec()
	await _decir("Vale volvió a la cama… y se durmió. El vivo sigue prendido.")
	await _decir("DIN: Falta el cierre, equipo. Un susto que se comparta. ♥")
	if Globals.tiene_extra("ratoncito"):
		await _decir("El vivo sigue solo, sin nadie… como la compu de Bruno.")
	_brillar($Props/Tripode)


## Cierre (opcional): el Ratoncito de la 202 sobre el teléfono. El vivo "trabaja" sin nadie y
## Din lo premia: la misma trampa que en la 202. No da sello; la foto honesta sigue siendo el cierre.
func _ratoncito_en_el_vivo() -> void:
	var tripode: ObjetoInteractivo = $Props/Tripode
	if _ratoncito_usado:
		await _decir("Ya vi lo que pasa. Din aplaude a un ratón. Prefiero algo de verdad.")
		return
	_ratoncito_usado = true
	_hablando_telefono = true
	tripode._sacudir()
	await _decir("Apoyo al Ratoncito sobre la pantalla. Toc, toc, toc… El teléfono no se bloquea.")
	await _decir("CHAT: «¿se durmió?»")
	await _decir("CHAT: «nah, está tocando la pantalla, sigue activa»")
	await G.gui.ui.mostrar_certificacion("DIN: Actividad detectada en el vivo. Rendimiento: 100%. ♥", "(Vale está dormida.)")
	await _decir("…Nadie hace nada y Din está feliz. Como con Bruno.")
	await _decir("Esto no asusta a nadie. Es un disfraz de trabajo. Lo saco.")
	_hablando_telefono = false
	tripode._sacudir()
	Globals.anotar("Con el Ratoncito, Din aplaude aunque nadie haga nada. Le alcanza con que parezca.")
	await _decir("Lo que falta es lo contrario: algo de verdad. Mejor POSEO el teléfono.")
	_brillar(tripode)


func _foto_honesta() -> void:
	await _decir("Permiso, Ojo de Vidrio. Me meto en el teléfono.")
	await _parpadear_nuna(false)
	$Props/Tripode.modulate = COLOR_POSESION
	await _decir("¡Clic! Vale dormida, despeinada, con la boca abierta. Sin filtro.")
	await _flash()
	$Props/Tripode.modulate = Color.WHITE
	await _parpadear_nuna(true)
	state.foto_subida = true
	_rec_visible = false
	_actualizar_rec()
	await G.gui.ui.mostrar_certificacion("ESPECTRAGRAM · @vale subió una foto. ♥ 48.210", "(«¡Por fin algo real!» · «igual que yo a las 3 am»)")
	_poner_vale("despierta")
	await _decir("VALE: ¿Qué…? ¿Quién subió esto?")
	_reposo($Props/Vale, &"despierta_lee")
	await G.gui.ui.mostrar_certificacion("Tu autenticidad rinde 300%. ¡Subí otra hoy!", "(Espectragram te recomienda: ser auténtica todos los días a las 9.)")
	_poner_vale("llora_rie")
	await _decir("Llora y se ríe. Otra vez las dos cosas.")
	await _decir("…Le mostré a todos algo que no eligió mostrar. Eso también cuenta como susto, ¿no?")
	await G.gui.ui.mostrar_certificacion("REGISTRO: SUSTO MÁXIMO.", "(El Registro no distingue emociones.)")
	Globals.anotar("Vale muestra una vida prestada y la devuelve el lunes. Yo no tengo nada que devolver. ¿Qué me falta a mí?")
	await _mision_cumplida()


func _mision_cumplida() -> void:
	if state.mision_completada:
		return
	state.mision_completada = true
	Globals.llenar_vela(Ajustes.LUMI_HABITACION_ID)
	await _decir("DIN: Presentate en Gerencia para tu evaluación de desempeño. ♥")
	await _decir("¿Gerencia? ¿Arriba de todo?")
	if not Globals.tiene_extra("delineador"):
		_brillar($Props/Delineador)
		await _decir("Antes de irme… ese delineador de la mesa de luz me puede servir.")
	_brillar($Props/Puerta)


# ---------- Salida: el vistazo a la máquina ----------

func _salir_de_la_303() -> void:
	if not Globals.tiene_extra("delineador"):
		_brillar($Props/Delineador)
		await _decir("Me falta el delineador. Está en la mesa de luz.")
		return
	var salir: bool = await PreguntaSiNo.preguntar(self, "¿Subir a la Gerencia?")
	if not salir:
		await _decir("Un ratito más con Vale.")
		return
	await _decir("¡Chau, Vale! ¡Chau, Santa Aureola y Espejo Juez!")
	var puerta = $Props/Puerta  # PuertaAnimada (la misma de la 101)
	if puerta.has_method("abrir"):
		await puerta.abrir()
	await C.player.walk($Markers/EntradaNuna.global_position)
	C.player.hide()
	if puerta.has_method("cerrar"):
		await puerta.cerrar()
	await _vistazo_maquina()
	_saliendo = true
	_cancelar_seleccion()
	R.goto_room("Recepcion")


## Unos segundos: la Gran Máquina, animada (la misma de la Gerencia). Sin explicaciones.
func _vistazo_maquina() -> void:
	G.block()
	var capa := CanvasLayer.new()
	capa.layer = 60
	add_child(capa)
	var fondo := ColorRect.new()
	fondo.color = Color.BLACK
	fondo.size = Vector2(320, 180)
	capa.add_child(fondo)
	var frames := AsepriteCargador.crear_desde_tira(RUTA_MAQUINA_ANIM, 161, 128, {"anda": [0, 2]}, 6.0)
	if frames != null:
		var maquina := AnimatedSprite2D.new()
		maquina.sprite_frames = frames
		maquina.centered = false
		maquina.position = Vector2(80, 12)
		maquina.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		capa.add_child(maquina)
		maquina.play(&"anda")
	else:
		capa.add_child(MaquinaGrayBox.new())
	await get_tree().create_timer(3.5).timeout
	capa.queue_free()
	G.unblock()


# ---------- Vale ----------

func _poner_vale(estado: String) -> void:
	state.vale_estado = estado
	var vale: ObjetoInteractivo = $Props/Vale
	match estado:
		"vivo":
			vale.fijar_anclaje(POS_VALE_CAMA)
			vale.color = Color(0.98, 0.62, 0.78)
		"espejo":
			vale.fijar_anclaje(POS_VALE_ESPEJO)
			_reposo($Props/Espejo, &"encendido")
			vale.color = Color(0.98, 0.62, 0.78)
		"llora_rie":
			vale.color = Color(0.62, 0.78, 1.0)
		"dormida":
			vale.fijar_anclaje(POS_VALE_CAMA)
			vale.color = Color(0.62, 0.52, 0.72)
		"despierta":
			vale.fijar_anclaje(POS_VALE_CAMA)
			vale.color = Color(1.0, 0.85, 0.9)
	_reposo(vale, StringName(estado))
	queue_redraw()


## Popochiu arma la zona de clic antes de que el objeto calcule su rectángulo:
## acá la copiamos al polígono real, así el clic coincide con lo que se ve.
func _sincronizar_zonas_clic() -> void:
	for obj in get_props():
		if obj is ObjetoInteractivo and not obj.interaction_polygon.is_empty():
			var poligono := obj.get_node_or_null("InteractionPolygon") as CollisionPolygon2D
			if poligono != null:
				poligono.polygon = obj.interaction_polygon
				poligono.position = Vector2.ZERO


# ---------- El cuadro REC ----------

func _crear_rec() -> void:
	if Engine.is_editor_hint() or is_instance_valid(_rec):
		return
	_rec = Node2D.new()
	_rec.name = "CuadroREC"
	_rec.z_index = 4
	_rec.draw.connect(_dibujar_rec)
	add_child(_rec)
	var titilar := Timer.new()
	titilar.wait_time = 0.5
	titilar.autostart = true
	titilar.timeout.connect(func():
		_rec_titila = not _rec_titila
		if is_instance_valid(_rec):
			_rec.queue_redraw())
	_rec.add_child(titilar)


func _actualizar_rec() -> void:
	if is_instance_valid(_rec):
		_rec.visible = _rec_visible
		_rec.queue_redraw()
	queue_redraw()


func _dibujar_rec() -> void:
	var r := Rect2(_cuadro_actual.position.floor(), _cuadro_actual.size.floor())
	var claro := Color("f1eee3")
	var oscuro := Color("221722")
	var rojo := Color("e32356")
	# Lo que queda fuera de cámara se ve apagado.
	var sombra := Color(0.03, 0.02, 0.06, 0.35)
	_rec.draw_rect(Rect2(0, 0, 320, r.position.y), sombra)
	_rec.draw_rect(Rect2(0, r.end.y, 320, 152 - r.end.y), sombra)
	_rec.draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), sombra)
	_rec.draw_rect(Rect2(r.end.x, r.position.y, 320 - r.end.x, r.size.y), sombra)
	# Esquinas de visor de cámara: 2 px de grosor, claras con contorno oscuro.
	var l := 10.0
	var g := 2.0
	for esq in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var x: float = r.position.x if esq.x == 0 else r.end.x - g
		var y: float = r.position.y if esq.y == 0 else r.end.y - g
		var hx: float = r.position.x if esq.x == 0 else r.end.x - l
		var vy: float = r.position.y if esq.y == 0 else r.end.y - l
		var horiz := Rect2(hx, y, l, g)
		var vert := Rect2(x, vy, g, l)
		_rec.draw_rect(horiz.grow(1), oscuro)
		_rec.draw_rect(vert.grow(1), oscuro)
		_rec.draw_rect(horiz, claro)
		_rec.draw_rect(vert, claro)
	# Etiqueta REC con punto titilante, adentro de la esquina de arriba.
	# Si el botón REC del diálogo está prendido, no la dibujamos: con uno alcanza.
	if _badge_on:
		return
	var etiqueta := Rect2(r.position + Vector2(5, 5), Vector2(24, 9))
	_rec.draw_rect(etiqueta, oscuro)
	_rec.draw_circle(etiqueta.position + Vector2(5, 4.5), 2.5, rojo if _rec_titila else Color("6d3141"))
	_rec.draw_string(_fuente(), etiqueta.position + Vector2(9, 7), "REC", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, claro)


func _en_cuadro(obj: ObjetoInteractivo) -> bool:
	return _rec_visible and _cuadro_actual.has_point(obj.position + Vector2(0, -2))


# ---------- Ayudas ----------

func _sumar_miedo_primera_vez(obj: ObjetoInteractivo) -> void:
	if obj == $Props/Vale or obj == $Props/Puerta or state.perturbados.has(String(obj.name)):
		return
	state.perturbados.append(String(obj.name))
	Globals.aumentar_vela(MIEDO_PRIMER_SUSTO)


func _parpadear_nuna(termina_visible: bool) -> void:
	for i in 4:
		C.player.visible = not C.player.visible
		await get_tree().create_timer(0.07).timeout
	C.player.visible = termina_visible


func _flash() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 59
	add_child(capa)
	var blanco := ColorRect.new()
	blanco.color = Color.WHITE
	blanco.size = Vector2(320, 180)
	capa.add_child(blanco)
	for a in [1.0, 0.6, 0.3, 0.0]:
		blanco.color.a = a
		await get_tree().create_timer(0.08).timeout
	capa.queue_free()


func _brillar(nodo: CanvasItem) -> void:
	# Pista "mirá acá": el objeto vibra (antes brillaba; así no cambian los colores del pixel art).
	if nodo.has_method("vibrar_pista"):
		nodo.vibrar_pista()
	elif nodo.has_method("_sacudir"):
		nodo._sacudir()


func _texto_guia() -> String:
	if state.mision_completada:
		if not Globals.tiene_extra("delineador"):
			return "Antes de irte, llevate el delineador de la mesa de luz."
		return "¡Turno cumplido! Mirá la puerta para subir a la Gerencia."
	if state.vale_estado == "dormida" and not state.foto_subida:
		return "Vale se durmió en vivo. Poseé el teléfono del trípode."
	if _poseyendo:
		return "Estás adentro del aro. Tocá TRANSFORMAR (%d de 3)." % state.aro_forma
	if not state.sello_aro:
		if not $Props/Aro.nombrado:
			return "Vale está EN VIVO: solo cuenta lo que entra en el cuadro REC. Mirá lo que hay adentro."
		return "Sello 1: ¡POSEÉ el aro de luz! Ilumina todo el vivo."
	if not state.sello_espejo:
		if not $Props/Espejo.nombrado:
			return "Vale está frente al espejo. Mirá el espejo."
		return "Sello 2: APARECÉ en el espejo mientras Vale se mira."
	if not state.camara_girada:
		return "Sello 3: la cámara solo mira donde la apuntás. ¿Y el trípode?"
	return "La cámara mira el desorden. ¡Perturbá el placard! Que salga todo en cámara."


func _actualizar_guia() -> void:
	G.gui.ui.establecer_guia(_texto_guia())
	_actualizar_medio_sello()


## Medio sello (como en la 202): el casillero que sigue se llena hasta la mitad cuando el
## sello en curso está empezado. Aro: ya lo poseíste. Espejo: pasaste una ronda. Placard: la
## cámara ya mira el desorden.
func _actualizar_medio_sello() -> void:
	var medio := false
	if not state.sello_aro:
		medio = _poseyendo or state.aro_forma > 0
	elif not state.sello_espejo:
		medio = state.espejo_ronda > 0
	elif not state.sello_placard:
		medio = state.camara_girada
	G.gui.ui.mostrar_medios_sellos(Globals.sellos + 1 if medio else 0)


func _mostrar_contexto_seleccionado() -> void:
	if not _seleccion_es_valida():
		_cancelar_seleccion()
		return
	var obj := objeto_seleccionado
	var especial := _nombre_tercer_verbo(obj)
	G.gui.ui.mostrar_objeto(obj.nombre_visible(), true, obj.puede_agarrar, obj.puede_perturbar or not especial.is_empty())
	G.gui.ui.renombrar_accion(Globals.PERTURBAR, especial)
	G.gui.ui.establecer_acciones_habilitadas(not ocupado and not G.is_blocked)


func _cancelar_seleccion() -> void:
	objeto_seleccionado = null
	G.gui.ui.mostrar_exploracion()
	G.gui.ui.establecer_acciones_habilitadas(false)


# ---------- Animaciones de los objetos (si tienen tira de Aseprite) ----------

## Cambia la animación de reposo de un objeto animado (y la muestra ya, salvo mostrar = false).
func _reposo(obj: ObjetoInteractivo, nombre: StringName, mostrar := true) -> void:
	var a := obj as ObjetoAnimado
	if a != null and a.tiene_animacion(nombre):
		a.anim_reposo = nombre
		if mostrar:
			a.mostrar_reposo()


## Perturbar: si el objeto tiene animación de susto la reproduce; si no, tiembla.
func _reaccionar(obj: ObjetoInteractivo) -> void:
	var a := obj as ObjetoAnimado
	if a != null:
		a.reaccionar()
	else:
		obj._sacudir()


## El espejo se desfasa en rojo un ratito y vuelve a calibrar.
func _error_espejo(espejo: ObjetoInteractivo) -> void:
	var a := espejo as ObjetoAnimado
	if a == null or not a.reproducir(&"error"):
		return
	await get_tree().create_timer(0.36).timeout
	if is_instance_valid(a):
		a.mostrar_reposo()


func _decir(texto: String) -> void:
	if texto.is_empty():
		return
	var en_vivo := texto.begins_with("CHAT:") or (texto.begins_with("VALE") and _rec_visible)
	_mostrar_badge_rec(_hablando_telefono or en_vivo)
	await C.player.say(texto)
	_mostrar_badge_rec(false)


## Botón rojo «REC ●» arriba del diálogo: aparece cuando se habla del teléfono o del vivo.
func _mostrar_badge_rec(mostrar: bool) -> void:
	if Engine.is_editor_hint():
		return
	if not is_instance_valid(_badge_rec):
		if not mostrar:
			return
		_badge_rec = BadgeREC.new()
		_badge_rec.fuente = _fuente()
		add_child(_badge_rec)
	_badge_rec.visible = mostrar
	if _badge_on != mostrar:
		_badge_on = mostrar
		if is_instance_valid(_rec):
			_rec.queue_redraw()


class BadgeREC extends CanvasLayer:
	var fuente: Font
	var _dibujo := Node2D.new()
	var _titila := true

	func _init() -> void:
		layer = 55
		add_child(_dibujo)
		_dibujo.draw.connect(_dibujar)
		var t := Timer.new()
		t.wait_time = 0.5
		t.autostart = true
		t.timeout.connect(func():
			_titila = not _titila
			_dibujo.queue_redraw())
		add_child(t)

	func _dibujar() -> void:
		var r := Rect2(258, Ajustes.UI_HUD_TAMANO.y + 8, 40, 13)  # adentro del cuadro, sin tapar la esquina
		var rojo := Color("e32356")
		var oscuro := Color("221722")
		_dibujo.draw_rect(r.grow(1), oscuro)
		_dibujo.draw_rect(r, rojo)
		_dibujo.draw_rect(Rect2(r.position.x, r.end.y - 2, r.size.x, 2), Color("bd0d3c"))  # sombrita del botón
		_dibujo.draw_string(fuente, r.position + Vector2(5, 9), "REC", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("f1eee3"))
		var c := Vector2(r.end.x - 8, r.position.y + 6)
		_dibujo.draw_circle(c, 3.5, Color("f1eee3"))
		_dibujo.draw_circle(c, 2.0, rojo if _titila else Color("bd0d3c"))


# ---------- Juego de memoria del espejo (gray box) ----------

class PanelMemoria extends CanvasLayer:
	const NOMBRES := ["FILTRO", "LUZ", "CONTRASTE", "LIKE"]
	const COLORES := [Color("e32356"), Color("3687f1"), Color("f6b915"), Color("b5e1dc")]
	## Tira de 8 botones de 16x16: 4 apagados (gota, destello, medio círculo, carita) y 4 prendidos.
	const RUTA_BOTONES := "res://arte/objetos/botones_espejo.png"
	var _icono_off: Array = []
	var _icono_on: Array = []
	const NOTAS := [523.25, 659.25, 783.99, 1046.5]
	signal _tocado(indice: int)
	var cancelado := false
	var frase: Array = []
	var _botones: Array[Button] = []
	var _frase: Label
	var _estado: Label
	var _sonido: AudioStreamPlayer
	var _tonos: Array = []
	var _escuchando := false

	func _init() -> void:
		layer = 60
		var fondo := ColorRect.new()
		fondo.color = Color(0, 0, 0, 0.88)
		fondo.size = Vector2(320, 152)
		fondo.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(fondo)
		var orden := OrdenTrabajo.new()
		var tema: Theme = orden._crear_tema()
		orden.free()
		var titulo := _label("ESPEJO JUEZ · CALIBRANDO ROSTRO…", Color(1, 1, 1), tema)
		titulo.position = Vector2(0, 22)
		var tira: Texture2D = load(RUTA_BOTONES) if ResourceLoader.exists(RUTA_BOTONES) else null
		for i in 4:
			var b := Button.new()
			b.text = NOMBRES[i]
			b.theme = tema
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(74, 22)
			b.position = Vector2(6 + i * 77, 54)  # anchos para que CONTRASTE no pise a LIKE
			if tira:
				for prendido in [false, true]:
					var a := AtlasTexture.new()
					a.atlas = tira
					a.region = Rect2((i + (4 if prendido else 0)) * 16, 0, 16, 16)
					(_icono_on if prendido else _icono_off).append(a)
				b.icon = _icono_off[i]
			b.pressed.connect(func():
				if _escuchando:
					_tocar(i, true))
			add_child(b)
			_botones.append(b)
		_frase = _label("", Color(1, 0.9, 0.5), tema)
		_frase.position = Vector2(0, 92)
		_estado = _label("", Color(0.7, 0.7, 0.75), tema)
		_estado.position = Vector2(0, 110)
		var cerrar := Button.new()
		cerrar.text = "SALIR"
		cerrar.theme = tema
		cerrar.focus_mode = Control.FOCUS_NONE
		cerrar.position = Vector2(270, 130)
		for estado in ["normal", "hover", "pressed"]:  # margen para que no se corte la S
			var caja: StyleBox = tema.get_stylebox(estado, "Button").duplicate()
			caja.content_margin_left = 4
			caja.content_margin_right = 4
			cerrar.add_theme_stylebox_override(estado, caja)
		cerrar.pressed.connect(func():
			cancelado = true
			_tocado.emit(-1))
		add_child(cerrar)
		_sonido = AudioStreamPlayer.new()
		_sonido.bus = InterfazUI.bus_voces()
		add_child(_sonido)
		for f in NOTAS:
			_tonos.append(_tono(f))

	func _label(texto: String, color: Color, tema: Theme) -> Label:
		var l := Label.new()
		l.text = texto
		l.theme = tema
		l.size = Vector2(320, 12)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", color)
		add_child(l)
		return l

	## Muestra la frase con las palabras de las rondas acertadas; el resto, con guiones.
	func revelar(rondas: int) -> void:
		var partes: Array = []
		for i in frase.size():
			var t: String = frase[i]
			if i >= rondas:
				var oculto := ""
				for c in t:
					oculto += " " if c == " " else "_"
				t = oculto
			partes.append(t)
		_frase.text = " ".join(partes)

	func avisar(texto: String) -> void:
		_estado.text = texto

	## Muestra la secuencia y espera que el jugador la repita. true si acertó.
	func jugar(secuencia: Array) -> bool:
		avisar("Mirá y escuchá…")
		await get_tree().create_timer(0.6).timeout
		for i in secuencia:
			await _tocar(i, false)
			await get_tree().create_timer(0.15).timeout
		avisar("Tu turno: repetí la melodía.")
		_escuchando = true
		for esperado in secuencia:
			var tocado: int = await _tocado
			if cancelado or tocado != esperado:
				_escuchando = false
				return false
		_escuchando = false
		avisar("¡Bien!")
		return true

	func _tocar(i: int, del_jugador: bool) -> void:
		_sonido.stream = _tonos[i]
		_sonido.play()
		if _icono_on.size() == 4:
			_botones[i].icon = _icono_on[i]
		else:
			_botones[i].modulate = COLORES[i] * 1.6
		if del_jugador:
			_tocado.emit(i)
		await get_tree().create_timer(0.3).timeout
		if is_instance_valid(_botones[i]):
			_botones[i].modulate = Color.WHITE
			if _icono_off.size() == 4:
				_botones[i].icon = _icono_off[i]

	## Una nota cuadrada de chiptune, generada en el momento.
	static func _tono(frecuencia: float) -> AudioStreamWAV:
		var tasa := 22050
		var n := int(tasa * 0.25)
		var datos := PackedByteArray()
		datos.resize(n * 2)
		for k in n:
			var env := 1.0 - float(k) / n
			var v := 5000.0 * env * (1.0 if sin(TAU * frecuencia * k / tasa) >= 0.0 else -1.0)
			datos.encode_s16(k * 2, int(v))
		var s := AudioStreamWAV.new()
		s.format = AudioStreamWAV.FORMAT_16_BITS
		s.mix_rate = tasa
		s.stereo = false
		s.data = datos
		return s


# ---------- La Gran Máquina (gray box, solo para el vistazo) ----------

class MaquinaGrayBox extends Node2D:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 320, 180), Color(0.06, 0.04, 0.08))
		# La puerta entreabierta: solo se ve una franja del medio.
		draw_rect(Rect2(0, 0, 100, 152), Color(0.18, 0.12, 0.10))
		draw_rect(Rect2(220, 0, 100, 152), Color(0.18, 0.12, 0.10))
		var paso := int(_t * 6.0)  # cuadro a cuadro
		var bronce := Color(0.65, 0.50, 0.25)
		for i in 3:
			var c := Vector2(130 + i * 30, 50 + (i % 2) * 24)
			draw_circle(c, 12, bronce)
			draw_circle(c, 4, Color(0.06, 0.04, 0.08))
			var a := (paso + i * 2) * 0.5
			draw_line(c, c + Vector2(cos(a), sin(a)) * 12, Color(0.06, 0.04, 0.08), 2)
		draw_rect(Rect2(100, 100, 120, 4), Color(0.35, 0.30, 0.30))  # cinta
		for i in 4:  # frascos de bruma que entran (violeta) y velas que salen (amarillo)
			var x := 100 + ((paso * 4 + i * 30) % 120)
			draw_rect(Rect2(x, 92, 5, 8), Color(0.62, 0.48, 0.88))
			var x2 := 216 - ((paso * 4 + i * 30) % 120)
			draw_rect(Rect2(x2, 110, 3, 8), Color(1.0, 0.9, 0.5))
		for i in 3:  # fantasmas translúcidos empujando palancas
			var y := 126 + (1 if (paso + i) % 2 == 0 else 0)
			draw_rect(Rect2(112 + i * 36, y, 10, 14), Color(1, 1, 1, 0.25))
			draw_line(Vector2(122 + i * 36, y + 4), Vector2(128 + i * 36, y - 6 + (paso + i) % 3), Color(0.5, 0.5, 0.5), 1)
