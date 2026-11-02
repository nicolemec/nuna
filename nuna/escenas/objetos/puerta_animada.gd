class_name PuertaAnimada
extends ObjetoInteractivo

const RUTA_TIRA: String = "res://arte/objetos/door.png"
const FRAME_ANCHO: int = 25
const FRAME_ALTO: int = 130
const FPS_BASE: float = 10.0
const ANIM_CERRADA: StringName = &"cerrada"
const ANIM_ABRE: StringName = &"abre"
const ANIM_ABIERTA: StringName = &"abierta"
const ANIM_CIERRA: StringName = &"cierra"
const ETIQUETAS: Dictionary = {
	"cerrada": [0, 0],
	"abre": [1, 5],
	"abierta": [6, 6],
	"cierra": [7, 11],
}
const DURACIONES_MS: Dictionary = {
	"cerrada": [100],
	"abre": [100, 100, 100, 100, 100],
	"abierta": [100],
	"cierra": [100, 100, 100, 100, 100],
}
# Los nombres internos abre/cierra corresponden a los tags se_abre/se_cierra del JSON.
const ANIMACIONES_SIN_LOOP: Array = ["abre", "cierra"]

var _sprite: AnimatedSprite2D


func _ready() -> void:
	super._ready()
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.centered = false
	_sprite.position = Vector2(-floorf(tamano.x / 2.0), -FRAME_ALTO)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)

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
		push_error("No se pudieron crear las animaciones de la puerta.")
	mostrar_cerrada()


func _draw() -> void:
	if _sprite == null or not _sprite.visible:
		super._draw()


func mostrar_cerrada() -> void:
	_mostrar_estado(ANIM_CERRADA)


func abrir() -> void:
	if not _preparar_animacion_finita(ANIM_ABRE):
		mostrar_abierta()
		return
	_sprite.stop()
	_sprite.play(ANIM_ABRE)
	await _sprite.animation_finished
	mostrar_abierta()


func mostrar_abierta() -> void:
	_mostrar_estado(ANIM_ABIERTA)


func cerrar() -> void:
	if not _preparar_animacion_finita(ANIM_CIERRA):
		mostrar_cerrada()
		return
	_sprite.stop()
	_sprite.play(ANIM_CIERRA)
	await _sprite.animation_finished
	mostrar_cerrada()


func _mostrar_estado(animacion: StringName) -> void:
	if _sprite.sprite_frames == null:
		push_warning("No se puede mostrar '%s': faltan los SpriteFrames de la puerta." % animacion)
		_sprite.visible = false
		queue_redraw()
		return
	if not _sprite.sprite_frames.has_animation(animacion):
		push_warning("No existe la animación de puerta '%s'." % animacion)
		_sprite.visible = false
		queue_redraw()
		return
	_sprite.visible = true
	queue_redraw()
	_sprite.stop()
	_sprite.play(animacion)


func _preparar_animacion_finita(animacion: StringName) -> bool:
	if _sprite.sprite_frames == null:
		push_warning("No se puede reproducir '%s': faltan los SpriteFrames de la puerta." % animacion)
		return false
	if not _sprite.sprite_frames.has_animation(animacion):
		push_warning("No existe la animación de puerta '%s'." % animacion)
		return false
	if _sprite.sprite_frames.get_animation_loop(animacion):
		push_warning("La animación de puerta '%s' tiene loop; se omite la espera." % animacion)
		return false
	return true
