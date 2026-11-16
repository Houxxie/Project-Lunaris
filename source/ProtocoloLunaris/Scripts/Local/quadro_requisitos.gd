class_name QuadroRequisitos
extends Control
## Faixa de baixo da tela do horizonte: o veredito do local na missão INTEIRA, numa linha.
##
##   x DOES NOT MEET THE REQUIREMENTS  (before delay: met)  [!]
##
## - A borda e o texto levam a cor do status; a marca tem forma além de cor (X = não atende).
## - Depois de um "+7d", diz também qual era o status antes do adiamento.
## - Quando o local NÃO atende, aparece ao lado o botão de atenção. Ele abre uma janela que
##   explica o porquê: cada requisito com o valor, o limite e (se houve adiamento) o valor de
##   antes. A janela fecha no X, com Esc ou clicando fora.
## Os valores e limites de cada linha também estão na tabela logo acima (coluna LIMIT).
##
## Uso de IA: escrito com assistência do Claude (Anthropic).

const TAM := 8
const MARGEM := 6.0
const LADO_DO_BOTAO := 16.0
## Palavra curta para o status de antes do adiamento.
const STATUS_CURTO := {"met": "met", "not_met": "not met", "insufficient_data": "insufficient data"}

var local_id := ""
var _atencao: Button   # o botão do triângulo de atenção


func _ready() -> void:
	_atencao = Estilo.botao_quadrado("attention-icon", LADO_DO_BOTAO)
	_atencao.tooltip_text = Config.t("Why it does not meet the requirements")
	_atencao.visible = false
	_atencao.connect("acionado", _explicar)
	add_child(_atencao)


func mostrar(id: String) -> void:
	local_id = id
	var status: String = Dados.requisitos_de(id)["status"]
	_atencao.visible = status == "not_met"
	_atencao.position = Vector2(_fim_do_texto() + 8.0, roundf((size.y - LADO_DO_BOTAO) / 2.0))
	queue_redraw()


## "max 48 h", "min 60%": o limite de um requisito, do jeito que aparece na tabela e na janela.
static func texto_do_limite(regra: Dictionary) -> String:
	var valor := float(regra["value"])
	var unidade: String = regra.get("unit", "")
	var texto := CalculoLunar.formatar(valor, unidade)
	if unidade != "%" and is_equal_approx(valor, roundf(valor)):
		texto = "%d %s" % [int(valor), unidade]   # limite inteiro em horas vai sem casa decimal
	return Config.t("max %s" if String(regra["op"]).begins_with("<") else "min %s") % texto


func _titulo() -> String:
	return Dados.rotulo_status(Dados.requisitos_de(local_id)["status"]).to_upper()


## "(before delay: met)", ou "" se não houve adiamento.
func _antes() -> String:
	if Dados.inicio_antes_do_adiamento < 0.0:
		return ""
	var era: String = Dados.requisitos_de(local_id, Dados.inicio_antes_do_adiamento)["status"]
	return "(%s)" % (Config.t("before delay: %s") % Config.t(STATUS_CURTO[era]))


func _largura(negrito: bool, texto: String) -> float:
	return Estilo.fonte(negrito).get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM).x


## Onde o texto da faixa termina (o botão de atenção fica logo depois).
func _fim_do_texto() -> float:
	var x := MARGEM + 9.0 + _largura(true, _titulo())
	if _antes() != "":
		x += 8.0 + _largura(false, _antes())
	return x


func _draw() -> void:
	if local_id == "":
		return
	var status: String = Dados.requisitos_de(local_id)["status"]
	var cor := Estilo.cor_status(status)
	draw_style_box(Estilo.caixa(Color(Estilo.MARINHO, 0.45), Color(cor, 0.9), 0.0), Rect2(Vector2.ZERO, size))
	var y := roundf(size.y / 2.0) + 3.0
	Estilo.desenhar_marca(self, Vector2(MARGEM, y - 6.0), status)
	draw_string(Estilo.fonte(true), Vector2(MARGEM + 9.0, y), _titulo(), HORIZONTAL_ALIGNMENT_LEFT, -1, TAM, cor)
	if _antes() != "":
		draw_string(Estilo.fonte(), Vector2(MARGEM + 17.0 + _largura(true, _titulo()), y), _antes(),
				HORIZONTAL_ALIGNMENT_LEFT, -1, TAM, Estilo.TEXTO_FRACO)


## Abre a janela que explica por que o local não atende aos requisitos.
func _explicar() -> void:
	DialogoTexto.abrir(self, Config.t("REQUIREMENTS NOT MET"), texto_do_motivo(local_id), Vector2(470, 222))


## O texto da janela (BBCode): os requisitos não atendidos e os atendidos, cada um com o valor
## na missão inteira, o limite e, se houve adiamento, o valor de antes.
static func texto_do_motivo(id: String) -> String:
	var ruim := Estilo.RUIM.to_html(false)
	var bom := Estilo.BOM.to_html(false)
	var fraco := Estilo.TEXTO_FRACO.to_html(false)
	var regras: Array = Dados.regras()
	var agora := Dados.requisitos_de(id)
	var adiou := Dados.inicio_antes_do_adiamento >= 0.0
	var antes := Dados.requisitos_de(id, Dados.inicio_antes_do_adiamento) if adiou else {}

	var s := "[b]%s[/b]\n" % Dados.nome_limpo(id)
	s += "[color=#%s]%s %s   %s %s[/color]\n\n" % [fraco, Config.t("LANDING"), Dados.fmt_dia(Dados.inicio_missao),
			Config.t("DURATION"), Config.dias(int(Dados.duracao_h / 24.0))]
	for grupo in [["not_met", "NOT MET", ruim], ["met", "MET", bom]]:
		var linhas := ""
		for i in regras.size():
			var checagem: Dictionary = agora["checks"][i]
			if checagem["status"] != grupo[0] or checagem["value"] == null:
				continue
			var unidade: String = regras[i].get("unit", "")
			linhas += "- %s: [color=#%s][b]%s[/b][/color] (%s)" % [Config.t(regras[i]["name"]), grupo[2],
					CalculoLunar.formatar(float(checagem["value"]), unidade), texto_do_limite(regras[i])]
			if adiou and antes["checks"][i]["value"] != null:
				linhas += " [color=#%s]- %s[/color]" % [fraco, Config.t("before delay: %s")
						% CalculoLunar.formatar(float(antes["checks"][i]["value"]), unidade)]
			linhas += "\n"
		if linhas != "":
			s += "[color=#%s][b]%s[/b][/color]\n%s\n" % [grupo[2], Config.t(grupo[1]), linhas]
	s += Config.longo("guia_requisitos_fim")
	return s
