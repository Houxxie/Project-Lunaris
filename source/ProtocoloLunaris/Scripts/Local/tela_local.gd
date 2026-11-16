extends Control
## Tela do horizonte de um local. De cima para baixo, cada faixa com um assunto:
##
## 1. MISSÃO (faixa_missao.gd): data do pouso, duração, o adiamento (com o botão de desfazer)
##    e, à direita, o horizonte em uso (com relevo, ou o plano de 0°).
## 2. HORIZONTE: o que se vê no céu no instante do cursor (terreno, Sol e Terra).
## 3. LEITURA NO CURSOR (leitura_cursor.gd): a data do cursor e, para o Sol e a Terra, se está
##    visível, a folga sobre o horizonte, elevação, azimute e o próximo pôr ou nascer.
## 4. LINHA DO TEMPO (num quadro translúcido): os botões PLAY e +7d (adiar 7 dias) e, para
##    cada corpo, a faixa de visibilidade com os números na mesma linha e o limite do
##    requisito. Os números contam do pouso até o cursor; com o cursor no fim da missão (como
##    a tela abre), são os totais.
## 5. STATUS (quadro_requisitos.gd): o veredito na missão inteira e, quando o local não
##    atende, o botão de atenção, que abre a explicação do porquê.
##
## Todos os números vêm de `Dados` (que lê os JSON); esta tela só mostra.
## A interface é montada por código em `_ready`, dentro de um quadro de 640x360.
##
## Uso de IA: escrito com assistência do Claude (Anthropic).

## Emitido quando o usuário quer voltar ao mapa e esta tela está aberta por cima dele.
signal fechar_pedido

const TEMPO_DA_ANIMACAO := 14.0   # segundos para o PLAY percorrer a missão inteira
const MARGEM := 8.0
const LARGURA := 624.0            # largura das faixas (tela menos as margens)

var _quadro: Control
var _cursor := 0.0
var _tocando := false

var _titulo: Label
var _faixa: FaixaMissao
var _vista: VistaHorizonte
var _leitura: LeituraCursor
var _linha: LinhaTempo
var _requisitos: QuadroRequisitos
var _botao_adiar: Button
var _limites: Dictionary = {}     # o requisito de cada linha da tabela (ver `_limites_por_linha`)


func _ready() -> void:
	_quadro = Estilo.preparar_tela(self)
	_cursor = Dados.fim_missao()
	_montar_barra()
	_montar_faixa_da_missao()
	_montar_horizonte()
	_montar_linha_do_tempo()
	_montar_requisitos()
	Dados.missao_mudou.connect(_ao_mudar_missao)
	_atualizar()


func _process(delta: float) -> void:
	if not _tocando:
		return
	var duracao := Dados.fim_missao() - Dados.inicio_missao
	_cursor += delta * duracao / TEMPO_DA_ANIMACAO
	if _cursor >= Dados.fim_missao():
		_cursor = Dados.fim_missao()
		_tocar(false)
	_atualizar_cursor()


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()   # o Esc é desta tela, não do mapa que está por baixo
		_voltar()
	elif evento.is_action_pressed("ui_right"):
		_mover_cursor(_cursor + Dados.HORA * (24.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0))
	elif evento.is_action_pressed("ui_left"):
		_mover_cursor(_cursor - Dados.HORA * (24.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0))
	elif evento.is_action_pressed("ui_accept"):
		_tocar(not _tocando)


# ---------- montagem ----------

func _montar_barra() -> void:
	var voltar := Estilo.botao_imagem("back-to-map")
	voltar.position = Vector2(MARGEM, 4)
	voltar.connect("acionado", _voltar)
	_quadro.add_child(voltar)

	# Só o nome do local (sem sigla, sem parêntese, sem coordenadas).
	_titulo = Estilo.rotulo("", 8, Estilo.CIANO)
	Estilo.em_negrito(_titulo)
	_titulo.clip_text = true
	_titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Estilo.colocar(_quadro, _titulo, Rect2(102, 4, 342, 20))

	var sobre := Estilo.botao_imagem("about")
	sobre.position = Vector2(450, 4)
	sobre.tooltip_text = Config.t("Context and facts about this site")
	sobre.connect("acionado", _abrir_sobre)
	_quadro.add_child(sobre)

	var fontes := Estilo.botao_imagem("sources")
	fontes.position = Vector2(544, 4)
	fontes.connect("acionado", func(): DialogoTexto.abrir_fontes(self))
	_quadro.add_child(fontes)


## Faixa fina logo abaixo dos botões: a missão (pouso, duração, adiamento) e o horizonte em uso.
func _montar_faixa_da_missao() -> void:
	_faixa = FaixaMissao.new()
	_faixa.position = Vector2(MARGEM, 28)
	_faixa.size = Vector2(LARGURA, 14)
	_quadro.add_child(_faixa)


func _montar_horizonte() -> void:
	_vista = VistaHorizonte.new()
	_vista.position = Vector2(MARGEM, 45)
	_vista.size = Vector2(LARGURA, 152)
	_quadro.add_child(_vista)

	# Logo abaixo do gráfico, a leitura do instante do cursor: a data e, para o Sol e a Terra,
	# se está visível, a folga sobre o horizonte, elevação, azimute e o próximo pôr ou nascer.
	_leitura = LeituraCursor.new()
	_leitura.position = Vector2(MARGEM, 200)
	_leitura.size = Vector2(LARGURA, 36)
	_quadro.add_child(_leitura)


## Quadro translúcido com o PLAY à esquerda e a linha do tempo (faixas + números) ao lado.
func _montar_linha_do_tempo() -> void:
	var quadro_linha := Panel.new()
	quadro_linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fundo bem transparente e borda apagada: agrupa sem pesar na tela.
	quadro_linha.add_theme_stylebox_override("panel",
			Estilo.caixa(Color(Estilo.MARINHO, 0.45), Color(Estilo.INDIGO, 0.45), 0.0))
	Estilo.colocar(_quadro, quadro_linha, Rect2(MARGEM, 239, LARGURA, 88))

	# PLAY e +7d empilhados à esquerda, alinhados com as faixas: o de cima começa na altura
	# do topo da faixa do Sol e o de baixo termina na altura do pé da faixa "Both".
	var topo_linha := 243.0
	var topo_faixas := topo_linha + LinhaTempo.TOPO_LINHAS
	var pe_faixas := topo_faixas + 2.0 * LinhaTempo.PASSO + LinhaTempo.ALTURA_FAIXA
	# Os dois botões dividem a altura das três faixas: cada um fica com metade.
	var lado := floorf((pe_faixas - topo_faixas - 1.0) / 2.0)
	var tocar := Estilo.botao_quadrado("play-icon", lado)
	tocar.tooltip_text = Config.t("Play / pause the mission (Space)")
	tocar.position = Vector2(MARGEM + 8.0, topo_faixas)
	tocar.connect("acionado", func(): _tocar(not _tocando))
	_quadro.add_child(tocar)

	var adiar := Estilo.botao_quadrado("delay-icon", lado)
	# Esta imagem é um pouco mais alta que larga (a etiqueta "+7d" passa da moldura).
	adiar.custom_minimum_size = Vector2(lado, pe_faixas - topo_faixas - lado - 1.0)
	adiar.tooltip_text = Config.t("Delay the landing by 7 days")
	adiar.position = Vector2(MARGEM + 8.0, topo_faixas + lado + 1.0)
	adiar.connect("acionado", Dados.adiar_7_dias)
	_quadro.add_child(adiar)
	_botao_adiar = adiar

	_linha = LinhaTempo.new()
	_linha.position = Vector2(MARGEM + 46.0, topo_linha)
	_linha.size = Vector2(LARGURA - 54.0, 80)
	_linha.cursor_mudou.connect(func(t: float):
		_tocar(false)
		_mover_cursor(t))
	_quadro.add_child(_linha)


## Faixa de baixo: o veredito do local na missão inteira e, quando ele não atende, o botão de
## atenção que abre a explicação (cada requisito com o valor, o limite e o antes do adiamento).
func _montar_requisitos() -> void:
	_requisitos = QuadroRequisitos.new()
	_requisitos.position = Vector2(MARGEM, 330)
	_requisitos.size = Vector2(LARGURA, 24)
	_quadro.add_child(_requisitos)


## O requisito que vale para cada linha da tabela (Sol, Terra, os dois), tirado das regras dos
## dados: corpo -> {"campo", "op", "valor", "texto"}. É o que a coluna LIMIT mostra e o que as
## marcas ao lado dos números conferem.
func _limites_por_linha() -> Dictionary:
	var limites := {}
	for regra in Dados.regras():
		var caminho: Array = CalculoLunar.INDICADORES.get(regra["indicator"], [])
		if caminho.is_empty() or limites.has(caminho[0]):
			continue
		limites[caminho[0]] = {"campo": caminho[1], "op": regra["op"], "valor": float(regra["value"]),
				"texto": QuadroRequisitos.texto_do_limite(regra)}
	return limites


# ---------- comportamento ----------

## Volta ao mapa. Normalmente esta tela está aberta POR CIMA do mapa (quem a abriu foi a tela
## do mapa, que continua viva por baixo): então ela só pede para ser fechada, e o mapa faz a
## animação de recolhê-la para a nave. Se ela for a cena atual (aberta sozinha, num teste),
## troca de cena como antes.
func _voltar() -> void:
	if get_tree().current_scene == self:
		Dados.ir_para(Dados.CENA_MAPA)
	else:
		fechar_pedido.emit()


func _ao_mudar_missao() -> void:
	_tocar(false)
	_cursor = Dados.fim_missao()   # missão nova: os números voltam a mostrar os totais
	_atualizar()


func _tocar(ligar: bool) -> void:
	_tocando = ligar
	if ligar and _cursor >= Dados.fim_missao() - 1.0:
		_cursor = Dados.inicio_missao


func _mover_cursor(t: float) -> void:
	_cursor = clampf(t, Dados.inicio_missao, Dados.fim_missao())
	_atualizar_cursor()


func _tem_dados() -> bool:
	return Dados.avaliar(Dados.local_id)["status"] == "ok"


func _atualizar() -> void:
	var id := Dados.local_id
	var l := Dados.local(id)
	_titulo.text = Dados.nome_limpo(id)
	_faixa.mostrar(id)
	_limites = _limites_por_linha()
	_requisitos.mostrar(id)
	_botao_adiar.disabled = not Dados.pode_adiar()   # adiado, o fim da missão passaria do fim dos dados
	_atualizar_cursor()


func _atualizar_cursor() -> void:
	# Faixas: as janelas do JSON recortadas pela missão inteira.
	var recortadas := {}
	if _tem_dados():
		var todas := Dados.janelas(Dados.local_id)
		for corpo in ["sun", "earth", "both"]:
			recortadas[corpo] = CalculoLunar.recortar(todas[corpo], Dados.inicio_missao, Dados.fim_missao())
	_linha.mostrar(Dados.inicio_missao, Dados.fim_missao(), _cursor, recortadas, _contas_ate_o_cursor(), _limites)
	_vista.mostrar(Dados.local_id, _cursor, Dados.inicio_missao, Dados.fim_missao())
	_leitura.mostrar(Dados.local_id, _cursor, Dados.inicio_missao, Dados.fim_missao())


## Indicadores contados do pouso até o cursor, por corpo. São as mesmas contas da missão
## inteira (recortar + estatísticas), só que com o fim no cursor. {} sem dados ou no pouso.
func _contas_ate_o_cursor() -> Dictionary:
	var a := Dados.inicio_missao
	var contas := {}
	if _tem_dados() and _cursor > a:
		var todas := Dados.janelas(Dados.local_id)
		for corpo in ["sun", "earth", "both"]:
			contas[corpo] = CalculoLunar.estatisticas(CalculoLunar.recortar(todas[corpo], a, _cursor), a, _cursor)
	return contas


func _abrir_sobre() -> void:
	var id := Dados.local_id
	var l := Dados.local(id)
	var ciano := Estilo.CIANO.to_html(false)
	var fraco := Estilo.TEXTO_FRACO.to_html(false)
	# O contexto e os fatos vêm dos arquivos de dados (em inglês); as traduções estão em
	# traducoes.gd, e os números das frases continuam sendo os dos dados.
	var s := "[b]%s[/b]\n%s\n\n" % [Dados.nome_limpo(id), Dados.fmt_coordenadas(id)]
	s += "%s\n\n" % Config.t(l.get("context", ""))
	var fatos: Array = Dados.textos.get("site_facts", {}).get(id, {}).get("facts", [])
	if not fatos.is_empty():
		s += "[color=#%s]%s[/color]\n" % [ciano, Config.t("FACTS FROM THE DATA")]
		for f in fatos:
			s += "- %s\n" % Config.t(f)
		s += "\n"
	s += "[color=#%s]%s[/color]\n" % [ciano, Config.t("HOW THE MOON IS DIFFERENT")]
	for f in Dados.textos.get("general_facts", []):
		s += "- %s\n" % Config.t(f)
	if String(l.get("source", "")) != "":
		s += "\n[color=#%s]%s[/color]" % [fraco, Config.t("Coordinates source: %s") % Config.t(l["source"])]
	DialogoTexto.abrir(self, Config.t("%s - about this site") % id, s)
