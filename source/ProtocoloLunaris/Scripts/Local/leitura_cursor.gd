class_name LeituraCursor
extends Control
## Leitura do instante do cursor, logo abaixo do gráfico do horizonte:
##
##   At cursor: 2027-01-04 00:00 UTC, day 14
##   Sun    hidden, 6.6° below the terrain  ·  el -4.0° az 197.4°  ·  rises in ~240 h (after the mission)
##   Earth  hidden, 1.0° below the terrain  ·  el -2.1° az 335.6°  ·  rises in ~45 h (after the mission)
##
## - visível ou não, e a folga: a elevação menos o horizonte naquela direção. "above/below the
##   terrain" quando o local tem relevo; "above/below the horizon" quando o horizonte é o
##   plano de 0°.
## - `el` e `az`: elevação e azimute no cursor (de `Dados.posicao`).
## - próximo pôr ou nascer, contado do cursor. Ele é procurado até o FIM DOS DADOS, não até o
##   fim da missão; se cair depois da missão, a frase avisa. Sem evento até o fim dos dados:
##   "does not set / does not rise in the data period" (nunca "never").
## Fora da cobertura dos dados mostra só a linha da data.
##
## Todos os números vêm de `Dados`; aqui só se escreve.
##
## Uso de IA: escrito com assistência do Claude (Anthropic).

const TAM := 8
const NOMES := {"sun": "Sun", "earth": "Earth"}
const X_NOME := 6.0
const X_TEXTO := 56.0     ## onde começa a primeira coluna depois do nome
const ESPACO := 16.0      ## entre uma coluna e a próxima (com um pontinho no meio)

var local_id := ""
var cursor := 0.0
var inicio_da_missao := 0.0
var fim_da_missao := 0.0


func mostrar(id: String, t_cursor: float, t_inicio: float, t_fim: float) -> void:
	local_id = id
	cursor = t_cursor
	inicio_da_missao = t_inicio
	fim_da_missao = t_fim
	queue_redraw()


## Graus com 1 casa, sem "-0.0".
static func graus(v: float) -> String:
	var arredondado := snappedf(v, 0.1)
	return "%.1f°" % (0.0 if is_zero_approx(arredondado) else arredondado)


## A frase do próximo pôr ou nascer de um corpo ("sun" ou "earth"), contada de `t`.
static func proxima_mudanca(id: String, corpo: String, t: float, t_fim_da_missao: float) -> String:
	var m := Dados.proxima_mudanca(id, corpo, t)
	if m.is_empty():
		if Dados.visivel_em(id, corpo, t):
			return Config.t("does not set in the data period")
		return Config.t("does not rise in the data period")
	var horas := roundi((float(m["t"]) - t) / Dados.HORA)
	var frase := Config.t("sets in ~%d h" if m["tipo"] == "set" else "rises in ~%d h") % horas
	if float(m["t"]) > t_fim_da_missao:
		frase = Config.t("%s (after the mission)") % frase
	return frase


## "hidden, 6.6° below the terrain", "visible, 4.6° above the horizon"...
static func situacao(visivel: bool, folga: float, com_relevo: bool) -> String:
	var frase := "%s above the terrain" if visivel else "%s below the terrain"
	if not com_relevo:
		frase = "%s above the horizon" if visivel else "%s below the horizon"
	return "%s, %s" % [Config.t("visible" if visivel else "hidden"), Config.t(frase) % graus(absf(folga))]


func _largura(texto: String) -> float:
	return Estilo.fonte().get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM).x


func _draw() -> void:
	draw_style_box(Estilo.caixa(Color(Estilo.MARINHO, 0.45), Color(Estilo.INDIGO, 0.45), 0.0), Rect2(Vector2.ZERO, size))
	if local_id == "":
		return
	var fonte := Estilo.fonte()
	var negrito := Estilo.fonte(true)

	# Linha de cima: a data do cursor e o dia da missão.
	var dias := maxi(int(round((fim_da_missao - inicio_da_missao) / Dados.DIA)), 1)
	var dia := mini(int((cursor - inicio_da_missao) / Dados.DIA) + 1, dias)
	draw_string(fonte, Vector2(X_NOME, 10.0), Config.t("At cursor: %s, day %d") % [Dados.fmt_data(cursor), dia],
			HORIZONTAL_ALIGNMENT_LEFT, -1, TAM, Estilo.TEXTO_FRACO)

	if Dados.avaliar(local_id)["status"] != "ok":
		return
	var pos := Dados.posicao(local_id, cursor)
	if pos.is_empty():
		return
	var com_relevo := Dados.modelo_em_uso(local_id) == "terrain"

	# As três colunas de cada linha; a largura de cada coluna é a do texto mais comprido dela.
	var linhas: Array = []
	var larguras := [0.0, 0.0, 0.0]
	for corpo in ["sun", "earth"]:
		var el: float = pos[corpo + "_el"]
		var az: float = pos[corpo + "_az"]
		var folga := el - Dados.horizonte(local_id, az)
		var textos := [situacao(folga > 0.0, folga, com_relevo), "el %s az %s" % [graus(el), graus(az)],
				proxima_mudanca(local_id, corpo, cursor, fim_da_missao)]
		for i in 3:
			larguras[i] = maxf(larguras[i], _largura(textos[i]))
		linhas.append({"corpo": corpo, "visivel": folga > 0.0, "textos": textos})

	var y := 20.0
	for linha in linhas:
		var cor := Estilo.cor_corpo(linha["corpo"])
		var cor_texto := Estilo.TEXTO if linha["visivel"] else Estilo.TEXTO_FRACO
		draw_string(negrito, Vector2(X_NOME, y), Config.t(NOMES[linha["corpo"]]), HORIZONTAL_ALIGNMENT_LEFT, -1, TAM, cor)
		var x := X_TEXTO
		for i in 3:
			draw_string(fonte, Vector2(x, y), linha["textos"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, TAM,
					cor_texto if i < 2 else Estilo.TEXTO_FRACO)
			x += larguras[i] + ESPACO
			if i < 2:   # pontinho entre as colunas
				draw_rect(Rect2(x - ESPACO / 2.0 - 1.0, y - 4.0, 2.0, 2.0), Color(Estilo.TEXTO_FRACO, 0.7))
		y += 10.0
