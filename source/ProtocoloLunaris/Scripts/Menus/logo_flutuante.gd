extends TextureRect
## Faz a logo "flutuar": sobe e desce devagar, sem parar.
##
## Mexe nos offsets (e não na posição) para continuar funcionando quando a janela muda de tamanho.

## Quantos pixels (da tela base, 320x180) a logo sobe e desce.
@export var amplitude: float = 3.0
## Segundos para um ciclo completo (subir e descer).
@export var periodo: float = 3.4
## Mover em pixels inteiros (estilo pixel art). Desligue para um movimento mais suave.
@export var passo_inteiro: bool = true

var _t := 0.0
var _topo := 0.0
var _base := 0.0


func _ready() -> void:
	_topo = offset_top
	_base = offset_bottom


func _process(delta: float) -> void:
	_t += delta
	var dy := sin(_t * TAU / periodo) * amplitude
	if passo_inteiro:
		dy = round(dy)
	offset_top = _topo + dy
	offset_bottom = _base + dy
