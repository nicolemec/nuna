extends RefCounted
## Validación previa: el lector Popochiu presupone JSON y estados bien formados.


static func completar_carga_desde_menu(_datos: Dictionary) -> void:
	G.load_feedback_finished.emit.call_deferred()


## API para menú y GUI: devuelve {error: String, scene: String} sin restaurar estados.
## Si error está vacío, la GUI en una habitación puede ejecutar E.load_game(slot).
static func leer_slot(slot: int) -> Dictionary:
	var ruta := PopochiuSaveLoad.SAVE_GAME_PATH % slot
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return {"error": "No se encontró la partida guardada.", "scene": ""}
	var json := JSON.new()
	if json.parse(archivo.get_as_text()) != OK:
		return {"error": "La partida guardada está dañada.", "scene": ""}
	var error := validar(json.data)
	if not error.is_empty():
		return {"error": error, "scene": ""}
	var estado: PopochiuRoomData = load(PopochiuResources.get_data_value("rooms", json.data.player.room, ""))
	return {"error": "", "scene": estado.scene}


## Devuelve "" para JSON nativo compatible; las secciones vacías son opcionales.
## Los arrays packed del motor se representan como Array al leer JSON.
static func validar(datos: Variant) -> String:
	var invalida := "La partida guardada no es compatible."
	if not datos is Dictionary or not datos.get("player") is Dictionary:
		return invalida
	var jugador: Dictionary = datos.player
	if not jugador.get("room") is String or not jugador.get("id") is String:
		return invalida
	if not jugador.get("position") is Dictionary:
		return invalida
	if not _numero(jugador.position.get("x")) or not _numero(jugador.position.get("y")):
		return invalida
	var sala := PopochiuResources.get_data_value("rooms", jugador.room, "") as String
	var personaje := PopochiuResources.get_data_value("characters", jugador.id, "") as String
	if sala.is_empty() or personaje.is_empty():
		return invalida
	var estado: PopochiuRoomData = load(sala)
	if not ResourceLoader.exists(estado.scene, "PackedScene"):
		return "La habitación guardada no está disponible."
	for seccion in ["rooms", "characters", "inventory_items", "dialogs"]:
		if not datos.has(seccion):
			continue
		if not datos[seccion] is Dictionary:
			return invalida
		for id: String in datos[seccion]:
			var ruta: String = PopochiuResources.get_data_value(seccion, id, "")
			if ruta.is_empty() or not datos[seccion][id] is Dictionary:
				return invalida
			var recurso: Resource = load(ruta)
			var propiedades: Dictionary = datos[seccion][id].duplicate()
			if seccion == "dialogs":
				if not _dialogo_valido(recurso, propiedades.get("options")):
					return invalida
				propiedades.erase("options")
			if not _propiedades_validas(recurso, propiedades):
				return invalida
			if seccion == "rooms" and not _sala_valida(datos[seccion][id], recurso):
				return invalida
	if datos.has("globals"):
		if not datos.globals is Dictionary or not _propiedades_validas(Globals, datos.globals, true):
			return invalida
	if not _inventario_valido(jugador.get("inventory", [])):
		return invalida
	if datos.has("character_inventories"):
		if not datos.character_inventories is Dictionary:
			return invalida
		for id: String in datos.character_inventories:
			if PopochiuResources.get_data_value("characters", id, "").is_empty():
				return invalida
			if not _inventario_valido(datos.character_inventories[id]):
				return invalida
	return ""


static func _propiedades_validas(objeto: Object, valores: Dictionary, permitir_desconocidas := false) -> bool:
	var propiedades := {}
	for propiedad: Dictionary in objeto.get_property_list():
		propiedades[propiedad.name] = propiedad
	for nombre: String in valores:
		if nombre in ["script", "resource_path", "resource_name"]:
			return false
		if objeto is Resource and nombre in ["scene", "script_name"]:
			return false
		if nombre == "custom_data":
			if not valores[nombre] is Dictionary:
				return false
			if objeto.has_method("on_save"):
				var modelo: Variant = objeto.call("on_save")
				if modelo is Dictionary and not _forma_valida(valores[nombre], modelo):
					return false
			continue
		if not propiedades.has(nombre):
			if permitir_desconocidas:
				continue
			return false
		var tipo: int = propiedades[nombre].type
		var valor: Variant = valores[nombre]
		if tipo in [TYPE_INT, TYPE_FLOAT]:
			if not _numero(valor):
				return false
		elif tipo == TYPE_STRING_NAME:
			if not valor is String:
				return false
		elif tipo in [TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY]:
			if not valor is Array:
				return false
			for entrada in valor:
				if tipo == TYPE_PACKED_STRING_ARRAY:
					if not entrada is String:
						return false
				elif not _numero(entrada):
					return false
		elif typeof(valor) != tipo:
			return false
		if tipo == TYPE_ARRAY:
			var original: Array = objeto.get(nombre)
			if original.is_typed():
				for entrada in valor:
					if original.get_typed_builtin() in [TYPE_INT, TYPE_FLOAT]:
						if not _numero(entrada):
							return false
					elif typeof(entrada) != original.get_typed_builtin():
						return false
	return true


static func _sala_valida(sala: Dictionary, original: PopochiuRoomData) -> bool:
	for categoria in PopochiuResources.ROOM_CHILDREN + ["characters"]:
		if not sala.has(categoria):
			continue
		if not sala[categoria] is Dictionary:
			return false
		for id: String in sala[categoria]:
			if not sala[categoria][id] is Dictionary:
				return false
			var modelos: Dictionary = original.get(categoria)
			if modelos.has(id) and not _forma_valida(sala[categoria][id], modelos[id]):
				return false
	if sala.has("characters"):
		for id: String in sala.characters:
			if PopochiuResources.get_data_value("characters", id, "").is_empty():
				return false
			var personaje: Dictionary = sala.characters[id]
			for clave in ["x", "y", "facing", "light_mask", "baseline"]:
				if not _numero(personaje.get(clave)):
					return false
			if not personaje.get("visible") is bool:
				return false
			for clave in ["modulate", "self_modulate"]:
				if not personaje.get(clave) is String:
					return false
			for clave in ["walk_to_point", "look_at_point", "dialog_pos", "follow_character_offset"]:
				if personaje.has(clave):
					if not personaje[clave] is Dictionary:
						return false
					if not _numero(personaje[clave].get("x")) or not _numero(personaje[clave].get("y")):
						return false
	return true


static func _inventario_valido(entradas: Variant) -> bool:
	if not entradas is Array:
		return false
	for entrada in entradas:
		var nombre: Variant = entrada if entrada is String else entrada.get("name") if entrada is Dictionary else null
		if not nombre is String or PopochiuResources.get_data_value("inventory_items", nombre, "").is_empty():
			return false
		if entrada is Dictionary and (not _numero(entrada.get("qty", 1)) or entrada.get("qty", 1) <= 0):
			return false
	return true


static func _dialogo_valido(dialogo: PopochiuDialog, opciones: Variant) -> bool:
	if not opciones is Dictionary:
		return false
	for id: String in opciones:
		var encontrada := false
		for opcion: PopochiuDialogOption in dialogo.options:
			if opcion.id == id:
				if not opciones[id] is Dictionary or not _propiedades_validas(opcion, opciones[id]):
					return false
				encontrada = true
				break
		if not encontrada:
			return false
	return true


static func _forma_valida(valor: Variant, modelo: Variant) -> bool:
	if modelo is int or modelo is float:
		return _numero(valor)
	if typeof(valor) != typeof(modelo):
		return false
	if modelo is Dictionary:
		for clave: String in valor:
			if modelo.has(clave) and not _forma_valida(valor[clave], modelo[clave]):
				return false
	return true


static func _numero(valor: Variant) -> bool:
	return (valor is int or valor is float) and is_finite(float(valor))
