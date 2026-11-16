extends SceneTree
## Confere se todos os textos dos arquivos de dados (janelas SOURCES e ABOUT) têm tradução
## em português e em espanhol, e se os números das frases traduzidas são os mesmos do inglês.
##
## Como rodar (na pasta do projeto):
##   Godot_v4.7.2-stable_win64_console.exe --headless --script res://Testes/teste_traducoes.gd
## Rode de novo sempre que o Ricardo gerar os arquivos de dados outra vez: se uma frase mudou
## e ficou sem tradução, ela aparece aqui (no programa ela apareceria em inglês).

var _falhas := 0
var _total := 0


func _initialize() -> void:
	_rodar()


func _rodar() -> void:
	await process_frame
	await process_frame
	var config := root.get_node("Config")
	var dados := root.get_node("Dados")
	var idioma_antes: String = config.idioma

	# Todos os textos dos dados que as janelas mostram.
	var textos: Array = []
	var t: Dictionary = dados.textos
	for fonte in t.get("sources", []):
		textos.append(fonte["title"])
		textos.append(fonte["text"])
	textos.append_array(t.get("simplifications", []))
	textos.append_array(t.get("general_facts", []))
	textos.append(t.get("footer", ""))
	textos.append(dados.requisitos.get("label", ""))
	textos.append(dados.descricao_dos_requisitos())
	for regra in dados.regras():
		textos.append(regra["name"])
	for l in dados.locais:
		textos.append(l["context"])
		textos.append_array(t.get("site_facts", {}).get(l["id"], {}).get("facts", []))
		# A fonte das coordenadas dos pontos de amostra é uma frase explicativa (traduzida).
		# A dos outros 5 locais é só o título de uma publicação, que fica em inglês.
		if l.get("category", "") == "artemis_candidate_region":
			textos.append(l["source"])

	var numeros := RegEx.create_from_string("-?[0-9]+(?:\\.[0-9]+)?")
	for idioma in ["pt_BR", "es"]:
		config.idioma = idioma
		for texto in textos:
			_total += 1
			var traduzido: String = config.t(texto)
			if traduzido == texto:
				_falhas += 1
				print("SEM TRADUÇÃO (%s): %s" % [idioma, texto])
				continue
			# Os números têm de ser os mesmos, na mesma quantidade (a ordem pode mudar).
			var a: Array = numeros.search_all(texto).map(func(m): return m.get_string())
			var b: Array = numeros.search_all(traduzido).map(func(m): return m.get_string())
			a.sort()
			b.sort()
			if a != b:
				_falhas += 1
				print("NÚMEROS DIFERENTES (%s):\n   %s\n   %s" % [idioma, texto, traduzido])
	config.idioma = idioma_antes

	print("")
	if _falhas == 0:
		print("TUDO CERTO: %d textos conferidos (%d por idioma), todos traduzidos e com os mesmos números." % [_total, _total / 2])
	else:
		print("FALHAS: %d de %d." % [_falhas, _total])
	quit(0 if _falhas == 0 else 1)
