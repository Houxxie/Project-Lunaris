class_name LinhaTempo
extends Control
## Linha do tempo da missão em forma de tabela. Cada linha é um corpo (Sol, Terra, os dois
## juntos): o nome, a faixa com os períodos visíveis pintados e, na mesma linha, os números:
##
##                                   VISIBLE        LONGEST GAP        LIMIT
##   Sun    [=========      ]   219.3 h (65%)      x 116.7 h       max 48 h
##   Earth  [===========    ]   247.7 h (74%)       x 88.3 h       max 72 h
##   Both   [=========      ]  = 219.3 h (65%)       116.7 h        min 60%
##
## - VISIBLE e LONGEST GAP contam do pouso até o cursor (com o cursor no fim da missão, são os
##   totais). LONGEST GAP é o maior período CONTÍNUO sem o corpo, não o total de horas sem ele.
## - LIMIT é o requisito que vale para aquela linha (`limites`), e a marca ao lado do número
##   diz se ele é atendido: X = não atende; quadradinho = atende.
##   Um limite máximo do maior período sem o corpo é marcado com X assim que é passado (não tem
##   volta). As outras marcas só aparecem com o cursor no fim da missão, porque antes disso o
##   número ainda pode mudar para os dois lados.
## - O usuário arrasta o cursor sobre as faixas; emite `cursor_mudou(t)` (Unix UTC, hora cheia).
##   A data do cursor fica na leitura logo acima (leitura_cursor.gd).
## - As faixas são as janelas do JSON recortadas pela missão (as mesmas usadas nas contas).
##
## Uso de IA: escrito com assistência do Claude (Anthropic).

signal cursor_mudou(t: float)

const NOMES := {"sun": "Sun", "earth": "Earth", "both": "Both"}
const TAM := 8                   # tamanho da fonte pixelada
const ALTURA_FAIXA := 12.0
const PASSO := 22.0              # distância entre uma linha e a próxima
const TOPO_LINHAS := 14.0        # acima disso ficam os títulos das colunas
const X_FAIXA := 44.0            # onde as faixas começam (à esquerda ficam os nomes)
## Larguras das três colunas de números, da direita para a esquerda, e o espaço entre elas.
const LARGURA_LIMITE := 58.0     # "máx. 100 h"
const LARGURA_INTERVALO := 134.0 # marca + "pelo menos 105.3 h" (o texto mais comprido, em português)
const LARGURA_VISIVEL := 104.0   # marca + "672.0 h (100%)"
const ESPACO := 10.0
const LARGURA_NUMEROS := LARGURA_VISIVEL + LARGURA_INTERVALO + LARGURA_LIMITE + 3.0 * ESPACO + 2.0

var inicio := 0.0
var fim := 1.0
var cursor := 0.0
var janelas: Dictionary = {}     ## {"sun": [[ini, fim]...], "earth": [...], "both": [...]} ou {} sem dados
var contas: Dictionary = {}      ## corpo -> estatísticas do pouso até o cursor ({} com o cursor no pouso)
## corpo -> o requisito daquela linha: {"campo": "hours" | "fraction" | "longest_gap_h",
## "op": "<=" ..., "valor": número, "texto": "max 48 h"}. Linha sem requisito não aparece aqui.
var limites: Dictionary = {}

var _arrastando := false


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_HSIZE


func mostrar(t_inicio: float, t_fim: float, t_cursor: float, janelas_recortadas: Dictionary,
		contas_ate_o_cursor: Dictionary = {}, limites_por_linha: Dictionary = {}) -> void:
	inicio = t_inicio
	fim = t_fim
	cursor = clampf(t_cursor, inicio, fim)
	janelas = janelas_recortadas
	contas = contas_ate_o_cursor
	limites = limites_por_linha
	queue_redraw()


## Área das três faixas.
func _trilho() -> Rect2:
	return Rect2(X_FAIXA, TOPO_LINHAS, size.x - X_FAIXA - LARGURA_NUMEROS, 2.0 * PASSO + ALTURA_FAIXA)


func _x(t: float) -> float:
	var r := _trilho()
	return r.position.x + (t - inicio) / (fim - inicio) * r.size.x


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		_arrastando = evento.pressed
		if evento.pressed:
			_mover(evento.position.x)
	elif evento is InputEventMouseMotion and _arrastando:
		_mover(evento.position.x)


func _mover(x: float) -> void:
	var r := _trilho()
	var f := clampf((x - r.position.x) / r.size.x, 0.0, 1.0)
	var t := roundf((inicio + f * (fim - inicio)) / Dados.HORA) * Dados.HORA
	cursor_mudou.emit(clampf(t, inicio, fim))


## Escreve `texto` terminando em `x_fim`. Com `status` ("met" ou "not_met"), põe a marca dele
## logo antes do texto.
func _direita(fonte: Font, texto: String, x_fim: float, y: float, cor: Color, status := "") -> void:
	var w := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM).x
	draw_string(fonte, Vector2(x_fim - w, y), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM, cor)
	if status != "":
		Estilo.desenhar_marca(self, Vector2(x_fim - w - 9.0, y - 6.0), status)


## A marca de um número da linha `corpo`, coluna `campo`: "met", "not_met" ou "" (sem marca).
func _status(corpo: String, campo: String) -> String:
	if not limites.has(corpo) or not contas.has(corpo):
		return ""
	var limite: Dictionary = limites[corpo]
	# "hours" e "fraction" ficam na mesma coluna (VISIBLE); "longest_gap_h" na outra.
	if (limite["campo"] == "longest_gap_h") != (campo == "longest_gap_h"):
		return ""
	var atende := CalculoLunar.cumpre(float(contas[corpo][limite["campo"]]), limite["op"], limite["valor"])
	var no_fim := cursor >= fim - 1.0
	# Um máximo do maior período sem o corpo, uma vez passado, não volta: marca na hora.
	var sem_volta: bool = limite["campo"] == "longest_gap_h" and String(limite["op"]).begins_with("<")
	if not atende and (sem_volta or no_fim):
		return "not_met"
	return "met" if atende and no_fim else ""


func _draw() -> void:
	var fonte := Estilo.fonte()
	var negrito := Estilo.fonte(true)
	var r := _trilho()
	var sem_dados := janelas.is_empty()
	var fim_limite := size.x - 2.0
	var fim_intervalo := fim_limite - LARGURA_LIMITE - ESPACO
	var fim_visivel := fim_intervalo - LARGURA_INTERVALO - ESPACO

	_direita(fonte, Config.t("VISIBLE"), fim_visivel, 9.0, Estilo.TEXTO_FRACO)
	_direita(fonte, Config.t("LONGEST GAP"), fim_intervalo, 9.0, Estilo.TEXTO_FRACO)
	_direita(fonte, Config.t("LIMIT"), fim_limite, 9.0, Estilo.TEXTO_FRACO)

	var i := 0
	for corpo in ["sun", "earth", "both"]:
		var y := TOPO_LINHAS + i * PASSO
		var cor := Estilo.cor_corpo(corpo)
		draw_string(fonte, Vector2(0, y + 10.0), Config.t(NOMES[corpo]), HORIZONTAL_ALIGNMENT_LEFT, -1, TAM, cor)
		draw_rect(Rect2(r.position.x, y, r.size.x, ALTURA_FAIXA), Color(Estilo.INDIGO_ESCURO, 0.6))
		for j in janelas.get(corpo, []):
			var x0 := floorf(_x(j[0]))
			var x1 := maxf(ceilf(_x(j[1])), x0 + 1.0)
			draw_rect(Rect2(x0, y, x1 - x0, ALTURA_FAIXA), cor)
		# Números da linha: "-" sem dados; zeros com o cursor ainda no pouso.
		var visivel := "-" if sem_dados else Dados.fmt_horas(0.0)
		var maior := visivel
		if contas.has(corpo):
			var e: Dictionary = contas[corpo]
			visivel = "%s (%s)" % [Dados.fmt_horas(e["hours"]), Dados.fmt_pct(e["fraction"])]
			maior = Dados.fmt_horas(e["longest_gap_h"])
			if e["gap_touches_start"] or e["gap_touches_end"]:
				maior = "%s %s" % [Dados.rotulo_status("at_least"), maior]
		var status_visivel := _status(corpo, "hours")
		var status_maior := _status(corpo, "longest_gap_h")
		_direita(negrito, visivel, fim_visivel, y + 10.0, Estilo.RUIM if status_visivel == "not_met" else cor, status_visivel)
		_direita(negrito, maior, fim_intervalo, y + 10.0, Estilo.RUIM if status_maior == "not_met" else cor, status_maior)
		if limites.has(corpo) and not sem_dados:
			_direita(fonte, limites[corpo]["texto"], fim_limite, y + 10.0, Estilo.TEXTO_FRACO)
		i += 1

	# Marcas de dia (mais altas a cada 7 dias).
	var base := r.end.y + 3.0
	var dias := int(round((fim - inicio) / Dados.DIA))
	for d in dias + 1:
		var x := floorf(_x(inicio + d * Dados.DIA)) + 0.5
		var alto := d % 7 == 0
		draw_line(Vector2(x, base), Vector2(x, base + (4.0 if alto else 2.0)), Color(Estilo.TEXTO_FRACO, 0.9 if alto else 0.5), 1.0)
	if sem_dados:
		draw_string(fonte, Vector2(r.position.x + 6.0, TOPO_LINHAS + PASSO + 10.0),
				Dados.rotulo_status("insufficient_data"), HORIZONTAL_ALIGNMENT_LEFT, -1, TAM, Estilo.AVISO)

	# Cursor: um risco de cima a baixo das três faixas.
	var xc := floorf(_x(cursor)) + 0.5
	draw_line(Vector2(xc, TOPO_LINHAS - 3.0), Vector2(xc, base + 4.0), Estilo.CIANO, 1.0)
