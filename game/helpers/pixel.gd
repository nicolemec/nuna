class_name Pixel
## Movimiento pixel a pixel, para respetar el pixel art: velocidad constante (sin
## aceleración suave) y el objeto siempre en posiciones enteras, nunca "entre" pixeles.
## Uso: Pixel.mover(tween, nodo, "position:x", 300.0, 2.0)


static func mover(tw: Tween, obj: Object, propiedad: NodePath, hasta: Variant, segundos: float) -> Tweener:
	var desde: Variant = obj.get_indexed(propiedad)
	var aplicar := func (valor: Variant) -> void:
		if valor is Vector2:
			obj.set_indexed(propiedad, (valor as Vector2).round())
		else:
			obj.set_indexed(propiedad, roundf(float(valor)))
	return tw.tween_method(aplicar, desde, hasta, segundos)
