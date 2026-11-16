class_name JanelaConfig
extends Control
## Janela de configurações: idioma (English, Português, Español), volume da música e volume
## dos efeitos sonoros. Abre pelo botão de engrenagem do menu principal.
##
## Tudo o que muda aqui é guardado em `Config` (que grava no computador do usuário).
## Trocar o idioma atualiza os textos desta janela na hora e avisa as telas pelo sinal
## `Config.idioma_mudou`.
## Fechar: botão X, tecla Esc ou clique fora.
##
## Uso de IA: escrito com assistência do Claude (Anthropic).

const LARGURA := 216.0

var _painel: PanelContainer
var _escuro: ColorRect
var _titulo: Label
var _rotulo_idioma: Label
var _botoes_idioma := {}        # idioma -> Button
var _rotulo_musica: Label
var _rotulo_sfx: Label
var _valor_musica: Label
var _valor_sfx: Label
var _fechar: Button
var _fechando := false


static func abrir(de: Node) -> JanelaConfig:
	var j := JanelaConfig.new()
	Estilo.tela_de(de).add_child(j)
	return j


func _ready() -> void:
	theme = Estilo.tema()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # fonte pixelada nítida
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50

	_escuro = ColorRect.new()
	_escuro.color = Color(0, 0, 0.03, 0.72)
	_escuro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_escuro.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			fechar())
	add_child(_escuro)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)

	_painel = PanelContainer.new()
	_painel.custom_minimum_size.x = LARGURA
	_painel.add_theme_stylebox_override("panel", Estilo.caixa(Estilo.MARINHO, Estilo.CIANO, 8.0))
	centro.add_child(_painel)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 5)
	_painel.add_child(coluna)

	# Título e X.
	var topo := HBoxContainer.new()
	coluna.add_child(topo)
	_titulo = Estilo.rotulo("", 8, Estilo.CIANO)
	Estilo.em_negrito(_titulo)
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(_titulo)
	_fechar = Estilo.botao_quadrado("close", 16.0)
	_fechar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fechar.connect("acionado", fechar)
	topo.add_child(_fechar)
	coluna.add_child(HSeparator.new())

	# Idioma: um botão por idioma, cada um escrito no próprio idioma.
	_rotulo_idioma = Estilo.rotulo("", 8, Estilo.TEXTO_FRACO)
	coluna.add_child(_rotulo_idioma)
	var linha_idioma := HBoxContainer.new()
	linha_idioma.add_theme_constant_override("separation", 4)
	coluna.add_child(linha_idioma)
	for idioma in Config.IDIOMAS:
		var b := Estilo.botao_texto(Config.NOMES_DOS_IDIOMAS[idioma])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 14
		b.pressed.connect(func(): Config.definir_idioma(idioma))
		linha_idioma.add_child(b)
		_botoes_idioma[idioma] = b
	coluna.add_child(HSeparator.new())

	# Volumes.
	var musica := _linha_de_volume(coluna, "musica", Config.volume_musica, Config.definir_volume_musica)
	_rotulo_musica = musica[0]
	_valor_musica = musica[1]
	var sfx := _linha_de_volume(coluna, "efeitos-sonoros", Config.volume_sfx, Config.definir_volume_sfx)
	_rotulo_sfx = sfx[0]
	_valor_sfx = sfx[1]

	Config.idioma_mudou.connect(_atualizar_textos)
	_atualizar_textos()

	# Animação de abertura, igual à das outras janelas.
	_escuro.modulate.a = 0.0
	create_tween().tween_property(_escuro, "modulate:a", 1.0, 0.15)
	Estilo.animar_abertura(_painel, LARGURA)


## Uma linha de volume: ícone, nome, barra deslizante de 0 a 100 e o valor em %.
## Devolve [rótulo do nome, rótulo do valor].
func _linha_de_volume(coluna: VBoxContainer, icone: String, valor: float, ao_mudar: Callable) -> Array:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 4)
	coluna.add_child(linha)
	linha.add_child(Estilo.icone(icone, 16.0))
	var nome := Estilo.rotulo("", 8, Estilo.TEXTO)
	nome.custom_minimum_size.x = 92
	nome.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha.add_child(nome)
	var barra := HSlider.new()
	barra.min_value = 0
	barra.max_value = 100
	barra.step = 5
	barra.value = roundf(valor * 100.0)
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	barra.custom_minimum_size.y = 12
	barra.focus_mode = Control.FOCUS_NONE
	barra.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	linha.add_child(barra)
	var texto := Estilo.rotulo("%d%%" % int(barra.value), 8, Estilo.CIANO)
	texto.custom_minimum_size.x = 26
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	texto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha.add_child(texto)
	barra.value_changed.connect(func(v: float):
		texto.text = "%d%%" % int(v)
		ao_mudar.call(v / 100.0))
	return [nome, texto]


func _atualizar_textos() -> void:
	_titulo.text = Config.t("SETTINGS")
	_rotulo_idioma.text = Config.t("LANGUAGE")
	_rotulo_musica.text = Config.t("MUSIC")
	_rotulo_sfx.text = Config.t("SOUND EFFECTS")
	_fechar.tooltip_text = Config.t("Close (Esc)")
	# O idioma em uso fica destacado.
	for idioma in _botoes_idioma:
		var b: Button = _botoes_idioma[idioma]
		if idioma == Config.idioma:
			b.add_theme_stylebox_override("normal", Estilo.caixa(Color(Estilo.CIANO, 0.22), Estilo.CIANO, 2.0))
			b.add_theme_color_override("font_color", Estilo.CIANO)
		else:
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_color_override("font_color")


## Fecha recolhendo a janela para o canto de onde ela abriu, enquanto o fundo clareia.
func fechar() -> void:
	if _fechando:
		return
	_fechando = true
	create_tween().tween_property(_escuro, "modulate:a", 0.0, 0.17)
	Config.som("fechar_tela")
	await Estilo.animar_fechamento(_painel).finished
	queue_free()


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		fechar()
