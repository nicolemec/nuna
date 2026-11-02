class_name VentanaAnimada
extends ObjetoInteractivo

const RUTA_TIRA: String = "res://arte/objetos/ventana_anim.png"
const FRAME_ANCHO: int = 40
const FRAME_ALTO: int = 60
const FPS_BASE: float = 10.0
const ANIM_QUIETA: StringName = &"quieta"
const ANIM_BAILA: StringName = &"baila"
const ETIQUETAS: Dictionary = {
	"quieta": [0, 0],
	"baila": [1, 3],
}
const DURACIONES_MS: Dictionary = {
	"quieta": [150],
	"baila": [150, 250, 150],
}

var _sprite: AnimatedSprite2D


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
		[],
		DURACIONES_MS
	)
	if _sprite.sprite_frames == null:
		push_error("No se pudieron crear las animaciones de Doña Cortina.")
	else:
		_sprite.sprite_frames.set_animation_loop(ANIM_BAILA, true)
	mostrar_quieta()


func _draw() -> void:
	if _sprite == null or not _sprite.visible:
		super._draw()


func mostrar_quieta() -> void:
	_reproducir_animacion(ANIM_QUIETA)


func bailar() -> void:
	_reproducir_animacion(ANIM_BAILA)


func detener() -> void:
	mostrar_quieta()


func _reproducir_animacion(animacion: StringName) -> bool:
	if _sprite.sprite_frames == null:
		push_warning("No se puede mostrar '%s' en la ventana: faltan los SpriteFrames." % animacion)
		_cambiar_visibilidad_sprite(false)
		return false
	if not _sprite.sprite_frames.has_animation(animacion):
		push_warning("No existe la animación '%s' de la ventana." % animacion)
		if animacion != ANIM_QUIETA and _sprite.sprite_frames.has_animation(ANIM_QUIETA):
			_cambiar_visibilidad_sprite(true)
			_sprite.stop()
			_sprite.play(ANIM_QUIETA)
			return false
		_cambiar_visibilidad_sprite(false)
		return false
	_cambiar_visibilidad_sprite(true)
	_sprite.stop()
	_sprite.play(animacion)
	return true


func _cambiar_visibilidad_sprite(visible: bool) -> void:
	if _sprite.visible != visible:
		_sprite.visible = visible
		queue_redraw()
