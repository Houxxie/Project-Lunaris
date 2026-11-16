@tool
class_name FundoEspacial
extends Control
## Fundo espacial animado, desenhado em tempo real (substitui o vídeo de estrelas).
##
## As estrelas piscam em ritmos diferentes e os cometas surgem em momentos, posições e
## velocidades aleatórios, então a animação nunca se repete igual. Para usar em outra tela,
## instancie Scenes/Fundo/fundo_espacial.tscn como PRIMEIRO filho da tela (fica atrás de tudo)
## e ajuste as opções no Inspetor.
##
## Tudo é desenhado em pixels inteiros da tela base (320x180), para combinar com o pixel art.
## No editor aparece só o céu parado; a animação roda quando o programa roda.

@export_group("Céu")
## Cor de fundo do espaço.
@export var cor_fundo: Color = Color("#04050c")
## Número 0 = céu diferente a cada vez que a tela abre. Outro número = sempre o mesmo céu.
@export var semente: int = 0

@export_group("Estrelas")
## Estrelas por pixel da tela. 0.006 dá umas 350 estrelas numa tela de 320x180.
@export_range(0.0, 0.05, 0.0005) var densidade_estrelas: float = 0.006
## Cores possíveis das estrelas (sorteadas).
@export var cores_estrelas: PackedColorArray = PackedColorArray([
	Color("#ffffff"), Color("#d6ecff"), Color("#9fe3ff"), Color("#c3b5ff")])
## Fração das estrelas que piscam (o resto fica com brilho fixo).
@export_range(0.0, 1.0) var fracao_piscando: float = 0.7
## Intervalo (mín., máx.) em segundos entre os "brilhos" rápidos de uma estrela grande.
@export var intervalo_brilhos: Vector2 = Vector2(1.5, 4.0)

@export_group("Cometas")
@export var cometas_ativos: bool = true
## Intervalo (mín., máx.) em segundos entre um cometa e o próximo.
@export var intervalo_cometas: Vector2 = Vector2(2.5, 8.0)
## Velocidade (mín., máx.) em pixels por segundo.
@export var velocidade_cometas: Vector2 = Vector2(70.0, 160.0)
## Comprimento da cauda (mín., máx.) em pixels.
@export var cauda_cometas: Vector2 = Vector2(8.0, 26.0)
## Quantos cometas podem aparecer ao mesmo tempo.
@export_range(1, 6) var max_cometas: int = 2
@export var cor_cometa: Color = Color("#c8f4ff")

@export_group("Movimento")
## Deriva lenta do céu, em pixels por segundo. Ex.: (-2, 0) faz as estrelas andarem para a esquerda.
@export var deriva: Vector2 = Vector2.ZERO

@export_group("Salto")
## Quantas estrelas, no máximo, viram riscos durante o salto (as mais fortes primeiro).
@export_range(0, 1000) var max_riscos: int = 500

## Salto ("velocidade da luz"): cada estrela vira um risco em cima da linha que vai do centro
## da tela até ela. As duas pontas do risco são dadas em "distâncias da estrela ao centro":
##    0 = no lugar da estrela;  1 = uma distância inteira mais para fora;  -1 = no centro da tela.
## `salto_frente` é a ponta de fora (a mais clara) e `salto_tras` a de dentro.
## Com as duas em 0 o céu é o normal. Quem anima estes dois números é a transição do menu
## para o mapa (Scripts/UI/salto_espacial.gd).
var salto_frente := 0.0
var salto_tras := 0.0

## Empurra o céu inteiro de lado, em pixels (as estrelas que saem por uma borda voltam pela
## outra). A tela do mapa anima isto para dar a impressão de "virar o rosto".
var desvio := Vector2.ZERO

const _DURACAO_BRILHO := 0.6

## Desenha os riscos do salto. Fica dentro de uma telinha separada (`_tela_riscos`) do tamanho
## da tela base, para as linhas saírem em pixels grandes, como o resto do pixel art.
class Riscos extends Node2D:
	var pontos := PackedVector2Array()   # dois pontos por pedaço de risco
	var cores := PackedColorArray()      # uma cor por pedaço

	func _draw() -> void:
		if pontos.size() >= 2:
			draw_multiline_colors(pontos, cores)   # largura padrão: 1 pixel da telinha

var _tela_riscos: SubViewport
var _riscos: Riscos
var _rng := RandomNumberGenerator.new()
var _estrelas: Array[Dictionary] = []
var _cometas: Array[Dictionary] = []
var _t := 0.0
var _proximo_cometa := 0.0
var _proximo_brilho := 0.0
var _brilho_estrela := -1
var _brilho_t := 0.0
var _deslocamento := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if semente != 0:
		_rng.seed = semente
	else:
		_rng.randomize()
	resized.connect(_gerar_estrelas)
	if not Engine.is_editor_hint() and not (get_parent() is Control):
		# Dentro de um Node2D as âncoras não funcionam: ocupar a tela inteira manualmente.
		get_viewport().size_changed.connect(_cobrir_tela)
		_cobrir_tela()
	_gerar_estrelas()
	_proximo_cometa = _rng.randf_range(0.8, 2.5)  # o primeiro cometa vem logo
	_proximo_brilho = _rng.randf_range(intervalo_brilhos.x, intervalo_brilhos.y)


func _cobrir_tela() -> void:
	var tela := get_viewport_rect()
	position = tela.position
	size = tela.size


## Lança um cometa agora (ex.: para marcar uma transição de tela).
func lancar_cometa_agora() -> void:
	_lancar_cometa()


## Troca o céu: sorteia de novo as estrelas com a semente dada (0 = aleatório).
func trocar_ceu(nova_semente: int = 0) -> void:
	semente = nova_semente
	if semente != 0:
		_rng.seed = semente
	else:
		_rng.randomize()
	_gerar_estrelas()


func _gerar_estrelas() -> void:
	_estrelas.clear()
	if size.x < 2.0 or size.y < 2.0 or cores_estrelas.is_empty():
		queue_redraw()
		return
	var total := int(size.x * size.y * densidade_estrelas)
	for i in total:
		var sorteio := _rng.randf()
		var tipo := 0                # 0 = pontinho fraco
		if sorteio > 0.97:
			tipo = 2                 # estrela grande, em cruz
		elif sorteio > 0.82:
			tipo = 1                 # pontinho forte
		_estrelas.append({
			"p": Vector2(_rng.randi_range(0, int(size.x) - 1), _rng.randi_range(0, int(size.y) - 1)),
			"cor": cores_estrelas[_rng.randi() % cores_estrelas.size()],
			"brilho": _rng.randf_range(0.3, 0.8) if tipo == 0 else _rng.randf_range(0.75, 1.0),
			"freq": _rng.randf_range(0.12, 1.0),
			"fase": _rng.randf() * TAU,
			"pisca": _rng.randf() < fracao_piscando,
			"tipo": tipo,
			"risco": false,
		})
	# Quais estrelas viram risco no salto: as mais fortes primeiro, até `max_riscos`.
	var ordem: Array = range(_estrelas.size())
	ordem.sort_custom(func(a, b): return _estrelas[a]["tipo"] > _estrelas[b]["tipo"])
	for k in mini(max_riscos, ordem.size()):
		_estrelas[ordem[k]]["risco"] = true
	_brilho_estrela = -1
	queue_redraw()


# ---------- salto ----------

func _saltando() -> bool:
	return salto_frente != 0.0 or salto_tras != 0.0


## Cria (na primeira vez que há um salto) a telinha onde os riscos são desenhados.
func _preparar_tela_de_riscos() -> void:
	if _tela_riscos == null:
		_tela_riscos = SubViewport.new()
		_tela_riscos.transparent_bg = true
		_tela_riscos.disable_3d = true
		_riscos = Riscos.new()
		_tela_riscos.add_child(_riscos)
		add_child(_tela_riscos)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # a telinha é ampliada sem suavizar
	_tela_riscos.size = Vector2i(maxi(int(ceilf(size.x)), 2), maxi(int(ceilf(size.y)), 2))
	_tela_riscos.render_target_update_mode = SubViewport.UPDATE_ALWAYS


## Monta os riscos deste quadro. Cada risco tem 3 pedaços, do mais apagado (ponta de dentro)
## ao mais claro (ponta de fora). Risco menor que 1 pixel não entra: a estrela continua um ponto.
func _atualizar_riscos() -> void:
	var pontos := PackedVector2Array()
	var cores := PackedColorArray()
	var centro := size / 2.0
	var meio := Vector2(0.5, 0.5)   # as linhas passam pelo meio dos pixels
	for e in _estrelas:
		if not e["risco"]:
			continue
		var p := _posicao(e)
		var d := p - centro
		var a := p + d * salto_tras
		var b := p + d * salto_frente
		if (b - a).length_squared() < 1.0:
			continue
		var cor: Color = e["cor"]
		var alfa := minf(1.0, float(e["brilho"]) + 0.3)
		var c1 := a.lerp(b, 0.45)
		var c2 := a.lerp(b, 0.8)
		# As cores vão já misturadas com a cor do céu, sem transparência: uma telinha com
		# fundo transparente escurece o que é desenhado nela meio transparente.
		pontos.append(a.floor() + meio)
		pontos.append(c1.floor() + meio)
		cores.append(cor_fundo.lerp(cor, alfa * 0.25))
		pontos.append(c1.floor() + meio)
		pontos.append(c2.floor() + meio)
		cores.append(cor_fundo.lerp(cor, alfa * 0.6))
		pontos.append(c2.floor() + meio)
		pontos.append(b.floor() + meio)
		cores.append(cor_fundo.lerp(cor.lerp(Color.WHITE, 0.5), alfa))
	_riscos.pontos = pontos
	_riscos.cores = cores
	_riscos.queue_redraw()


## Onde a estrela está agora (a posição sorteada mais a deriva do céu).
func _posicao(e: Dictionary) -> Vector2:
	var base: Vector2 = e["p"]
	return Vector2(fposmod(base.x + _deslocamento.x + desvio.x, size.x),
			fposmod(base.y + _deslocamento.y + desvio.y, size.y))


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	_deslocamento += deriva * delta

	if cometas_ativos:
		_proximo_cometa -= delta
		if _proximo_cometa <= 0.0:
			if _cometas.size() < max_cometas:
				_lancar_cometa()
			_proximo_cometa = _rng.randf_range(intervalo_cometas.x, intervalo_cometas.y)

	_proximo_brilho -= delta
	if _proximo_brilho <= 0.0:
		_sortear_brilho()
		_proximo_brilho = _rng.randf_range(intervalo_brilhos.x, intervalo_brilhos.y)
	if _brilho_estrela >= 0:
		_brilho_t += delta
		if _brilho_t > _DURACAO_BRILHO:
			_brilho_estrela = -1

	var margem := cauda_cometas.y + 4.0
	for i in range(_cometas.size() - 1, -1, -1):
		var c := _cometas[i]
		c["p"] += c["dir"] * c["vel"] * delta
		var p: Vector2 = c["p"]
		if p.y > size.y + margem or p.x < -margem or p.x > size.x + margem:
			_cometas.remove_at(i)

	if _saltando():
		_preparar_tela_de_riscos()
		_atualizar_riscos()
	elif _tela_riscos != null and _tela_riscos.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		_tela_riscos.render_target_update_mode = SubViewport.UPDATE_DISABLED   # salto acabou

	queue_redraw()


func _sortear_brilho() -> void:
	var grandes: Array[int] = []
	for i in _estrelas.size():
		if _estrelas[i]["tipo"] > 0:
			grandes.append(i)
	if grandes.is_empty():
		return
	_brilho_estrela = grandes[_rng.randi() % grandes.size()]
	_brilho_t = 0.0


func _lancar_cometa() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	var para_direita := _rng.randf() < 0.5
	var angulo := deg_to_rad(_rng.randf_range(12.0, 38.0))   # inclinação abaixo da horizontal
	var direcao := Vector2(cos(angulo), sin(angulo))
	if not para_direita:
		direcao.x = -direcao.x
	var inicio: Vector2
	if _rng.randf() < 0.6:
		inicio = Vector2(_rng.randf_range(size.x * 0.1, size.x * 0.9), -3.0)   # entra por cima
	else:
		var x := -3.0 if para_direita else size.x + 3.0                         # entra pela lateral
		inicio = Vector2(x, _rng.randf_range(0.0, size.y * 0.55))
	_cometas.append({
		"p": inicio,
		"dir": direcao,
		"vel": _rng.randf_range(velocidade_cometas.x, velocidade_cometas.y),
		"cauda": _rng.randf_range(cauda_cometas.x, cauda_cometas.y),
	})


func _ponto(p: Vector2, cor: Color) -> void:
	draw_rect(Rect2(p.floor(), Vector2.ONE), cor)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), cor_fundo)
	if size.x < 2.0 or size.y < 2.0:
		return
	var animar := not Engine.is_editor_hint()
	# Durante o salto: quanto do céu normal ainda aparece (1 = todo, 0 = nada). As estrelas que
	# não viram risco somem aos poucos; as que viram são desenhadas como risco, mais abaixo.
	var saltando := animar and _saltando()
	var resto := 1.0
	var centro := size / 2.0
	if saltando:
		resto = clampf(1.0 - 3.0 * maxf(absf(salto_frente), absf(salto_tras)), 0.0, 1.0)

	for i in _estrelas.size():
		var e := _estrelas[i]
		var alfa: float = e["brilho"]
		if animar and e["pisca"]:
			alfa *= 0.5 + 0.5 * (0.5 + 0.5 * sin(_t * e["freq"] * TAU + e["fase"]))
		var p := _posicao(e)
		var cor: Color = e["cor"]
		if saltando:
			if not e["risco"]:
				if resto > 0.0:
					_ponto(p, Color(cor, alfa * resto))
				continue
			var d := p - centro
			if (d * (salto_frente - salto_tras)).length_squared() >= 1.0:
				continue   # esta já virou risco (desenhado na telinha de riscos)
			p += d * salto_frente   # risco curto demais: ainda é um ponto, já no lugar novo
			if not Rect2(Vector2.ZERO, size).has_point(p):
				continue
		_ponto(p, Color(cor, alfa))
		if saltando:
			continue   # sem os bracinhos e sem o brilho rápido durante o salto
		if e["tipo"] == 2:
			var braco := Color(cor, alfa * 0.45)
			for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				_ponto(p + d, braco)
		if i == _brilho_estrela:
			# brilho rápido: uma cruz que cresce e some
			var k := 1.0 - _brilho_t / _DURACAO_BRILHO
			var tamanho := 1 + int(round(2.0 * sin(PI * _brilho_t / _DURACAO_BRILHO)))
			for passo in range(1, tamanho + 1):
				var a := k * (1.0 - float(passo - 1) / (tamanho + 1))
				for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
					_ponto(p + d * passo, Color(Color.WHITE, a))

	if saltando and _tela_riscos != null:
		draw_texture_rect(_tela_riscos.get_texture(), Rect2(Vector2.ZERO, Vector2(_tela_riscos.size)), false)

	for c in _cometas:
		var cabeca: Vector2 = c["p"]
		var direcao: Vector2 = c["dir"]
		var cauda := int(c["cauda"])
		for k in range(cauda, 0, -1):
			var f := 1.0 - float(k) / cauda
			_ponto(cabeca - direcao * k, Color(cor_cometa, f * f * 0.85))
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			_ponto(cabeca + d, Color(cor_cometa, 0.3))
		_ponto(cabeca, Color.WHITE)
