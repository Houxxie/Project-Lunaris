class_name SaltoEspacial
extends CanvasLayer
## Transição do menu para o mapa, no estilo "salto para a velocidade da luz".
##
## 1. PARTIDA (ainda no menu): os botões somem em fade out, as estrelas se esticam em riscos
##    a partir do centro da tela e a logo vem na direção da câmera até passar por ela.
## 2. CLARÃO: a tela fica clara por um instante. A cena é trocada atrás dele, então a troca
##    (e a mudança da tela base de 320x180 para 640x360) não aparece.
## 3. CHEGADA (já no mapa): o clarão some, os riscos encolhem de volta para estrelas e a tela
##    do mapa vem de longe, do centro, até ocupar o lugar dela.
##
## Este nó fica na raiz da árvore, fora das telas, por isso continua vivo durante a troca de
## cena. Enquanto ele existe, cliques e teclas são ignorados.
##
## Uso (a partir do menu):  SaltoEspacial.iniciar(self, Dados.CENA_MAPA)
## A volta do mapa para o menu é a mesma animação ao contrário:  SaltoEspacial.voltar(self, Dados.CENA_MENU)
## Para mudar o ritmo, mexa só nas constantes abaixo.
##
## Uso de IA: escrito com assistência do Claude (Anthropic).

const TEMPO_BOTOES := 0.3      ## fade out dos botões (s)
const TEMPO_PARTIDA := 1.1     ## do clique até o clarão (s)
const TEMPO_CLARAO := 0.22     ## o clarão sobe nos últimos instantes da partida (s)
const TEMPO_CHEGADA := 0.85    ## do clarão até a tela do mapa parar no lugar (s)
const COR_CLARAO := Color("#e4f8ff")
const ZOOM_DA_LOGO := 18.0     ## quantas vezes a logo cresce até "passar pela câmera"
const RISCO_NA_PARTIDA := 6.0  ## até onde a ponta dos riscos vai (ver FundoEspacial.salto_frente)

var _clarao: ColorRect


## Começa o salto: anima a saída do `menu`, troca para a cena `destino` e anima a chegada.
static func iniciar(menu: Control, destino: String) -> void:
	var salto := SaltoEspacial.new()
	menu.get_tree().root.add_child(salto)
	salto._rodar(menu, destino)


func _ready() -> void:
	layer = 100   # por cima de tudo
	_clarao = ColorRect.new()
	_clarao.color = Color(COR_CLARAO, 0.0)
	_clarao.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clarao.mouse_filter = Control.MOUSE_FILTER_STOP   # segura os cliques durante a transição
	add_child(_clarao)


## Segura também o teclado (Esc, Enter...) enquanto a transição acontece.
func _input(_evento: InputEvent) -> void:
	get_viewport().set_input_as_handled()


func _rodar(menu: Control, destino: String) -> void:
	var arvore := get_tree()
	var id_do_menu := menu.get_instance_id()

	# ---------- 1. partida ----------
	var partida := create_tween().set_parallel(true)
	for nome in ["BotaoNavegar", "BotaoSair", "BotaoConfig"]:
		var botao: Control = menu.get_node_or_null(nome)
		if botao != null:
			# `self_modulate` (e não `modulate`): a animação do próprio botão mexe no `modulate`
			partida.tween_property(botao, "self_modulate:a", 0.0, TEMPO_BOTOES)

	var fundo := _achar_fundo(menu)
	if fundo != null:
		fundo.cometas_ativos = false
		# A ponta de fora dispara devagar e acelera; a de dentro fica um tempo presa na estrela
		# (a estrela "estica") e só no fim sai atrás.
		partida.tween_property(fundo, "salto_frente", RISCO_NA_PARTIDA, TEMPO_PARTIDA) \
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		partida.tween_property(fundo, "salto_tras", RISCO_NA_PARTIDA * 0.6, TEMPO_PARTIDA * 0.35) \
				.set_delay(TEMPO_PARTIDA * 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var logo: Control = menu.get_node_or_null("Logotipo")
	if logo != null:
		logo.set_process(false)                  # para de flutuar
		logo.pivot_offset = logo.size / 2.0      # cresce a partir do próprio centro
		# Enquanto cresce, o centro da logo vai para o centro da tela: ela vem direto na câmera.
		var centro_da_logo := logo.position.y + logo.size.y / 2.0
		var descida := menu.size.y / 2.0 - centro_da_logo
		partida.tween_property(logo, "scale", Vector2.ONE * ZOOM_DA_LOGO, TEMPO_PARTIDA) \
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		partida.tween_property(logo, "position:y", logo.position.y + descida, TEMPO_PARTIDA * 0.8) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# Some ao passar pela câmera (bem no fim, quando já está maior que a tela).
		partida.tween_property(logo, "modulate:a", 0.0, TEMPO_PARTIDA * 0.22) \
				.set_delay(TEMPO_PARTIDA * 0.76).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	partida.tween_property(_clarao, "color:a", 1.0, TEMPO_CLARAO) \
			.set_delay(TEMPO_PARTIDA - TEMPO_CLARAO).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await partida.finished

	# ---------- 2. troca de cena, atrás do clarão ----------
	Dados.ir_para(destino)
	# A cena nova entra no fim do quadro: espera ela existir (no máximo 2 s, por segurança).
	var espera := 0
	while espera < 120 and (arvore.current_scene == null or arvore.current_scene.get_instance_id() == id_do_menu):
		await arvore.process_frame
		espera += 1
	var tela := arvore.current_scene
	if tela == null:
		queue_free()
		return
	await arvore.process_frame   # um quadro para a tela nova se arrumar por baixo do clarão

	# ---------- 3. chegada ----------
	var chegada := create_tween().set_parallel(true)
	var fundo_novo := _achar_fundo(tela)
	if fundo_novo != null:
		# Começa com riscos que vão do centro da tela até quase o lugar de cada estrela e
		# encolhe: primeiro a ponta de fora chega à estrela, depois a de dentro.
		fundo_novo.salto_frente = -0.9
		fundo_novo.salto_tras = -1.0
		chegada.tween_property(fundo_novo, "salto_frente", 0.0, TEMPO_CHEGADA * 0.55) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		chegada.tween_property(fundo_novo, "salto_tras", 0.0, TEMPO_CHEGADA) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var quadro := tela.find_child("Quadro", true, false) as Control
	if quadro != null:
		quadro.pivot_offset = quadro.size / 2.0
		quadro.scale = Vector2.ONE * 0.02
		quadro.modulate.a = 0.0
		chegada.tween_property(quadro, "scale", Vector2.ONE, TEMPO_CHEGADA) \
				.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		chegada.tween_property(quadro, "modulate:a", 1.0, TEMPO_CHEGADA * 0.3)

	chegada.tween_property(_clarao, "color:a", 0.0, TEMPO_CHEGADA * 0.4) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await chegada.finished
	if is_instance_valid(quadro):
		quadro.scale = Vector2.ONE
		quadro.pivot_offset = Vector2.ZERO   # como estava antes da transição
	queue_free()


## A volta: o mesmo salto de trás para a frente, do mapa para o menu.
## 1. SAÍDA (ainda no mapa): a tela do mapa encolhe para o centro, a nave some e as estrelas
##    viram riscos na direção do centro, até o clarão.
## 2. TROCA de cena atrás do clarão.
## 3. CHEGADA (já no menu): os riscos encolhem de fora para dentro até virarem estrelas, a
##    logo vem de perto da câmera e recua até o lugar dela, e os botões aparecem em fade in.
static func voltar(tela: Control, destino: String) -> void:
	var salto := SaltoEspacial.new()
	tela.get_tree().root.add_child(salto)
	salto._rodar_volta(tela, destino)


func _rodar_volta(tela: Control, destino: String) -> void:
	var arvore := get_tree()
	var id_da_tela := tela.get_instance_id()

	# ---------- 1. saída do mapa (a chegada do salto, ao contrário) ----------
	var saida := create_tween().set_parallel(true)
	var fundo := _achar_fundo(tela)
	if fundo != null:
		fundo.cometas_ativos = false
		saida.tween_property(fundo, "salto_tras", -1.0, TEMPO_CHEGADA) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		saida.tween_property(fundo, "salto_frente", -0.9, TEMPO_CHEGADA * 0.55) \
				.set_delay(TEMPO_CHEGADA * 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	for filho in tela.get_children():
		if filho is Nave:
			filho.sumir()
	var quadro := tela.find_child("Quadro", true, false) as Control
	if quadro != null:
		quadro.pivot_offset = quadro.size / 2.0
		saida.tween_property(quadro, "scale", Vector2.ONE * 0.02, TEMPO_CHEGADA) \
				.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
		saida.tween_property(quadro, "modulate:a", 0.0, TEMPO_CHEGADA * 0.3).set_delay(TEMPO_CHEGADA * 0.7)
	saida.tween_property(_clarao, "color:a", 1.0, TEMPO_CHEGADA * 0.4) \
			.set_delay(TEMPO_CHEGADA * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await saida.finished

	# ---------- 2. troca de cena, atrás do clarão ----------
	Dados.reiniciar()   # ao voltar ao menu, o mapa recomeça do estado inicial (lista escondida)
	Dados.ir_para(destino)
	var espera := 0
	while espera < 120 and (arvore.current_scene == null or arvore.current_scene.get_instance_id() == id_da_tela):
		await arvore.process_frame
		espera += 1
	var menu := arvore.current_scene
	if menu == null:
		queue_free()
		return
	await arvore.process_frame

	# ---------- 3. chegada ao menu (a partida do salto, ao contrário) ----------
	var chegada := create_tween().set_parallel(true)
	var botoes: Array = []
	for nome in ["BotaoNavegar", "BotaoSair", "BotaoConfig"]:
		var botao: Control = menu.get_node_or_null(nome)
		if botao != null:
			botao.self_modulate.a = 0.0
			botoes.append(botao)
			chegada.tween_property(botao, "self_modulate:a", 1.0, TEMPO_BOTOES).set_delay(TEMPO_PARTIDA - TEMPO_BOTOES)

	var fundo_do_menu := _achar_fundo(menu)
	if fundo_do_menu != null:
		fundo_do_menu.cometas_ativos = false
		fundo_do_menu.salto_frente = RISCO_NA_PARTIDA
		fundo_do_menu.salto_tras = RISCO_NA_PARTIDA * 0.6
		chegada.tween_property(fundo_do_menu, "salto_frente", 0.0, TEMPO_PARTIDA) \
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		chegada.tween_property(fundo_do_menu, "salto_tras", 0.0, TEMPO_PARTIDA * 0.35) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var logo: Control = menu.get_node_or_null("Logotipo")
	var lugar_da_logo := 0.0
	if logo != null:
		logo.set_process(false)   # só volta a flutuar quando chegar ao lugar
		lugar_da_logo = logo.position.y
		logo.pivot_offset = logo.size / 2.0
		logo.scale = Vector2.ONE * ZOOM_DA_LOGO
		logo.modulate.a = 0.0
		logo.position.y = lugar_da_logo + (menu.size.y / 2.0 - (lugar_da_logo + logo.size.y / 2.0))
		chegada.tween_property(logo, "scale", Vector2.ONE, TEMPO_PARTIDA) \
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		chegada.tween_property(logo, "position:y", lugar_da_logo, TEMPO_PARTIDA * 0.8) \
				.set_delay(TEMPO_PARTIDA * 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		chegada.tween_property(logo, "modulate:a", 1.0, TEMPO_PARTIDA * 0.22) \
				.set_delay(TEMPO_PARTIDA * 0.02).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	chegada.tween_property(_clarao, "color:a", 0.0, TEMPO_CLARAO) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await chegada.finished
	if is_instance_valid(logo):
		logo.scale = Vector2.ONE
		logo.position.y = lugar_da_logo
		logo.set_process(true)
	if is_instance_valid(fundo_do_menu):
		fundo_do_menu.cometas_ativos = true
	queue_free()


## O fundo de estrelas de uma tela (o primeiro filho que for um FundoEspacial).
static func _achar_fundo(tela: Node) -> FundoEspacial:
	for filho in tela.get_children():
		if filho is FundoEspacial:
			return filho
	return null
