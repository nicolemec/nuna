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
var _resultado: Label


func _armar() -> void:
	caja.add_child(_label("CAFETERA - RECETA DEL DEADLINE", COLOR_GRIS))
	caja.add_child(_label("3 de café por cada 1 de agua.", COLOR_NARANJA))
	caja.add_child(_label("La jarra lleva 12 medidas justas.", COLOR_NARANJA))
	caja.add_child(_label("Azúcar: 1 por cada noche sin dormir.", COLOR_NARANJA))
	caja.add_child(_label("Lo que la receta no dice, está en la habitación.", COLOR_PISTA))
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
	_resultado = _label("", COLOR_ROJO)
	_resultado.visible = false
	caja.add_child(_resultado)
	caja.add_child(_label("clic afuera para cerrar", COLOR_PISTA))
	_refrescar()


func _cambiar(nombre: String, delta: int) -> void:
	match nombre:
		"café": cafe = clampi(cafe + delta, 0, 15)
		"agua": agua = clampi(agua + delta, 0, 15)
		"azúcar": azucar = clampi(azucar + delta, 0, 15)
	if _resultado.visible:
		_resultado.visible = false  # al tocar algo, se borra el error anterior
		reacomodar()
	_refrescar()


## Muestra en el panel qué salió mal (en rojo) y lo sacude cuadro a cuadro.
func mostrar_error(texto: String) -> void:
	_resultado.text = "NO: " + texto
	_resultado.visible = true
	reacomodar()
	var base := _panel.position
	var tw := create_tween()
	for dx in [3, -3, 2, -2, 0]:
		tw.tween_callback(func(): _panel.position = base + Vector2(dx, 0))
		tw.tween_interval(0.05)


func _refrescar() -> void:
	_valores["café"].text = str(cafe)
	_valores["agua"].text = str(agua)
	_valores["azúcar"].text = str(azucar)
	_jarra.text = "Jarra: %d / %d medidas" % [cafe + agua, MAXIMO]
	_jarra.add_theme_color_override("font_color", COLOR_ROJO if cafe + agua > MAXIMO else COLOR_PISTA)
