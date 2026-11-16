class_name CalculoLunar
extends RefCounted
## As contas do programa. É a tradução, função por função, de `Referencia/lunar_calc.py` (do Ricardo).
##
## Regras:
## - Todos os tempos são segundos Unix em UTC.
## - Uma "janela" é um par [início, fim] em que o corpo (Sol ou Terra) está visível.
## - Os dicionários de resultado usam as mesmas chaves do Python e do `reference_1y.json`
##   (status, sun, earth, both, hours, fraction, longest_gap_h...), para facilitar a conferência.
##
## Uso de IA: traduzido para GDScript com assistência do Claude (Anthropic) e conferido
## automaticamente contra `Testes/reference_1y.json` (ver `Testes/teste_referencia.gd`).

const TOL := 1e-3  # segundos; tolerância para "encosta no início/fim"

## Indicador -> [corpo, campo] dentro do resultado de `avaliar_janelas`.
const INDICADORES := {
	"sun_hours": ["sun", "hours"], "earth_hours": ["earth", "hours"], "both_hours": ["both", "hours"],
	"sun_fraction": ["sun", "fraction"], "earth_fraction": ["earth", "fraction"],
	"both_fraction": ["both", "fraction"],
	"longest_gap_sun_h": ["sun", "longest_gap_h"], "longest_gap_earth_h": ["earth", "longest_gap_h"],
	"longest_gap_both_h": ["both", "longest_gap_h"],
}
## Indicadores em que menor é melhor (para ordenar a classificação).
const MENOR_E_MELHOR := ["longest_gap_sun_h", "longest_gap_earth_h", "longest_gap_both_h"]
const ORDEM_STATUS := {"met": 0, "not_met": 1, "insufficient_data": 2}


# ---------- janelas ----------

## Recorta as janelas ao período [a, b] (`clip`).
static func recortar(janelas: Array, a: float, b: float) -> Array:
	var res: Array = []
	for j in janelas:
		var lo: float = max(float(j[0]), a)
		var hi: float = min(float(j[1]), b)
		if hi > lo:
			res.append([lo, hi])
	return res


## Horas visíveis e maior intervalo sem o corpo em [a, b]; `janelas` já recortadas (`period_stats`).
static func estatisticas(janelas: Array, a: float, b: float) -> Dictionary:
	var total := 0.0
	var bordas: Array[float] = [a]
	for j in janelas:
		total += float(j[1]) - float(j[0])
		bordas.append(float(j[0]))
		bordas.append(float(j[1]))
	bordas.append(b)
	# Os intervalos SEM o corpo ficam entre as bordas: (a, 1ª janela), (fim da 1ª, início da 2ª)... (última, b).
	var maior := -1.0
	var g0 := a
	var g1 := a
	for i in range(0, bordas.size(), 2):
		var comprimento := bordas[i + 1] - bordas[i]
		if comprimento >= maior:  # no empate vale o último, como no max() de tuplas do Python
			maior = comprimento
			g0 = bordas[i]
			g1 = bordas[i + 1]
	return {
		"hours": total / 3600.0,
		"fraction": total / (b - a),
		"longest_gap_h": maior / 3600.0,
		"gap_touches_start": maior > 0.0 and absf(g0 - a) < TOL,
		"gap_touches_end": maior > 0.0 and absf(g1 - b) < TOL,
	}


## Indicadores de uma missão a partir das janelas do JSON (`evaluate_windows`).
## `janelas` = {"sun": [...], "earth": [...], "both": [...]}, do bloco `terrain` ou do horizonte plano.
static func avaliar_janelas(janelas: Dictionary, inicio: float, duracao_h: float,
		cobertura_ini: float, cobertura_fim: float) -> Dictionary:
	var a := inicio
	var b := inicio + duracao_h * 3600.0
	if a < cobertura_ini - TOL or b > cobertura_fim + TOL:
		return {"status": "insufficient_data"}
	var res := {"status": "ok"}
	for corpo in ["sun", "earth", "both"]:
		res[corpo] = estatisticas(recortar(janelas[corpo], a, b), a, b)
	res["both_fraction"] = res["both"]["fraction"]
	return res


## Próximo nascer ou pôr de um corpo depois do instante t, até `limite` (`next_change`).
## `janelas_do_corpo` são as janelas inteiras do local (sem recortar pela missão), em ordem.
## Devolve {"tipo": "set" | "rise", "t": instante}, ou {} se não há evento até o limite.
static func proxima_mudanca(janelas_do_corpo: Array, t: float, limite: float) -> Dictionary:
	for j in janelas_do_corpo:
		var w0 := float(j[0])
		var w1 := float(j[1])
		if w0 <= t and t < w1:   # visível agora: o próximo evento é o pôr
			return {"tipo": "set", "t": w1} if w1 < limite - TOL else {}
		if w0 > t:               # escondido agora: o próximo evento é o nascer
			return {"tipo": "rise", "t": w0} if w0 < limite - TOL else {}
	return {}


## true se o instante t cai dentro de alguma das janelas (o corpo está visível em t).
static func visivel_em(janelas_do_corpo: Array, t: float) -> bool:
	for j in janelas_do_corpo:
		if float(j[0]) <= t and t < float(j[1]):
			return true
	return false


# ---------- posição no cursor ----------

## Interpola o azimute pelo caminho curto: de 359° para 1° passa por 0°, não por 180° (`lerp_azimuth`).
static func interpolar_azimute(a0: float, a1: float, f: float) -> float:
	var d := fposmod(a1 - a0 + 180.0, 360.0) - 180.0
	return fposmod(a0 + f * d, 360.0)


## Elevação do horizonte do terreno (graus) num azimute (`horizon_at`).
## O valor k do perfil vale no azimute (k + 0,5) * 360/n; interpolação linear, dando a volta em 0°/360°.
static func horizonte_em(perfil: Array, azimute: float) -> float:
	var n := perfil.size()
	var x := fposmod(azimute, 360.0) * n / 360.0 - 0.5
	var k := int(floor(x))
	var p := x - k
	return float(perfil[posmod(k, n)]) * (1.0 - p) + float(perfil[posmod(k + 1, n)]) * p


# ---------- requisitos ----------

## Valor de um indicador no resultado; null se o cenário não tem dados (`indicator_value`).
static func valor_indicador(resultado: Dictionary, indicador: String) -> Variant:
	if resultado.get("status") != "ok":
		return null
	var caminho: Array = INDICADORES[indicador]
	return resultado[caminho[0]][caminho[1]]


## Formata um valor como no Python: "91%" ou "30.3 h" (`_fmt`).
static func formatar(valor: float, unidade: String) -> String:
	if unidade == "%":
		return "%.0f%%" % (valor * 100.0)
	return "%.1f %s" % [valor, unidade]


## true se `valor` respeita o limite de um requisito (`op` é "<=", "<", ">=" ou ">").
static func cumpre(valor: float, op: String, limite: float) -> bool:
	return _compara(valor, op, limite)


static func _compara(valor: float, op: String, limite: float) -> bool:
	match op:
		"<=": return valor <= limite
		"<": return valor < limite
		">=": return valor >= limite
		">": return valor > limite
	return false


## Status de cada requisito e do cenário: met / not_met / insufficient_data (`evaluate_requirements`).
## Qualquer requisito não atendido -> not_met; senão, algum sem dados -> insufficient_data; senão -> met.
## Um indicador bom nunca compensa um ruim.
## (O Python também monta uma frase para cada requisito; aqui não, porque nenhuma tela a mostra.)
static func avaliar_requisitos(resultado: Dictionary, regras: Array) -> Dictionary:
	var checagens: Array = []
	var tem_nao_atendido := false
	var tem_sem_dado := false
	for regra in regras:
		var v: Variant = valor_indicador(resultado, regra["indicator"])
		var status := ""
		if v == null:
			status = "insufficient_data"
			tem_sem_dado = true
		elif _compara(v, regra["op"], float(regra["value"])):
			status = "met"
		else:
			status = "not_met"
			tem_nao_atendido = true
		checagens.append({"id": regra["id"], "status": status, "value": v})
	var geral := "met"
	if tem_nao_atendido:
		geral = "not_met"
	elif tem_sem_dado:
		geral = "insufficient_data"
	return {"status": geral, "checks": checagens}


## true se o cenário atende a TODOS os requisitos. Mesmo critério de `avaliar_requisitos`
## (status "met"), mas sem montar a lista de checagens: serve para testar muitas datas depressa.
static func atende(resultado: Dictionary, regras: Array) -> bool:
	for regra in regras:
		var v: Variant = valor_indicador(resultado, regra["indicator"])
		if v == null or not _compara(v, regra["op"], float(regra["value"])):
			return false
	return true


## Ordena cenários [{"id": ..., "resultado": ...}]: primeiro pelo status, depois pela prioridade
## (`rank_scenarios`). Acrescenta em cada item os campos "status" e "valor".
static func classificar(cenarios: Array, regras: Array, prioridade: String) -> Array:
	var itens: Array = []
	for i in cenarios.size():
		var c: Dictionary = cenarios[i]
		var status: String = avaliar_requisitos(c["resultado"], regras)["status"]
		var v: Variant = valor_indicador(c["resultado"], prioridade)
		var chave := [ORDEM_STATUS[status], 1, 0.0, i]
		if v != null:
			chave = [ORDEM_STATUS[status], 0, (v if prioridade in MENOR_E_MELHOR else -v), i]
		var item := c.duplicate()
		item["status"] = status
		item["valor"] = v
		item["_chave"] = chave
		itens.append(item)
	itens.sort_custom(func(x, y):
		for k in 4:
			if x["_chave"][k] != y["_chave"][k]:
				return x["_chave"][k] < y["_chave"][k]
		return false)
	for item in itens:
		item.erase("_chave")
	return itens
