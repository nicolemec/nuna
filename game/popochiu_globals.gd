extends Node

signal progreso_cambiado
signal sellos_cambiados(cantidad: int)
signal bruma_cambiada(valor: float)
signal vela_cambiada(habitacion: StringName, valor: float)
signal inventario_cambiado
## La bruma llegó a cero: la interfaz ofrece el crédito de Din (nunca se pierde).
signal sin_bruma

const MIRAR := &"mirar"
const AGARRAR := &"agarrar"
const PERTURBAR := &"perturbar"
const SELLOS_TOTALES := 3
const NOMBRES_VERBOS := {MIRAR: "Mirar", AGARRAR: "Agarrar", PERTURBAR: "Perturbar"}
## Cosas que Nuna lleva y que no son objetos de Popochiu (no se usan sobre el cuarto,
## pero se pueden mirar en el inventario). El cuaderno siempre va primero.
const EXTRAS := {
	"cuaderno": {"nombre": "Cuaderno", "textura": "res://arte/objetos/cuaderno.png",
		"mirar": "Mi cuaderno de certificación. Acá anoto todo lo que aprendo… y lo que no."},
	"llave_101": {"nombre": "Llave 101", "textura": "res://arte/objetos/llave_101.png",
		"mirar": "La llave de la 101. Si la pierdo, se descuenta de mi Bruma."},
	"llave_202": {"nombre": "Llave 202", "textura": "res://arte/objetos/llave_202.png",
		"mirar": "La llave de la 202. Un muchacho que no duerme mucho."},
	"ratoncito": {"nombre": "Ratoncito Inquieto", "textura": "res://arte/objetos/ratoncito_202_icono.png",
		"mirar": "Mueve el mouse solo para que parezca que alguien trabaja. Como yo, pero a pilas."},
	"delineador": {"nombre": "Delineador", "textura": "res://arte/objetos/delineador_icono.png",
		"mirar": "El delineador de Vale. Sirve para remarcar lo que uno quiere que se vea."},
	"flacozem": {"nombre": "FLACOZEM™", "textura": "res://arte/objetos/flacozem_icono.png",
		"mirar": "FLACOZEM™: «¡Hace desaparecer lo que sobra!». Lo guardo yo, así no lo encuentra Vale."},
}
## Crédito de Bruma: cuánto presta Din y cuánto hay que devolver.
const CREDITO_MONTO := 40.0
const CREDITO_DEVOLUCION := 60.0
## De cada sello, cuánta bruma se va a pagar la deuda.
const CUOTA_POR_SELLO := 5.0
## Por debajo de esta bruma Nuna se empieza a ver transparente.
const BRUMA_OPACA := 40.0
const ALFA_MINIMO := 0.35

var sellos := 0
var sellos_obtenidos: Array = []
var bruma := 50.0
var vela_101 := 0.0
var goteo_iniciado := false
var pausado := false
var segundos_goteo := 0.0
## Llaves, el Ratoncito y otras cosas que no son objetos de Popochiu.
var extras: Array = []
## Extra que Nuna tiene "en la mano" (USAR desde el inventario). Vacío = ninguno.
var extra_activo: String = ""
## Lo que se debe del Crédito de Bruma, y cuántos créditos se pidieron.
var deuda := 0.0
var creditos := 0
## Certificaciones y notas del cuaderno (la última, al final).
var notas: Array = []
var _credito_en_curso := false
var _pausa_antes_credito := false



func _ready() -> void:
	# El cursor de Popochiu se reemplaza cuando todos los autoloads están listos.
	_aplicar_cursor.call_deferred()


func _aplicar_cursor() -> void:
	CursorPixel.aplicar()

func _process(delta: float) -> void:
	_actualizar_alfa_nuna(delta)
	if not goteo_iniciado or pausado:
		return
	segundos_goteo += delta
	while segundos_goteo >= 5.0:
		segundos_goteo -= 5.0
		cambiar_bruma(-1.0)


func cambiar_bruma(cantidad: float) -> void:
	bruma = clampf(bruma + cantidad, 0.0, 100.0)
	bruma_cambiada.emit(bruma)
	progreso_cambiado.emit()
	if bruma <= 0.0 and goteo_iniciado and not _credito_en_curso:
		_ofrecer_credito.call_deferred()


# ---------- Bruma: transparencia y crédito ----------

## Con poca bruma Nuna se ve más transparente (no se pierde: se desvanece de a poco).
## Usa self_modulate del dibujo, así no pisa los fundidos de las salas (modulate).
func _actualizar_alfa_nuna(delta: float) -> void:
	if not is_instance_valid(C.player):
		return
	var dibujo := C.player.get_node_or_null("AnimatedSprite2D") as CanvasItem
	if dibujo == null:
		return
	var objetivo := 1.0
	if goteo_iniciado:
		objetivo = lerpf(ALFA_MINIMO, 1.0, clampf(bruma / BRUMA_OPACA, 0.0, 1.0))
	dibujo.self_modulate.a = move_toward(dibujo.self_modulate.a, objetivo, delta * 0.8)


## Sin bruma: Din ofrece un crédito. Si no hay interfaz que lo muestre, se toma solo.
func _ofrecer_credito() -> void:
	if _credito_en_curso or bruma > 0.0:
		return
	_credito_en_curso = true
	_pausa_antes_credito = pausado
	pausado = true
	if sin_bruma.get_connections().is_empty():
		tomar_credito()
	else:
		sin_bruma.emit()


func tomar_credito() -> void:
	deuda += CREDITO_DEVOLUCION
	creditos += 1
	_credito_en_curso = false
	pausado = _pausa_antes_credito
	cambiar_bruma(CREDITO_MONTO)


func anotar(nota: String) -> void:
	if nota.is_empty() or (not notas.is_empty() and notas[-1] == nota):
		return
	notas.append(nota)


# ---------- Extras del inventario ----------

func agregar_extra(id: String) -> void:
	if not extras.has(id):
		extras.append(id)
		inventario_cambiado.emit()


func quitar_extra(id: String) -> void:
	if extras.has(id):
		extras.erase(id)
		inventario_cambiado.emit()


func tiene_extra(id: String) -> bool:
	return extras.has(id)


func es_extra(id: StringName) -> bool:
	return EXTRAS.has(String(id))


## Todo lo que se ve en el inventario: el cuaderno, los objetos de Popochiu y los extras.
func inventario_visible() -> Array:
	var lista: Array = ["cuaderno"]
	lista.append_array(obtener_inventario())
	for id in extras:
		if not lista.has(id):
			lista.append(id)
	return lista


func frase_mirar_extra(id: StringName) -> String:
	return EXTRAS.get(String(id), {}).get("mirar", "")


func aumentar_vela(habitacion_o_cantidad: Variant, cantidad: float = NAN) -> void:
	var aumento: float = float(habitacion_o_cantidad) if is_nan(cantidad) else cantidad
	vela_101 = clampf(vela_101 + aumento, 0.0, 100.0)
	vela_cambiada.emit(Ajustes.LUMI_HABITACION_ID, vela_101)
	progreso_cambiado.emit()


func vela_de(_habitacion: StringName) -> float:
	return vela_101


func llenar_vela(habitacion: StringName) -> void:
	aumentar_vela(habitacion, 100.0)


func iniciar_goteo() -> void:
	goteo_iniciado = true


func otorgar_sello(id: StringName) -> bool:
	if sellos_obtenidos.has(String(id)) or sellos >= SELLOS_TOTALES:
		return false
	sellos_obtenidos.append(String(id))
	sellos += 1
	# Parte de la bruma del sello se va a pagar el crédito (si hay deuda).
	var cuota: float = minf(deuda, CUOTA_POR_SELLO)
	deuda -= cuota
	cambiar_bruma(10.0 - cuota)
	sellos_cambiados.emit(sellos)
	return true


func obtener_inventario() -> Array:
	if not is_instance_valid(C.player):
		return []
	return C.player.inventory.keys().map(func (id: String): return id.to_lower())


func nombre_objeto(id: StringName) -> String:
	if EXTRAS.has(String(id)):
		return EXTRAS[String(id)].nombre
	return I.get_item_instance(String(id).to_pascal_case()).description


func tiene(id: StringName) -> bool:
	return is_instance_valid(C.player) and C.player.inventory.has(String(id).to_pascal_case())


func quitar_objeto(id: StringName) -> void:
	if tiene(id):
		await I.get_item_instance(String(id).to_pascal_case()).remove()


func reiniciar() -> void:
	I.clean_inventory_bg()
	sellos = 0
	sellos_obtenidos.clear()
	bruma = 50.0
	vela_101 = 0.0
	goteo_iniciado = false
	pausado = false
	segundos_goteo = 0.0
	extras.clear()
	deuda = 0.0
	creditos = 0
	notas.clear()
	_credito_en_curso = false
	# Reset cached data in place: scene scripts retain references to these resources.
	for paths in [PopochiuResources.get_section("rooms"), PopochiuResources.get_section("characters"), PopochiuResources.get_section("inventory_items")]:
		for path in paths:
			var cached: Resource = load(path)
			var defaults: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			for property in defaults.get_property_list():
				if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.name not in ["visited", "visited_first_time", "in_inventory"]:
					var value: Variant = defaults.get(property.name)
					if value is Array or value is Dictionary:
						value = value.duplicate(true)
					cached.set(property.name, value)
	R.rooms_states.clear()
	for path in PopochiuResources.get_section("rooms"):
		var room_data: PopochiuRoomData = load(path)
		R.rooms_states[room_data.script_name] = room_data
	C.characters_states.clear()
	I.items_states.clear()
	for path in PopochiuResources.get_section("inventory_items"):
		var data: PopochiuInventoryItemData = load(path)
		var item: Variant = I.get_item_instance(data.script_name)
		item.quantity_owned = 0
		item.reiniciar_coleccion()
	E.loaded_game = {}
	G.gui.actualizar_progreso()
	inventario_cambiado.emit()