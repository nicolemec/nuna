extends PopochiuRoomData

var entrada_completada := false
## Sello 1: el aro de luz (Poseer). 0 = normal, 1 rosa, 2 ojo, 3 rojo.
var aro_forma := 0
var sello_aro := false
## Sello 2: el espejo (Aparecer + memoria). Rondas acertadas (0 a 3).
var aparicion_desbloqueada := false
var espejo_ronda := 0
var sello_espejo := false
## Sello 3: la avalancha (Perturbar).
var camara_girada := false
var cajas_caidas := false
var sello_placard := false
## vivo, espejo, llora_rie, dormida, despierta
var vale_estado := "vivo"
var foto_subida := false
var flacozem_escondido := false
var mision_completada := false
## La recepción lo marca cuando Nuna «cae» de vuelta (para no repetirlo).
var cayo_en_recepcion := false
var perturbados: Array = []
