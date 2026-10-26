extends Node
## Estado global del juego. Se registra como Autoload con el nombre "GameState".
## En el paso 3 se suman la Bruma y el miedo.

signal verbo_cambiado(verbo: StringName)

const MIRAR := &"mirar"
const AGARRAR := &"agarrar"
const PERTURBAR := &"perturbar"

## Texto de cada botón, en el orden en que aparecen en la barra.
const NOMBRES_VERBOS: Dictionary = {
	&"mirar": "Mirar",
	&"agarrar": "Agarrar",
	&"perturbar": "Perturbar",
}

var verbo_actual: StringName = MIRAR


func elegir_verbo(verbo: StringName) -> void:
	verbo_actual = verbo
	verbo_cambiado.emit(verbo)
