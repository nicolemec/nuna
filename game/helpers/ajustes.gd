class_name Ajustes
## Todos los valores del juego en un solo lugar.
## Para ajustar algo jugando, cámbialo aquí y vuelve a ejecutar (F5).

# --- Nuna: movimiento ---
const NUNA_VELOCIDAD: float = 70.0        # píxeles por segundo
const NUNA_DISTANCIA_LLEGADA: float = 1.0 # a menos de esto, consideramos que llegó
const NUNA_FLOTE_ALTURA: float = 1.5      # cuántos píxeles sube y baja al flotar
const NUNA_FLOTE_VELOCIDAD: float = 3.0   # qué tan rápido sube y baja
const NUNA_UMBRAL_ORIENTACION: float = 0.5
const NUNA_DORMIR_SEGUNDOS: float = 2.0

# ¿Hacia dónde mira Nuna en el dibujo de Lorena? true = derecha
const NUNA_SPRITE_MIRA_A_LA_DERECHA: bool = true

# --- Nuna: animaciones ---
const ANIM_FLOTA_FRENTE: StringName = &"flota_frente"
const ANIM_FLOTA_DERECHA: StringName = &"flota_derecha"
const ANIM_FLOTA_ESPALDA: StringName = &"flota_espalda"
const ANIM_MINI_SALTO: StringName = &"mini_salto_frente"
const ANIM_INTERACTUA_FRENTE: StringName = &"interactua_frente"
const ANIM_INTERACTUA_LATERAL: StringName = &"interactua_lateral"
# Estas animaciones se reproducen una vez.
const ANIMS_SIN_LOOP: Array = [
	"mini_salto_frente",
	"interactua_frente",
	"interactua_lateral",
]

# --- Nuna: cómo cortar la tira nuna.png ---
const NUNA_FRAME_ANCHO: int = 24
const NUNA_FRAME_ALTO: int = 24
const NUNA_FPS: float = 10.0

const NUNA_ETIQUETAS: Dictionary = {
	"flota_frente": [0, 1],
	"flota_derecha": [2, 4],
	"flota_espalda": [5, 6],
	"mini_salto_frente": [7, 10],
	"interactua_frente": [11, 13],
	"interactua_lateral": [14, 16],
	"flota_rapido": [17, 19],
}

# Duración exportada por cuadro, en milisegundos.
const NUNA_DURACIONES_MS: Dictionary = {
	"flota_frente": [250, 250],
	"flota_derecha": [180, 180, 180],
	"flota_espalda": [250, 250],
	"mini_salto_frente": [120, 120, 200, 200],
	"interactua_frente": [120, 120, 200],
	"interactua_lateral": [120, 100, 120],
	"flota_rapido": [150, 100, 150],
}

# --- Habitación: zona donde Nuna puede flotar ---
const PISO_Y_MIN: float = 128.0   # lo más "al fondo" que puede ir
const PISO_Y_MAX: float = 148.0   # lo más "adelante" que puede ir
const LIMITE_X_MIN: float = 12.0
const LIMITE_X_MAX: float = 308.0
const UI_Y: float = 152.0         # límite lógico actual; se conserva
const UI_HUD_POS: Vector2 = Vector2(0.0, 0.0)
const UI_HUD_TAMANO: Vector2 = Vector2(320.0, 36.0)
const UI_HUD_FONDO: Color = Color(0.02, 0.02, 0.025, 0.90)
const UI_HUD_FUENTE: int = 8
const UI_HUD_INVENTARIO_ETIQUETA_POS: Vector2 = Vector2(6.0, 3.0)
const UI_HUD_INVENTARIO_ETIQUETA_TAMANO: Vector2 = Vector2(98.0, 12.0)
const UI_HUD_INVENTARIO_POS: Vector2 = Vector2(6.0, 18.0)
const UI_HUD_INVENTARIO_TAMANO: Vector2 = Vector2(42.0, 12.0)
const UI_HUD_CASILLERO_TAMANO: Vector2 = Vector2(12.0, 12.0)
const UI_HUD_CASILLERO_SEPARACION: int = 3
const UI_HUD_SELLOS_ETIQUETA_POS: Vector2 = Vector2(108.0, 3.0)
const UI_HUD_SELLOS_ETIQUETA_TAMANO: Vector2 = Vector2(66.0, 12.0)
const UI_HUD_SELLOS_POS: Vector2 = Vector2(108.0, 19.0)
const UI_HUD_SELLOS_TAMANO: Vector2 = Vector2(35.0, 9.0)
const UI_HUD_SELLO_TAMANO: Vector2 = Vector2(9.0, 9.0)
const UI_HUD_BORDE_SELLO: float = 1.0
const UI_HUD_SELLO_SEPARACION: int = 4
const UI_HUD_BRUMA_ETIQUETA_POS: Vector2 = Vector2(180.0, 3.0)
const UI_HUD_BRUMA_ETIQUETA_TAMANO: Vector2 = Vector2(46.0, 12.0)
const UI_HUD_BRUMA_POS: Vector2 = Vector2(229.0, 5.0)
const UI_HUD_MIEDO_ETIQUETA_POS: Vector2 = Vector2(180.0, 20.0)
const UI_HUD_MIEDO_ETIQUETA_TAMANO: Vector2 = Vector2(46.0, 12.0)
const UI_HUD_MIEDO_POS: Vector2 = Vector2(229.0, 22.0)
const UI_HUD_BARRA_TAMANO: Vector2 = Vector2(84.0, 7.0)
const UI_HUD_TEXTO_HOVER_MIEDO: String = "Vela: se enciende con miedo y quema tu tiempo"
const UI_FUENTE_HUD: String = "res://arte/fuentes/Tiny5-Regular.ttf"
const UI_FUENTE_DIALOGO: String = "res://arte/fuentes/monogram-extended.ttf"  # más legible y con tildes bien ubicadas
const UI_CONSOLA_DIALOGO_FUENTE: int = 16  # Monogram se ve nítida en múltiplos de 16
const UI_FUENTE_FALLBACK: String = "res://arte/fuentes/monogram-extended.ttf"
const UI_CONSOLA_COMPACTA_POS: Vector2 = Vector2(0.0, 166.0)
const UI_CONSOLA_COMPACTA_TAMANO: Vector2 = Vector2(320.0, 14.0)
const UI_CONSOLA_EXPANDIDA_POS: Vector2 = Vector2(0.0, 148.0)
const UI_CONSOLA_EXPANDIDA_TAMANO: Vector2 = Vector2(320.0, 32.0)
const UI_CONSOLA_TEXTO_POS: Vector2 = Vector2(5.0, 2.0)
const UI_CONSOLA_TEXTO_TAMANO: Vector2 = Vector2(310.0, 17.0)
const UI_CONSOLA_TEXTO_COMPACTO_TAMANO: Vector2 = Vector2(310.0, 10.0)
const UI_CONSOLA_OPCIONES_POS: Vector2 = Vector2(5.0, 20.0)
const UI_CONSOLA_OPCIONES_TAMANO: Vector2 = Vector2(310.0, 11.0)
const UI_CONSOLA_LETRA_CHICA_POS: Vector2 = Vector2(5.0, 20.0)  # debajo de la línea grande, donde van los verbos
const UI_CONSOLA_LETRA_CHICA_TAMANO: Vector2 = Vector2(310.0, 8.0)
const UI_CONSOLA_FUENTE: int = 8
const UI_CONSOLA_LETRA_CHICA_FUENTE: int = 8  # Tiny5 se ve nítida en 8; en 7 se borroneaba
const UI_CONSOLA_DURACION_CERTIFICACION_MIN_SEGUNDOS: float = 3.0
const UI_CONSOLA_BORDE_SUPERIOR_ALTO: float = 1.0
const UI_CONSOLA_ACCION_ANCHO: float = 98.0
const UI_CONSOLA_ACCION_PREFIJO_ANCHO: float = 8.0
const UI_CONSOLA_SEPARACION_ACCIONES: float = 4.0
const UI_CONSOLA_SEPARACION_CONTENIDO_ACCION: float = 3.0

# --- Lumi: prueba de certificación ---
const LUMI_COSTO_PERTURBAR_BRUMA: float = 5.0
const LUMI_RECOMPENSA_BRUMA_NIVEL: float = 10.0
const LUMI_RECOMPENSA_VELA_NIVEL: float = 10.0
const LUMI_RECOMPENSA_VELA_FOGONAZO: float = 25.0
const LUMI_COSTO_BRUMA_FOGONAZO: float = 10.0
const LUMI_BLOQUEO_CLICS_SEGUNDOS: float = 1.5
const LUMI_DURACION_QUEMADA_SEGUNDOS: float = 20.0
const LUMI_HABITACION_ID: StringName = &"habitacion_101"
const VELA_MAXIMA: float = 100.0
const BRUMA_RECOMPENSA_SELLO: float = 10.0
const BRUMA_GOTEO_INTERVALO_SEGUNDOS: float = 5.0
const BRUMA_GOTEO_CANTIDAD: float = 1.0
const LUMI_RUTA_TIRA: String = "res://arte/objetos/lampara_base.png"
const LUMI_FRAME_ANCHO: int = 25
const LUMI_FRAME_ALTO: int = 30
const LUMI_FPS_BASE: float = 10.0
const LUMI_FPS_SUBE: float = 8.33
const LUMI_FPS_NIVEL_3: float = 2.86
const LUMI_FPS_FOGONAZO: float = 10.0
const LUMI_FPS_QUEMADA: float = 6.67
const LUMI_SPRITE_OFFSET: Vector2 = Vector2(0.5, -6.0)
const LUMI_ETIQUETAS: Dictionary = {
	"apagada": [0, 0],
	"sube": [1, 4],
	"nivel_1": [5, 5],
	"nivel_2": [6, 6],
	"nivel_3": [7, 8],
	"cuidada": [9, 9],
	"fogonazo": [10, 14],
	"quemada": [15, 17],
}
const LUMI_ANIMACIONES_SIN_LOOP: Array = ["sube", "fogonazo", "quemada"]
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
