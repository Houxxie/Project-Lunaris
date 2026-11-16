class_name FaixaMissao
extends Control
## Faixa de cima da tela do horizonte: a missão em uso e o horizonte em uso, numa linha só.
##
##   LANDING 2026-12-21 | DURATION 14 DAYS | +7d from 2026-12-14 [UNDO]      0° reference horizon, no terrain
##
## - A data do pouso e a duração são só leitura (escolhe-se na tela do mapa).
## - Depois de um "+7d" aparece de quanto foi o adiamento e a data original, com o botão que
##   o desfaz. Vários "+7d" somam: "+14d from ...".
## - À direita, só nos locais sem dados de relevo, o aviso de que o horizonte é o plano de 0°
##   (texto de texts_en.json -> model_labels). Nos locais com relevo não aparece nada ali.
##
## Uso de IA: escrito com assistência do Claude (Anthropic).

const TAM := 8
const MARGEM := 6.0

var local_id := ""
var _desfazer: Button   # "UNDO DELAY": só aparece depois de um adiamento


func _ready() -> void:
	# Aqui o botão diz só "UNDO": ele fica colado no texto do adiamento, e a faixa é curta.
	_desfazer = Estilo.botao_texto(Config.t("UNDO"), Config.t("Go back to the landing date before the delay"))
	_desfazer.visible = false
	_desfazer.pressed.connect(Dados.desfazer_adiamento)
	add_child(_desfazer)


func mostrar(id: String) -> void:
	local_id = id
	var adiou := Dados.inicio_antes_do_adiamento >= 0.0
	_desfazer.visible = adiou
	if adiou:
		# logo depois do texto do adiamento (as mesmas contas de largura do `_draw`)
		var x := MARGEM
		for p in _pecas():
			x += _largura(p[1], p[0]) + float(p[3])
		_desfazer.size = Vector2(_desfazer.get_combined_minimum_size().x + 6.0, 12.0)
		_desfazer.position = Vector2(x + 2.0, roundf((size.y - _desfazer.size.y) / 2.0))
	queue_redraw()


func _largura(negrito: bool, texto: String) -> float:
	return Estilo.fonte(negrito).get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM).x


## Os pedaços de texto da esquerda, na ordem: [texto, em negrito?, cor, espaço depois].
## Um espaço de 14 ou mais leva um tracinho vertical no meio.
func _pecas() -> Array:
	var pecas := [
		[Config.t("LANDING"), false, Estilo.TEXTO_FRACO, 5.0],
		[Dados.fmt_dia(Dados.inicio_missao), true, Estilo.TEXTO, 14.0],
		[Config.t("DURATION"), false, Estilo.TEXTO_FRACO, 5.0],
		[Config.dias(int(Dados.duracao_h / 24.0)), true, Estilo.TEXTO, 14.0],
	]
	if Dados.inicio_antes_do_adiamento >= 0.0:
		var dias := roundi((Dados.inicio_missao - Dados.inicio_antes_do_adiamento) / Dados.DIA)
		pecas.append([Config.t("+%dd from %s") % [dias, Dados.fmt_dia(Dados.inicio_antes_do_adiamento)], false, Estilo.RUIM, 4.0])
	return pecas


func _draw() -> void:
	draw_style_box(Estilo.caixa(Color(Estilo.MARINHO, 0.45), Color(Estilo.INDIGO, 0.45), 0.0), Rect2(Vector2.ZERO, size))
	if local_id == "":
		return
	var y := roundf(size.y / 2.0) + 3.0
	var x := MARGEM
	var pecas := _pecas()
	for i in pecas.size():
		var p: Array = pecas[i]
		var espaco := float(p[3])
		draw_string(Estilo.fonte(p[1]), Vector2(x, y), p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, TAM, p[2])
		x += _largura(p[1], p[0]) + espaco
		if espaco >= 14.0 and i < pecas.size() - 1:
			draw_rect(Rect2(x - 7.0, 3.0, 1.0, size.y - 6.0), Color(Estilo.INDIGO, 0.8))
	# À direita, só nos locais SEM dados de relevo: o aviso de que o horizonte é o plano de 0°.
	# (Nos locais com relevo não há rótulo: o gráfico já mostra o terreno.)
	if Dados.modelo_em_uso(local_id) != "terrain":
		var modelo: String = Config.t(Dados.textos.get("model_labels", {}).get("reference", ""))
		draw_string(Estilo.fonte(), Vector2(size.x - MARGEM - _largura(false, modelo), y), modelo,
				HORIZONTAL_ALIGNMENT_LEFT, -1, TAM, Color(Estilo.TEXTO_FRACO, 0.9))
