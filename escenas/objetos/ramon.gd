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

var _sprite: AnimatedSprite2D
var _sintonizando: bool = false


func _ready() -> void:
	super._ready()
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.centered = false
	_sprite.position = Vector2(-floorf(tamano.x / 2.0), -tamano.y)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.visible = false
	add_child(_sprite)
	queue_redraw()

	_sprite.sprite_frames = AsepriteCargador.crear_desde_tira(
		RUTA_TIRA,
		FRAME_ANCHO,
		FRAME_ALTO,
		ETIQUETAS,
		FPS_BASE,
		ANIMACIONES_SIN_LOOP,
		DURACIONES_MS
	)
	if _sprite.sprite_frames == null:
		push_error("No se pudieron crear las animaciones de Ramón.")
	else:
		perturbado.connect(_al_perturbar)
	mostrar_quieto()


func _draw() -> void:
	if _sprite == null or not _sprite.visible:
		super._draw()


func mostrar_quieto() -> void:
	_sintonizando = false
	_reproducir_animacion(ANIM_QUIETO)


func sintonizar() -> void:
	if _sintonizando:
		return

	_sintonizando = true

	if not _preparar_animacion_finita(ANIM_SINTONIZANDO):
		_sintonizando = false
		sonar()
		return

	if not _reproducir_animacion(ANIM_SINTONIZANDO):
		_sintonizando = false
		sonar()
		return

	await _sprite.animation_finished

	_sintonizando = false
	sonar()


func sonar() -> void:
	if _reproducir_animacion(ANIM_SONANDO):
		comenzo_a_sonar.emit()


func detener() -> void:
	mostrar_quieto()


func _al_perturbar(objeto: ObjetoInteractivo) -> void:
	if objeto == self:
		sintonizar()


func _preparar_animacion_finita(animacion: StringName) -> bool:
	if _sprite.sprite_frames == null:
		push_warning("No se puede reproducir '%s' en Ramón: faltan los SpriteFrames." % animacion)
		return false
	if not _sprite.sprite_frames.has_animation(animacion):
		push_warning("No existe la animación '%s' de Ramón." % animacion)
		return false
	if _sprite.sprite_frames.get_animation_loop(animacion):
		push_warning("La animación '%s' de Ramón tiene loop; no se esperará su final." % animacion)
		return false
	return true


func _reproducir_animacion(animacion: StringName) -> bool:
	if _sprite.sprite_frames == null:
		push_warning("No se puede mostrar '%s' en Ramón: faltan los SpriteFrames." % animacion)
		_cambiar_visibilidad_sprite(false)
		return false
	if not _sprite.sprite_frames.has_animation(animacion):
		push_warning("No existe la animación '%s' de Ramón." % animacion)
		if animacion != ANIM_QUIETO and _sprite.sprite_frames.has_animation(ANIM_QUIETO):
			_cambiar_visibilidad_sprite(true)
			_sprite.stop()
			_sprite.play(ANIM_QUIETO)
			return false
		_cambiar_visibilidad_sprite(false)
		return false
	if animacion == ANIM_SONANDO:
		_sprite.sprite_frames.set_animation_loop(ANIM_SONANDO, true)
	_cambiar_visibilidad_sprite(true)
	_sprite.stop()
	_sprite.play(animacion)
	return true


func _cambiar_visibilidad_sprite(visible: bool) -> void:
	if _sprite.visible != visible:
		_sprite.visible = visible
		queue_redraw()
