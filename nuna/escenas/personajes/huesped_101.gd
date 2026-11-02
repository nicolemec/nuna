class_name Huesped101
extends ObjetoInteractivo

const RUTA_TIRA: String = "res://arte/objetos/bedcabeza.png"
const FRAME_ANCHO: int = 104
const FRAME_ALTO: int = 79
const FPS_BASE: float = 10.0
const ANIM_RESPIRA: StringName = &"respira"
const ANIM_TIEMBLA: StringName = &"tiembla"
const ANIM_RONCA: StringName = &"ronca"
const ANIM_SALTO: StringName = &"salto"
const ETIQUETAS: Dictionary = {
	"respira": [0, 1],
	"tiembla": [2, 4],
	"ronca": [5, 6],
	"salto": [7, 21],
}
const DURACIONES_MS: Dictionary = {
	"respira": [1000, 1000],
	"tiembla": [50, 75, 50],
	"ronca": [1000, 1000],
	"salto": [100, 100, 200, 100, 150, 100, 100, 100, 100, 200, 200, 200, 100, 100, 100],
}
const ANIMACIONES_SIN_LOOP: Array[String] = ["tiembla", "salto"]

var _sprite: AnimatedSprite2D
var _temporizador_ronca: Timer


func _ready() -> void:
	super._ready()

	var sprite_existente: Node = get_node_or_null("Sprite")
	if sprite_existente == null:
		_sprite = AnimatedSprite2D.new()
		_sprite.name = "Sprite"
		add_child(_sprite)
	elif sprite_existente is AnimatedSprite2D:
		_sprite = sprite_existente as AnimatedSprite2D
	else:
		push_error("El nodo 'Sprite' de Huesped101 no es un AnimatedSprite2D.")
		return

	_sprite.centered = false
	_sprite.position = Vector2(-FRAME_ANCHO / 2.0, -FRAME_ALTO)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cambiar_visibilidad_sprite(false)

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
		push_error("No se pudieron crear las animaciones de Huesped101.")
		return

	if _sprite.sprite_frames.has_animation(ANIM_RESPIRA):
		_sprite.sprite_frames.set_animation_loop(ANIM_RESPIRA, true)
	if _sprite.sprite_frames.has_animation(ANIM_TIEMBLA):
		_sprite.sprite_frames.set_animation_loop(ANIM_TIEMBLA, false)
	if _sprite.sprite_frames.has_animation(ANIM_RONCA):
		_sprite.sprite_frames.set_animation_loop(ANIM_RONCA, true)
	if _sprite.sprite_frames.has_animation(ANIM_SALTO):
		_sprite.sprite_frames.set_animation_loop(ANIM_SALTO, false)

	if not _sprite.animation_finished.is_connected(_al_terminar_animacion):
		_sprite.animation_finished.connect(_al_terminar_animacion)

	_temporizador_ronca = Timer.new()
	_temporizador_ronca.name = "TemporizadorRonca"
	_temporizador_ronca.one_shot = true
	_temporizador_ronca.timeout.connect(_al_terminar_ronquido)
	add_child(_temporizador_ronca)
	respirar()


func _draw() -> void:
	if _sprite == null or not _sprite.visible:
		super._draw()


func respirar() -> void:
	if _temporizador_ronca != null:
		_temporizador_ronca.stop()
	_reproducir_animacion(ANIM_RESPIRA)


func temblar() -> void:
	if _esta_reproduciendo(ANIM_SALTO) or _esta_reproduciendo(ANIM_TIEMBLA):
		return
	if _temporizador_ronca != null:
		_temporizador_ronca.stop()
	_reproducir_animacion(ANIM_TIEMBLA)


func roncar(segundos: float = 2.0) -> void:
	if _esta_reproduciendo(ANIM_SALTO):
		return
	if not is_finite(segundos) or segundos < 0.0:
		push_warning("La duración de roncar debe ser un número finito no negativo.")
		respirar()
		return
	if _temporizador_ronca != null:
		_temporizador_ronca.stop()
	if _reproducir_animacion(ANIM_RONCA):
		_temporizador_ronca.start(segundos)


func asustarse() -> void:
	if _esta_reproduciendo(ANIM_SALTO):
		return
	if _temporizador_ronca != null:
		_temporizador_ronca.stop()
	_reproducir_animacion(ANIM_SALTO)


func _reproducir_animacion(animacion: StringName) -> bool:
	if _sprite == null or _sprite.sprite_frames == null:
		push_warning("No se puede reproducir '%s' en Huesped101: faltan los SpriteFrames." % animacion)
		_cambiar_visibilidad_sprite(false)
		return false
	if not _sprite.sprite_frames.has_animation(animacion):
		push_warning("No existe la animación '%s' de Huesped101." % animacion)
		if animacion != ANIM_RESPIRA and _sprite.sprite_frames.has_animation(ANIM_RESPIRA):
			_cambiar_visibilidad_sprite(true)
			_sprite.stop()
			_sprite.play(ANIM_RESPIRA)
			return false
		_cambiar_visibilidad_sprite(false)
		return false

	_cambiar_visibilidad_sprite(true)
	_sprite.stop()
	_sprite.play(animacion)
	return true


func _esta_reproduciendo(animacion: StringName) -> bool:
	return _sprite != null and _sprite.is_playing() and _sprite.animation == animacion


func _al_terminar_animacion() -> void:
	if _sprite.animation == ANIM_TIEMBLA or _sprite.animation == ANIM_SALTO:
		respirar()


func _al_terminar_ronquido() -> void:
	if _esta_reproduciendo(ANIM_RONCA):
		respirar()


func _cambiar_visibilidad_sprite(visible: bool) -> void:
	if _sprite == null or _sprite.visible == visible:
		return
	_sprite.visible = visible
	queue_redraw()
