extends Node
## Autoload `Dados`: carrega os 4 JSON uma vez, guarda a missão escolhida e responde às telas.
##
## As telas não leem arquivos nem fazem contas por conta própria: pedem tudo daqui.
## Os números vêm só dos JSON do Ricardo (pasta res://Data). Nada é recalculado nem inventado.
##
## Uso de IA: escrito com assistência do Claude (Anthropic).

## Emitido quando o local, a data, a duração ou o modelo de horizonte mudam.
signal missao_mudou

const BASE_MENU := Vector2i(320, 180)   ## tela base do menu (pixel art grande)
const BASE_JOGO := Vector2i(640, 360)   ## tela base do mapa e do local (cabe mais informação)
const DIA := 86400.0
const HORA := 3600.0

const CENA_MENU := "res://Scenes/Main/main_menu.tscn"
const CENA_MAPA := "res://Scenes/Main/tela_principal.tscn"
const CENA_LOCAL := "res://Scenes/Main/tela_local.tscn"

## Frase da descrição dos requisitos (requirements_default.json) que não vale para este programa.
const FRASE_QUE_NAO_SE_APLICA := " Every value can be changed in the interface."
const DURACOES_RECOMENDADAS := [7, 14, 21]   ## dias; durações testadas na lista de recomendados
const DIAS_DA_MISSAO_INICIAL := 14           ## duração da missão com que o programa abre (ver `reiniciar`)
## Quanto tempo (ms) `adiantar_recomendados` trabalha por quadro. Um quadro a 60 fps tem 16 ms.
const MS_POR_QUADRO := 5
const DURACAO_MIN_H := 24.0
## Máximo de 28 dias: nos dados, nenhum local do polo atende aos requisitos em missões de
## 30 dias ou mais, em nenhuma data (a Terra sempre some por mais de 72 h seguidas).
const DURACAO_MAX_H := 24.0 * 28.0

# ---------- dados carregados ----------
var horizontes: Dictionary = {}
var mapas: Dictionary = {}
var textos: Dictionary = {}
var requisitos: Dictionary = {}
var locais: Array = []                 ## os 14 locais, na ordem do arquivo
var cobertura_ini := 0.0               ## início dos dados (Unix UTC)
var cobertura_fim := 0.0               ## fim dos dados (Unix UTC)
var _por_id: Dictionary = {}
var _mapa_por_id: Dictionary = {}

# ---------- missão escolhida ----------
var local_id := "IM2"
var inicio_missao := 0.0               ## pouso (Unix UTC, sempre em hora cheia)
var duracao_h := 336.0                 ## 14 dias
var usar_terreno := true               ## false = forçar o horizonte plano de 0° (só para comparar)
var mapa_id := "south_pole_px"
## Data de pouso original, de antes dos adiamentos ("+7d"); -1 se não há adiamento para comparar.
var inicio_antes_do_adiamento := -1.0
## true depois que o usuário aperta ANALYZE no mapa (libera a lista "meet the requirements").
var analise_feita := false

var _recomendados: Array = []
var _recomendados_de := -1.0           # data mínima para a qual a lista acima foi calculada
var _mais_dificil: Dictionary = {}     # a "data mais difícil" (ver `data_mais_dificil`)
var _busca: Dictionary = {}            # estado de `adiantar_recomendados` (vazio = nenhuma busca em andamento)
var _missao_inicial_pronta := false
var _cenas_carregando: Array[String] = []  # cenas pedidas em segundo plano que ainda não chegaram
var _cenas_adiantadas: Dictionary = {}     # caminho da cena -> cena (PackedScene) já carregada


func _ready() -> void:
	horizontes = _ler_json("res://Data/horizons_1y.json")
	mapas = _ler_json("res://Data/maps.json")
	textos = _ler_json("res://Data/texts_en.json")
	requisitos = _ler_json("res://Data/requirements_default.json")
	locais = horizontes.get("sites", [])
	for l in locais:
		_por_id[l["id"]] = l
	for m in mapas.get("maps", []):
		_mapa_por_id[m["id"]] = m
	cobertura_ini = float(horizontes.get("start_unix", 0))
	cobertura_fim = float(horizontes.get("stop_unix", 0))
	inicio_missao = cobertura_ini
	set_process(false)   # `_process` só liga quando há trabalho adiantado (ver o fim do arquivo)


func _ler_json(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		push_error("Dados: arquivo não encontrado: %s (na exportação, inclua *.json nos filtros)" % caminho)
		return {}
	var dado: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if not dado is Dictionary:
		push_error("Dados: JSON inválido: %s" % caminho)
		return {}
	return dado


# ---------- locais ----------

func local(id: String) -> Dictionary:
	return _por_id.get(id, {})


## Nome do local sem o parêntese do fim: "Nobile Rim 2 (sample point)" -> "Nobile Rim 2".
func nome_limpo(id: String) -> String:
	var nome: String = local(id).get("name", id)
	var abre := nome.rfind(" (")
	if abre > 0 and nome.ends_with(")"):
		nome = nome.substr(0, abre)
	return Config.nome_do_local(id, nome)   # traduzido, quando o nome tem palavras comuns


func tem_terreno(id: String) -> bool:
	return local(id).has("terrain")


## Ids dos locais com relevo calculado (os 11 do polo sul).
func ids_do_polo() -> Array:
	var ids: Array = []
	for l in locais:
		if l.has("terrain"):
			ids.append(l["id"])
	return ids


## Ids dos locais sem relevo (CH3, CE4, A11): só o horizonte plano de 0°.
func ids_sem_terreno() -> Array:
	var ids: Array = []
	for l in locais:
		if not l.has("terrain"):
			ids.append(l["id"])
	return ids


## "terrain" ou "reference": o modelo de horizonte em uso neste local.
## Regra do projeto: se o local tem o bloco `terrain`, ele é o padrão.
func modelo_em_uso(id: String) -> String:
	return "terrain" if (usar_terreno and tem_terreno(id)) else "reference"


## Janelas de visibilidade {"sun", "earth", "both"} de um modelo ("terrain" ou "reference").
func janelas_do_modelo(id: String, modelo: String) -> Dictionary:
	var l := local(id)
	if modelo == "terrain" and l.has("terrain"):
		return l["terrain"]["windows"]
	return l.get("windows", {"sun": [], "earth": [], "both": []})


func janelas(id: String) -> Dictionary:
	return janelas_do_modelo(id, modelo_em_uso(id))


# ---------- contas da missão ----------

func fim_missao() -> float:
	return inicio_missao + duracao_h * HORA


func avaliar_modelo(id: String, modelo: String, inicio: float, duracao: float) -> Dictionary:
	return CalculoLunar.avaliar_janelas(janelas_do_modelo(id, modelo), inicio, duracao,
			cobertura_ini, cobertura_fim)


## Indicadores do local na missão atual (ou em outra data/duração, se informadas).
func avaliar(id: String, inicio := -1.0, duracao := -1.0) -> Dictionary:
	return avaliar_modelo(id, modelo_em_uso(id),
			inicio_missao if inicio < 0.0 else inicio,
			duracao_h if duracao < 0.0 else duracao)


func regras() -> Array:
	return requisitos.get("rules", [])


## Descrição dos requisitos (do arquivo de dados), sem a frase que diz que os valores podem
## ser mudados na interface: este programa não tem essa função, então a frase não se aplica.
## Se o arquivo de dados vier sem ela, nada muda.
func descricao_dos_requisitos() -> String:
	return String(requisitos.get("description", "")).replace(FRASE_QUE_NAO_SE_APLICA, "")


## Classificação dos locais dados na missão atual (ou com outro início).
## Cada item: {"id", "resultado", "status", "valor"}; "valor" = horas com Sol e Terra juntos.
func classificacao(ids: Array, inicio := -1.0) -> Array:
	var cenarios: Array = []
	for id in ids:
		cenarios.append({"id": id, "resultado": avaliar(id, inicio)})
	return CalculoLunar.classificar(cenarios, regras(), requisitos.get("priority", "both_hours"))


## Quantos dos locais dados atendem aos requisitos.
func quantos_atendem(ids: Array, inicio := -1.0) -> int:
	var n := 0
	for item in classificacao(ids, inicio):
		if item["status"] == "met":
			n += 1
	return n


# ---------- datas que o usuário pode escolher ----------

## Missões recomendadas: até 5 combinações de data e duração, das melhores para as piores.
## Cada item: {"inicio" (Unix), "dias", "atendem", "total", "fracao"}.
##
## Critério (regra fixa, calculada dos dados; não é recomendação da NASA):
## - só datas que o calendário aceita (de hoje em diante) e missões de 7, 14 e 21 dias;
## - para cada duração, vence a data em que MAIS locais do polo sul atendem aos requisitos;
##   no empate, a de maior fração média com Sol e Terra visíveis juntos;
## - para 7 e 14 dias entra também a segunda melhor, a pelo menos 14 dias de distância da
##   primeira (senão a lista seria a mesma semana repetida).
## O resultado fica guardado: a busca testa ~1000 missões x 11 locais e leva uma fração de segundo.
func recomendados() -> Array:
	var minimo := data_minima()
	if _recomendados_de == minimo:
		return _recomendados
	if not _busca.is_empty() and _busca["minimo"] == minimo:
		_continuar_busca(false)   # havia uma busca adiantada pela metade: termina o que falta agora
		return _recomendados
	var ids := ids_do_polo()
	var lista: Array = []
	var pior := {}
	for dias in DURACOES_RECOMENDADAS:
		var candidatos: Array = []
		var t := minimo
		while t + dias * DIA <= cobertura_fim:
			_testar_missao(candidatos, ids, t, dias, pior)
			t += DIA
		lista.append_array(_melhores_da_duracao(candidatos, dias))
	_guardar_recomendados(lista, minimo, pior)
	return _recomendados


## A "data mais difícil": o caso oposto ao dos recomendados, para mostrar o quanto o resultado
## depende da data. Regra fixa: entre as missões de 14 dias de hoje em diante, a data em que
## MENOS locais do polo atendem aos requisitos; no empate, a de menor fração média com Sol e
## Terra juntos. Mesmo formato dos recomendados; {} se não houver missão de 14 dias possível.
## Sai da mesma busca dos recomendados (não custa uma busca a mais).
func data_mais_dificil() -> Dictionary:
	recomendados()
	return _mais_dificil


## A mesma busca de `recomendados`, feita aos poucos: alguns milissegundos por quadro, para a
## tela não travar. O menu chama isto ao abrir; quando o usuário chega ao mapa a lista já está
## pronta. Se alguém precisar da lista antes de isto terminar, `recomendados` termina na hora
## só o que estiver faltando.
func adiantar_recomendados() -> void:
	var minimo := data_minima()
	if not _busca.is_empty() or _recomendados_de == minimo:
		return
	# Onde a busca está: qual duração (posição em DURACOES_RECOMENDADAS) e qual data de pouso.
	_busca = {"minimo": minimo, "ids": ids_do_polo(), "duracao": 0, "t": minimo,
			"candidatos": [], "lista": [], "pior": {}}
	set_process(true)   # o trabalho é feito em `_process`, um pedaço por quadro


## Um pedaço da busca adiantada: trabalha MS_POR_QUADRO milissegundos e para até o próximo quadro.
## Com `aos_poucos = false` não para: vai até o fim de uma vez.
func _continuar_busca(aos_poucos := true) -> void:
	var b := _busca
	if _recomendados_de == b["minimo"]:   # a lista já foi calculada inteira por outro caminho
		_busca = {}
		return
	var relogio := Time.get_ticks_msec()
	while b["duracao"] < DURACOES_RECOMENDADAS.size():
		var dias: int = DURACOES_RECOMENDADAS[b["duracao"]]
		while b["t"] + dias * DIA <= cobertura_fim:
			_testar_missao(b["candidatos"], b["ids"], b["t"], dias, b["pior"])
			b["t"] += DIA
			if aos_poucos and Time.get_ticks_msec() - relogio >= MS_POR_QUADRO:
				return
		b["lista"].append_array(_melhores_da_duracao(b["candidatos"], dias))
		b["candidatos"] = []
		b["t"] = b["minimo"]
		b["duracao"] += 1
	_guardar_recomendados(b["lista"], b["minimo"], b["pior"])
	_busca = {}


## Testa uma missão (pouso em `t`, `dias` de duração) em todos os locais do polo e, se algum
## atende aos requisitos, acrescenta a missão aos candidatos.
## De passagem, entre as missões de 14 dias, guarda em `pior` a de menos locais atendendo
## (no empate, a de menor fração média): é a "data mais difícil".
func _testar_missao(candidatos: Array, ids: Array, t: float, dias: int, pior: Dictionary) -> void:
	var n := 0
	var soma := 0.0
	for id in ids:
		var res := avaliar_modelo(id, "terrain", t, dias * 24.0)
		if CalculoLunar.atende(res, regras()):
			n += 1
		soma += res["both"]["fraction"]
	var fracao := soma / ids.size()
	if n > 0:
		candidatos.append({"inicio": t, "dias": dias, "atendem": n, "total": ids.size(), "fracao": fracao})
	if dias == DIAS_DA_MISSAO_INICIAL and (pior.is_empty() or n < pior["atendem"]
			or (n == pior["atendem"] and fracao < pior["fracao"])):
		pior["inicio"] = t
		pior["dias"] = dias
		pior["atendem"] = n
		pior["total"] = ids.size()
		pior["fracao"] = fracao


## Das missões candidatas de uma duração, as melhores: 2 para 7 e 14 dias, 1 para 21, com pelo
## menos 14 dias entre uma e outra.
func _melhores_da_duracao(candidatos: Array, dias: int) -> Array:
	candidatos.sort_custom(_melhor_missao)
	var escolhidos: Array = []
	for c in candidatos:
		var longe := true
		for e in escolhidos:
			if absf(c["inicio"] - e["inicio"]) < 14.0 * DIA:
				longe = false
		if longe:
			escolhidos.append(c)
		if escolhidos.size() >= (1 if dias >= 21 else 2):
			break
	return escolhidos


func _guardar_recomendados(lista: Array, minimo: float, pior: Dictionary) -> void:
	lista.sort_custom(_melhor_missao)
	_recomendados = lista.slice(0, 5)
	_mais_dificil = pior
	_recomendados_de = minimo


func _melhor_missao(a: Dictionary, b: Dictionary) -> bool:
	if a["atendem"] != b["atendem"]:
		return a["atendem"] > b["atendem"]
	if not is_equal_approx(a["fracao"], b["fracao"]):
		return a["fracao"] > b["fracao"]
	return a["inicio"] < b["inicio"]


## Volta ao estado inicial do mapa: lista escondida e a missão inicial escolhida.
##
## A missão inicial é a primeira recomendada de 14 dias (DIAS_DA_MISSAO_INICIAL), e não a
## primeira da lista. A primeira da lista costuma ser uma missão de 7 dias em que todos os
## locais atendem com 100%: bonita, mas não mostra diferença nenhuma entre os locais. Com 14
## dias o resultado varia de local para local e muda muito com uma semana de atraso, que é a
## mensagem principal do programa. A lista de recomendados em si não muda.
## Sem recomendada de 14 dias, vale a primeira da lista; sem lista, 14 dias a partir do
## primeiro dia permitido.
func reiniciar() -> void:
	analise_feita = false
	inicio_antes_do_adiamento = -1.0
	usar_terreno = true
	var lista := recomendados()
	if lista.is_empty():
		inicio_missao = data_minima()
		duracao_h = 336.0
	else:
		var escolhida: Dictionary = lista[0]
		for r in lista:
			if r["dias"] == DIAS_DA_MISSAO_INICIAL:
				escolhida = r
				break
		inicio_missao = escolhida["inicio"]
		duracao_h = escolhida["dias"] * 24.0
	_missao_inicial_pronta = true
	missao_mudou.emit()


## Chamada pela tela do mapa ao abrir: na primeira vez, escolhe a missão inicial.
func garantir_missao_inicial() -> void:
	if not _missao_inicial_pronta:
		reiniciar()


## Hoje, à 00:00 UTC (segundo o relógio do computador).
func hoje_utc() -> float:
	return floorf(Time.get_unix_time_from_system() / DIA) * DIA


## Último dia que o calendário aceita: o pouso precisa cair dentro dos dados.
func data_maxima() -> float:
	return cobertura_fim - DIA


## Primeiro dia que o calendário aceita: hoje. Se hoje já passou do fim dos dados (ou ainda
## não chegou neles), vale o primeiro dia dos dados, para o programa continuar utilizável.
func data_minima() -> float:
	var hoje := hoje_utc()
	if hoje < cobertura_ini or hoje > data_maxima():
		return cobertura_ini
	return hoje


# ---------- mudar a missão ----------

func escolher_local(id: String) -> void:
	if _por_id.has(id):
		local_id = id
		missao_mudou.emit()


## Muda a data do pouso (arredondada à hora) e/ou a duração. Apaga a comparação do adiamento.
func definir_missao(inicio: float, duracao: float) -> void:
	inicio_missao = clampf(roundf(inicio / HORA) * HORA, cobertura_ini, cobertura_fim - DIA)
	duracao_h = clampf(duracao, DURACAO_MIN_H, DURACAO_MAX_H)
	inicio_antes_do_adiamento = -1.0
	missao_mudou.emit()


## "Delay 7 days": mesma duração, pouso 7 dias depois.
## No PRIMEIRO adiamento guarda a data original; os seguintes não mexem nela. Assim a
## comparação "antes do adiamento" é sempre com a data que o usuário tinha escolhido, por mais
## vezes que ele adie, e `desfazer_adiamento` volta para ela.
## Não faz nada se a missão adiada passaria do fim dos dados (ver `pode_adiar`).
func adiar_7_dias() -> void:
	if not pode_adiar():
		return
	if inicio_antes_do_adiamento < 0.0:
		inicio_antes_do_adiamento = inicio_missao
	inicio_missao += 7.0 * DIA
	missao_mudou.emit()


## Volta para a data de pouso de antes dos adiamentos.
func desfazer_adiamento() -> void:
	if inicio_antes_do_adiamento < 0.0:
		return
	inicio_missao = inicio_antes_do_adiamento
	inicio_antes_do_adiamento = -1.0
	missao_mudou.emit()


## true se a missão, adiada em 7 dias, ainda cabe inteira nos dados. Os botões "+7d" (no mapa
## e na tela do horizonte) ficam desabilitados quando isto é false.
func pode_adiar() -> bool:
	return inicio_missao + 7.0 * DIA + duracao_h * HORA <= cobertura_fim + 0.001


## Status e valor de cada requisito para um local, na missão atual (ou com outro início).
## {"status": geral, "checks": [{"id", "status", "value"}, ...]}
func requisitos_de(id: String, inicio := -1.0) -> Dictionary:
	return CalculoLunar.avaliar_requisitos(avaliar(id, inicio), regras())


# ---------- próximo nascer ou pôr ----------

## Próximo nascer ou pôr de um corpo ("sun" ou "earth") num local, depois do instante t.
## Olha as janelas inteiras do local até o FIM DOS DADOS (e não até o fim da missão: quase
## sempre o próximo evento cai depois dela). {"tipo": "set" | "rise", "t": instante} ou {}.
func proxima_mudanca(id: String, corpo: String, t: float) -> Dictionary:
	return CalculoLunar.proxima_mudanca(janelas(id).get(corpo, []), t, cobertura_fim)


## true se o corpo ("sun" ou "earth") está visível no local no instante t, pelas janelas.
func visivel_em(id: String, corpo: String, t: float) -> bool:
	return CalculoLunar.visivel_em(janelas(id).get(corpo, []), t)


# ---------- posição do Sol e da Terra num instante ----------

## {"sun_az", "sun_el", "earth_az", "earth_el"} em graus no instante t; {} fora da cobertura.
func posicao(id: String, t: float) -> Dictionary:
	var serie: Dictionary = local(id).get("series", {})
	if serie.is_empty() or t < cobertura_ini or t > cobertura_fim:
		return {}
	var n: int = serie["sun_el"].size()
	var x := (t - cobertura_ini) / float(horizontes.get("step_seconds", 3600))
	var i := clampi(int(floor(x)), 0, n - 2)
	var f := clampf(x - i, 0.0, 1.0)
	return {
		"sun_az": CalculoLunar.interpolar_azimute(serie["sun_az"][i], serie["sun_az"][i + 1], f),
		"sun_el": lerpf(serie["sun_el"][i], serie["sun_el"][i + 1], f),
		"earth_az": CalculoLunar.interpolar_azimute(serie["earth_az"][i], serie["earth_az"][i + 1], f),
		"earth_el": lerpf(serie["earth_el"][i], serie["earth_el"][i + 1], f),
	}


## Silhueta do terreno (1440 elevações, uma a cada 0,25°); [] se o local não tem relevo.
func perfil_do_terreno(id: String) -> Array:
	var l := local(id)
	if l.has("terrain"):
		return l["terrain"]["horizon"]["elevation_deg"]
	return []


## Elevação do horizonte (graus) num azimute, no modelo em uso. Sem relevo, é 0°.
func horizonte(id: String, azimute: float) -> float:
	if modelo_em_uso(id) == "terrain":
		return CalculoLunar.horizonte_em(perfil_do_terreno(id), azimute)
	return float(horizontes.get("visibility_threshold_deg", 0.0))


# ---------- mapas ----------

func mapa(id: String) -> Dictionary:
	return _mapa_por_id.get(id, {})


## Textura de um mapa. No JSON o caminho é "assets/maps/x.png"; no projeto é res://Assets/Maps/x.png.
func textura_do_mapa(id: String) -> Texture2D:
	var arquivo: String = String(mapa(id).get("image", "")).get_file()
	return load("res://Assets/Maps/" + arquivo) as Texture2D


# ---------- formatação (sempre UTC, horas com 1 casa, % sem casas) ----------

func fmt_data(t: float) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(roundf(t / HORA) * HORA))
	return "%04d-%02d-%02d %02d:00 UTC" % [d["year"], d["month"], d["day"], d["hour"]]


func fmt_dia(t: float) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(roundf(t / HORA) * HORA))
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]


func fmt_horas(h: float) -> String:
	return "%.1f h" % h


func fmt_pct(fracao: float) -> String:
	return "%.0f%%" % (fracao * 100.0)


func fmt_coordenadas(id: String) -> String:
	var l := local(id)
	var lat := float(l.get("latitude_deg", 0.0))
	var lon := float(l.get("longitude_east_deg", 0.0))
	return "%.2f° %s, %.2f° %s" % [absf(lat), Config.cardeal("S" if lat < 0.0 else "N"),
			absf(lon), Config.cardeal("W" if lon < 0.0 else "E")]


func rotulo_status(status: String) -> String:
	return Config.t(textos.get("status_labels", {}).get(status, status))


# ---------- telas ----------

## Troca a tela base (320x180 no menu, 640x360 nas outras telas). A janela não muda de tamanho.
func usar_base(tamanho: Vector2i) -> void:
	get_window().content_scale_size = tamanho


func ir_para(cena: String) -> void:
	if cena in _cenas_carregando:
		_receber_cena(cena)   # ainda carregando em segundo plano: espera só o que falta
	if _cenas_adiantadas.has(cena):
		get_tree().change_scene_to_packed(_cenas_adiantadas[cena])
	else:
		get_tree().change_scene_to_file(cena)


## Uma cena pronta para ser instanciada (a tela do horizonte, que abre por cima do mapa).
## Se ela foi adiantada, já está na mão; senão é carregada agora.
func cena(caminho: String) -> PackedScene:
	if caminho in _cenas_carregando:
		_receber_cena(caminho)
	if not _cenas_adiantadas.has(caminho):
		_cenas_adiantadas[caminho] = load(caminho)
	return _cenas_adiantadas[caminho]


## Começa a carregar uma cena em segundo plano, sem travar a tela. Quando `ir_para` for
## chamada para ela, a troca é imediata. A cena fica guardada: da segunda vez em diante já está pronta.
func adiantar_cena(cena: String) -> void:
	if _cenas_adiantadas.has(cena) or cena in _cenas_carregando:
		return
	if ResourceLoader.load_threaded_request(cena) == OK:
		_cenas_carregando.append(cena)
		set_process(true)   # `_process` recolhe a cena quando ela terminar de carregar


## Recolhe uma cena pedida em segundo plano (se ainda não terminou de carregar, espera).
func _receber_cena(cena: String) -> void:
	_cenas_carregando.erase(cena)
	var pronta := ResourceLoader.load_threaded_get(cena) as PackedScene
	if pronta != null:
		_cenas_adiantadas[cena] = pronta


# ---------- trabalho adiantado, um pouco por quadro ----------

## Só roda enquanto há algo adiantado em andamento (busca dos recomendados ou cena carregando).
func _process(_delta: float) -> void:
	if not _busca.is_empty():
		_continuar_busca()
	for cena in _cenas_carregando.duplicate():
		if ResourceLoader.load_threaded_get_status(cena) != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_receber_cena(cena)
	if _busca.is_empty() and _cenas_carregando.is_empty():
		set_process(false)


## Programa fechando com uma cena ainda carregando: espera terminar, para sair sem erro.
func _exit_tree() -> void:
	for cena in _cenas_carregando.duplicate():
		_receber_cena(cena)
