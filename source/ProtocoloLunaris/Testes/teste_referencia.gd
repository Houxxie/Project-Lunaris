extends SceneTree
## Confere as contas do Godot contra os números do Ricardo (Testes/reference_1y.json).
##
## Como rodar (na pasta do projeto):
##   Godot_v4.7.2-stable_win64_console.exe --headless --script res://Testes/teste_referencia.gd
## Sai com "TUDO CERTO" ou lista o que não bateu. Tolerância: 0,1 h (0,002 nas frações).

const TOL_H := 0.1
const TOL_F := 0.002
const TOL_GRAUS := 0.01

var _dados: Node
var _falhas := 0
var _checagens := 0


func _initialize() -> void:
	_dados = root.get_node_or_null("Dados")
	if _dados == null:
		_dados = load("res://Scripts/Dados/dados.gd").new()
		_dados.name = "Dados"
		root.add_child(_dados)
	if _dados.locais.is_empty():
		_dados._ready()  # neste modo (--script) o autoload ainda não recebeu o _ready
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Testes/reference_1y.json"))

	for caso in ref["cases"]:
		_conferir_caso(caso, "reference")
	for caso in ref["terrain_cases"]:
		_conferir_caso(caso, "terrain")
	for caso in ref["requirement_cases"]:
		_conferir_requisitos(caso)
	for caso in ref["ranking_cases"]:
		_conferir_classificacao(caso)

	print("")
	if _falhas == 0:
		print("TUDO CERTO: %d conferências bateram com reference_1y.json." % _checagens)
	else:
		print("FALHAS: %d de %d conferências não bateram." % [_falhas, _checagens])
	quit(0 if _falhas == 0 else 1)


func _unix(iso: String) -> float:
	return float(Time.get_unix_time_from_datetime_string(iso.trim_suffix("Z")))


func _ok(condicao: bool, descricao: String) -> void:
	_checagens += 1
	if not condicao:
		_falhas += 1
		print("  NÃO BATEU: ", descricao)


func _perto(obtido: float, esperado: float, tol: float, descricao: String) -> void:
	_ok(absf(obtido - esperado) <= tol, "%s: obtido %s, esperado %s" % [descricao, obtido, esperado])


func _conferir_caso(caso: Dictionary, modelo: String) -> void:
	var id: String = caso["site_id"]
	var inicio := _unix(caso["start_utc"])
	var nome := "%s %s %s %dh" % [id, modelo, caso["start_utc"], caso["duration_h"]]
	var res: Dictionary = _dados.avaliar_modelo(id, modelo, inicio, float(caso["duration_h"]))
	_ok(res["status"] == caso["status"], nome + " status")
	if caso["status"] != "ok" or res["status"] != "ok":
		return
	for corpo in ["sun", "earth", "both"]:
		_perto(res[corpo]["hours"], caso[corpo]["hours"], TOL_H, "%s %s.hours" % [nome, corpo])
		_perto(res[corpo]["fraction"], caso[corpo]["fraction"], TOL_F, "%s %s.fraction" % [nome, corpo])
		_perto(res[corpo]["longest_gap_h"], caso[corpo]["longest_gap_h"], TOL_H, "%s %s.longest_gap_h" % [nome, corpo])
		_ok(res[corpo]["gap_touches_start"] == caso[corpo]["gap_touches_start"], "%s %s.gap_touches_start" % [nome, corpo])
		_ok(res[corpo]["gap_touches_end"] == caso[corpo]["gap_touches_end"], "%s %s.gap_touches_end" % [nome, corpo])
	_perto(res["both_fraction"], caso["both_fraction"], TOL_F, nome + " both_fraction")
	# Posição do Sol e da Terra no início da missão (só nos casos com relevo).
	_dados.usar_terreno = true
	var pos: Dictionary = _dados.posicao(id, inicio)
	for corpo in ["sun", "earth"]:
		var chave: String = corpo + "_at_start"
		if not caso.has(chave):
			continue
		var esperado: Dictionary = caso[chave]
		var az: float = pos[corpo + "_az"]
		var el: float = pos[corpo + "_el"]
		var hz: float = _dados.horizonte(id, az)
		_perto(az, esperado["azimuth_deg"], TOL_GRAUS, "%s %s azimute" % [nome, corpo])
		_perto(el, esperado["elevation_deg"], TOL_GRAUS, "%s %s elevação" % [nome, corpo])
		_perto(hz, esperado["horizon_deg"], TOL_GRAUS, "%s %s horizonte" % [nome, corpo])
		_ok((el > hz) == esperado["visible"], "%s %s visível" % [nome, corpo])


func _conferir_requisitos(caso: Dictionary) -> void:
	var id: String = caso["site_id"]
	var modelo: String = caso["model"]
	var inicio := _unix(caso["start_utc"])
	var dur := float(caso["duration_h"])
	var nome := "requisitos %s %s %s" % [id, modelo, caso["start_utc"]]
	var regras: Array = _dados.regras()
	var antes: Dictionary = _dados.avaliar_modelo(id, modelo, inicio, dur)
	var depois: Dictionary = _dados.avaliar_modelo(id, modelo, inicio + 7.0 * 86400.0, dur)
	var ra: Dictionary = CalculoLunar.avaliar_requisitos(antes, regras)
	var rd: Dictionary = CalculoLunar.avaliar_requisitos(depois, regras)
	_ok(ra["status"] == caso["status"], nome + " status")
	_conferir_checagens(ra["checks"], caso["checks"], nome)
	if caso.has("delayed_7d_status"):
		_ok(rd["status"] == caso["delayed_7d_status"], nome + " status adiado")
		_conferir_checagens(rd["checks"], caso["delayed_7d_checks"], nome + " adiado")


## Cada requisito: o status e o valor do indicador. (A referência também traz uma frase por
## requisito e as frases do adiamento; o programa não as monta mais, porque nenhuma tela as
## mostra, então aqui se confere o número que estaria dentro delas.)
func _conferir_checagens(obtidas: Array, esperadas: Array, nome: String) -> void:
	_ok(obtidas.size() == esperadas.size(), nome + " nº de requisitos")
	for i in mini(obtidas.size(), esperadas.size()):
		var e: Dictionary = esperadas[i]
		_ok(obtidas[i]["status"] == e["status"], "%s %s status" % [nome, e["id"]])
		if e.get("value") == null or obtidas[i]["value"] == null:
			_ok(e.get("value") == obtidas[i]["value"], "%s %s valor (um dos dois não existe)" % [nome, e["id"]])
		else:
			# frações (0 a 1) usam a tolerância de fração; horas, a de horas
			var tol := TOL_F if float(e["value"]) <= 1.0 and String(e["id"]).contains("frac") else TOL_H
			_perto(obtidas[i]["value"], float(e["value"]), tol, "%s %s valor" % [nome, e["id"]])


func _conferir_classificacao(caso: Dictionary) -> void:
	var inicio := _unix(caso["start_utc"]) + float(caso["delay_days"]) * 86400.0
	var nome := "classificação %s +%dd" % [caso["start_utc"], caso["delay_days"]]
	_dados.usar_terreno = (caso["model"] == "terrain")
	_dados.duracao_h = float(caso["duration_h"])
	var lista: Array = _dados.classificacao(_dados.ids_do_polo(), inicio)
	_dados.usar_terreno = true
	_ok(lista.size() == caso["ranking"].size(), nome + " nº de locais")
	for i in mini(lista.size(), caso["ranking"].size()):
		var esperado: Dictionary = caso["ranking"][i]
		_ok(lista[i]["id"] == esperado["site_id"], "%s posição %d: obtido %s, esperado %s" % [nome, i + 1, lista[i]["id"], esperado["site_id"]])
		_ok(lista[i]["status"] == esperado["status"], "%s %s status" % [nome, esperado["site_id"]])
		if lista[i]["valor"] != null:
			_perto(lista[i]["valor"], esperado["both_hours"], TOL_H, "%s %s both_hours" % [nome, esperado["site_id"]])
