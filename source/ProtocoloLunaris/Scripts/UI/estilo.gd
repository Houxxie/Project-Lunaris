class_name Estilo
extends RefCounted
## Cores, tema e pecinhas de interface usadas pelas telas do programa (mapa e local).
##
## As telas do programa usam a base 640x360, então os tamanhos aqui estão nessa escala
## (fonte 8 = 16 px numa janela de 1280x720).
##
## Uso de IA: escrito com assistência do Claude (Anthropic).

# ---------- paleta (a mesma família dos botões: azul-marinho, índigo e ciano) ----------
const TEXTO := Color("#e6f1ff")
const TEXTO_FRACO := Color("#93a4c7")
const CIANO := Color("#4fe3ff")
const INDIGO := Color("#5560b8")
const INDIGO_ESCURO := Color("#2a2f66")
const MARINHO := Color("#070b22")
const SOL := Color("#ffd24a")
const TERRA := Color("#5fb4ff")
const AMBOS := Color("#7df2a8")
const BOM := Color("#7df2a8")      # atende
const RUIM := Color("#ff7b6b")     # não atende
const AVISO := Color("#ffc857")    # dados insuficientes

const PASTA_BOTOES := "res://Assets/Sprites/botoes/"
const PASTA_ICONES := "res://Assets/Sprites/icones/"
const PROPORCAO_BOTAO := 512.0 / 116.0   # largura / altura das imagens de botão

static var _tema: Theme
static var _tema_pixel: Theme
static var _fonte: FontFile
static var _fonte_negrito: FontFile


static func cor_status(status: String) -> Color:
	match status:
		"met": return BOM
		"not_met": return RUIM
	return AVISO


static func cor_corpo(corpo: String) -> Color:
	match corpo:
		"sun": return SOL
		"earth": return TERRA
	return AMBOS


## Caixa de cor lisa com borda de 1 px (visual de painel pixel art).
static func caixa(fundo: Color, borda: Color, margem := 4.0, largura_borda := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fundo
	s.border_color = borda
	s.set_border_width_all(largura_borda)
	s.set_content_margin_all(margem)
	s.anti_aliasing = false
	return s


## A fonte pixelada do programa (5x7 pixels, em Assets/Fonts). Tem duas versões: normal e negrito.
## É uma fonte de tamanho fixo: use tamanho 8 (x1) ou 16 (x2); outros tamanhos não existem.
## Para dar ênfase, use MAIÚSCULAS, negrito ou cor, e não um tamanho intermediário.
static func fonte(negrito := false) -> FontFile:
	if _fonte == null:
		_fonte = load("res://Assets/Fonts/lunaris_pixel.fnt")
		_fonte_negrito = load("res://Assets/Fonts/lunaris_pixel_bold.fnt")
		for f in [_fonte, _fonte_negrito]:
			f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	return _fonte_negrito if negrito else _fonte


## Tema das telas do programa. Aplique na raiz da tela: `theme = Estilo.tema()`.
## `pixel = true` (padrão): tudo na fonte pixelada. `pixel = false`: fonte lisa antiga, usada
## só pela tela do local enquanto ela não é refeita.
static func tema(pixel := true) -> Theme:
	if pixel:
		if _tema_pixel == null:
			_tema_pixel = _montar_tema(true)
		return _tema_pixel
	if _tema == null:
		_tema = _montar_tema(false)
	return _tema


static func _montar_tema(pixel: bool) -> Theme:
	var t := Theme.new()
	t.default_font_size = 8
	if pixel:
		t.default_font = fonte()
		t.set_font("bold_font", "RichTextLabel", fonte(true))
		_estilo_do_deslizante(t)

	t.set_color("font_color", "Label", TEXTO)
	t.set_constant("line_spacing", "Label", 0)

	var normal := caixa(Color(INDIGO_ESCURO, 0.85), INDIGO, 2.0)
	var sobre := caixa(Color(INDIGO, 0.9), CIANO, 2.0)
	var apertado := caixa(Color(MARINHO, 0.95), CIANO, 2.0)
	var inativo := caixa(Color(MARINHO, 0.6), Color(INDIGO, 0.4), 2.0)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", sobre)
	t.set_stylebox("pressed", "Button", apertado)
	t.set_stylebox("hover_pressed", "Button", apertado)
	t.set_stylebox("disabled", "Button", inativo)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXTO)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", CIANO)
	t.set_color("font_focus_color", "Button", TEXTO)
	t.set_color("font_disabled_color", "Button", Color(TEXTO_FRACO, 0.5))
	t.set_font_size("font_size", "Button", 8)
	t.set_constant("h_separation", "Button", 2)

	t.set_stylebox("panel", "PanelContainer", caixa(Color(MARINHO, 0.88), INDIGO, 5.0))
	t.set_stylebox("panel", "Panel", caixa(Color(MARINHO, 0.88), INDIGO, 5.0))

	t.set_color("default_color", "RichTextLabel", TEXTO)
	t.set_font_size("normal_font_size", "RichTextLabel", 8)
	t.set_font_size("bold_font_size", "RichTextLabel", 8)
	t.set_constant("line_separation", "RichTextLabel", 1)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_stylebox("focus", "RichTextLabel", StyleBoxEmpty.new())

	for barra in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", barra, caixa(Color(MARINHO, 0.6), Color(0, 0, 0, 0), 2.0, 0))
		t.set_stylebox("grabber", barra, caixa(INDIGO, INDIGO, 2.0, 0))
		t.set_stylebox("grabber_highlight", barra, caixa(CIANO, CIANO, 2.0, 0))
		t.set_stylebox("grabber_pressed", barra, caixa(CIANO, CIANO, 2.0, 0))

	t.set_stylebox("panel", "TooltipPanel", caixa(MARINHO, CIANO, 3.0))
	t.set_color("font_color", "TooltipLabel", TEXTO)
	t.set_font_size("font_size", "TooltipLabel", 8)

	t.set_constant("separation", "VBoxContainer", 2)
	t.set_constant("separation", "HBoxContainer", 3)
	t.set_stylebox("separator", "HSeparator", _linha(Color(INDIGO, 0.6)))
	t.set_constant("separation", "HSeparator", 3)
	t.set_stylebox("separator", "VSeparator", _linha(Color(INDIGO, 0.6), true))
	t.set_constant("separation", "VSeparator", 5)
	return t


static func _linha(cor: Color, vertical := false) -> StyleBoxLine:
	var s := StyleBoxLine.new()
	s.color = cor
	s.thickness = 1
	s.vertical = vertical
	return s


## Visual da barra deslizante (HSlider): trilho fino e um puxador retangular, em pixels inteiros.
static func _estilo_do_deslizante(t: Theme) -> void:
	var trilho := caixa(Color(INDIGO_ESCURO, 0.9), INDIGO, 0.0)
	trilho.content_margin_top = 2
	trilho.content_margin_bottom = 2
	t.set_stylebox("slider", "HSlider", trilho)
	t.set_stylebox("grabber_area", "HSlider", caixa(Color(CIANO, 0.55), Color(CIANO, 0.55), 0.0, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", caixa(Color(CIANO, 0.8), Color(CIANO, 0.8), 0.0, 0))
	t.set_icon("grabber", "HSlider", _puxador(TEXTO))
	t.set_icon("grabber_highlight", "HSlider", _puxador(CIANO))
	t.set_icon("grabber_disabled", "HSlider", _puxador(TEXTO_FRACO))
	t.set_icon("tick", "HSlider", _puxador(Color(0, 0, 0, 0)))


static func _puxador(cor: Color) -> ImageTexture:
	var img := Image.create(5, 11, false, Image.FORMAT_RGBA8)
	img.fill(MARINHO)
	img.fill_rect(Rect2i(1, 1, 3, 9), cor)
	return ImageTexture.create_from_image(img)


## Animação de abertura das janelas (estilo cyberpunk): a janela nasce do próprio canto
## superior direito. Primeiro um risco de luz corre para a esquerda, depois ele se abre para
## baixo. Sem piscar: a cor fica fixa do começo ao fim.
## `largura` = largura final da janela (se o nó ainda não tiver tamanho definido).
## `para_cima` e `pela_esquerda` trocam o canto de onde ela nasce (inferior e/ou esquerdo);
## a ficha do local usa isso para nascer sempre da ponta do risco.
## Devolve o Tween, para quem quiser encadear algo depois da abertura.
## Para fechar, use `animar_fechamento`: a janela se recolhe para o mesmo canto.
static func animar_abertura(no: Control, largura := -1.0, para_cima := false, pela_esquerda := false) -> Tween:
	var largura_final := largura if largura > 0.0 else no.size.x
	no.pivot_offset = Vector2(0.0 if pela_esquerda else largura_final, no.size.y if para_cima else 0.0)
	no.scale = Vector2(0.02, 0.03)
	no.modulate = Color.WHITE
	var t := no.create_tween()
	t.tween_property(no, "scale", Vector2(1.0, 0.03), 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(no, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	no.set_meta("tween_da_janela", t)
	return t


## Animação de fechamento: o contrário da abertura. A janela se recolhe para o mesmo canto de
## onde nasceu (o pivô que `animar_abertura` deixou no nó): primeiro fecha na vertical até
## virar um risco de luz, depois o risco corre de volta para o canto.
## Não apaga o nó: quem chama espera o Tween terminar e então apaga.
static func animar_fechamento(no: Control) -> Tween:
	var abertura: Variant = no.get_meta("tween_da_janela", null)
	if abertura is Tween and abertura.is_valid():
		abertura.kill()   # fechou antes de terminar de abrir
	var t := no.create_tween()
	t.tween_property(no, "scale", Vector2(1.0, 0.03), 0.10).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_property(no, "scale", Vector2(0.02, 0.03), 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	no.set_meta("tween_da_janela", t)
	return t


## A tela (o nó logo abaixo da raiz) a que um nó pertence. As janelas se penduram nela, e não
## na "cena atual", porque a tela do horizonte abre por cima do mapa sem ser a cena atual.
static func tela_de(no: Node) -> Node:
	var raiz: Node = no.get_tree().root
	var tela := no
	while tela.get_parent() != null and tela.get_parent() != raiz:
		tela = tela.get_parent()
	return tela


## Deixa um texto em negrito (versão em negrito da mesma fonte pixelada).
static func em_negrito(no: Control) -> void:
	no.add_theme_font_override("font", fonte(true))


## Texto simples. `tamanho` em pixels da base 640x360.
static func rotulo(texto: String, tamanho := 8, cor := TEXTO) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	return l


## Texto que quebra linha sozinho (para parágrafos).
static func paragrafo(texto: String, tamanho := 7, cor := TEXTO) -> Label:
	var l := rotulo(texto, tamanho, cor)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## Botão pequeno de texto (para "?", "-7", "MENU"...).
static func botao_texto(texto: String, dica := "", tamanho := 8) -> Button:
	var b := Button.new()
	b.text = texto
	b.tooltip_text = dica
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", tamanho)
	som_de_passar(b)
	return b


## Faz um botão tocar o som de "passar o mouse por algo clicável" (se não estiver desabilitado).
static func som_de_passar(b: BaseButton) -> void:
	b.mouse_entered.connect(func():
		if not b.disabled:
			Config.som("passar"))


## Botão de imagem (arquivo em Assets/Sprites/botoes, sem a extensão), com a animação do
## `botao_animado.gd`. Ligue as ações no sinal `acionado`.
static func botao_imagem(nome: String, altura := 20.0) -> Button:
	var b := Button.new()
	b.set_script(load("res://Scripts/UI/botao_animado.gd"))
	b.set("sem_margens", true)
	b.icon = load(Config.caminho_do_botao(nome))   # a versão do idioma escolhido, se existir
	b.flat = true
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # imagem grande reduzida: precisa de filtro suave
	b.custom_minimum_size = Vector2(roundf(altura * PROPORCAO_BOTAO), altura)
	b.size = b.custom_minimum_size
	return b


## Botão de imagem QUADRADO (help, close, play-icon). Igual ao `botao_imagem`, mas com
## largura = altura. Ligue as ações no sinal `acionado`.
static func botao_quadrado(nome: String, lado := 20.0) -> Button:
	var b := botao_imagem(nome, lado)
	b.custom_minimum_size = Vector2(lado, lado)
	# O tamanho só "pega" depois que o botão entra na tela, então é acertado nesse momento.
	b.ready.connect(func(): b.size = b.custom_minimum_size)
	return b


## Ícone 64x64 do projeto mostrado em tamanho pequeno, com pixels nítidos.
static func icone(nome: String, lado := 16.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(PASTA_ICONES + nome + ".png")
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.custom_minimum_size = Vector2(lado, lado)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Marca de status de 5x5 pixels, desenhada num nó (`tela`) com o canto em `p`. A forma muda
## com o status, para não depender só da cor: quadrado cheio = atende; X = não atende;
## quadrado vazado = dados insuficientes.
static func desenhar_marca(tela: CanvasItem, p: Vector2, status: String) -> void:
	var cor := cor_status(status)
	p = p.floor()
	match status:
		"met":
			tela.draw_rect(Rect2(p, Vector2(5, 5)), cor)
		"not_met":
			for i in 5:
				tela.draw_rect(Rect2(p + Vector2(i, i), Vector2.ONE), cor)
				tela.draw_rect(Rect2(p + Vector2(4 - i, i), Vector2.ONE), cor)
		_:
			tela.draw_rect(Rect2(p + Vector2(0.5, 0.5), Vector2(4, 4)), cor, false, 1.0)


## A mesma marca como peça de interface (para as linhas da lista do mapa).
static func marca_de_status(status: String) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(5, 5)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func(): desenhar_marca(c, Vector2.ZERO, status))
	return c


## Quadradinho colorido (marca de status nas listas).
static func marca(cor: Color, lado := 5.0) -> ColorRect:
	var c := ColorRect.new()
	c.color = cor
	c.custom_minimum_size = Vector2(lado, lado)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Põe `no` dentro de `pai` numa posição e tamanho fixos (em pixels do quadro 640x360).
## O tamanho é aplicado DEPOIS de entrar na árvore: antes disso o nó ainda não recebeu o tema
## do programa e calcularia o tamanho mínimo com a fonte padrão (grande demais).
static func colocar(pai: Node, no: Control, retangulo: Rect2) -> void:
	pai.add_child(no)
	no.position = retangulo.position
	no.size = retangulo.size


## Painel com borda, posicionado à mão dentro do quadro 640x360.
static func painel(retangulo: Rect2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = retangulo.position
	p.size = retangulo.size
	p.custom_minimum_size = retangulo.size
	return p


## Monta a base de uma tela do programa: troca a base para 640x360, aplica o tema e devolve o
## "quadro" de 640x360 centralizado, onde a tela posiciona suas peças.
## `pixel = true`: fonte pixelada e texturas sem suavização (pixels nítidos).
static func preparar_tela(tela: Control, pixel := true) -> Control:
	Dados.usar_base(Dados.BASE_JOGO)
	tela.theme = tema(pixel)
	if pixel:
		tela.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tela.add_child(centro)
	var quadro := Control.new()
	quadro.name = "Quadro"
	quadro.custom_minimum_size = Vector2(Dados.BASE_JOGO)
	quadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(quadro)
	return quadro
