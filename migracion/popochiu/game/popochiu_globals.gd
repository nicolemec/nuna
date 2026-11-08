extends Node

signal progreso_cambiado
signal sellos_cambiados(cantidad: int)
signal bruma_cambiada(valor: float)
signal vela_cambiada(habitacion: StringName, valor: float)
signal inventario_cambiado

const MIRAR := &"mirar"
const AGARRAR := &"agarrar"
const PERTURBAR := &"perturbar"
const SELLOS_TOTALES := 3
const NOMBRES_VERBOS := {MIRAR: "Mirar", AGARRAR: "Agarrar", PERTURBAR: "Perturbar"}

var sellos := 0
var sellos_obtenidos: Array = []
var bruma := 50.0
var vela_101 := 0.0
var goteo_iniciado := false
var pausado := false
var segundos_goteo := 0.0


func _process(delta: float) -> void:
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
	cambiar_bruma(10.0)
	sellos_cambiados.emit(sellos)
	return true


func obtener_inventario() -> Array:
	if not is_instance_valid(C.player):
		return []
	return C.player.inventory.keys().map(func (id: String): return id.to_lower())


func nombre_objeto(id: StringName) -> String:
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