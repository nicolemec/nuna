class_name ObjetoAnimado
extends ObjetoInteractivo
## Objeto con animación exportada desde Aseprite como tira horizontal (_anim.png).
## En reposo muestra "anim_reposo"; al perturbarlo reproduce "anim_perturbar"
## unas vueltas y vuelve al reposo. Lo usan los objetos de la 202.

@export_file("*.png") var ruta_tira: String = ""
@export var frame_ancho: int = 16
@export var frame_alto: int = 16
@export var etiquetas: Dictionary = {}       ## "nombre": [desde, hasta] (frames desde 0)
@export var duraciones_ms: Dictionary = {}   ## "nombre": [ms, ms, ...]
@export var anim_reposo: StringName = &"quieta"
@export var anim_perturbar: StringName = &""
@export var vueltas_perturbar: int = 2

var _anim: AnimatedSprite2D
var _vueltas := 0


func _ready() -> void:
	super._ready()
	_anim = AnimatedSprite2D.new()
	_anim.name = "Sprite"
	_anim.centered = false
	_anim.position = Vector2(-floorf(tamano.x / 2.0), -tamano.y)
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anim.visible = false
	add_child(_anim)
	if not ruta_tira.is_empty() and ResourceLoader.exists(ruta_tira):
		_anim.sprite_frames = AsepriteCargador.crear_desde_tira(ruta_tira, frame_ancho, frame_alto, etiquetas, 10.0, [], duraciones_ms)
	_anim.animation_looped.connect(_on_vuelta)
	_anim.animation_finished.connect(_on_terminada)
	mostrar_reposo()


func _draw() -> void:
	if _anim == null or not _anim.visible:
		super._draw()


func tiene_animacion(nombre: StringName) -> bool:
	return _anim != null and _anim.sprite_frames != null and _anim.sprite_frames.has_animation(nombre)


func reproducir(nombre: StringName) -> bool:
	if not tiene_animacion(nombre):
		_anim.visible = false
		queue_redraw()
		return false
	_anim.visible = true
	queue_redraw()
	_anim.stop()
	_anim.play(nombre)
	return true


func mostrar_reposo() -> void:
	reproducir(anim_reposo)


## Lo llama la sala al perturbar el objeto. Si no tiene animación, tiembla.
func reaccionar() -> void:
	if anim_perturbar == &"" or not reproducir(anim_perturbar):
		_sacudir()
		return
	_vueltas = 0


func _on_vuelta() -> void:
	if _anim.animation != anim_perturbar or anim_perturbar == anim_reposo:
		return
	_vueltas += 1
	if _vueltas >= vueltas_perturbar:
		mostrar_reposo()


func _on_terminada() -> void:
	if _anim.animation == anim_perturbar:
		mostrar_reposo()
