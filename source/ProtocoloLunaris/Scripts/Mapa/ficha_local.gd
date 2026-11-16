class_name FichaLocal
extends Control
## Ficha de um local. O usuário para o mouse 0,5 s numa linha da LISTA e a ficha aparece
## no MAPA, saindo do marcador daquele local.
##
## Animação: do marcador sai um risco que se estica um pouco para o lado menos poluído; na
## ponta dele abre uma janelinha; dentro dela o texto aparece como se estivesse sendo
## digitado num terminal.
##
## Conteúdo: nome completo (sem o parêntese), coordenadas e uma descrição de até 10 palavras.
## A fonte aqui é lisa (não pixelada), de largura fixa, no estilo de terminal.
##
## Uso de IA: escrito com assistência do Claude (Anthropic).

## A janela se ajusta ao texto: fica da largura da linha mais comprida (nome ou coordenadas),
## dentro destes limites. A descrição quebra linha para caber nessa largura.
const LARGURA_MIN := 150.0
const LARGURA_MAX := 192.0
const MARGEM := 4.0
const TAMANHO_FONTE := 8           # tamanhos de fonte são inteiros: de 7 para 8 é o passo mais perto de +10%
const COR_TEXTO := Color.WHITE
const COR_COORDENADAS := Color("#c9d6f2")
const LETRAS_POR_SEGUNDO := 75.0
const TEMPO_DA_LINHA := 0.14
const FOLGA_DO_MARCADOR := 5.0     # o risco começa logo fora do losango do marcador
## Descrições curtas (até 10 palavras) dos 5 locais com coordenada publicada, resumidas do
## campo `context` de horizons_1y.json.
## Os 9 pontos das regiões candidatas não têm texto próprio nos dados (lá o contexto deles é
## a mesma frase, só mudando o nome da região). O que os dados dizem de diferente sobre cada
## um é quanto do ano ele vê o Sol e a Terra, então a descrição deles é montada com esses dois
## números (ver `descricao`). Eles continuam sendo chamados de "sample point", não de local de pouso.
const DESCRICAO_DE_AMOSTRA := "Sample point: Sun visible %s of the year, Earth %s."
const DESCRICOES := {
	"CR1": "One of the most illuminated spots near the south pole.",
	"IM2": "NASA CLPS delivery by Intuitive Machines, landed 6 March 2025.",
	"CH3": "India's lander, 2023, about 600 km from the south pole.",
	"CE4": "First landing on the lunar far side, 3 January 2019.",
	"A11": "Equatorial near-side site, 20 July 1969. Two-week days and nights.",
}

static var _fonte: Font

var _origem := Vector2.ZERO        # o marcador no mapa (ou a borda da linha da lista)
var _do_marcador := true           # false = o local não está neste mapa; o risco sai da lista
var _evitar := Rect2()             # área que a janela não deve cobrir (a lista)
var _inicio := Vector2.ZERO        # onde o risco começa
var _cotovelo := Vector2.ZERO      # onde o risco dobra
var _ponta := Vector2.ZERO         # onde o risco termina e a janela nasce
var _progresso := 0.0:             # 0 = sem risco, 1 = risco inteiro
	set(v):
		_progresso = v
		queue_redraw()
var _painel: PanelContainer
var _texto: RichTextLabel
var _fechando := false
var _tween_do_risco: Tween


## Fonte lisa de largura fixa (a do sistema: Consolas no Windows). Onde não houver nenhuma
## (versão web), o Godot usa a fonte lisa padrão dele.
static func fonte() -> Font:
	if _fonte == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "DejaVu Sans Mono", "Menlo", "Courier New", "monospace"])
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_fonte = f
	return _fonte


## Descrição curta do local, no idioma escolhido (as traduções ficam em traducoes.gd).
static func descricao(id: String) -> String:
	if DESCRICOES.has(id):
		return Config.t(DESCRICOES[id])
	# Ponto de amostra: as frações do ano com Sol e com Terra, do resumo com relevo dos dados
	# (terrain.summary). São os mesmos números que aparecem nos fatos da janela ABOUT.
	var resumo: Dictionary = Dados.local(id).get("terrain", {}).get("summary", {})
	if resumo.has("sun") and resumo.has("earth"):
		return Config.t(DESCRICAO_DE_AMOSTRA) % [
			Dados.fmt_pct(resumo["sun"]["fraction"]), Dados.fmt_pct(resumo["earth"]["fraction"])]
	return ""   # sem resumo nos dados não há o que dizer (hoje os 9 pontos de amostra têm)


## Abre a ficha do local `id`.
## - `origem`: de onde o risco sai, em coordenadas globais (o marcador no mapa).
## - `do_marcador`: true se a origem é um marcador (o risco pode ir para qualquer lado);
##   false se é a borda esquerda de uma linha da lista (o risco só vai para a esquerda).
## - `mapa`: para contar os marcadores que a janela cobriria e escolher o lado mais limpo.
## - `evitar`: retângulo que a janela não deve cobrir (a lista).
static func abrir(de: Node, origem: Vector2, id: String, do_marcador := true,
		mapa: MapaLunar = null, evitar := Rect2()) -> FichaLocal:
	var f := FichaLocal.new()
	f._origem = origem
	f._do_marcador = do_marcador
	f._evitar = evitar
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE   # não rouba o mouse da lista
	f.z_index = 30
	f.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	f._montar(id)
	Estilo.tela_de(de).add_child(f)
	f._animar(mapa)
	return f


## Fecha fazendo o caminho de volta: a janela se recolhe para a ponta do risco e o risco se
## recolhe para o marcador.
func fechar() -> void:
	if _fechando:
		return
	_fechando = true
	if is_instance_valid(_tween_do_risco):
		_tween_do_risco.kill()   # fechou antes de o risco terminar de sair
	if _painel.modulate.a > 0.0:
		await Estilo.animar_fechamento(_painel).finished
		if not is_inside_tree():
			return
		_painel.visible = false
	var volta := create_tween()
	volta.tween_property(self, "_progresso", 0.0, TEMPO_DA_LINHA * 0.7)
	await volta.finished
	queue_free()


func _montar(id: String) -> void:
	_painel = PanelContainer.new()
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_theme_stylebox_override("panel", Estilo.caixa(Color(Estilo.MARINHO, 0.96), Estilo.CIANO, MARGEM))
	_painel.modulate.a = 0.0   # invisível até a animação começar
	add_child(_painel)

	# Largura do texto: a da linha mais comprida entre o nome e as coordenadas.
	var linha_nome := "> " + Dados.nome_limpo(id)
	var linha_coordenadas := "  " + Dados.fmt_coordenadas(id)
	var largura := 0.0
	for linha in [linha_nome, linha_coordenadas]:
		largura = maxf(largura, fonte().get_string_size(linha, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANHO_FONTE).x)
	largura = clampf(ceilf(largura) + 2.0, LARGURA_MIN, LARGURA_MAX)

	_texto = RichTextLabel.new()
	_texto.custom_minimum_size.x = largura
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texto.bbcode_enabled = true
	_texto.fit_content = true
	_texto.scroll_active = false
	_texto.add_theme_font_override("normal_font", fonte())
	_texto.add_theme_font_size_override("normal_font_size", TAMANHO_FONTE)
	_texto.add_theme_color_override("default_color", COR_TEXTO)
	_texto.add_theme_constant_override("line_separation", 1)
	_texto.text = "[color=#%s]> %s[/color]\n[color=#%s]  %s[/color]\n%s" % [
		Estilo.CIANO.to_html(false), Dados.nome_limpo(id),
		COR_COORDENADAS.to_html(false), Dados.fmt_coordenadas(id),
		descricao(id)]
	_texto.visible_characters = 0
	_painel.add_child(_texto)


func _animar(mapa: MapaLunar) -> void:
	# Espera dois quadros: só então o texto sabe a própria altura (ele quebra linha sozinho).
	await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var tam := _painel.get_combined_minimum_size()
	_painel.size = tam

	# O risco sai para um lado e dobra na diagonal, para cima ou para baixo. Das opções que
	# cabem na tela, ganha a que cobre menos coisas: marcadores do mapa e a lista. No empate,
	# a que tem mais espaço livre.
	var lados: Array = [-1.0, 1.0] if _do_marcador else [-1.0]
	var opcoes: Array = []
	for sx in lados:        # -1 = para a esquerda, 1 = para a direita
		for sy in [1.0, -1.0]:   # 1 = para baixo, -1 = para cima
			var inicio: Vector2 = _origem + Vector2(FOLGA_DO_MARCADOR * sx if _do_marcador else 0.0, 0.0)
			var cotovelo: Vector2 = inicio + Vector2(8.0 * sx, 0.0)
			var ponta: Vector2 = cotovelo + Vector2(10.0 * sx, 10.0 * sy)
			var canto := Vector2(ponta.x if sx > 0.0 else ponta.x - tam.x,
					ponta.y if sy > 0.0 else ponta.y - tam.y).round()
			var r := Rect2(canto, tam)
			if r.position.x < 2.0 or r.position.y < 2.0 or r.end.x > size.x - 2.0 or r.end.y > size.y - 2.0:
				continue
			var poluicao := 0
			if mapa != null:
				poluicao += 10 * mapa.marcadores_em(r)
				if not mapa.get_global_rect().encloses(r):
					poluicao += 5   # sair do mapa (cobrir o título, por exemplo) só se for para livrar um marcador
			if _evitar.has_area() and _evitar.intersects(r):
				poluicao += 100
			if sx > 0.0:
				poluicao += 1   # à direita do marcador costuma ficar a sigla dele
			var folga: float = (size.y - r.end.y) if sy > 0.0 else r.position.y
			opcoes.append({"inicio": inicio, "cotovelo": cotovelo, "ponta": ponta, "canto": canto,
					"para_cima": sy < 0.0, "pela_esquerda": sx > 0.0, "poluicao": poluicao, "folga": folga})
	if opcoes.is_empty():
		queue_free()
		return
	opcoes.sort_custom(func(a, b):
		return a["poluicao"] < b["poluicao"] if a["poluicao"] != b["poluicao"] else a["folga"] > b["folga"])
	var escolha: Dictionary = opcoes[0]
	_inicio = escolha["inicio"]
	_cotovelo = escolha["cotovelo"]
	_ponta = escolha["ponta"]
	_painel.position = escolha["canto"]

	# 1) o risco se estica; 2) a janela abre a partir da ponta; 3) o texto é "digitado".
	if _fechando:
		return
	_tween_do_risco = create_tween()
	_tween_do_risco.tween_property(self, "_progresso", 1.0, TEMPO_DA_LINHA)
	await _tween_do_risco.finished
	if not is_inside_tree() or _fechando:
		return
	_painel.modulate.a = 1.0
	var abertura := Estilo.animar_abertura(_painel, tam.x, escolha["para_cima"], escolha["pela_esquerda"])
	await abertura.finished
	if not is_inside_tree() or _fechando:
		return
	var letras := _texto.get_total_character_count()
	create_tween().tween_property(_texto, "visible_characters", letras, letras / LETRAS_POR_SEGUNDO)


func _draw() -> void:
	if _progresso <= 0.0:
		return
	# Risco em dois trechos: reto até o cotovelo, depois na diagonal até a ponta.
	var trecho1 := _inicio.distance_to(_cotovelo)
	var trecho2 := _cotovelo.distance_to(_ponta)
	var andado := _progresso * (trecho1 + trecho2)
	if not _do_marcador:
		draw_rect(Rect2(_inicio - Vector2(1.5, 1.5), Vector2(3, 3)), Estilo.CIANO)
	if andado <= trecho1:
		draw_line(_inicio, _inicio.lerp(_cotovelo, andado / trecho1), Estilo.CIANO, 1.0, true)
	else:
		draw_line(_inicio, _cotovelo, Estilo.CIANO, 1.0, true)
		draw_line(_cotovelo, _cotovelo.lerp(_ponta, (andado - trecho1) / trecho2), Estilo.CIANO, 1.0, true)
