class_name Ajustes
## Todos los valores del juego en un solo lugar.
## Para ajustar algo jugando, cámbialo aquí y vuelve a ejecutar (F5).

# --- Nuna: movimiento ---
const NUNA_VELOCIDAD: float = 70.0        # píxeles por segundo
const NUNA_DISTANCIA_LLEGADA: float = 1.0 # a menos de esto, consideramos que llegó
const NUNA_FLOTE_ALTURA: float = 1.0      # cuántos píxeles sube y baja al flotar
const NUNA_FLOTE_VELOCIDAD: float = 3.0   # qué tan rápido sube y baja

# ¿Hacia dónde mira Nuna en el dibujo de Lorena? true = derecha
const NUNA_SPRITE_MIRA_A_LA_DERECHA: bool = true

# --- Nuna: animaciones ---
# Son los nombres EXACTOS de las etiquetas de Aseprite.
# Si una etiqueta cambia de nombre, solo se cambia aquí.
const ANIM_QUIETO: StringName = &"cuerpo"
const ANIM_MOVIENDO: StringName = &"cuerpo"         # probar con &"mini salto"
const ANIM_INTERACTUAR: StringName = &"interacciones"
const ANIM_DORMIR: StringName = &"dormiditu"
# Animaciones que se reproducen una vez y se detienen (no se repiten).
const ANIMS_SIN_LOOP: Array = ["mini salto", "interacciones", "dormiditu"]

# --- Nuna: cómo cortar la tira nuna.png ---
const NUNA_FRAME_ANCHO: int = 24
const NUNA_FRAME_ALTO: int = 24
const NUNA_FPS: float = 10.0   # 100 ms por frame

# Etiquetas: "nombre": [primer frame, último frame]. El primer frame es el 0.
const NUNA_ETIQUETAS: Dictionary = {
	"cuerpo": [0, 7],
	"mini salto": [8, 13],
	"interacciones": [14, 21],
	"dormiditu": [22, 22],
}

# --- Habitación: zona donde Nuna puede flotar ---
const PISO_Y_MIN: float = 128.0   # lo más "al fondo" que puede ir
const PISO_Y_MAX: float = 148.0   # lo más "adelante" que puede ir
const LIMITE_X_MIN: float = 12.0
const LIMITE_X_MAX: float = 308.0
const UI_Y: float = 152.0         # desde aquí hacia abajo está la interfaz

## Corta una tira horizontal (PNG) en frames iguales y arma las animaciones
## a partir de un diccionario: {"nombre": [desde, hasta]}. No necesita JSON.
static func crear_desde_tira(ruta_png: String, ancho: int, alto: int, etiquetas: Dictionary, fps: float, sin_loop: Array = []) -> SpriteFrames:
	var textura: Texture2D = load(ruta_png)
	if textura == null:
		push_error("No encontré la imagen: " + ruta_png)
		return null

	var total: int = textura.get_width() / ancho   # 552 / 24 = 23 frames
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

		for i in range(desde, hasta + 1):
			var recorte := AtlasTexture.new()
			recorte.atlas = textura
			recorte.region = Rect2(i * ancho, 0, ancho, alto)
			sf.add_frame(nombre, recorte)

	return sf
