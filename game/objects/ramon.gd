class_name Ramon
extends ObjetoInteractivo

const RUTA_TIRA: String = "res://arte/objetos/radio-anim.png"
const FRAME_ANCHO: int = 30
const FRAME_ALTO: int = 50
const FPS_BASE: float = 10.0
const ANIM_QUIETO: StringName = &"quieto"
const ANIM_SINTONIZANDO: StringName = &"sintonizando"
const ANIM_SONANDO: StringName = &"sonando"
const ETIQUETAS: Dictionary = {
	"quieto": [0, 0],
	"sintonizando": [1, 2],
	"sonando": [3, 5],
}
const DURACIONES_MS: Dictionary = {
	"quieto": [100],
	"sintonizando": [300, 300],
	"sonando": [150, 100, 150],
}
const ANIMACIONES_SIN_LOOP: Array = ["sintonizando"]

signal comenzo_a_sonar

## Volumen de la canción al revés: fuerte al sintonizar y después de fondo, bajo la música.
const VOLUMEN_CANCION_DB := -6.0
const VOLUMEN_CANCION_FONDO_DB := -20.0
const SEGUNDOS_ANTES_DE_BAJAR := 7.0
const VOLUMEN_PARLANTE_DB := -6.0

var _anim_sprite: AnimatedSprite2D
var _sintonizando: bool = false
## Sonidos hechos con código (Chip): no hay archivos de audio para la radio.
var _parlante: AudioStreamPlayer   # estática y estaciones
var _cancion: AudioStreamPlayer    # Radio Revés, en loop
var _fundido: Tween
var _tarea_cancion := -1


func _ready() -> void:
	super._ready()
	_parlante = _crear_reproductor("Parlante", VOLUMEN_PARLANTE_DB)
	_cancion = _crear_reproductor("Cancion", VOLUMEN_CANCION_DB)
	# La canción al revés se arma en segundo plano para que no trabe el juego al sonar.
	if not Chip.cancion_reves_lista():
		_tarea_cancion = WorkerThreadPool.add_task(func (): Chip.radio_reves())
		tree_exiting.connect(_esperar_cancion)
	_anim_sprite = AnimatedSprite2D.new()
	_anim_sprite.name = "Sprite"
	_anim_sprite.centered = false
	_anim_sprite.position = Vector2(-floorf(tamano.x / 2.0), -tamano.y)
	_anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anim_sprite.visible = false
	add_child(_anim_sprite)
	queue_redraw()

	_anim_sprite.sprite_frames = AsepriteCargador.crear_desde_tira(
		RUTA_TIRA,
		FRAME_ANCHO,
		FRAME_ALTO,
		ETIQUETAS,
		FPS_BASE,
		ANIMACIONES_SIN_LOOP,
		DURACIONES_MS
	)
	if _anim_sprite.sprite_frames == null:
		push_error("No se pudieron crear las animaciones de Ramón.")
	else:
		perturbado.connect(_al_perturbar)
	mostrar_quieto()


func _draw() -> void:
	if _anim_sprite == null or not _anim_sprite.visible:
		super._draw()


func mostrar_quieto() -> void:
	_sintonizando = false
	_reproducir_animacion(ANIM_QUIETO)
	if _cancion != null:
		_cancion.stop()


## Ruido de dial entre estación y estación.
func estatica() -> void:
	_parlante.stream = Chip.radio_estatica()
	_parlante.play()


## Lo que suena en la estación elegida (1 a 5). No espera: suena mientras Nuna habla.
func reproducir_estacion(numero: int) -> void:
	_parlante.stream = Chip.radio_estacion(numero)
	_parlante.play()


func sintonizar() -> void:
	if _sintonizando:
		return

	_sintonizando = true
	estatica()

	if not _preparar_animacion_finita(ANIM_SINTONIZANDO):
		_sintonizando = false
		sonar()
		return

	if not _reproducir_animacion(ANIM_SINTONIZANDO):
		_sintonizando = false
		sonar()
		return

	await _anim_sprite.animation_finished

	_sintonizando = false
	sonar()


## Ramón canta la canción de cuna al revés. Con de_fondo = true (al volver a la sala) suena bajito.
func sonar(de_fondo := false) -> void:
	if _reproducir_animacion(ANIM_SONANDO) and not de_fondo:
		comenzo_a_sonar.emit()
	_tocar_cancion(de_fondo)


func _tocar_cancion(de_fondo: bool) -> void:
	if _cancion == null:
		return
	if _fundido != null and _fundido.is_valid():
		_fundido.kill()
	_esperar_cancion()
	_cancion.stream = Chip.radio_reves()
	if not _cancion.playing:
		_cancion.play()
	if de_fondo:
		_cancion.volume_db = VOLUMEN_CANCION_FONDO_DB
		return
	_cancion.volume_db = VOLUMEN_CANCION_DB
	_fundido = create_tween()
	_fundido.tween_interval(SEGUNDOS_ANTES_DE_BAJAR)
	_fundido.tween_property(_cancion, "volume_db", VOLUMEN_CANCION_FONDO_DB, 3.0)


func _esperar_cancion() -> void:
	if _tarea_cancion != -1:
		WorkerThreadPool.wait_for_task_completion(_tarea_cancion)
		_tarea_cancion = -1


func _crear_reproductor(nombre: String, volumen: float) -> AudioStreamPlayer:
	var reproductor := AudioStreamPlayer.new()
	reproductor.name = nombre
	reproductor.volume_db = volumen
	reproductor.bus = Musica.bus_retro()
	add_child(reproductor)
	return reproductor


func detener() -> void:
	mostrar_quieto()


func _al_perturbar(objeto: ObjetoInteractivo) -> void:
	if objeto == self:
		sintonizar()


func _preparar_animacion_finita(animacion: StringName) -> bool:
	if _anim_sprite.sprite_frames == null:
		push_warning("No se puede reproducir '%s' en Ramón: faltan los SpriteFrames." % animacion)
		return false
	if not _anim_sprite.sprite_frames.has_animation(animacion):
		push_warning("No existe la animación '%s' de Ramón." % animacion)
		return false
	if _anim_sprite.sprite_frames.get_animation_loop(animacion):
		push_warning("La animación '%s' de Ramón tiene loop; no se esperará su final." % animacion)
		return false
	return true


func _reproducir_animacion(animacion: StringName) -> bool:
	if _anim_sprite.sprite_frames == null:
		push_warning("No se puede mostrar '%s' en Ramón: faltan los SpriteFrames." % animacion)
		_cambiar_visibilidad_anim_sprite(false)
		return false
	if not _anim_sprite.sprite_frames.has_animation(animacion):
		push_warning("No existe la animación '%s' de Ramón." % animacion)
		if animacion != ANIM_QUIETO and _anim_sprite.sprite_frames.has_animation(ANIM_QUIETO):
			_cambiar_visibilidad_anim_sprite(true)
			_anim_sprite.stop()
			_anim_sprite.play(ANIM_QUIETO)
			return false
		_cambiar_visibilidad_anim_sprite(false)
		return false
	if animacion == ANIM_SONANDO:
		_anim_sprite.sprite_frames.set_animation_loop(ANIM_SONANDO, true)
	_cambiar_visibilidad_anim_sprite(true)
	_anim_sprite.stop()
	_anim_sprite.play(animacion)
	return true


func _cambiar_visibilidad_anim_sprite(visible: bool) -> void:
	if _anim_sprite.visible != visible:
		_anim_sprite.visible = visible
		queue_redraw()
