extends Control
## Menu principal: EXPLORE abre o mapa; QUIT fecha o programa; a engrenagem (canto de cima, à
## direita) abre as configurações (idioma e volumes).

var _saltando := false   # true depois de apertar EXPLORE (a transição para o mapa já começou)


func _ready() -> void:
	Dados.usar_base(Dados.BASE_MENU)  # o menu usa a tela base 320x180; o resto do programa, 640x360
	# No navegador não existe "fechar o programa": get_tree().quit() não funciona lá.
	$BotaoSair.visible = not OS.has_feature("web")
	_montar_engrenagem()
	Config.idioma_mudou.connect(_atualizar_idioma)
	_atualizar_idioma()
	# O som do EXPLORE toca no instante do clique (a ação em si espera o "flash" do botão).
	$BotaoNavegar.pressed.connect(func():
		if not _saltando:
			Config.som("explorar"))
	# Enquanto o menu está parado, adianta o que a tela do mapa precisa para abrir (carregar a
	# cena e achar as missões recomendadas). Assim a transição do EXPLORE não dá um tranco.
	Dados.adiantar_cena(Dados.CENA_MAPA)
	Dados.adiantar_recomendados()


## Botão de configurações: a imagem da engrenagem (que já tem a própria moldura), no canto
## superior direito. É um botão de imagem igual aos outros: sem borda e sem descrição.
func _montar_engrenagem() -> void:
	var b := Estilo.botao_quadrado("settings-icon", 20.0)
	b.name = "BotaoConfig"
	add_child(b)
	# 20x20 colado no canto, com 6 de margem.
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	b.offset_left = -26
	b.offset_right = -6
	b.offset_top = 6
	b.offset_bottom = 26
	b.connect("acionado", func(): JanelaConfig.abrir(self))


## Troca as imagens dos botões (elas têm o texto desenhado) para o idioma escolhido.
func _atualizar_idioma() -> void:
	$BotaoNavegar.icon = load(Config.caminho_do_botao("explore"))
	$BotaoSair.icon = load(Config.caminho_do_botao("quit"))


## EXPLORE: em vez de trocar de tela de uma vez, faz o salto (ver salto_espacial.gd).
func _on_botao_play_pressed() -> void:
	if _saltando:
		return
	_saltando = true
	Config.iniciar_musica()   # a música de fundo só começa aqui, com fade-in (e não para mais)
	SaltoEspacial.iniciar(self, Dados.CENA_MAPA)


func _on_botao_sair_pressed() -> void:
	get_tree().quit()
