class_name CafeteraPanel
extends Panel202
## Minijuego de la cafetera: preparar el café del deadline siguiendo la receta pegada.
## Receta: 3 medidas de café por cada medida de agua, la jarra lleva 12 justas,
## y una cucharada de azúcar por cada noche sin dormir (las noches tachadas del calendario: 8).

signal preparado(cafe: int, agua: int, azucar: int)

const MAXIMO := 12

var cafe := 0
var agua := 0
var azucar := 0
var _valores := {}
var _jarra: Label


func _armar() -> void:
	caja.add_child(_label("CAFETERA - RECETA DEL DEADLINE", COLOR_GRIS))
	caja.add_child(_label("3 de café por cada 1 de agua.", COLOR_NARANJA))
	caja.add_child(_label("La jarra lleva 12 medidas justas.", COLOR_NARANJA))
	caja.add_child(_label("Azúcar: 1 por cada noche sin dormir.", COLOR_NARANJA))
	caja.add_child(_espacio(2))
	for nombre in ["café", "agua", "azúcar"]:
		var fila := HBoxContainer.new()
		fila.alignment = BoxContainer.ALIGNMENT_CENTER
		fila.add_theme_constant_override("separation", 4)
		var etiqueta := _label(nombre.capitalize(), COLOR_CLARO, false)
		etiqueta.custom_minimum_size = Vector2(56, 0)
		fila.add_child(etiqueta)
		fila.add_child(_boton("-", _cambiar.bind(nombre, -1), 16))
		var valor := _label("0", COLOR_CLARO)
		valor.custom_minimum_size = Vector2(22, 0)
		fila.add_child(valor)
		_valores[nombre] = valor
		fila.add_child(_boton("+", _cambiar.bind(nombre, 1), 16))
		caja.add_child(fila)
	caja.add_child(_espacio(2))
	var fila_boton := HBoxContainer.new()
	fila_boton.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_boton.add_theme_constant_override("separation", 10)
	_jarra = _label("", COLOR_PISTA)
	_jarra.custom_minimum_size = Vector2(130, 0)
	fila_boton.add_child(_jarra)
	fila_boton.add_child(_boton("Preparar", func(): preparado.emit(cafe, agua, azucar), 70))
	caja.add_child(fila_boton)
	caja.add_child(_label("clic afuera para cerrar", COLOR_PISTA))
	_refrescar()


func _cambiar(nombre: String, delta: int) -> void:
	match nombre:
		"café": cafe = clampi(cafe + delta, 0, 15)
		"agua": agua = clampi(agua + delta, 0, 15)
		"azúcar": azucar = clampi(azucar + delta, 0, 15)
	_refrescar()


func _refrescar() -> void:
	_valores["café"].text = str(cafe)
	_valores["agua"].text = str(agua)
	_valores["azúcar"].text = str(azucar)
	_jarra.text = "Jarra: %d / %d medidas" % [cafe + agua, MAXIMO]
