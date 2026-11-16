class_name VistaHorizonte
extends Control
## Vista do horizonte de um local: a silhueta do terreno, o Sol e a Terra no instante do cursor.
##
## - Eixo x: azimute, com o Norte no centro (S - W - N - E - S). Eixo y: elevação em graus.
## - A silhueta vem de `terrain.horizon.elevation_deg` (1440 valores). Sem relevo, é a linha de 0°.
## - A linha tracejada é a referência de 0°. Os pontinhos são o caminho do Sol e da Terra
##   durante a missão.
## - Corpo escondido (elevação <= horizonte naquela direção) aparece apagado.
## - O terreno é iluminado pelo Sol do instante do cursor: de costas para o Sol os morros
##   aparecem claros, olhando para ele ficam em contraluz (escuros, com um fio de luz na
##   crista), a encosta virada para o Sol fica mais clara que a outra, e com o Sol abaixo do
##   horizonte tudo escurece. É só desenho: nenhuma conta do programa usa esta iluminação.
## - O Sol passa por TRÁS da Terra quando os dois se cruzam.
## O gráfico não leva números por cima: eles ficam na leitura do cursor, logo abaixo. Qual
## horizonte está em uso (com relevo ou o plano de 0°) aparece na faixa da missão, logo acima.
##
## Uso de IA: escrito com assistência do Claude (Anthropic).

const MARGEM_BAIXO := 11.0     # faixa dos pontos cardeais
const LADO_ICONE := 16.0
const TAM := 8                 # tamanho da fonte pixelada (único tamanho pequeno que existe)
# Iluminação do terreno pelo Sol (tudo em 2D, pensado como se fosse 3D):
const COR_SOMBRA := Color("#0c1024")      # terreno sem luz nenhuma
const COR_LUZ := Color("#a3abc9")         # terreno com o Sol batendo de frente
const COR_BORDA := Color("#8f9bc8")       # linha da crista
const COR_CONTRALUZ := Color("#fff1c2")   # fio de luz na crista, olhando para o Sol
const LUZ_AMBIENTE := 0.2                 # o quanto o terreno aparece sem Sol (para não sumir à noite)
const BRILHO_DE_DIA := 0.6   ## quão claro o terreno fica com o Sol alto (0 a 1)             # o quanto a inclinação da encosta pesa no claro e escuro

var local_id := ""
var cursor := 0.0              ## instante mostrado (Unix UTC)
var inicio := 0.0              ## início da missão
var fim := 0.0                 ## fim da missão

var _sol: Texture2D
var _terra: Texture2D
var _el_min := -8.0
var _el_max := 12.0
var _alturas: Array[float] = []        # altura do horizonte em cada coluna do gráfico
var _inclinacoes: Array[float] = []    # inclinação do horizonte em cada coluna
var _perfil_de := ""                   # para que local e tamanho as duas listas acima foram feitas


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	_sol = load(Estilo.PASTA_ICONES + "sol.png")
	_terra = load(Estilo.PASTA_ICONES + "terra.png")


## Atualiza o que é mostrado e redesenha.
func mostrar(id: String, t_cursor: float, t_inicio: float, t_fim: float) -> void:
	if id != local_id:
		local_id = id
		_calcular_escala()
	cursor = t_cursor
	inicio = t_inicio
	fim = t_fim
	queue_redraw()


## Escolhe a faixa de elevação do gráfico: perto do polo o Sol fica a poucos graus do horizonte,
## então a escala é fina; no equador ele chega a quase 90°.
func _calcular_escala() -> void:
	var resumo: Dictionary = Dados.local(local_id).get("summary", {})
	var topo := 0.0
	for chave in ["sun_elevation_range_deg", "earth_elevation_range_deg"]:
		if resumo.has(chave):
			topo = maxf(topo, float(resumo[chave][1]))
	_el_max = clampf(topo * 1.12 + 1.0, 12.0, 92.0)
	_el_min = -8.0 if _el_max <= 20.0 else -_el_max * 0.3


func _area() -> Rect2:
	return Rect2(0, 0, size.x, size.y - MARGEM_BAIXO)


func _x(azimute: float) -> float:
	return fposmod(azimute + 180.0, 360.0) / 360.0 * size.x


func _y(elevacao: float) -> float:
	var a := _area()
	return a.position.y + (_el_max - elevacao) / (_el_max - _el_min) * a.size.y


func _draw() -> void:
	var a := _area()
	var fonte := Estilo.fonte()
	draw_rect(Rect2(Vector2.ZERO, size), Color(Estilo.MARINHO, 0.9))
	if local_id == "":
		return
	var com_terreno := Dados.modelo_em_uso(local_id) == "terrain"

	# Grade de elevação.
	var passo := 2.0
	if _el_max > 60.0:
		passo = 15.0
	elif _el_max > 25.0:
		passo = 10.0
	var e := ceilf(_el_min / passo) * passo
	while e < _el_max:
		var y := roundf(_y(e)) + 0.5
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(Estilo.INDIGO, 0.22 if e != 0.0 else 0.0), 1.0)
		if y > 10.0:
			draw_string(fonte, Vector2(2, y - 1), "%d°" % int(e), HORIZONTAL_ALIGNMENT_LEFT, -1, TAM, Color(Estilo.TEXTO_FRACO, 0.8))
		e += passo

	# Pontos cardeais (Norte no centro).
	var cardeais := {-180.0: Config.cardeal("S"), -90.0: Config.cardeal("W"), 0.0: Config.cardeal("N"),
			90.0: Config.cardeal("E"), 180.0: Config.cardeal("S")}
	for az in cardeais:
		var x: float = clampf(roundf((az + 180.0) / 360.0 * size.x), 0.0, size.x - 1.0) + 0.5
		draw_line(Vector2(x, 0), Vector2(x, a.end.y), Color(Estilo.INDIGO, 0.22), 1.0)
		var largura := fonte.get_string_size(cardeais[az], HORIZONTAL_ALIGNMENT_LEFT, -1, TAM).x
		draw_string(fonte, Vector2(clampf(x - largura / 2.0, 2.0, size.x - largura - 2.0), size.y - 2.0),
				cardeais[az], HORIZONTAL_ALIGNMENT_LEFT, -1, TAM, Estilo.TEXTO_FRACO)

	# Caminho do Sol e da Terra durante a missão (um ponto a cada 2 h).
	var t := inicio
	while t <= fim:
		var p := Dados.posicao(local_id, t)
		if not p.is_empty():
			_ponto(p["sun_az"], p["sun_el"], Color(Estilo.SOL, 0.45))
			_ponto(p["earth_az"], p["earth_el"], Color(Estilo.TERRA, 0.45))
		t += 2.0 * Dados.HORA

	# Onde o Sol está agora: é ele que ilumina o terreno.
	var pos := Dados.posicao(local_id, cursor)
	var tem_sol := not pos.is_empty()
	var sol_az: float = pos["sun_az"] if tem_sol else 0.0
	var sol_el: float = pos["sun_el"] if tem_sol else -90.0
	# A luz é a mesma no terreno inteiro e depende só de quanto o Sol está acima do horizonte
	# na direção dele: com folga, tudo claro; chegando perto de sumir, tudo escurece por igual.
	var folga_do_sol: float = sol_el - Dados.horizonte(local_id, sol_az) if tem_sol else -90.0
	var forca := smoothstep(-2.5, 1.5, folga_do_sol) if tem_sol else 0.0

	# Clarão em volta do Sol, desenhado ANTES do terreno: quando o Sol está atrás de um morro,
	# só a parte de cima do clarão aparece, por cima da crista.
	if tem_sol and forca > 0.0 and sol_el > _el_min - 4.0 and sol_el < _el_max + 4.0:
		var centro_do_sol := Vector2(roundf(_x(sol_az)), roundf(_y(sol_el)))
		for dx in [0.0, -size.x, size.x]:
			for anel in [[30.0, 0.045], [21.0, 0.06], [13.0, 0.08]]:
				draw_circle(centro_do_sol + Vector2(dx, 0), anel[0], Color(Estilo.SOL, anel[1] * forca))

	# Terreno (ou a linha de 0°), iluminado pelo Sol.
	_preparar_perfil(com_terreno)
	for coluna in _alturas.size():
		var az := (coluna + 0.5) / size.x * 360.0 - 180.0
		var altura: float = _alturas[coluna]
		var y := clampf(roundf(_y(altura)), 0.0, a.end.y)
		# Ângulo (em azimute) desta direção até o Sol: 0 = olhando para o Sol; 180 = de costas.
		var ate_o_sol := deg_to_rad(fposmod(sol_az - az + 180.0, 360.0) - 180.0)
		# Brilho igual em todas as colunas (pedido do usuário: nada de lado claro e lado escuro).
		var brilho := LUZ_AMBIENTE + (1.0 - LUZ_AMBIENTE) * forca * BRILHO_DE_DIA
		var cor_do_topo := COR_SOMBRA.lerp(COR_LUZ, brilho)
		var cor_do_corpo := cor_do_topo
		# Três faixas, da crista para baixo, cada vez mais escuras: dá volume ao morro.
		var alto := a.end.y - y
		draw_rect(Rect2(coluna, y, 1, alto), cor_do_corpo.lerp(COR_SOMBRA, 0.55))
		draw_rect(Rect2(coluna, y, 1, minf(alto, 14.0)), cor_do_corpo.lerp(cor_do_topo, 0.5).lerp(COR_SOMBRA, 0.25))
		draw_rect(Rect2(coluna, y, 1, minf(alto, 5.0)), cor_do_topo)
		# A linha da crista: mais clara onde bate luz e, perto do Sol, um fio de contraluz
		# (mais forte quando o Sol está rente à crista).
		var rente := clampf(1.0 - absf(sol_el - altura) / 5.0, 0.0, 1.0)
		var contraluz := rente * exp(-pow(rad_to_deg(ate_o_sol) / 26.0, 2.0)) * smoothstep(-4.0, 0.0, sol_el - altura + 3.0)
		var cor_da_crista := COR_SOMBRA.lerp(COR_BORDA, 0.45 + 0.55 * brilho).lerp(COR_CONTRALUZ, contraluz if tem_sol else 0.0)
		draw_rect(Rect2(coluna, y, 1, 1), cor_da_crista)

	# Linha de referência de 0° (tracejada), por cima do terreno.
	var yz := roundf(_y(0.0)) + 0.5
	draw_dashed_line(Vector2(0, yz), Vector2(size.x, yz), Color(Estilo.CIANO, 0.55), 1.0, 3.0)

	# Sol e Terra no instante do cursor.
	if pos.is_empty():
		var aviso := Dados.rotulo_status("insufficient_data")
		var w := fonte.get_string_size(aviso, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM).x
		draw_string(fonte, Vector2((size.x - w) / 2.0, a.size.y / 2.0), aviso, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM, Estilo.AVISO)
	else:
		# O Sol é desenhado primeiro: ele está muito mais longe, então quando os dois se
		# cruzam no céu é a Terra que passa na frente.
		# Cada nome fica em cima do seu corpo (ou embaixo, se não couber em cima). Quando os
		# dois corpos estão perto, um nome cairia em cima do outro: aí troca-se de lado
		# primeiro o nome do Sol, depois o da Terra, até nenhum atrapalhar o outro.
		var c_sol := _centro_do_corpo(pos["sun_az"], pos["sun_el"])
		var c_terra := _centro_do_corpo(pos["earth_az"], pos["earth_el"])
		var t_sol := _texto_do_corpo("Sun", pos["sun_az"], pos["sun_el"])
		var t_terra := _texto_do_corpo("Earth", pos["earth_az"], pos["earth_el"])
		var sol_embaixo := not _cabe_em_cima(c_sol)
		var terra_embaixo := not _cabe_em_cima(c_terra)
		var resolvido := false
		for troca_terra: bool in [false, true]:
			for troca_sol: bool in [false, true]:
				# um nome que não cabe em cima não pode ser trocado para lá
				if resolvido or (troca_sol and sol_embaixo) or (troca_terra and terra_embaixo):
					continue
				var caixa_sol := _caixa_do_nome(t_sol, c_sol, sol_embaixo or troca_sol)
				var caixa_terra := _caixa_do_nome(t_terra, c_terra, terra_embaixo or troca_terra)
				if not _nomes_se_atrapalham(caixa_sol, caixa_terra, c_sol, c_terra):
					sol_embaixo = sol_embaixo or troca_sol
					terra_embaixo = terra_embaixo or troca_terra
					resolvido = true
		_corpo(_sol, t_sol, c_sol, pos["sun_az"], pos["sun_el"], Estilo.SOL, sol_embaixo)
		_corpo(_terra, t_terra, c_terra, pos["earth_az"], pos["earth_el"], Estilo.TERRA, terra_embaixo)

	draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), Estilo.INDIGO, false, 1.0)


## Guarda, para cada coluna de pixels do gráfico, a altura do horizonte e a inclinação dele
## (quanto sobe por grau de azimute). Isso não muda com o cursor, então é calculado uma vez
## por local e por tamanho; a cada quadro só as cores são refeitas.
func _preparar_perfil(com_terreno: bool) -> void:
	var colunas := int(size.x)
	var chave := "%s|%d|%s" % [local_id, colunas, com_terreno]
	if chave == _perfil_de:
		return
	_perfil_de = chave
	_alturas.resize(colunas)
	_inclinacoes.resize(colunas)
	var perfil: Array = Dados.perfil_do_terreno(local_id) if com_terreno else []
	for coluna in colunas:
		var az := (coluna + 0.5) / size.x * 360.0 - 180.0
		if perfil.is_empty():
			_alturas[coluna] = 0.0
			_inclinacoes[coluna] = 0.0
		else:
			_alturas[coluna] = CalculoLunar.horizonte_em(perfil, az)
			# inclinação medida num trecho de 6° (3° para cada lado), para pegar a encosta e não cada pedrinha
			_inclinacoes[coluna] = (CalculoLunar.horizonte_em(perfil, az + 3.0) - CalculoLunar.horizonte_em(perfil, az - 3.0)) / 6.0


func _ponto(azimute: float, elevacao: float, cor: Color) -> void:
	if elevacao < _el_min or elevacao > _el_max:
		return
	draw_rect(Rect2(floorf(_x(azimute)), floorf(_y(elevacao)), 1, 1), cor)


## Onde o corpo é desenhado (o centro do desenho), já preso dentro do gráfico.
func _centro_do_corpo(azimute: float, elevacao: float) -> Vector2:
	var a := _area()
	return Vector2(roundf(_x(azimute)), roundf(clampf(_y(elevacao), a.position.y + 9.0, a.end.y - 9.0)))


## O nome escrito junto do corpo. `nome` é "Sun" ou "Earth"; a frase inteira é traduzida (em
## português e espanhol o adjetivo muda com o gênero: "Sol (oculto)", "Terra (oculta)").
func _texto_do_corpo(nome: String, azimute: float, elevacao: float) -> String:
	var texto := nome
	if elevacao < _el_min:
		texto += " (below this view)"
	elif elevacao > _el_max:
		texto += " (above this view)"
	elif elevacao <= Dados.horizonte(local_id, azimute):
		texto += " (hidden)"
	return Config.t(texto)


## O nome cabe em cima do corpo sem sair pelo topo do gráfico?
func _cabe_em_cima(c: Vector2) -> bool:
	return c.y - 22.0 > 2.0


## O retângulo que o nome ocupa: em cima do corpo ou embaixo dele.
func _caixa_do_nome(texto: String, c: Vector2, embaixo: bool) -> Rect2:
	var w := Estilo.fonte().get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM).x
	var tx := clampf(c.x - w / 2.0, 2.0, size.x - w - 2.0)
	return Rect2(tx, c.y + 10.0 if embaixo else c.y - 19.0, w, 8.0)


## Um nome cai em cima do outro nome, ou em cima do desenho do outro corpo?
func _nomes_se_atrapalham(caixa_sol: Rect2, caixa_terra: Rect2, c_sol: Vector2, c_terra: Vector2) -> bool:
	var metade := Vector2(LADO_ICONE, LADO_ICONE) / 2.0
	return caixa_sol.grow(1.0).intersects(caixa_terra) \
			or caixa_sol.intersects(Rect2(c_terra - metade, metade * 2.0)) \
			or caixa_terra.intersects(Rect2(c_sol - metade, metade * 2.0))


func _corpo(textura: Texture2D, texto: String, centro: Vector2, azimute: float, elevacao: float, cor: Color, nome_embaixo: bool) -> void:
	var visivel := elevacao > Dados.horizonte(local_id, azimute)
	var tinta := Color(1, 1, 1, 1.0 if visivel else 0.38)
	var fonte := Estilo.fonte()
	# Desenha também do outro lado quando está perto da emenda Sul/Sul.
	for dx in [0.0, -size.x, size.x]:
		var c: Vector2 = centro + Vector2(dx, 0)
		if c.x < -LADO_ICONE or c.x > size.x + LADO_ICONE:
			continue
		if visivel:
			draw_circle(c, 11.0, Color(cor, 0.12))
		draw_texture_rect(textura, Rect2(c - Vector2(LADO_ICONE, LADO_ICONE) / 2.0, Vector2(LADO_ICONE, LADO_ICONE)), false, tinta)
		var caixa := _caixa_do_nome(texto, c, nome_embaixo)
		draw_string(fonte, Vector2(caixa.position.x, caixa.end.y), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM, Color(cor, 1.0 if visivel else 0.7))
