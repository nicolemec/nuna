class_name HuespedBruno
extends ObjetoAnimado
## Bruno dormido en la cama (como Ofelia en la 101).
## Respira; cada tanto ronca; al perturbarlo tiembla, pero no se despierta.
## asustarse(): se sienta en la cama (el susto grande es leve: no salta).

const SEGUNDOS_ENTRE_RONQUIDOS := 7.0

var sentado := false
var _reloj_ronquido := 0.0


func _ready() -> void:
	super._ready()
	if tiene_animacion(&"sentarse"):
		_anim.sprite_frames.set_animation_loop(&"sentarse", false)
	if tiene_animacion(&"ronca"):
		_anim.sprite_frames.set_animation_loop(&"ronca", false)


func _process(delta: float) -> void:
	super._process(delta)
	if sentado or _anim == null or _anim.animation != anim_reposo:
		return
	_reloj_ronquido += delta
	if _reloj_ronquido >= SEGUNDOS_ENTRE_RONQUIDOS:
		_reloj_ronquido = 0.0
		reproducir(&"ronca")


func _on_terminada() -> void:
	if _anim.animation == &"ronca":
		mostrar_reposo()
		return
	super._on_terminada()


func reaccionar() -> void:
	if sentado:
		_sacudir()
		return
	super.reaccionar()


func temblar() -> void:
	reaccionar()


func asustarse() -> void:
	sentado = true
	anim_reposo = &"sentarse"
	reproducir(&"sentarse")
