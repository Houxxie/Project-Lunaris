extends SceneTree
## Revisão automática de TODOS os textos do programa, nos três idiomas.
##
## Como rodar (na pasta do projeto):
##   Godot_v4.7.2-stable_win64_console.exe --headless --script res://Testes/revisar_textos.gd
##
## O que confere:
##  1. Todo texto que o código pede (Config.t / Config.longo) existe na tabela de traduções.
##  2. Cada tradução tem os mesmos marcadores do inglês (%d, %s, {1}...), na mesma quantidade.
##  3. Nenhuma tradução está vazia; avisa as que ficaram iguais ao inglês (para olhar).
##  4. Toda letra usada (traduções e textos dos dados) existe na fonte pixelada.
##  5. Os textos que ficam em lugares de largura fixa cabem neles, nos três idiomas.
##  6. Entradas da tabela que ninguém usa mais.
## Não confere a qualidade da tradução: isso é leitura humana.

const PASTA_SCRIPTS := "res://Scripts"
const IDIOMAS := ["en", "pt_BR", "es"]

var _problemas := 0
var _avisos := 0
var config: Node
var dados: Node


func _initialize() -> void:
	_rodar()


func _problema(texto: String) -> void:
	_problemas += 1
	print("  PROBLEMA: ", texto)


func _aviso(texto: String) -> void:
	_avisos += 1
	print("  aviso: ", texto)


func _arquivos_gd(pasta: String) -> Array:
	var lista: Array = []
	for nome in DirAccess.get_files_at(pasta):
		if nome.ends_with(".gd"):
			lista.append(pasta.path_join(nome))
	for sub in DirAccess.get_directories_at(pasta):
		lista.append_array(_arquivos_gd(pasta.path_join(sub)))
	return lista


## Tira os escapes de um texto como ele aparece no código ("a\\nb" -> "a" + quebra + "b").
func _sem_escapes(s: String) -> String:
	return s.replace("\\n", "\n").replace("\\\"", "\"").replace("\\\\", "\\")


func _marcadores(s: String, expressao: RegEx) -> Array:
	var lista: Array = expressao.search_all(s).map(func(m): return m.get_string())
	lista.sort()
	return lista


func _rodar() -> void:
	await process_frame
	await process_frame
	config = root.get_node("Config")
	dados = root.get_node("Dados")
	var idioma_antes: String = config.idioma
	var T = load("res://Scripts/Dados/traducoes.gd")
	var textos: Dictionary = T.TEXTOS
	var longos: Dictionary = T.LONGOS
	var modelos: Array = T.MODELOS

	# ---------- 1. o que o código pede existe na tabela? ----------
	print("\n1. Textos pedidos pelo código")
	var pede_t := RegEx.create_from_string("Config\\.t\\(\\s*\"((?:[^\"\\\\]|\\\\.)*)\"")
	var pede_longo := RegEx.create_from_string("Config\\.longo\\(\\s*\"([^\"]*)\"")
	var literal := RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
	var usados := {}
	var todo_o_codigo := ""
	for caminho in _arquivos_gd(PASTA_SCRIPTS):
		if caminho.ends_with("traducoes.gd"):
			continue
		var codigo := FileAccess.get_file_as_string(caminho)
		todo_o_codigo += codigo
		for m in pede_t.search_all(codigo):
			var chave := _sem_escapes(m.get_string(1))
			usados[chave] = true
			if not textos.has(chave):
				_problema("%s pede Config.t(\"%s\"), que não está na tabela" % [caminho.get_file(), m.get_string(1)])
		for m in pede_longo.search_all(codigo):
			if not longos.has(m.get_string(1)):
				_problema("%s pede Config.longo(\"%s\"), que não está na tabela" % [caminho.get_file(), m.get_string(1)])
	# textos que chegam ao Config.t por variável (constantes do código e textos dos dados)
	var de_dados: Array = []
	var t: Dictionary = dados.textos
	for fonte in t.get("sources", []):
		de_dados.append(fonte["title"])
		de_dados.append(fonte["text"])
	de_dados.append_array(t.get("simplifications", []))
	de_dados.append_array(t.get("general_facts", []))
	de_dados.append(t.get("footer", ""))
	de_dados.append_array(t.get("status_labels", {}).values())
	# rótulo do horizonte plano de 0°, na faixa da missão dos locais sem relevo
	de_dados.append(t.get("model_labels", {}).get("reference", ""))
	de_dados.append(dados.requisitos.get("label", ""))
	de_dados.append(dados.descricao_dos_requisitos())
	for regra in dados.regras():
		de_dados.append(regra["name"])
	for l in dados.locais:
		de_dados.append(l["context"])
		de_dados.append(String(l.get("source", "")))
		de_dados.append_array(t.get("site_facts", {}).get(l["id"], {}).get("facts", []))
	# textos que o código monta juntando pedaços (vista do horizonte: nome + situação)
	for corpo in ["Sun", "Earth"]:
		for situacao in ["", " (hidden)", " (below this view)", " (above this view)"]:
			de_dados.append(corpo + situacao)
	var literais_do_codigo := {}
	for m in literal.search_all(todo_o_codigo):
		literais_do_codigo[_sem_escapes(m.get_string(1))] = true
	print("  %d textos pedidos direto pelo código, %d vindos dos dados" % [usados.size(), de_dados.size()])

	# ---------- 2 e 3. marcadores e traduções vazias ou iguais ao inglês ----------
	print("\n2. Marcadores (%d, %s, {1}) e traduções vazias")
	var pct := RegEx.create_from_string("%[ds]")
	var chaves := RegEx.create_from_string("\\{[0-9]+\\}")
	var iguais: Array = []
	for chave in textos:
		var linha: Array = textos[chave]
		if linha.size() != 2:
			_problema("\"%s\" não tem as 2 colunas (português, espanhol)" % chave)
			continue
		for i in 2:
			var trad: String = linha[i]
			if trad.strip_edges() == "":
				_problema("tradução vazia (%s) de \"%s\"" % [IDIOMAS[i + 1], chave])
			if _marcadores(chave, pct) != _marcadores(trad, pct):
				_problema("marcadores diferentes (%s): \"%s\" -> \"%s\"" % [IDIOMAS[i + 1], chave, trad])
			if (chave.count("\n")) != (trad.count("\n")) and chave.length() < 80:
				_aviso("quebras de linha diferentes (%s): \"%s\"" % [IDIOMAS[i + 1], chave.replace("\n", "/")])
			if trad == chave:
				iguais.append("%s: %s" % [IDIOMAS[i + 1], chave.replace("\n", "/")])
	for nome in longos:
		var linha: Array = longos[nome]
		if linha.size() != 3:
			_problema("LONGOS[%s] não tem as 3 colunas" % nome)
			continue
		for i in 3:
			if String(linha[i]).strip_edges() == "":
				_problema("LONGOS[%s] vazio em %s" % [nome, IDIOMAS[i]])
			if _marcadores(linha[0], pct) != _marcadores(linha[i], pct):
				_problema("LONGOS[%s]: marcadores diferentes em %s" % [nome, IDIOMAS[i]])
	for linha in modelos:
		var grupos: int = String(linha[0]).count("{n}") + String(linha[0]).count("{s}")
		var esperado: Array = []
		for k in range(1, grupos + 1):
			esperado.append("{%d}" % k)
		esperado.sort()
		for i in [1, 2]:
			if _marcadores(linha[i], chaves) != esperado:
				_problema("MODELO com valores faltando ou sobrando (%s): %s" % [IDIOMAS[i], String(linha[0]).left(50)])
	print("  traduções iguais ao inglês (conferir se é isso mesmo): ", iguais.size())
	for linha in iguais:
		print("     ", linha)

	# ---------- 4. letras que a fonte pixelada não tem ----------
	print("\n4. Letras fora da fonte pixelada")
	var fonte: Font = load("res://Assets/Fonts/lunaris_pixel.fnt")
	var negrito: Font = load("res://Assets/Fonts/lunaris_pixel_bold.fnt")
	var tudo: Array = []
	for chave in textos:
		tudo.append(chave)
		tudo.append_array(textos[chave])
	for nome in longos:
		tudo.append_array(longos[nome])
	for linha in modelos:
		tudo.append_array(linha)
	for idioma in IDIOMAS:
		tudo.append_array(T.MESES[idioma])
		tudo.append_array(T.DIAS_DA_SEMANA[idioma])
	for id in T.NOMES_DOS_LOCAIS:
		tudo.append_array(T.NOMES_DOS_LOCAIS[id])
	tudo.append_array(config.NOMES_DOS_IDIOMAS.values())
	tudo.append_array(de_dados)
	for l in dados.locais:
		tudo.append(l["name"])
		tudo.append(String(l.get("source", "")))
	var faltando := {}
	for s in tudo:
		for c in String(s):
			var codigo := c.unicode_at(0)
			if codigo == 10 or c == "[" or c == "]":
				continue
			if not fonte.has_char(codigo) or not negrito.has_char(codigo):
				if not faltando.has(c):
					faltando[c] = String(s).left(60)
	if faltando.is_empty():
		print("  nenhuma: todas as letras usadas existem na fonte")
	for c in faltando:
		_problema("a fonte não tem \"%s\" (U+%04X), usada em: %s" % [c, c.unicode_at(0), faltando[c]])

	# ---------- 5. larguras nos lugares de tamanho fixo ----------
	print("\n5. Textos em lugares de largura fixa (largura em pixels da tela 640x360)")
	for idioma in IDIOMAS:
		config.idioma = idioma
		var casos := [
			# [onde, texto, fonte em negrito?, tamanho, largura máxima]
			["lista do mapa: resumo", config.t("%d OF %d MEET THE\nREQUIREMENTS") % [11, 11], true, 8, 144.0],
			["lista do mapa: antes do adiamento", config.t("BEFORE DELAY: %d OF %d") % [11, 11], false, 8, 144.0],
			["lista do mapa: outros locais", config.t("OTHER SITES"), false, 8, 144.0],
			["lista do mapa: botão de desfazer", config.t("UNDO DELAY"), false, 8, 138.0],
			["datas: título", config.t("BEST DATES"), true, 8, 196.0],
			["datas: data mais difícil", config.t("HARDEST DATE"), true, 8, 196.0],
			["título do mapa (polo)", config.t("LUNAR SOUTH POLE"), true, 16, 410.0],
			["título do mapa (Lua inteira)", config.t("WHOLE MOON"), true, 16, 410.0],
			["recomendados: subtítulo", config.t("WHEN THE MOST SOUTH POLE SITES\nMEET THE REQUIREMENTS"), false, 8, 196.0],
			["recomendados: sem datas", config.t("NO SUCH DATES LEFT\nIN THE DATA"), false, 8, 196.0],
			# tabela da linha do tempo (linha_tempo.gd): as colunas têm largura fixa; nas duas
			# primeiras, 9 px ficam para a marca de status ao lado do número
			["linha do tempo: VISIBLE (pior caso)", "672.0 h (100%)", true, 8, 95.0],
			["linha do tempo: LONGEST GAP (pior caso)", "%s 672.0 h" % config.t("at least"), true, 8, 125.0],
			["linha do tempo: LIMIT (pior caso)", config.t("max %s") % "100 h", false, 8, 58.0],
			["linha do tempo: título VISIBLE", config.t("VISIBLE"), false, 8, 104.0],
			["linha do tempo: título LONGEST GAP", config.t("LONGEST GAP"), false, 8, 134.0],
			["linha do tempo: título LIMIT", config.t("LIMIT"), false, 8, 58.0],
			["linha do tempo: nome da faixa", config.t("Earth"), false, 8, 42.0],
			# leitura no cursor (leitura_cursor.gd)
			["leitura no cursor: nome do corpo", config.t("Earth"), true, 8, 48.0],
			["leitura no cursor: linha da data", config.t("At cursor: %s, day %d") % ["2027-11-13 23:00 UTC", 28], false, 8, 612.0],
			["configurações: nome do volume", config.t("SOUND EFFECTS"), false, 8, 104.0],
		]
		for mes in config.meses():
			casos.append(["calendário: mês", "%s 2027" % mes, true, 8, 104.0])
		for id in dados.locais.map(func(l): return l["id"]):
			casos.append(["título do horizonte: " + id, dados.nome_limpo(id), true, 8, 342.0])
		# Linhas inteiras da tela do horizonte, com as mesmas contas de largura do código.
		var w := func(f: Font, s: String) -> float: return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		# Leitura no cursor (leitura_cursor.gd): situação + "el az" + próximo evento, no pior caso.
		var situacao := 0.0
		for palavra in ["visible", "hidden"]:
			for frase in ["%s above the terrain", "%s below the terrain", "%s above the horizon", "%s below the horizon"]:
				situacao = maxf(situacao, w.call(fonte, "%s, %s" % [config.t(palavra), config.t(frase) % "88.8°"]))
		var evento: float = maxf(w.call(fonte, config.t("%s (after the mission)") % (config.t("rises in ~%d h") % 999)),
				w.call(fonte, config.t("does not rise in the data period")))
		var leitura: float = 56.0 + situacao + 16.0 + w.call(fonte, "el -88.8° az 359.9°") + 16.0 + evento
		if leitura > 618.0:
			_problema("[%s] leitura no cursor: a linha vai até %d px, cabem 618" % [idioma, leitura])
		# Faixa da missão (faixa_missao.gd): pouso, duração, adiamento e botão à esquerda; horizonte à direita.
		var esquerda: float = 6.0 + w.call(fonte, config.t("LANDING")) + 5.0 + w.call(negrito, "2027-11-13") + 14.0 \
				+ w.call(fonte, config.t("DURATION")) + 5.0 + w.call(negrito, config.dias(28)) + 14.0 \
				+ w.call(fonte, config.t("+%dd from %s") % [49, "2027-11-13"]) + 6.0 + w.call(fonte, config.t("UNDO")) + 12.0
		var direita: float = w.call(fonte, config.t("0° reference horizon, no terrain")) + 6.0
		if esquerda + 8.0 + direita > 624.0:
			_problema("[%s] faixa da missão: %d px de texto, cabem 616" % [idioma, esquerda + direita])
		# Faixa de status (quadro_requisitos.gd): veredito + "(antes do adiamento: ...)" + botão de atenção.
		for status in ["Meets the requirements", "Does not meet the requirements"]:
			var faixa: float = 15.0 + w.call(negrito, config.t(status).to_upper()) + 8.0 \
					+ w.call(fonte, "(%s)" % (config.t("before delay: %s") % config.t("insufficient data"))) + 8.0 + 16.0
			if faixa > 618.0:
				_problema("[%s] faixa de status: vai até %d px, cabem 618" % [idioma, faixa])
		for caso in casos:
			var f: Font = negrito if caso[2] else fonte
			var maior := 0.0
			for parte in String(caso[1]).split("\n"):
				maior = maxf(maior, f.get_string_size(parte, HORIZONTAL_ALIGNMENT_LEFT, -1, caso[3]).x)
			if maior > caso[4]:
				_problema("[%s] %s: \"%s\" tem %d px, cabem %d" % [idioma, caso[0], String(caso[1]).replace("\n", "/"), maior, caso[4]])
	config.idioma = idioma_antes
	print("  conferido nos 3 idiomas")

	# ---------- 6. entradas que ninguém usa ----------
	print("\n6. Entradas da tabela sem uso")
	var sem_uso := 0
	for chave in textos:
		if not usados.has(chave) and not chave in de_dados and not literais_do_codigo.has(chave):
			sem_uso += 1
			print("     ", String(chave).replace("\n", "/").left(90))
	for nome in longos:
		if not todo_o_codigo.contains("\"%s\"" % nome):
			sem_uso += 1
			print("     LONGOS: ", nome)
	if sem_uso == 0:
		print("  nenhuma")

	print("\nRESULTADO: %d problema(s), %d aviso(s)." % [_problemas, _avisos])
	quit(0 if _problemas == 0 else 1)
