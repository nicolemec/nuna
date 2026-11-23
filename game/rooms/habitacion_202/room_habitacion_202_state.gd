extends PopochiuRoomData

var entrada_completada := false
var laptop_quemada := false
var mails_resueltos := 0
var cafe_listo := false
var alarma_sonada := false
var taza_con_dientes := false
var mision_completada := false
var perturbados: Array = []
## Acto 2: Din manda POSEER (beta) por el teléfono cuando los 3 puzzles dieron su medio sello.
var poseer_desbloqueado := false
## Objetos ya poseídos (cada uno completa su sello).
var poseidos: Array = []
## Cuántas veces Nuna se equivocó con el azúcar (a la segunda, la pista se hace más clara).
var errores_azucar := 0
