class_name LamparaRecepcion
extends ZonaIntro
## La lámpara del mostrador de la recepción: el primer objeto que Nuna perturba.
## Usa arte/objetos/lampara_hotel.png (+ .json), exportado de lampararahotel.aesprite.aseprite.

const RUTA_PNG := "res://arte/objetos/lampara_hotel.png"
const RUTA_JSON := "res://arte/objetos/lampara_hotel.json"
const ANIMACIONES := {
	"apagada": [0, 0],
	"encendiendo": [1, 1],
	"encendida": [2, 2],
}
## Parpadeo al perturbarla: [animación, segundos].
const PARPADEO := [
	["encendiendo", 0.08], ["apagada", 0.10], ["encendida", 0.06], ["apagada", 0.14],
	["encendiendo", 0.07], ["apagada", 0.22], ["encendiendo", 0.10], ["encendida", 0.0],
]

var _animacion: AnimatedSprite2D


func _ready() -> void:
	accion_directa = false
	super._ready()
	_animacion = AnimatedSprite2D.new()
	_animacion.name = "Sprite"
	_animacion.centered = false
	_animacion.position = Vector2(-16, -38)
	_animacion.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_animacion.sprite_frames = SpriteJson.cargar(RUTA_JSON, RUTA_PNG, ANIMACIONES)
	add_child(_animacion)
	_animacion.play(&"encendida")


## Tiembla y parpadea (la reacción de "perturbar").
func parpadear() -> void:
	_sacudir()
	for paso: Array in PARPADEO:
		_animacion.play(StringName(paso[0]))
		if paso[1] > 0.0:
			await get_tree().create_timer(paso[1]).timeout
	_sacudir()
