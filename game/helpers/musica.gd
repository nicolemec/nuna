class_name Musica
extends AudioStreamPlayer
## Música de fondo. Vive en la raíz del árbol, así sigue sonando al cambiar de sala.
## Uso: Musica.tocar(&"menu"), Musica.tocar(&"intro") o Musica.tocar(&"habitacion").
## Si la pista pedida ya suena, no se reinicia. Entre pistas distintas hace un fundido.
## Busca los archivos en audio/soundtrack y, si no están, en audio/sfx.
##
## Estética retro: la música y los efectos grabados (el grito) pasan por el bus "Retro",
## que baja la resolución del sonido (como un chip de 8 bits) y recorta los agudos.
## Los archivos no se modifican. Para escucharlos limpios, poné RETRO en false.
## Canales, como una consola de 4 voces: 1 música, 2 voz de Nuna, 3 efectos (timbre,
## grito), 4 ambiente. Cada uno suena de a una cosa por vez (un sonido nuevo corta al anterior).

## Las tomas grabadas con los patches de Pure Data (nuna_amb_*.pd).
## Para cambiar una canción, grabá otra toma y cambiá el nombre acá.
const PISTAS := {
	&"menu": "nuna_menu_toma_1.wav",                # menú de inicio
	&"intro": "nuna_intro_toma_1.wav",              # teatro, calle y recepción
	&"habitacion": "nuna_habitaciones_toma_1.wav",  # habitaciones del hotel
}
const CARPETAS := ["res://audio/soundtrack/", "res://audio/sfx/"]
const VOLUMEN_DB := -8.0
const SILENCIO_DB := -40.0
const FUNDIDO := 1.0
const RETRO := true
const BUS_RETRO := "Retro"
## Cuánto se "rompe" el sonido (0 = nada, 1 = mucho) y hasta qué frecuencia llegan los agudos.
const RETRO_INTENSIDAD := 0.25
const RETRO_AGUDOS_HZ := 7000.0

var pista_actual: StringName = &""
var _pendiente: StringName = &""
var _tween: Tween


static func tocar(pista: StringName) -> void:
	var arbol := Engine.get_main_loop() as SceneTree
	if arbol == null or Engine.is_editor_hint():
		return
	var musica := arbol.root.get_node_or_null("Musica") as Musica
	if musica == null:
		musica = Musica.new()
		musica.name = "Musica"
		musica._pendiente = pista
		# Diferido: puede llamarse desde el _ready de una escena.
		arbol.root.add_child.call_deferred(musica)
		return
	musica._cambiar(pista)


static func ruta_de(archivo: String) -> String:
	for carpeta: String in CARPETAS:
		if ResourceLoader.exists(carpeta + archivo):
			return carpeta + archivo
	return ""


## El bus por donde salen los sonidos grabados. Se crea la primera vez que se pide.
static func bus_retro() -> StringName:
	if not RETRO:
		return &"Master"
	var indice := AudioServer.get_bus_index(BUS_RETRO)
	if indice == -1:
		AudioServer.add_bus()
		indice = AudioServer.bus_count - 1
		AudioServer.set_bus_name(indice, BUS_RETRO)
		AudioServer.set_bus_send(indice, &"Master")
		var lofi := AudioEffectDistortion.new()
		lofi.mode = AudioEffectDistortion.MODE_LOFI
		lofi.drive = RETRO_INTENSIDAD
		lofi.post_gain = -2.0
		AudioServer.add_bus_effect(indice, lofi)
		var agudos := AudioEffectLowPassFilter.new()
		agudos.cutoff_hz = RETRO_AGUDOS_HZ
		AudioServer.add_bus_effect(indice, agudos)
	return StringName(BUS_RETRO)


func _ready() -> void:
	bus = bus_retro()
	process_mode = Node.PROCESS_MODE_ALWAYS
	volume_db = SILENCIO_DB
	if _pendiente != &"":
		_cambiar(_pendiente)


func _cambiar(pista: StringName) -> void:
	if pista == pista_actual and playing:
		return
	if not PISTAS.has(pista):
		push_warning("Musica: no hay una pista llamada '%s'." % pista)
		return
	var ruta := ruta_de(PISTAS[pista])
	if ruta.is_empty():
		push_warning("Musica: no encontré '%s' en audio/soundtrack ni en audio/sfx." % PISTAS[pista])
		return
	pista_actual = pista
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	if playing:
		_tween.tween_property(self, "volume_db", SILENCIO_DB, FUNDIDO * 0.6)
	_tween.tween_callback(_empezar.bind(ruta))
	_tween.tween_property(self, "volume_db", VOLUMEN_DB, FUNDIDO)


func _empezar(ruta: String) -> void:
	var cancion := load(ruta) as AudioStream
	if cancion == null:
		push_warning("Musica: no pude abrir '%s'." % ruta)
		return
	var mp3 := cancion as AudioStreamMP3
	if mp3 != null:
		mp3.loop = true
	var wav := cancion as AudioStreamWAV
	if wav != null:
		# Repetir la toma entera, de punta a punta.
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	stream = cancion
	play()
	print("Musica: sonando '%s' (bus %s)." % [ruta.get_file(), bus])
