class_name FantasmaBanco
extends ZonaIntro
## El fantasma sentado en el banco de la calle. Estados: presente, desapareciendo, desaparecido.
## Usa arte/objetos/fantasmaextra.png (+ .json): cuadro 0 = presente, 0–2 = se desvanece, 3 = vacío.

const RUTA_PNG := "res://arte/objetos/fantasmaextra.png"
const RUTA_JSON := "res://arte/objetos/fantasmaextra.json"
const ANIMACIONES := {
	"presente": [0, 0],
	"desapareciendo": [0, 2],
	"desaparecido": [3, 3],
}

enum Estado { PRESENTE, DESAPARECIENDO, DESAPARECIDO }

var estado: int = Estado.PRESENTE
var _animacion: AnimatedSprite2D


func _ready() -> void:
	super._ready()
	_animacion = AnimatedSprite2D.new()
	_animacion.name = "Sprite"
	_animacion.centered = false
	_animacion.position = Vector2(-15, -30)
	_animacion.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_animacion.sprite_frames = SpriteJson.cargar(RUTA_JSON, RUTA_PNG, ANIMACIONES, ["desapareciendo"])
	add_child(_animacion)
	mostrar_presente()


func mostrar_presente() -> void:
	estado = Estado.PRESENTE
	visible = true
	_animacion.play(&"presente")


func desaparecer() -> void:
	if estado != Estado.PRESENTE:
		return
	estado = Estado.DESAPARECIENDO
	clickable = false
	resaltar = false
	_animacion.play(&"desapareciendo")
	await _animacion.animation_finished
	estado = Estado.DESAPARECIDO
	_animacion.play(&"desaparecido")
