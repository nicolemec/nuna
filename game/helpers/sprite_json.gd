class_name SpriteJson
## Arma SpriteFrames a partir de una hoja exportada por Aseprite (PNG + JSON).
## Acepta el JSON en formato "Hash" (frames como diccionario) o "Array".
## Respeta la duración de cada cuadro tal como viene del JSON.
##
## Uso:
##   SpriteJson.cargar("res://arte/viejo/viejo.json", "res://arte/viejo/viejo.png")
##       -> una animación por cada tag del JSON.
##   SpriteJson.cargar(json, png, {"flota_frente": [20, 21]})
##       -> animaciones elegidas a mano por rango de cuadros (útil cuando el JSON
##          repite nombres de tag, como pasa en nuna.json).


static func cargar(ruta_json: String, ruta_png: String, rangos: Dictionary = {}, sin_loop: Array = []) -> SpriteFrames:
	var textura: Texture2D = load(ruta_png)
	if textura == null:
		push_error("SpriteJson: no encontré la imagen " + ruta_png)
		return null
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta_json))
	if not datos is Dictionary or not datos.has("frames"):
		push_error("SpriteJson: no pude leer " + ruta_json)
		return null

	var cuadros: Array = cuadros_de(datos)
	var animaciones: Dictionary = rangos.duplicate()
	if animaciones.is_empty():
		for etiqueta: Dictionary in datos.get("meta", {}).get("frameTags", []):
			if animaciones.has(etiqueta.name):
				push_warning("SpriteJson: el tag '%s' está repetido en %s; uso el primero." % [etiqueta.name, ruta_json])
				continue
			animaciones[etiqueta.name] = [int(etiqueta.from), int(etiqueta.to)]

	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	for nombre_texto: String in animaciones:
		var rango: Array = animaciones[nombre_texto]
		var desde := int(rango[0])
		var hasta := int(rango[1])
		if desde < 0 or hasta >= cuadros.size() or desde > hasta:
			push_warning("SpriteJson: '%s' pide cuadros %d-%d y la hoja tiene %d" % [nombre_texto, desde, hasta, cuadros.size()])
			continue
		var nombre := StringName(nombre_texto)
		sf.add_animation(nombre)
		# Velocidad 1 cuadro por segundo: la duración relativa de cada cuadro queda en segundos.
		sf.set_animation_speed(nombre, 1.0)
		sf.set_animation_loop(nombre, not sin_loop.has(nombre_texto))
		for i in range(desde, hasta + 1):
			var cuadro: Dictionary = cuadros[i]
			var recorte := AtlasTexture.new()
			recorte.atlas = textura
			recorte.region = Rect2(cuadro.frame.x, cuadro.frame.y, cuadro.frame.w, cuadro.frame.h)
			sf.add_frame(nombre, recorte, maxf(float(cuadro.get("duration", 100)) / 1000.0, 0.01))
	return sf


## Devuelve los cuadros en orden (0, 1, 2…), sin importar el formato del JSON.
static func cuadros_de(datos: Dictionary) -> Array:
	var frames: Variant = datos.frames
	if frames is Array:
		return frames
	var lista: Array = (frames as Dictionary).values()
	lista.sort_custom(func (a: Dictionary, b: Dictionary) -> bool:
		return a.frame.y < b.frame.y if a.frame.y != b.frame.y else a.frame.x < b.frame.x)
	return lista
