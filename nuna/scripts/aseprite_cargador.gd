class_name AsepriteCargador
## Arma las animaciones de un sprite a partir de una tira horizontal (PNG).


## Corta una tira horizontal en frames iguales y arma las animaciones
## a partir de un diccionario: {"nombre": [desde, hasta]}.
static func crear_desde_tira(ruta_png: String, ancho: int, alto: int, etiquetas: Dictionary, fps: float, sin_loop: Array = [], duraciones_ms: Dictionary = {}) -> SpriteFrames:
	var textura: Texture2D = load(ruta_png)
	if textura == null:
		push_error("No encontré la imagen: " + ruta_png)
		return null

	var total: int = textura.get_width() / ancho
	print("La tira tiene %d frames de %dx%d" % [total, ancho, alto])

	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")

	for nombre_texto in etiquetas.keys():
		var rango: Array = etiquetas[nombre_texto]
		var desde: int = int(rango[0])
		var hasta: int = int(rango[1])
		if desde < 0 or hasta >= total or desde > hasta:
			push_warning("La etiqueta '%s' pide frames %d-%d, pero la tira va de 0 a %d" % [nombre_texto, desde, hasta, total - 1])
			continue

		var nombre := StringName(nombre_texto)
		sf.add_animation(nombre)
		sf.set_animation_speed(nombre, fps)
		sf.set_animation_loop(nombre, not sin_loop.has(String(nombre_texto)))

		var duraciones_tag: Variant = duraciones_ms.get(nombre_texto, [])
		if typeof(duraciones_tag) != TYPE_ARRAY:
			push_warning("La etiqueta '%s' no tiene una lista de duraciones; se usará la duración base" % nombre_texto)
			duraciones_tag = []
		if not duraciones_tag.is_empty() and duraciones_tag.size() != hasta - desde + 1:
			push_warning("La etiqueta '%s' no tiene una duración por cada cuadro; se usará la duración base" % nombre_texto)
			duraciones_tag = []

		for i in range(desde, hasta + 1):
			var recorte := AtlasTexture.new()
			recorte.atlas = textura
			recorte.region = Rect2(i * ancho, 0, ancho, alto)
			var duracion_relativa: float = 1.0
			var indice_duracion: int = i - desde
			if not duraciones_tag.is_empty():
				var duracion_ms: Variant = duraciones_tag[indice_duracion]
				if (typeof(duracion_ms) == TYPE_INT or typeof(duracion_ms) == TYPE_FLOAT) and is_finite(float(duracion_ms)) and float(duracion_ms) > 0.0:
					duracion_relativa = maxf(float(duracion_ms) * fps / 1000.0, 0.01)
			sf.add_frame(nombre, recorte, duracion_relativa)

	return sf
