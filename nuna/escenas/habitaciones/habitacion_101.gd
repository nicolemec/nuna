extends Node2D
## Habitación 101 · prototipo gris.
## Paso 1: hacer clic para que Nuna flote hasta ahí.

@onready var nuna: Nuna = $Nuna
@onready var marcador: ColorRect = $Marcador


func _ready() -> void:
	marcador.visible = false
	nuna.llego.connect(_on_nuna_llego)


# _unhandled_input recibe solo los clics que la interfaz no usó.
# Cuando agreguemos la barra de verbos (paso 2), sus botones no moverán a Nuna.
func _unhandled_input(event: InputEvent) -> void:
	var boton := event as InputEventMouseButton
	if boton == null or not boton.pressed or boton.button_index != MOUSE_BUTTON_LEFT:
		return

	var clic: Vector2 = get_global_mouse_position()  # ya viene en coordenadas de 320×180
	if clic.y >= Ajustes.UI_Y:
		return  # clic en la franja de interfaz: no mover

	# Si haces clic en la pared, Nuna va al punto del piso que está debajo
	var destino := Vector2(
		clampf(clic.x, Ajustes.LIMITE_X_MIN, Ajustes.LIMITE_X_MAX),
		clampf(clic.y, Ajustes.PISO_Y_MIN, Ajustes.PISO_Y_MAX)
	)
	nuna.ir_a(destino)

	# Marcador: un puntito donde va a llegar
	marcador.position = destino - marcador.size / 2.0
	marcador.visible = true


func _on_nuna_llego() -> void:
	marcador.visible = false
