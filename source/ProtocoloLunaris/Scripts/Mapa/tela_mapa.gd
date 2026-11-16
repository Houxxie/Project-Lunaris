extends Control
## Tela do mapa ("Lunar South Pole").
##
## 1. O usuário vê o mapa grande e centralizado, com os marcadores dos locais.
## 2. Embaixo, escolhe a data do pouso (calendário) e a duração (barra de 1 a 28 dias),
##    ou fica com a data recomendada, e aperta ANALYZE.
## 3. Só então aparece, na lateral, a lista "meet the requirements": sigla e horas com
##    Sol e Terra juntos, e os marcadores ganham a cor do status.
## Depois do primeiro ANALYZE a lista fica aberta e se atualiza sozinha quando a data ou a
## duração mudam. Voltar ao menu recomeça do estado inicial (lista escondida).
##
## Animações desta tela:
## - uma navezinha (nave.gd): no polo sul passeia na faixa livre à esquerda do mapa; na Lua
##   inteira só aparece com a lista aberta (ver `_modo_da_nave`). Ao clicar num local ela viaja
##   até ele e pousa, e a tela do horizonte cresce a partir dela (e volta para ela ao fechar);
## - trocar entre o polo sul e a Lua inteira é uma rolagem só do mapa, como quem vira o rosto;
##   o botão de trocar e o título são "apagados e digitados de novo";
## - voltar ao menu é o salto do EXPLORE ao contrário (salto_espacial.gd).
##
## A interface é montada por código em `_ready`, dentro de um quadro de 640x360.
##
## Uso de IA: escrito com assistência do Claude (Anthropic).

const MAPA_POLO := "south_pole_px"
const MAPA_GLOBAL := "global_px"
const AREA_MAPA := Rect2(8, 27, 624, 296)     # onde o mapa pode ficar (sem a lista)
const LARGURA_LISTA := 156.0
## Clicar num marcador do mapa ou numa linha da lista abre a tela do horizonte daquele local
## (Scenes/Main/tela_local.tscn: horizonte, linha do tempo, Delay 7 days).
## Mude para false para desligar o clique sem apagar nada.
const ABRIR_TELA_DO_LOCAL := true
## Tempo (s) com o mouse parado numa linha da lista até a ficha do local aparecer.
const ESPERA_DA_FICHA := 0.5
## Tempo (s) depois de a tela abrir até a nave surgir (dá tempo de a tela chegar do salto).
const ESPERA_DA_NAVE := 1.1
## Troca de mapa "virando o rosto": tempo (s) de cada metade (sair e chegar), o quanto a tela
## achata ao sair de vista e quantos pixels o céu corre.
const TEMPO_DE_VIRAR := 0.3
const ACHATADO := Vector2(0.6, 0.92)
const PASSO_DO_CEU := 320.0
## Botão de trocar de mapa "apagado e digitado": a parte de dentro da moldura onde ficam o
## ícone e o texto (em frações do tamanho do botão), a cor de fundo dessa parte (medida nas
## imagens dos botões) e em quantos degraus o texto aparece.
const MIOLO_DO_BOTAO := Rect2(0.07, 0.26, 0.86, 0.50)
const COR_DE_DENTRO_DO_BOTAO := Color("#0d152f")
const LETRAS_DO_BOTAO := 12.0
## Tela do horizonte crescendo a partir da nave e voltando para ela (s).
const TEMPO_ABRIR_HORIZONTE := 0.4
const TEMPO_FECHAR_HORIZONTE := 0.3

var _quadro: Control
var _mapa: MapaLunar
var _titulo: Label
var _botao_global: Button
var _botao_polo: Button
var _painel_lista: PanelContainer
var _lista: VBoxContainer
var _data: Label
var _recomendada: Button
var _lista_aberta := false
var _barra: PanelContainer
var _espera_ficha: Timer
var _ficha: FichaLocal
var _ficha_id := ""
var _ficha_linha: Control
var _botao_calendario: Button
var _deslizante: HSlider
var _duracao: Label
var _adiar: Button
var _analisar: Button
var _atualizando := false
var _botao_menu: Button
var _botao_ajuda: Button
var _linhas := {}                  # id do local -> a linha dele na lista (Button)
var _nave: Nave
var _escudo: Control               # segura os cliques enquanto uma animação acontece
var _ocupada := false              # true durante as animações que não podem ser interrompidas
var _lista_recolhida := false      # true enquanto a lista fica fechada à força (troca de mapa)
var _horizonte: Control            # a tela do horizonte, quando aberta por cima do mapa
var _fechando_horizonte := false


func _ready() -> void:
	_quadro = Estilo.preparar_tela(self)
	Dados.garantir_missao_inicial()
	_espera_ficha = Timer.new()
	_espera_ficha.one_shot = true
	_espera_ficha.timeout.connect(_mostrar_ficha)
	add_child(_espera_ficha)
	_montar_barra()
	_montar_mapa_e_lista()
	_montar_controles()
	_montar_nave()
	Dados.missao_mudou.connect(_atualizar)
	_trocar_mapa(Dados.mapa_id)
	Dados.adiantar_cena(Dados.CENA_LOCAL)   # a tela do horizonte fica pronta para abrir sem tranco


func _exit_tree() -> void:
	if is_instance_valid(_horizonte):
		_horizonte.queue_free()   # ela mora na raiz, fora desta tela


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_voltar_ao_menu()


## Volta ao menu com o salto ao contrário (ver salto_espacial.gd). O mapa recomeça do estado
## inicial (lista escondida): quem faz isso é o próprio salto, na hora da troca de tela.
func _voltar_ao_menu() -> void:
	if _ocupada:
		return
	_ocupar(true)
	_fechar_ficha()
	Config.som("voltar_menu")
	Config.parar_musica()   # a música some em fade-out e só volta no próximo EXPLORE
	SaltoEspacial.voltar(self, Dados.CENA_MENU)


## Liga ou desliga o "escudo": enquanto uma animação acontece, cliques e Esc são ignorados.
func _ocupar(sim: bool) -> void:
	_ocupada = sim
	_escudo.visible = sim


# ---------- montagem ----------

func _montar_barra() -> void:
	var menu := Estilo.botao_imagem("menu")
	_botao_menu = menu
	menu.position = Vector2(8, 4)
	menu.connect("acionado", _voltar_ao_menu)
	_quadro.add_child(menu)

	_titulo = Estilo.rotulo("", 16, Estilo.CIANO)
	Estilo.em_negrito(_titulo)
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Estilo.colocar(_quadro, _titulo, Rect2(100, 3, 440, 22))

	var ajuda := Estilo.botao_quadrado("help")
	_botao_ajuda = ajuda
	ajuda.position = Vector2(518, 4)   # quadrado, logo à esquerda do botão de trocar de mapa
	ajuda.connect("acionado", func(): DialogoTexto.abrir_guia(self, Dados.mapa_id == MAPA_GLOBAL))
	_quadro.add_child(ajuda)

	_botao_global = Estilo.botao_imagem("whole-moon")
	_botao_global.position = Vector2(544, 4)
	_botao_global.connect("acionado", func(): _virar_para(MAPA_GLOBAL))
	_quadro.add_child(_botao_global)

	_botao_polo = Estilo.botao_imagem("south-pole")
	_botao_polo.position = Vector2(544, 4)
	_botao_polo.connect("acionado", func(): _virar_para(MAPA_POLO))
	_quadro.add_child(_botao_polo)


func _montar_mapa_e_lista() -> void:
	_mapa = MapaLunar.new()
	_mapa.local_escolhido.connect(_abrir_local)
	_quadro.add_child(_mapa)
	if not ABRIR_TELA_DO_LOCAL:
		_mapa.mouse_default_cursor_shape = Control.CURSOR_ARROW  # nada para clicar por enquanto

	_painel_lista = PanelContainer.new()
	_painel_lista.visible = false
	_quadro.add_child(_painel_lista)
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 1)
	_painel_lista.add_child(_lista)


## Barra de baixo: data do pouso, duração e o botão ANALYZE.
func _montar_controles() -> void:
	var painel := PanelContainer.new()
	_barra = painel
	_quadro.add_child(painel)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 5)
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	painel.add_child(linha)

	linha.add_child(Estilo.rotulo(Config.t("LANDING"), 8, Estilo.TEXTO_FRACO))
	var coluna_data := VBoxContainer.new()
	coluna_data.add_theme_constant_override("separation", 0)
	coluna_data.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_child(coluna_data)
	_data = Estilo.rotulo(Dados.fmt_dia(Dados.inicio_missao), 8, Estilo.TEXTO)
	Estilo.em_negrito(_data)
	coluna_data.add_child(_data)
	# O texto verde é um botão: abre a lista de datas e durações recomendadas.
	_recomendada = Estilo.botao_texto(Config.t("BEST DATES"), Config.t("See the best landing dates and durations in the data"))
	var sublinhado := Estilo.caixa(Color(0, 0, 0, 0), Color(Estilo.BOM, 0.6), 0.0, 0)
	sublinhado.border_width_bottom = 1
	sublinhado.content_margin_bottom = 1
	var sublinhado_claro: StyleBoxFlat = sublinhado.duplicate()
	sublinhado_claro.border_color = Color.WHITE
	for estado in ["normal", "pressed"]:
		_recomendada.add_theme_stylebox_override(estado, sublinhado)
	for estado in ["hover", "hover_pressed"]:
		_recomendada.add_theme_stylebox_override(estado, sublinhado_claro)
	_recomendada.add_theme_color_override("font_color", Estilo.BOM)
	_recomendada.add_theme_color_override("font_pressed_color", Estilo.BOM)
	_recomendada.pressed.connect(_abrir_recomendados)
	coluna_data.add_child(_recomendada)

	_botao_calendario = Button.new()
	_botao_calendario.icon = load(Estilo.PASTA_ICONES + "data.png")
	_botao_calendario.expand_icon = true
	_botao_calendario.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_botao_calendario.custom_minimum_size = Vector2(20, 20)  # ícone de 64 px mostrado em 16 px (1/4 exato)
	_botao_calendario.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_botao_calendario.focus_mode = Control.FOCUS_NONE
	_botao_calendario.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_botao_calendario.tooltip_text = Config.t("Choose the landing date (UTC)")
	Estilo.som_de_passar(_botao_calendario)
	_botao_calendario.pressed.connect(_abrir_calendario)
	linha.add_child(_botao_calendario)

	linha.add_child(VSeparator.new())

	linha.add_child(Estilo.rotulo(Config.t("DURATION"), 8, Estilo.TEXTO_FRACO))
	_deslizante = HSlider.new()
	_deslizante.min_value = Dados.DURACAO_MIN_H / 24.0
	_deslizante.max_value = Dados.DURACAO_MAX_H / 24.0
	_deslizante.step = 1.0
	_deslizante.custom_minimum_size = Vector2(120, 12)
	_deslizante.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_deslizante.focus_mode = Control.FOCUS_NONE
	_deslizante.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	_deslizante.value_changed.connect(_ao_mudar_duracao)
	linha.add_child(_deslizante)
	_duracao = Estilo.rotulo("", 8, Estilo.TEXTO)
	Estilo.em_negrito(_duracao)
	_duracao.custom_minimum_size.x = 48
	linha.add_child(_duracao)

	# "+7d": adia o pouso em 7 dias, com a mesma duração, e mostra o efeito nos locais todos.
	# É o mesmo botão (e a mesma conta) da tela do horizonte.
	_adiar = Estilo.botao_quadrado("delay-icon", 20.0)
	_adiar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_adiar.tooltip_text = Config.t("Delay the landing by 7 days")
	_adiar.connect("acionado", _ao_adiar)
	linha.add_child(_adiar)

	linha.add_child(VSeparator.new())

	_analisar = Estilo.botao_texto(Config.t("ANALYZE"), Config.t("Check every site against the requirements for this mission"))
	Estilo.em_negrito(_analisar)
	_analisar.custom_minimum_size = Vector2(64, 20)
	_analisar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_analisar.add_theme_stylebox_override("normal", Estilo.caixa(Color(Estilo.CIANO, 0.18), Estilo.CIANO, 3.0))
	_analisar.add_theme_color_override("font_color", Estilo.CIANO)
	_analisar.pressed.connect(_ao_analisar)
	linha.add_child(_analisar)

	# Centraliza a barra embaixo do mapa, com a largura que o conteúdo pedir.
	var tam := painel.get_combined_minimum_size()
	tam.y = maxf(tam.y, 30.0)
	painel.size = tam
	painel.position = Vector2(roundf((640.0 - tam.x) / 2.0), 326.0)


# ---------- comportamento ----------

func _trocar_mapa(id_do_mapa: String) -> void:
	Dados.mapa_id = id_do_mapa
	var polo := id_do_mapa == MAPA_POLO
	_botao_global.visible = polo
	_botao_polo.visible = not polo
	_titulo.text = Config.t("LUNAR SOUTH POLE" if polo else "WHOLE MOON")
	_atualizar()


## Tamanho e posição do mapa: o maior possível na área livre, centralizado na tela.
## Com a lista aberta, se o mapa centralizado bateria nela (Lua inteira), ele encolhe para o
## espaço que sobra à esquerda.
func _posicionar_mapa() -> void:
	var m := Dados.mapa(Dados.mapa_id)
	var tam_mapa := Vector2(m.get("width", 256), m.get("height", 256))
	var area := AREA_MAPA
	var escala := minf(area.size.x / tam_mapa.x, area.size.y / tam_mapa.y)
	var limite_direito := _painel_lista.position.x - 8.0
	if Dados.analise_feita and area.get_center().x + tam_mapa.x * escala / 2.0 > limite_direito:
		area.size.x = limite_direito - area.position.x
		escala = minf(area.size.x / tam_mapa.x, area.size.y / tam_mapa.y)
	if _mapa.mapa_id != Dados.mapa_id or not is_equal_approx(_mapa.escala, escala):
		_mapa.mostrar(Dados.mapa_id, escala)
	_mapa.position = (area.get_center() - _mapa.size / 2.0).round()


func _atualizar() -> void:
	_atualizando = true
	_data.text = Dados.fmt_dia(Dados.inicio_missao)
	_deslizante.value = Dados.duracao_h / 24.0
	_duracao.text = _texto_dias(int(Dados.duracao_h / 24.0))
	_adiar.disabled = not Dados.pode_adiar()   # adiada, a missão passaria do fim dos dados
	_atualizando = false

	# Depois do primeiro ANALYZE a lista fica aberta e acompanha a data e a duração.
	# (Durante a troca de mapa ela fica recolhida e reabre na chegada.)
	var mostrar := Dados.analise_feita and not _lista_recolhida
	var status := {}
	if mostrar:
		var polo: Array = Dados.classificacao(Dados.ids_do_polo())
		var outros: Array = Dados.classificacao(Dados.ids_sem_terreno())
		for item in polo + outros:
			status[item["id"]] = item["status"]
		_montar_lista(polo, outros)
	_mapa.status_por_id = status
	_mapa.queue_redraw()

	_painel_lista.visible = mostrar
	_painel_lista.position.x = 632.0 - LARGURA_LISTA
	_posicionar_mapa()
	# No polo, a lista começa na altura do topo do mapa. Na Lua inteira (mapa mais baixo que
	# a lista), ela fica centralizada na altura do mapa, alinhada com a imagem da Lua.
	var y := AREA_MAPA.position.y
	if Dados.mapa_id == MAPA_GLOBAL:
		y = _mapa.position.y + (_mapa.size.y - _painel_lista.size.y) / 2.0
	_painel_lista.position.y = roundf(clampf(y, AREA_MAPA.position.y, AREA_MAPA.end.y - _painel_lista.size.y))
	if mostrar and not _lista_aberta:
		Estilo.animar_abertura(_painel_lista)
	_lista_aberta = mostrar


func _texto_dias(dias: int) -> String:
	return Config.dias(dias)


func _ao_analisar() -> void:
	Config.som("analisar")   # só no clique do botão, não toda vez que a lista abre
	Dados.analise_feita = true
	_atualizar()
	_orientar_nave()   # na Lua inteira, é com a lista aberta que a nave pode aparecer


## "+7d" na barra do mapa: adia o pouso em 7 dias. A lista abre junto (se ainda não estava
## aberta), porque sem ela não se vê o efeito; a linha "BEFORE DELAY" e as marcas de quem
## mudou de status aparecem nela.
func _ao_adiar() -> void:
	if not Dados.pode_adiar():
		return
	Dados.analise_feita = true
	Dados.adiar_7_dias()   # avisa a tela pelo sinal `missao_mudou`
	_orientar_nave()


func _abrir_calendario() -> void:
	var ponto := Vector2(_botao_calendario.global_position.x - 60.0, _barra.global_position.y - 2.0) - global_position
	Calendario.abrir(self, ponto, Dados.inicio_missao, Dados.data_minima(), Dados.data_maxima(),
			func(dia: float): Dados.definir_missao(dia, Dados.duracao_h))


func _ao_mudar_duracao(dias: float) -> void:
	if _atualizando:
		return
	Dados.definir_missao(Dados.inicio_missao, dias * 24.0)


## Lista de missões recomendadas (até 5 combinações de data e duração). Clicar numa linha
## aplica a data e a duração dela. O critério está em `Dados.recomendados()`.
func _abrir_recomendados() -> void:
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 2)
	# "BEST DATES" (e não "recommended missions"): é o melhor resultado nos dados, não uma
	# recomendação oficial.
	var titulo := Estilo.rotulo(Config.t("BEST DATES"), 8, Estilo.CIANO)
	Estilo.em_negrito(titulo)
	coluna.add_child(titulo)
	coluna.add_child(Estilo.rotulo(Config.t("WHEN THE MOST SOUTH POLE SITES\nMEET THE REQUIREMENTS"), 8, Estilo.TEXTO_FRACO))
	coluna.add_child(HSeparator.new())

	# Abre logo acima da barra de baixo, para a data escolhida continuar à vista.
	var ponto := Vector2(_recomendada.global_position.x - 6.0, _barra.global_position.y - 2.0) - global_position
	var janela := JanelaFlutuante.abrir(self, ponto, coluna)
	var lista := Dados.recomendados()
	if lista.is_empty():
		coluna.add_child(Estilo.rotulo(Config.t("NO SUCH DATES LEFT\nIN THE DATA"), 8, Estilo.AVISO))
	for r in lista:
		coluna.add_child(_linha_de_missao(janela, r, Estilo.BOM))

	# O caso oposto, com rótulo próprio: a missão de 14 dias em que menos locais atendem.
	var dificil := Dados.data_mais_dificil()
	if not dificil.is_empty():
		coluna.add_child(HSeparator.new())
		var rotulo := Estilo.rotulo(Config.t("HARDEST DATE"), 8, Estilo.RUIM)
		Estilo.em_negrito(rotulo)
		coluna.add_child(rotulo)
		coluna.add_child(_linha_de_missao(janela, dificil, Estilo.RUIM))


## Uma linha da janela de datas: data, duração e quantos locais do polo atendem. Clicar nela
## aplica a missão e fecha a janela. A missão em uso fica destacada.
func _linha_de_missao(janela: JanelaFlutuante, r: Dictionary, cor_da_contagem: Color) -> Button:
	var inicio: float = r["inicio"]
	var dias: int = r["dias"]
	var b := Button.new()
	Estilo.som_de_passar(b)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(196, 14)
	var atual := is_equal_approx(inicio, Dados.inicio_missao) and is_equal_approx(dias * 24.0, Dados.duracao_h)
	if atual:
		b.add_theme_stylebox_override("normal", Estilo.caixa(Color(Estilo.CIANO, 0.18), Estilo.CIANO, 2.0))
	b.pressed.connect(func():
		janela.fechar()
		Dados.definir_missao(inicio, dias * 24.0))
	var linha := HBoxContainer.new()
	linha.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	linha.offset_left = 5
	linha.offset_right = -5
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(linha)
	var data := Estilo.rotulo(Dados.fmt_dia(inicio), 8, Estilo.TEXTO)
	Estilo.em_negrito(data)
	data.custom_minimum_size.x = 74
	linha.add_child(data)
	var duracao := Estilo.rotulo(_texto_dias(dias), 8, Estilo.TEXTO)
	duracao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(duracao)
	linha.add_child(Estilo.rotulo(Config.t("%d OF %d") % [r["atendem"], r["total"]], 8, cor_da_contagem))
	for filho in linha.get_children():
		filho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


# ---------- lista "meet the requirements" ----------

func _montar_lista(polo: Array, outros: Array) -> void:
	_fechar_ficha()  # as linhas vão ser recriadas
	_linhas.clear()
	for filho in _lista.get_children():
		_lista.remove_child(filho)
		filho.queue_free()
	var atendem := 0
	for item in polo:
		if item["status"] == "met":
			atendem += 1

	var resumo := Estilo.rotulo(Config.t("%d OF %d MEET THE\nREQUIREMENTS") % [atendem, polo.size()], 8,
			Estilo.BOM if atendem > 0 else Estilo.RUIM)
	Estilo.em_negrito(resumo)
	_lista.add_child(resumo)
	# Depois de um "+7d": o status que cada local tinha antes, para marcar quem mudou.
	var antes := {}
	if Dados.inicio_antes_do_adiamento >= 0.0:
		_lista.add_child(Estilo.rotulo(Config.t("BEFORE DELAY: %d OF %d") % [
				Dados.quantos_atendem(Dados.ids_do_polo(), Dados.inicio_antes_do_adiamento), polo.size()],
				8, Estilo.TEXTO_FRACO))
		for item in Dados.classificacao(Dados.ids_do_polo() + Dados.ids_sem_terreno(), Dados.inicio_antes_do_adiamento):
			antes[item["id"]] = item["status"]
		# Desfaz todos os "+7d" de uma vez: volta para a data original.
		var desfazer := Estilo.botao_texto(Config.t("UNDO DELAY"),
				Config.t("Go back to the landing date before the delay"))
		desfazer.custom_minimum_size.y = 12
		desfazer.pressed.connect(Dados.desfazer_adiamento)
		_lista.add_child(desfazer)
	_lista.add_child(HSeparator.new())

	for item in polo:
		_lista.add_child(_linha_da_lista(item, antes.get(item["id"], "")))
	_lista.add_child(HSeparator.new())
	_lista.add_child(Estilo.rotulo(Config.t("OTHER SITES"), 8, Estilo.TEXTO_FRACO))
	for item in outros:
		_lista.add_child(_linha_da_lista(item, antes.get(item["id"], "")))

	_painel_lista.custom_minimum_size = Vector2(LARGURA_LISTA, 0)
	_painel_lista.size = Vector2(LARGURA_LISTA, 0)


## Uma linha da lista: marca de status, sigla e horas com Sol e Terra juntos.
## A marca tem forma além de cor (quadrado cheio = atende; X = não atende).
## `status_antes`: o status do local antes do último "+7d" ("" se não houve adiamento). Se ele
## mudou, a linha ganha uma setinha: para baixo (vermelha) se deixou de atender, para cima
## (verde) se passou a atender.
func _linha_da_lista(item: Dictionary, status_antes := "") -> Button:
	var id: String = item["id"]
	var cor := Estilo.cor_status(item["status"])
	var b := Button.new()
	_linhas[id] = b
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if ABRIR_TELA_DO_LOCAL else Control.CURSOR_ARROW
	b.custom_minimum_size = Vector2(0, 13)
	b.clip_contents = true
	b.add_theme_stylebox_override("normal", Estilo.caixa(Color(Estilo.INDIGO_ESCURO, 0.35), Color(0, 0, 0, 0), 2.0, 0))
	b.pressed.connect(func(): _abrir_local(id))
	b.mouse_entered.connect(func():
		Config.som("passar")
		_mapa.destacado = id if _mapa.tem_local(id) else ""
		_agendar_ficha(id, b))
	b.mouse_exited.connect(func():
		_mapa.destacado = ""
		_fechar_ficha())

	var linha := HBoxContainer.new()
	linha.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	linha.offset_left = 4
	linha.offset_right = -4
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_theme_constant_override("separation", 5)
	b.add_child(linha)

	linha.add_child(Estilo.marca_de_status(item["status"]))
	var sigla := Estilo.rotulo(id, 8, Estilo.TEXTO)
	Estilo.em_negrito(sigla)
	sigla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(sigla)
	if status_antes != "" and status_antes != item["status"]:
		linha.add_child(_seta_de_mudanca(item["status"] == "met"))
	var valor := "-"
	if item["valor"] != null:
		valor = Dados.fmt_horas(item["valor"])
	var v := Estilo.rotulo(valor, 8, cor)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	linha.add_child(v)
	for filho in linha.get_children():
		filho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## Setinha de 5x5 pixels que marca um local cujo status mudou com o adiamento.
func _seta_de_mudanca(melhorou: bool) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(5, 5)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var cor := Estilo.BOM if melhorou else Estilo.RUIM
		for i in 3:   # triângulo: 5, 3 e 1 pixels de largura
			var y := (2 - i) + 1 if melhorou else i + 1
			c.draw_rect(Rect2(i, y, 5 - 2 * i, 1), cor))
	return c


# ---------- ficha do local (mouse parado numa linha da lista) ----------

## Começa a contar a espera: se o mouse continuar na linha, a ficha abre.
func _agendar_ficha(id: String, linha: Control) -> void:
	_fechar_ficha()
	_ficha_id = id
	_ficha_linha = linha
	_espera_ficha.start(ESPERA_DA_FICHA)


func _fechar_ficha() -> void:
	_espera_ficha.stop()
	_ficha_linha = null
	if is_instance_valid(_ficha):
		_ficha.fechar()
	_ficha = null


func _mostrar_ficha() -> void:
	if not is_instance_valid(_ficha_linha) or not _ficha_linha.is_inside_tree():
		return
	# A ficha nasce do marcador do local NO MAPA. Se o local não aparece neste mapa (ex.: os
	# três locais distantes, quando o mapa é o do polo), ela sai da borda da linha da lista.
	var no_mapa: Variant = _mapa.posicao_global(_ficha_id)
	var lista := _painel_lista.get_global_rect()
	if no_mapa != null:
		_ficha = FichaLocal.abrir(self, no_mapa, _ficha_id, true, _mapa, lista)
	else:
		var r := _ficha_linha.get_global_rect()
		_ficha = FichaLocal.abrir(self, Vector2(r.position.x - 1.0, r.get_center().y).round(), _ficha_id, false, _mapa)


# ---------- a nave ----------

func _montar_nave() -> void:
	_nave = Nave.new()
	_nave.obstaculos = _obstaculos
	_nave.pos = Vector2(-24.0, 120.0)   # se for chamada antes de surgir, entra pela borda esquerda
	add_child(_nave)
	move_child(_nave, 1)   # logo depois do fundo de estrelas: atrás do quadro com o mapa e as barras
	resized.connect(_atualizar_zona_da_nave)

	_escudo = Control.new()
	_escudo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_escudo.mouse_filter = Control.MOUSE_FILTER_STOP
	_escudo.z_index = 20
	_escudo.visible = false
	add_child(_escudo)
	get_tree().create_timer(ESPERA_DA_NAVE).timeout.connect(_surgir_nave)


## Um instante depois de a tela abrir, a nave entra em cena (se for o caso: ver `_orientar_nave`).
func _surgir_nave() -> void:
	if _nave.estado() != Nave.Estado.ESCONDIDA:
		return   # já foi chamada para pousar antes de surgir
	if _ocupada:
		get_tree().create_timer(0.5).timeout.connect(_surgir_nave)   # espera a animação em curso
		return
	_orientar_nave()


## Onde a nave pode ficar depende do mapa aberto e da lista:
## - "faixa": no polo sul, ela passeia só na faixa livre à esquerda do mapa;
## - "livre": na Lua inteira com a lista aberta (o mapa fica menor), passeia pela tela toda,
##   por trás da lista e em volta do mapa;
## - "escondida": na Lua inteira sem a lista (o mapa ocupa a tela), ela não aparece. Só sai
##   de trás do mapa para pousar e volta para lá depois.
func _modo_da_nave() -> String:
	if Dados.mapa_id == MAPA_POLO:
		return "faixa"
	return "livre" if Dados.analise_feita else "escondida"


## A faixa livre à esquerda do mapa, do topo ao pé dele.
func _faixa_esquerda() -> Rect2:
	var m := _mapa.get_global_rect()
	return Rect2(0.0, m.position.y, m.position.x, m.size.y)


## Um lugar atrás do mapa, junto de um dos cantos de baixo (o mais perto de `perto_de`). É de
## lá que a nave sai, por baixo do mapa, e para lá que ela volta quando some.
func _esconderijo(perto_de: Vector2) -> Vector2:
	var m := _mapa.get_global_rect()
	var esquerdo := Vector2(m.position.x + 22.0, m.end.y - 12.0)
	var direito := Vector2(m.end.x - 22.0, m.end.y - 12.0)
	return esquerdo if perto_de.distance_squared_to(esquerdo) <= perto_de.distance_squared_to(direito) else direito


func _atualizar_zona_da_nave() -> void:
	_nave.tela = Rect2(Vector2.ZERO, size)
	_nave.zona = _faixa_esquerda() if _modo_da_nave() == "faixa" else _nave.tela


## Põe a nave no papel certo para a tela de agora. Chamada quando a tela abre, quando o mapa
## muda e quando a lista abre.
func _orientar_nave() -> void:
	_atualizar_zona_da_nave()
	var escondida := _nave.estado() == Nave.Estado.ESCONDIDA
	match _modo_da_nave():
		"faixa":
			if escondida:   # surge acoplada na borda esquerda do mapa e logo se desprende
				_nave.surgir_acoplada(_mapa.global_position + Vector2(0.0, 44.0))
		"livre":
			if escondida:   # sai de trás do mapa e passa a passear
				_nave.surgir_de_tras(_esconderijo(Vector2.ZERO))
		"escondida":
			_nave.esconder(_esconderijo(_nave.pos))


## O que tapa a nave quando ela passa por trás: o mapa, a lista, a barra de baixo e os botões.
func _obstaculos() -> Array:
	var lista: Array = [_mapa.get_global_rect(), _barra.get_global_rect(),
			_botao_menu.get_global_rect(), _botao_ajuda.get_global_rect(),
			(_botao_global if _botao_global.visible else _botao_polo).get_global_rect()]
	if _painel_lista.visible:
		lista.append(_painel_lista.get_global_rect())
	return lista


# ---------- troca de mapa "virando o rosto" ----------

## Troca entre o mapa do polo sul e o da Lua inteira como quem vira o rosto de uma tela para
## outra. Só o MAPA se mexe: ele corre para um lado, achatando, o céu corre junto, e o outro
## mapa chega pelo lado oposto. Os botões e as barras ficam parados. O botão de trocar de mapa
## e o título mudam como um texto sendo apagado e digitado de novo.
## Se a lista estiver aberta, ela se recolhe antes e reabre na chegada.
func _virar_para(id_do_mapa: String) -> void:
	if _ocupada or id_do_mapa == Dados.mapa_id:
		return
	_ocupar(true)
	_fechar_ficha()
	Config.som("trocar_tela")
	_nave.soltar()   # se ainda estava acoplada ao mapa, solta-se antes de ele sair de vista
	if id_do_mapa == MAPA_GLOBAL and not Dados.analise_feita:
		_nave.sumir()   # na Lua inteira sem a lista a nave não aparece
	var tinha_lista := _painel_lista.visible
	if tinha_lista:
		await Estilo.animar_fechamento(_painel_lista).finished
		_lista_recolhida = true
		_painel_lista.visible = false
		_lista_aberta = false

	# +1: olhamos para a direita (a Lua inteira fica "à direita"), então o mapa corre para a esquerda.
	var sentido := 1.0 if id_do_mapa == MAPA_GLOBAL else -1.0
	var longe := size.x
	var botao_velho := _botao_global if _botao_global.visible else _botao_polo
	var botao_novo := _botao_polo if botao_velho == _botao_global else _botao_global
	for filho in get_children():
		if filho is FundoEspacial:
			create_tween().tween_property(filho, "desvio:x", filho.desvio.x - sentido * PASSO_DO_CEU,
					TEMPO_DE_VIRAR * 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 1. o mapa sai; o botão e o título são "apagados", letra por letra
	_mapa.pivot_offset = _mapa.size / 2.0
	var saida := create_tween().set_parallel(true)
	saida.tween_property(_mapa, "position:x", _mapa.position.x - sentido * longe, TEMPO_DE_VIRAR) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	saida.tween_property(_mapa, "scale", ACHATADO, TEMPO_DE_VIRAR) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	saida.tween_method(func(v: float): _cortar_botao(botao_velho, v), 1.0, 0.0, TEMPO_DE_VIRAR)
	saida.tween_property(_titulo, "visible_ratio", 0.0, TEMPO_DE_VIRAR)
	await saida.finished

	# 2. a troca, com o mapa fora de vista e os textos apagados
	_cortar_botao(botao_velho, 1.0)   # ele fica escondido, já inteiro para a próxima vez
	_trocar_mapa(id_do_mapa)          # troca o mapa, o título e qual dos dois botões aparece
	_cortar_botao(botao_novo, 0.0)
	_titulo.visible_ratio = 0.0
	var lugar := _mapa.position.x     # onde o mapa novo deve parar
	_mapa.pivot_offset = _mapa.size / 2.0
	_mapa.scale = ACHATADO
	_mapa.position.x = lugar + sentido * longe

	# 3. o outro mapa chega; o botão e o título são "digitados"
	var entrada := create_tween().set_parallel(true)
	entrada.tween_property(_mapa, "position:x", lugar, TEMPO_DE_VIRAR) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	entrada.tween_property(_mapa, "scale", Vector2.ONE, TEMPO_DE_VIRAR) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	entrada.tween_method(func(v: float): _cortar_botao(botao_novo, v), 0.0, 1.0, TEMPO_DE_VIRAR)
	entrada.tween_property(_titulo, "visible_ratio", 1.0, TEMPO_DE_VIRAR)
	await entrada.finished
	_mapa.scale = Vector2.ONE
	_mapa.position.x = lugar
	_cortar_botao(botao_novo, 1.0)
	_titulo.visible_ratio = 1.0

	if tinha_lista:
		_lista_recolhida = false
		_atualizar()   # a lista reabre, com a animação de abertura
	_orientar_nave()
	_ocupar(false)


## Mostra só o começo do texto de um botão de imagem, como se o resto ainda não tivesse sido
## digitado: `corte` 1 = tudo à vista; 0 = tudo apagado. Uma "tampa" da cor de dentro do botão
## cobre o ícone e o texto da direita para a esquerda, em degraus (as "letras"), com um cursor
## ciano na ponta. A moldura do botão fica sempre inteira.
func _cortar_botao(botao: Button, corte: float) -> void:
	var tampa := botao.get_node_or_null("Tampa") as ColorRect
	if tampa == null:
		tampa = ColorRect.new()
		tampa.name = "Tampa"
		tampa.color = COR_DE_DENTRO_DO_BOTAO
		tampa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		botao.add_child(tampa)
		var novo_cursor := ColorRect.new()
		novo_cursor.name = "Cursor"
		novo_cursor.color = Estilo.CIANO
		novo_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		botao.add_child(novo_cursor)
	var miolo := Rect2(MIOLO_DO_BOTAO.position * botao.size, MIOLO_DO_BOTAO.size * botao.size)
	var passo := roundf(clampf(corte, 0.0, 1.0) * LETRAS_DO_BOTAO) / LETRAS_DO_BOTAO
	var x := miolo.position.x + miolo.size.x * passo
	tampa.visible = passo < 1.0
	tampa.position = Vector2(x, miolo.position.y)
	tampa.size = Vector2(miolo.end.x - x, miolo.size.y)
	var cursor := botao.get_node("Cursor") as ColorRect
	cursor.visible = passo > 0.0 and passo < 1.0
	cursor.position = Vector2(x, miolo.position.y + 1.0)
	cursor.size = Vector2(1.0, miolo.size.y - 2.0)


# ---------- tela do horizonte: abre a partir da nave ----------

## Clique num local (marcador ou linha da lista): a nave viaja até ele e pousa; a tela do
## horizonte então cresce a partir da nave, por cima do mapa.
func _abrir_local(id: String) -> void:
	if not ABRIR_TELA_DO_LOCAL or _ocupada:
		return
	_ocupar(true)
	_fechar_ficha()
	# Onde pousar: no marcador do local. Se ele não aparece neste mapa (os três locais
	# distantes, com o mapa do polo aberto), na linha dele na lista.
	var alvo := size / 2.0
	var no_mapa: Variant = _mapa.posicao_global(id)
	if no_mapa != null:
		alvo = (no_mapa as Vector2) - global_position
	elif _linhas.has(id) and is_instance_valid(_linhas[id]):
		var r: Rect2 = _linhas[id].get_global_rect()
		alvo = Vector2(r.position.x + 6.0, r.get_center().y) - global_position
	Dados.escolher_local(id)

	# A tela do horizonte é montada já agora, escondida, para não dar tranco na hora de abrir.
	# Ela fica na raiz, por cima desta tela (que continua viva por baixo).
	_horizonte = Dados.cena(Dados.CENA_LOCAL).instantiate()
	_horizonte.visible = false
	_horizonte.z_index = 10   # acima da nave, abaixo das janelas
	get_tree().root.add_child(_horizonte)
	_horizonte.set_process_unhandled_input(false)
	_horizonte.connect("fechar_pedido", _fechar_horizonte)

	# Na Lua inteira sem a lista a nave está escondida: ela sai de trás do mapa, por baixo.
	_nave.viajar_e_pousar(alvo, _esconderijo(alvo) if _modo_da_nave() == "escondida" else Nave.SEM_PONTO)
	await _nave.pousou
	Config.som("abrir_tela")   # a nave pousou: a tela do horizonte começa a abrir
	await _animar_horizonte(true)
	visible = false   # com o horizonte aberto por cima, o mapa não precisa ser desenhado


## A tela do horizonte pediu para fechar: ela se recolhe de volta para a nave, que então
## decola e volta a passear.
func _fechar_horizonte() -> void:
	if _fechando_horizonte or not is_instance_valid(_horizonte):
		return
	_fechando_horizonte = true
	visible = true
	Config.som("fechar_tela")
	await _animar_horizonte(false)
	_horizonte.queue_free()
	_horizonte = null
	_fechando_horizonte = false
	_atualizar_zona_da_nave()
	# Ela volta para onde estava: a passear na zona dela ou, na Lua inteira sem a lista, para
	# trás do mapa (e some).
	_nave.decolar(_esconderijo(_nave.pos) if _modo_da_nave() == "escondida" else Nave.SEM_PONTO)
	_ocupar(false)


## Faz a tela do horizonte crescer a partir da nave (`abrindo`) ou encolher de volta para ela.
## Enquanto dura, uma moldura ciano contorna a tela e segura os cliques.
func _animar_horizonte(abrindo: bool) -> void:
	var h := _horizonte
	var moldura := Panel.new()
	moldura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	moldura.mouse_filter = Control.MOUSE_FILTER_STOP
	moldura.z_index = 60   # acima de tudo o que há na tela do horizonte
	moldura.add_theme_stylebox_override("panel", Estilo.caixa(Color(0, 0, 0, 0), Estilo.CIANO, 0.0, 2))
	h.add_child(moldura)
	h.set_process_unhandled_input(false)
	h.pivot_offset = _nave.pos
	var t := create_tween()
	if abrindo:
		h.scale = Vector2.ONE * 0.02
		h.visible = true
		t.tween_property(h, "scale", Vector2.ONE, TEMPO_ABRIR_HORIZONTE) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		t.tween_property(h, "scale", Vector2.ONE * 0.02, TEMPO_FECHAR_HORIZONTE) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await t.finished
	moldura.queue_free()
	if abrindo:
		h.set_process_unhandled_input(true)
