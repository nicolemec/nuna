class_name VozNuna
extends Node
## Las "voces" de los personajes: no hablan, hacen un sonidito por sílaba (como un canal
## de consola de 8 bits). Un solo canal: cada sílaba corta a la anterior.
##
## NUNA: pip agudo y cortito; cada pip sale un poquito más agudo y el último sube más,
## como una preguntita.
## VIEJO: zumbido grave y largo, más lento; el tono va bajando, como alguien cansado.
## FANTASMA: grave pero apagado, tembloroso.
## CEREMONIA: una flauta solemne que sigue una melodía (el texto del teatro).
## Las voces con "chip" se generan con código (game/helpers/chip.gd): no dependen de archivos.
##
## Las líneas de Nuna no llevan prefijo. Las de otros personajes empiezan con "NOMBRE: ".
## Un personaje que no está en VOCES (LUMI, RAMÓN…) queda en silencio.
## Para cambiar un sonido, reemplazá el .wav por otro con el mismo nombre.

const VOCES := {
	"NUNA": {
		"wav": "res://audio/sfx/nuna_pip.wav",
		"pausa": 0.075,             # segundos entre sílaba y sílaba
		"pausa_puntuacion": 0.14,   # extra en comas, puntos y signos
		"maximo": 14,               # una línea larga no suena eterna
		"subida_por_silaba": 0.02,  # cuánto sube el tono en cada sílaba
		"subida_final": 0.08,       # y cuánto más en la última
		"volumen_db": -10.0,
	},
	"VIEJO": {
		"chip": "viejo",            # sonido hecho con código (Chip.voz_viejo)
		"pausa": 0.16,
		"pausa_puntuacion": 0.22,
		"maximo": 9,
		"subida_por_silaba": -0.012,  # va bajando
		"subida_final": -0.06,        # y cierra con un suspiro
		"volumen_db": -6.0,
	},
	"FANTASMA": {
		"chip": "fantasma",         # grave pero apagado
		"pausa": 0.2,
		"pausa_puntuacion": 0.3,
		"maximo": 8,
		"subida_por_silaba": -0.008,
		"subida_final": -0.05,
		"volumen_db": -4.0,
	},
	"CEREMONIA": {
		"chip": "ceremonia",        # flauta solemne: sigue una melodía en vez de subir
		"pausa": 0.17,
		"pausa_puntuacion": 0.25,
		"maximo": 16,
		"melodia": [1.0, 1.0, 1.335, 1.5, 1.335, 1.26, 1.335, 1.5, 2.0, 1.5],
		"volumen_db": -8.0,
	},
}

const VOCALES := "aeiouáéíóúü"
const PUNTUACION := ",.;:!?¡¿…"

var _reproductor: AudioStreamPlayer
var _sonidos := {}
## Cada línea nueva cancela las sílabas que quedaban de la anterior.
var _linea := 0


func _ready() -> void:
	_reproductor = AudioStreamPlayer.new()
	_reproductor.name = "Pip"
	_reproductor.max_polyphony = 1  # un canal: cada sílaba corta a la anterior
	add_child(_reproductor)
	for quien: String in VOCES:
		var voz: Dictionary = VOCES[quien]
		match voz.get("chip", ""):
			"viejo":
				_sonidos[quien] = Chip.voz_viejo()
			"fantasma":
				_sonidos[quien] = Chip.voz_fantasma()
			"ceremonia":
				_sonidos[quien] = Chip.voz_ceremonia()
			_:
				var ruta: String = voz.get("wav", "")
				if ResourceLoader.exists(ruta):
					_sonidos[quien] = load(ruta)
	print("Voces listas: ", ", ".join(PackedStringArray(_sonidos.keys())))


## Hace sonar una línea de diálogo con la voz de quien la dice.
func decir(texto: String) -> void:
	_linea += 1
	var mi_linea := _linea
	var quien := _quien_habla(texto)
	if not VOCES.has(quien) or not _sonidos.has(quien):
		return
	var voz: Dictionary = VOCES[quien]
	if quien != "NUNA":
		texto = texto.substr(texto.find(": ") + 2)
	var golpes := _golpes(texto, voz["pausa"], voz["pausa_puntuacion"])
	var total := mini(golpes.size(), voz["maximo"])
	_reproductor.stream = _sonidos[quien]
	_reproductor.volume_db = voz["volumen_db"]
	for i in total:
		if mi_linea != _linea or not is_inside_tree():
			return
		var tono := 1.0
		if voz.has("melodia"):
			var melodia: Array = voz["melodia"]
			tono = melodia[i % melodia.size()]
		else:
			tono = 1.0 + voz["subida_por_silaba"] * i
			if i == total - 1 and total > 1:
				tono += voz["subida_final"]
		_reproductor.pitch_scale = maxf(tono, 0.5)
		_reproductor.play()
		await get_tree().create_timer(golpes[i]).timeout


## Corta las sílabas (cuando el jugador pasa la línea con un clic).
func callar() -> void:
	_linea += 1


## "VIEJO: ¿Sí?" → "VIEJO". Sin prefijo en mayúsculas, es Nuna.
func _quien_habla(texto: String) -> String:
	var dos_puntos := texto.find(": ")
	if dos_puntos <= 0 or dos_puntos > 12:
		return "NUNA"
	var nombre := texto.substr(0, dos_puntos)
	if nombre == nombre.to_upper() and nombre != nombre.to_lower():
		return nombre
	return "NUNA"


## Una entrada por sílaba (grupo de vocales seguidas): cuánto esperar después de ese sonido.
func _golpes(texto: String, pausa: float, pausa_puntuacion: float) -> Array[float]:
	var golpes: Array[float] = []
	var en_vocal := false
	for letra in texto.to_lower():
		if VOCALES.contains(letra):
			if not en_vocal:
				golpes.append(pausa)
			en_vocal = true
			continue
		en_vocal = false
		if PUNTUACION.contains(letra) and not golpes.is_empty():
			golpes[golpes.size() - 1] = pausa + pausa_puntuacion
	# "Mmm…" o "...": sin vocales, igual suena una vez si hay letras.
	if golpes.is_empty() and texto.strip_edges().length() > 0 and texto.to_lower() != texto.to_upper():
		golpes.append(pausa)
	return golpes
