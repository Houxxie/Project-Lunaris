class_name DialogoTexto
extends Control
## Janela de texto por cima da tela: usada pelos botões HELP, ABOUT e SOURCES.
##
## Abrir:  DialogoTexto.abrir(self, "Título", "texto em BBCode")
## Fechar: botão X, tecla Esc ou clique fora da janela. Ela se recolhe para o canto de onde abriu.
##
## Uso de IA: escrito com assistência do Claude (Anthropic).

const TAMANHO := Vector2(460, 270)

var _painel: PanelContainer
var _escuro: ColorRect
var _largura := 0.0
var _fechando := false


static func abrir(de: Node, titulo: String, bbcode: String, tamanho := TAMANHO) -> DialogoTexto:
	var d := DialogoTexto.new()
	var cena := Estilo.tela_de(de)   # a tela que pediu a janela (mapa, horizonte...)
	# Na fonte pixelada só existem os tamanhos 8 e 16; na fonte lisa o título usa 11.
	var pixel: bool = cena is Control and cena.theme == Estilo.tema(true)
	d._montar(titulo, bbcode, tamanho, 16 if pixel else 11, pixel)
	cena.add_child(d)
	return d


## Guia rápido da tela do mapa (botão HELP): o que a tela faz, como usar e como ler a lista.
## `lua_inteira`: true no mapa da Lua inteira, false no mapa do polo sul.
static func abrir_guia(de: Node, lua_inteira: bool) -> DialogoTexto:
	var ciano := Estilo.CIANO.to_html(false)
	var bom := Estilo.BOM.to_html(false)
	var ruim := Estilo.RUIM.to_html(false)
	var fraco := Estilo.TEXTO_FRACO.to_html(false)
	var s := ""

	# Os parágrafos ficam em traducoes.gd (tabela LONGOS), nos três idiomas.
	s += _titulo_de_secao("WHAT THIS SCREEN DOES")
	s += Config.longo("guia_tela_lua" if lua_inteira else "guia_tela_polo") + "\n"
	s += Config.longo("guia_tela_escolha") + "\n\n"

	s += _titulo_de_secao("HOW TO USE IT")
	s += Config.longo("guia_uso_1") + "\n"
	s += Config.longo("guia_uso_2") % [int(Dados.DURACAO_MIN_H / 24.0), int(Dados.DURACAO_MAX_H / 24.0)] + "\n"
	s += Config.longo("guia_uso_3") + "\n"
	s += Config.longo("guia_uso_4") + "\n"
	s += Config.longo("guia_uso_5") + "\n\n"

	s += _titulo_de_secao("HOW TO READ THE LIST")
	s += Config.longo("guia_lista_cores") % [bom, ruim] + "\n"
	s += Config.longo("guia_lista_horas") + "\n"
	s += Config.longo("guia_lista_significado") + "\n\n"

	s += _titulo_de_secao("THE REQUIREMENTS")
	for regra in Dados.regras():
		s += "- %s: %s %s\n" % [Config.t(regra["name"]), _operador_em_palavras(regra["op"]),
				CalculoLunar.formatar(float(regra["value"]), regra.get("unit", ""))]
	s += Config.longo("guia_requisitos_fim") + "\n"
	s += "[color=#%s]%s.[/color]\n\n" % [fraco, Config.t(Dados.requisitos.get("label", ""))]

	s += _titulo_de_secao("WHY LONG MISSIONS TURN RED")
	s += Config.longo("guia_missoes_longas") % int(Dados.DURACAO_MAX_H / 24.0) + "\n\n"

	s += _titulo_de_secao("BEST DATES")
	s += Config.longo("guia_recomendados") + "\n\n"

	s += "[color=#%s]%s[/color]" % [fraco, Config.t(Dados.textos.get("footer", ""))]
	return abrir(de, Config.t("QUICK GUIDE"), s, Vector2(560, 300))


static func _titulo_de_secao(texto: String) -> String:
	return "[color=#%s][b]%s[/b][/color]\n" % [Estilo.CIANO.to_html(false), Config.t(texto)]


static func _operador_em_palavras(op: String) -> String:
	match op:
		"<=": return Config.t("at most")
		"<": return Config.t("less than")
		">=": return Config.t("at least")
		">": return Config.t("more than")
	return op


## Diálogo "Sources & assumptions", montado com os textos de texts_en.json.
static func abrir_fontes(de: Node) -> DialogoTexto:
	var t: Dictionary = Dados.textos
	var ciano := Estilo.CIANO.to_html(false)
	var fraco := Estilo.TEXTO_FRACO.to_html(false)
	# Os textos vêm dos arquivos de dados (em inglês); as traduções estão em traducoes.gd.
	var s := "[color=#%s]%s[/color]\n" % [ciano, Config.t("SOURCES")]
	for fonte in t.get("sources", []):
		s += "[b]%s[/b]\n%s\n" % [Config.t(fonte["title"]), Config.t(fonte["text"])]
		if String(fonte.get("url", "")) != "":
			s += "[color=#%s][url]%s[/url][/color]\n" % [ciano, fonte["url"]]
		s += "\n"
	s += "[b]%s[/b]\n%s\n\n" % [Config.t("Interface code"), Config.t("The Godot interface code was written with an AI coding assistant (Claude by Anthropic) following the team's specification. Every number on screen is read from the data files above and checked against reference values.")]
	s += "[color=#%s]%s[/color]\n" % [ciano, Config.t("ASSUMPTIONS AND SIMPLIFICATIONS")]
	for item in t.get("simplifications", []):
		s += "- %s\n" % Config.t(item)
	s += "\n[color=#%s]%s[/color]\n" % [ciano, Config.t(Dados.requisitos.get("label", "")).to_upper()]
	s += "%s\n" % Config.t(Dados.descricao_dos_requisitos())
	for regra in Dados.regras():
		s += "- %s %s %s\n" % [Config.t(regra["name"]), regra["op"], CalculoLunar.formatar(float(regra["value"]), regra.get("unit", ""))]
	s += "\n[color=#%s]%s[/color]" % [fraco, Config.t(t.get("footer", ""))]
	return abrir(de, Config.t("Sources & assumptions"), s)


func _ready() -> void:
	# Animação de abertura: o fundo escurece e a janela nasce do canto superior direito.
	_escuro.modulate.a = 0.0
	create_tween().tween_property(_escuro, "modulate:a", 1.0, 0.15)
	Config.som("abrir_info")
	Estilo.animar_abertura(_painel, _largura)


func _montar(titulo: String, bbcode: String, tamanho: Vector2, tamanho_titulo := 11, negrito := false) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # o tema vem da tela que abriu o diálogo
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	_largura = tamanho.x

	var escuro := ColorRect.new()
	_escuro = escuro
	escuro.color = Color(0, 0, 0.03, 0.72)
	escuro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	escuro.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			fechar())
	add_child(escuro)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)

	var painel := PanelContainer.new()
	_painel = painel
	painel.custom_minimum_size = tamanho
	painel.add_theme_stylebox_override("panel", Estilo.caixa(Estilo.MARINHO, Estilo.CIANO, 8.0))
	centro.add_child(painel)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 5)
	painel.add_child(coluna)

	var topo := HBoxContainer.new()
	coluna.add_child(topo)
	var t := Estilo.rotulo(titulo, tamanho_titulo, Estilo.CIANO)
	if negrito:
		Estilo.em_negrito(t)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(t)
	var fecha := Estilo.botao_quadrado("close", 18.0)
	fecha.tooltip_text = Config.t("Close (Esc)")
	fecha.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fecha.connect("acionado", fechar)
	topo.add_child(fecha)

	coluna.add_child(HSeparator.new())

	var texto := RichTextLabel.new()
	texto.bbcode_enabled = true
	texto.text = bbcode
	texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texto.selection_enabled = true
	texto.meta_clicked.connect(func(meta): OS.shell_open(str(meta)))
	coluna.add_child(texto)


## Fecha recolhendo a janela para o canto de onde ela abriu, enquanto o fundo clareia.
func fechar() -> void:
	if _fechando:
		return
	_fechando = true
	create_tween().tween_property(_escuro, "modulate:a", 0.0, 0.17)
	Config.som("fechar_info")
	await Estilo.animar_fechamento(_painel).finished
	queue_free()


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		fechar()
