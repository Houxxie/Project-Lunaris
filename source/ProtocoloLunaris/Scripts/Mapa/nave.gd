class_name Nave
extends Node2D
## A navezinha da tela do mapa: um módulo de pouso branco, parecido com os de verdade (cabine,
## estágio de descida, dois painéis solares, pernas e bocal do motor). Discreta de propósito:
## pequena, clara e com uma chama quase invisível.
##
## O que ela faz:
## - No POLO SUL: surge acoplada na borda esquerda do mapa, se desprende e passeia só na faixa
##   livre à esquerda dele (a `zona`).
## - Na LUA INTEIRA com a lista aberta: passeia pela tela toda, por trás da lista e do mapa.
## - Na LUA INTEIRA sem a lista: fica ESCONDIDA atrás do mapa. Só aparece para pousar, saindo
##   de trás dele, e depois volta para lá e some.
## - Quando um local é escolhido, VIAJA até ele e POUSA. Para isso ela primeiro sai de trás do
##   que a estiver tapando e só então vem para a FRENTE do mapa.
##
## Quem decide a zona e o esconderijo é a tela do mapa (tela_mapa.gd); a nave só obedece.
##
## O desenho fica aqui mesmo, em texto (um caractere = um pixel), como o ponteiro do mouse.
## Este nó fica parado na origem da tela e desenha a nave onde `pos` mandar; assim a poeira
## fica no lugar em que foi levantada.
## O movimento é todo feito em `_process`, sem esperas: uma ordem nova simplesmente toma o
## lugar da anterior.
##
## Uso de IA: escrito e desenhado com assistência do Claude (Anthropic).

## Avisa que a nave acabou de pousar.
signal pousou

enum Estado { ESCONDIDA, ACOPLADA, EM_MANOBRA, PASSEANDO, POUSADA }

const DESENHO := [
	"............g....gg..........",
	"............g...gg...........",
	"...........#######...........",
	"..........#WWWWWWW#..........",
	".........#WWWWWWWWw#.........",
	".#####...#WWWWkkWWw#...#####.",
	"#bBbBb####WWWWkcWWw####bBbBb#",
	"#bBbBb#gg#WWwwwwwWw#gg#bBbBb#",
	"#bBbBb####WWWWWWWww####bBbBb#",
	".#####.###############.#####.",
	".......#WWWwwwwwwwwwg#.......",
	".......#WWwwdwwwdwwwg#.......",
	".......#wwwwwwwwwwwgg#.......",
	"......gg.###########.gg......",
	".....gg.....#nnn#.....gg.....",
	"....gg.....#nnnnn#.....gg....",
	"..ggggg...............ggggg..",
]
## Caractere -> cor. O ponto é transparente.
const CORES := {
	"#": Color("#141a2e"),   # contorno
	"W": Color("#eef3fb"),   # branco do casco
	"w": Color("#c9d3e6"),   # cinza claro
	"g": Color("#8f9bb8"),   # cinza (sombra, antena, suportes)
	"d": Color("#5d6885"),   # frisos do estágio de descida
	"k": Color("#1c2740"),   # janelas
	"c": Color("#7fb0d8"),   # reflexo nas janelas
	"b": Color("#27407a"),   # painéis solares
	"B": Color("#3e5fa8"),
	"n": Color("#3a4258"),   # bocal do motor
}
const COR_DA_CHAMA := Color("#bfe9ff")
const COR_DA_POEIRA := Color("#cfd8ea")

const VELOCIDADE_PASSEIO := 26.0   ## pixels (da tela 640x360) por segundo
const PRESSA_FORA_DA_ZONA := 4.0   ## quantas vezes mais rápido ela anda para voltar à zona dela
const VELOCIDADE_VIAGEM := 330.0
const ALTURA_DE_APROXIMACAO := 14.0  ## ela chega um pouco acima do ponto e desce
## Do centro do desenho até as sapatas: pousada, o centro fica isto acima do ponto.
const ALTURA_DAS_PERNAS := 8.0
## Metade do tamanho da nave, com folga: usado para saber se algo a tapa.
const MEIA_NAVE := Vector2(16.0, 10.0)
const TEMPO_ACOPLADA := 1.0          ## segundos acoplada antes de se desprender
const Z_ATRAS := 0                   ## atrás do mapa e das barras (ela é irmã mais velha delas na árvore)
const Z_NA_FRENTE := 6               ## na frente do mapa e da lista, atrás das janelas
const SEM_PONTO := Vector2(INF, INF)

## Centro da nave, em coordenadas da tela.
var pos := Vector2.ZERO
var escala := 1.0
var chama := 0.0            ## 0 = motor apagado; 1 = aceso
var alfa := 0.0             ## 0 = invisível
## Onde ela passeia (um retângulo da tela). Se a zona muda no meio do passeio, ela larga o
## destino antigo e vai direto para a zona nova (mais depressa, enquanto estiver fora dela).
var zona := Rect2(0, 0, 640, 360):
	set(nova):
		if nova == zona:
			return
		zona = nova
		if _estado == Estado.PASSEANDO:
			_pausa = 0.0
			_novo_destino()
## A tela inteira: é nela que a nave procura um lugar à vista quando precisa sair de trás de algo.
var tela := Rect2(0, 0, 640, 360)
## Função que devolve os retângulos (Array de Rect2) que tapam a nave: mapa, lista e barras.
var obstaculos: Callable

var _estado := Estado.ESCONDIDA
var _textura: ImageTexture
var _t := 0.0
var _vel := Vector2.ZERO
var _destino := Vector2.ZERO
var _pausa := 0.0
var _espera_soltar := 0.0
var _escala_alvo := 1.0
var _chama_alvo := 0.0
var _alfa_alvo := 0.0
var _balanco := 1.0          # 1 = sobe e desce devagar; 0 = parada
var _poeiras: Array = []     # {"p": posição, "v": velocidade, "vida": 0..1, "r": raio}
# deslocamento em andamento (ver `_mover`)
var _movendo := false
var _de := Vector2.ZERO
var _ate := Vector2.ZERO
var _u := 0.0
var _duracao := 1.0
var _depois: Callable
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = Z_ATRAS
	_rng.randomize()
	_textura = ImageTexture.create_from_image(imagem())


## A nave como imagem (um pixel por caractere do desenho).
static func imagem() -> Image:
	var img := Image.create(String(DESENHO[0]).length(), DESENHO.size(), false, Image.FORMAT_RGBA8)
	for y in DESENHO.size():
		var linha: String = DESENHO[y]
		for x in linha.length():
			if CORES.has(linha[x]):
				img.set_pixel(x, y, CORES[linha[x]])
	return img


func estado() -> Estado:
	return _estado


# ---------- ordens ----------

## Aparece acoplada na borda esquerda de um quadro (o mapa): `ponto` é um ponto dessa borda.
## O painel solar da direita fica escondido atrás do quadro; um instante depois ela se
## desprende sozinha e passa a passear pela `zona`.
func surgir_acoplada(ponto: Vector2) -> void:
	_estado = Estado.ACOPLADA
	_movendo = false
	z_index = Z_ATRAS
	pos = ponto + Vector2(-8.0, 0.0)
	escala = 0.5
	_escala_alvo = 1.0
	alfa = 0.0
	_alfa_alvo = 1.0
	chama = 0.0
	_chama_alvo = 0.0
	_balanco = 0.0
	_espera_soltar = TEMPO_ACOPLADA


## Solta-se do quadro: uns jatinhos de gás no encaixe, um recuo devagar, e começa o passeio.
func soltar() -> void:
	if _estado != Estado.ACOPLADA:
		return
	_estado = Estado.EM_MANOBRA
	for i in 6:
		_soltar_poeira(pos + Vector2(8.0, _rng.randf_range(-4.0, 4.0)),
				Vector2(_rng.randf_range(-16.0, 4.0), _rng.randf_range(-12.0, 12.0)))
	_chama_alvo = 1.0
	_balanco = 1.0
	_mover(pos + Vector2(-26.0, -8.0), 1.0, _passear)


## Aparece saindo de trás de alguma coisa: `ponto` é um lugar escondido (atrás do mapa). Ela
## começa lá e já sai passeando pela `zona`.
func surgir_de_tras(ponto: Vector2) -> void:
	pos = ponto
	escala = 1.0
	_escala_alvo = 1.0
	alfa = 1.0
	_alfa_alvo = 1.0
	_passear()


## Vai até `alvo` (um ponto da tela) e pousa nele. No fim emite `pousou`.
## Se ela estava escondida, começa em `de_onde` (um lugar atrás do mapa) e sai de lá.
func viajar_e_pousar(alvo: Vector2, de_onde := SEM_PONTO) -> void:
	if _estado == Estado.ESCONDIDA:
		z_index = Z_ATRAS
		if de_onde.is_finite():
			pos = de_onde
		alfa = 1.0
	_estado = Estado.EM_MANOBRA
	_escala_alvo = 1.0
	_alfa_alvo = 1.0
	_chama_alvo = 1.0
	_balanco = 0.0
	var pousada := alvo + Vector2(0.0, -ALTURA_DAS_PERNAS)
	var acima := pousada + Vector2(0.0, -ALTURA_DE_APROXIMACAO)
	var chegar := func():
		z_index = Z_NA_FRENTE
		_mover(acima, clampf(pos.distance_to(acima) / VELOCIDADE_VIAGEM, 0.3, 0.9), func(): _descer(pousada, alvo))
	# Se algo a está tapando, primeiro ela sai de trás (ainda por trás) e só então vem para a frente.
	if z_index != Z_NA_FRENTE and _tapada(pos):
		var saida := _lugar_a_vista(pos, tela)
		_mover(saida, clampf(pos.distance_to(saida) / (VELOCIDADE_VIAGEM * 0.4), 0.2, 0.7), chegar)
	else:
		chegar.call()


## Levanta do ponto em que está pousada e sai de cima do mapa.
## Sem `esconderijo`, volta a passear pela `zona`. Com ele (um lugar atrás do mapa), vai até
## lá e some.
func decolar(esconderijo := SEM_PONTO) -> void:
	if _estado != Estado.POUSADA:
		return
	_estado = Estado.EM_MANOBRA
	_chama_alvo = 1.0
	_poeira(pos + Vector2(0.0, ALTURA_DAS_PERNAS))
	_mover(pos + Vector2(0.0, -ALTURA_DE_APROXIMACAO), 0.35, func():
		if esconderijo.is_finite():
			_ir_esconder(esconderijo)
		else:
			var livre := _lugar_a_vista(pos, zona)
			_mover(livre, clampf(pos.distance_to(livre) / (VELOCIDADE_VIAGEM * 0.5), 0.3, 1.4), _passear))


## Para de passear, vai para trás do mapa (o `esconderijo`) e some.
func esconder(esconderijo: Vector2) -> void:
	if _estado == Estado.ESCONDIDA or _estado == Estado.POUSADA:
		return
	_estado = Estado.EM_MANOBRA
	_ir_esconder(esconderijo)


## Some aos poucos, onde estiver (a tela está indo embora ou vai mudar).
func sumir() -> void:
	_estado = Estado.ESCONDIDA
	_movendo = false
	_alfa_alvo = 0.0
	_chama_alvo = 0.0


# ---------- por dentro ----------

func _passear() -> void:
	_estado = Estado.PASSEANDO
	z_index = Z_ATRAS
	_balanco = 1.0
	_chama_alvo = 1.0
	_vel = Vector2.ZERO
	_novo_destino()


func _descer(pousada: Vector2, chao: Vector2) -> void:
	_chama_alvo = 0.0
	_mover(pousada, 0.34, func():
		_poeira(chao)
		_estado = Estado.POUSADA
		pousou.emit())


## Vai até um lugar à vista perto do esconderijo (pela frente, se estiver na frente), passa
## para trás e entra atrás do mapa. Lá fica invisível.
func _ir_esconder(esconderijo: Vector2) -> void:
	_balanco = 0.0
	var entrar := func():
		z_index = Z_ATRAS
		_mover(esconderijo, clampf(pos.distance_to(esconderijo) / (VELOCIDADE_VIAGEM * 0.4), 0.25, 1.2), func():
			_estado = Estado.ESCONDIDA
			alfa = 0.0
			_alfa_alvo = 0.0
			_chama_alvo = 0.0)
	if z_index == Z_NA_FRENTE:
		var porta := _lugar_a_vista(esconderijo, tela)
		_mover(porta, clampf(pos.distance_to(porta) / (VELOCIDADE_VIAGEM * 0.5), 0.3, 1.4), entrar)
	else:
		entrar.call()


## Começa um deslocamento suave de onde está até `ate`, em `duracao` segundos, e chama `depois`.
func _mover(ate: Vector2, duracao: float, depois: Callable) -> void:
	_de = pos
	_ate = ate
	_duracao = maxf(duracao, 0.01)
	_u = 0.0
	_depois = depois
	_movendo = true


## A parte da zona em que o centro da nave pode ficar sem ela sair da zona.
func _miolo(retangulo: Rect2) -> Rect2:
	var r := retangulo.grow_individual(-MEIA_NAVE.x - 2.0, -MEIA_NAVE.y - 2.0, -MEIA_NAVE.x - 2.0, -MEIA_NAVE.y - 4.0)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return Rect2(retangulo.get_center(), Vector2.ZERO)
	return r


func _novo_destino() -> void:
	var dentro := _miolo(zona)
	# Na maior parte das vezes ela escolhe um lugar à vista; às vezes, qualquer lugar da zona
	# (e aí passa por trás do que houver nela).
	var tentativas := 12 if _rng.randf() < 0.6 else 1
	for i in tentativas:
		_destino = Vector2(_rng.randf_range(dentro.position.x, dentro.end.x),
				_rng.randf_range(dentro.position.y, dentro.end.y))
		if not _tapada(_destino):
			break
	if _rng.randf() < 0.35:
		_pausa = _rng.randf_range(0.8, 2.2)


func _retangulos() -> Array:
	return obstaculos.call() if obstaculos.is_valid() else []


## true se a nave, com o centro em `p`, ficaria (mesmo que em parte) atrás de alguma coisa.
func _tapada(p: Vector2) -> bool:
	for r in _retangulos():
		if (r as Rect2).grow_individual(MEIA_NAVE.x, MEIA_NAVE.y, MEIA_NAVE.x, MEIA_NAVE.y + 2.0).has_point(p):
			return true
	return false


## O lugar à vista, dentro de `onde`, mais perto de `p`. Se não houver nenhum, o próprio `p`.
func _lugar_a_vista(p: Vector2, onde: Rect2) -> Vector2:
	var dentro := _miolo(onde)
	var melhor := p
	var menor := INF
	var y := dentro.position.y
	while y <= dentro.end.y:
		var x := dentro.position.x
		while x <= dentro.end.x:
			var q := Vector2(x, y)
			var d := p.distance_squared_to(q)
			if d < menor and not _tapada(q):
				menor = d
				melhor = q
			x += 8.0
		y += 8.0
	return melhor


func _soltar_poeira(p: Vector2, v: Vector2) -> void:
	_poeiras.append({"p": p, "v": v, "vida": 1.0, "r": 1.0})


## Poeira levantada no pouso e na decolagem: dois lequinhos, um para cada lado.
func _poeira(p: Vector2) -> void:
	for lado in [-1.0, 1.0]:
		for i in 4:
			_soltar_poeira(p + Vector2(lado * 3.0, 0.0),
					Vector2(lado * _rng.randf_range(14.0, 34.0), _rng.randf_range(-12.0, 2.0)))


func _process(delta: float) -> void:
	_t += delta
	escala = move_toward(escala, _escala_alvo, delta * 2.5)
	chama = move_toward(chama, _chama_alvo, delta * 3.0)
	alfa = move_toward(alfa, _alfa_alvo, delta * 2.5)

	if _estado == Estado.ACOPLADA:
		_espera_soltar -= delta
		if _espera_soltar <= 0.0 and escala >= 1.0:
			soltar()

	if _movendo:
		_u += delta / _duracao
		pos = _de.lerp(_ate, smoothstep(0.0, 1.0, minf(_u, 1.0)))
		if _u >= 1.0:
			_movendo = false
			var proximo := _depois
			_depois = Callable()
			if proximo.is_valid():
				proximo.call()
	elif _estado == Estado.PASSEANDO:
		if _pausa > 0.0:
			_pausa -= delta
			_vel = _vel.lerp(Vector2.ZERO, minf(1.0, 3.0 * delta))
		else:
			var falta := _destino - pos
			if falta.length() < 6.0:
				_novo_destino()
				falta = _destino - pos
			var pressa := 1.0 if zona.has_point(pos) else PRESSA_FORA_DA_ZONA
			_vel = _vel.lerp(falta.normalized() * VELOCIDADE_PASSEIO * pressa, minf(1.0, 1.6 * delta))
		pos += _vel * delta

	for i in range(_poeiras.size() - 1, -1, -1):
		var f: Dictionary = _poeiras[i]
		f["p"] += f["v"] * delta
		f["v"] *= maxf(0.0, 1.0 - 2.5 * delta)
		f["vida"] -= delta * 1.8
		if f["vida"] <= 0.0:
			_poeiras.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for f in _poeiras:
		draw_rect(Rect2((f["p"] as Vector2).floor() - Vector2.ONE, Vector2(2.0, 2.0)),
				Color(COR_DA_POEIRA, 0.6 * f["vida"] * alfa))
	if alfa <= 0.0:
		return
	var sobe_e_desce := roundf(sin(_t * 1.8)) * _balanco if _estado != Estado.POUSADA else 0.0
	draw_set_transform((pos + Vector2(0.0, sobe_e_desce)).round(), 0.0, Vector2(escala, escala))
	var tam := Vector2(_textura.get_size())
	var canto := (-tam / 2.0).floor()
	# Chama do motor: curta e clara, quase transparente, tremendo um pouco.
	if chama > 0.05:
		var pisca := int(_t * 12.0) % 2
		var base := canto + Vector2(12.0, tam.y - 1.0)
		draw_rect(Rect2(base, Vector2(5.0, 1.0 + chama)), Color(COR_DA_CHAMA, 0.55 * alfa))
		draw_rect(Rect2(base + Vector2(1.0, 0.0), Vector2(3.0, (2.0 + pisca) * chama)), Color(COR_DA_CHAMA, 0.8 * alfa))
	draw_texture(_textura, canto, Color(1.0, 1.0, 1.0, alfa))
	draw_set_transform(Vector2.ZERO)
