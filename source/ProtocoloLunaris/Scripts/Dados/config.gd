extends Node
## Autoload `Config`: as preferências do usuário (idioma e volumes) e a tradução dos textos.
##
## - `Config.t("ANALYZE")` devolve o texto no idioma escolhido (a tabela está em traducoes.gd).
## - As preferências são gravadas em user://config.cfg e voltam na próxima vez que o programa abre.
## - Os volumes agem em dois canais de áudio, "Music" e "SFX", criados aqui.
## - O som do programa também mora aqui (por ser um autoload, ele não para na troca de tela):
##   `Config.iniciar_musica()` começa a música de fundo e `Config.som("passar")` toca um efeito.
##   Os arquivos ficam em Assets/Audio; os nomes estão em MUSICA e SONS, logo abaixo.
##
## Uso de IA: escrito com assistência do Claude (Anthropic).

signal idioma_mudou

const IDIOMAS := ["en", "pt_BR", "es"]
## Nome de cada idioma, escrito no próprio idioma.
const NOMES_DOS_IDIOMAS := {"en": "ENGLISH", "pt_BR": "PORTUGUÊS", "es": "ESPAÑOL"}
const ARQUIVO := "user://config.cfg"
const CANAL_MUSICA := "Music"
const CANAL_SFX := "SFX"
const CANAIS_DAS_COPIAS: Array[String] = ["MusicaA", "MusicaB"]   ## um canal para cada cópia da música

# ---------- som ----------
const PASTA_DE_AUDIO := "res://Assets/Audio/"
## Música de fundo (nome do arquivo, sem a extensão).
const MUSICA := "Musica Ambiente 1"
## Efeitos sonoros: nome usado no código -> nome do arquivo (sem a extensão).
const SONS := {
	"passar": "SFX Som passando por clicaveis",   # mouse em cima de algo clicável
	"explorar": "SFX Play",                       # clique no EXPLORE
	"abrir_tela": "SFX Click e abre tela",        # a tela do horizonte abre
	"fechar_tela": "SFX_Fechando telas",          # a tela do horizonte e as janelas fecham
	"voltar_menu": "SFX Som Voltando ao menu",   # botão MENU do mapa
	"abrir_info": "SFX Abrindo janelas de help e source e about",     # abre ajuda, fontes, sobre ou o motivo dos requisitos
	"fechar_info": "SFX Fechando janelas de help e source e about",   # fecha uma dessas janelas
	"analisar": "SFX Analisar",                # clique no ANALYZE
	"trocar_tela": "SFX Trocando Tela",           # troca entre o polo sul e a Lua inteira
}
## Ajuste de volume de cada arquivo (em dB), para todos soarem com o mesmo volume médio
## (-18 dB: volume médio dos trechos que não são silêncio, medido arquivo por arquivo).
## Arquivo que não está aqui toca sem ajuste. Ao trocar um arquivo, medir de novo.
const AJUSTE_DB := {
	"Musica Ambiente 1": -2.0,
	"SFX Som passando por clicaveis": -2.5,
	"SFX Play": 0.5,
	"SFX Click e abre tela": -1.5,
	"SFX_Fechando telas": -1.5,
	"SFX Som Voltando ao menu": -8.0,
	"SFX Abrindo janelas de help e source e about": -8.3,   # 30% mais baixo que os outros, a pedido
	"SFX Fechando janelas de help e source e about": -8.5,  # idem
	"SFX Analisar": 2.2,
	"SFX Trocando Tela": -0.9,
}
const TEMPO_DE_SAIDA := 1.5        ## segundos do fade-out da música, na volta ao menu
const VOLUME_INICIAL_DA_MUSICA := 0.1   ## a música começa mais baixa que os efeitos
const VOLUME_INICIAL_DOS_EFEITOS := 0.5
const TEMPO_DE_ENTRADA := 3.0      ## segundos do fade-in da música, quando ela começa
## A música não "recomeça": nos últimos segundos, uma segunda cópia dela entra do começo, bem
## baixinho, e vai subindo enquanto a primeira some. Assim a emenda do fim com o começo não
## dá para notar, mesmo que a faixa não tenha sido feita para repetir.
const TEMPO_DE_EMENDA := 5.0
const SILENCIO_DB := -50.0
const INTERVALO_DO_PASSAR_MS := 70   ## o som de passar o mouse não repete mais rápido que isto

var idioma := "en"            ## "en", "pt_BR" ou "es"
var volume_musica := VOLUME_INICIAL_DA_MUSICA     ## de 0 a 1
var volume_sfx := VOLUME_INICIAL_DOS_EFEITOS      ## de 0 a 1

var _escala_do_ponteiro := 0         # tamanho do ponteiro do mouse em uso (0 = ainda não aplicado)
var _modelos: Array[RegEx] = []    # expressões regulares dos MODELOS, montadas uma vez só
var _ja_traduzidos: Dictionary = {}  # frases já traduzidas por modelo (para não repetir a busca)
var _efeitos: Dictionary = {}        # nome do efeito -> AudioStream
var _tocadores_de_sfx: Array[AudioStreamPlayer] = []
var _tocadores_de_musica: Array[AudioStreamPlayer] = []   # dois: um toca, o outro espera a emenda
var _musica_atual := -1              # qual dos dois está tocando (-1 = a música ainda não começou)
var _proxima_copia := 0             # qual cópia da música toca no próximo EXPLORE
var _fades: Dictionary = {}          # canal -> o fade (Tween) em andamento nele
var _ultimo_passar := 0              # quando o som de passar o mouse tocou pela última vez (ms)


func _ready() -> void:
	_criar_canal(CANAL_MUSICA)
	_criar_canal(CANAL_SFX)
	_carregar()
	_aplicar_volumes()
	_montar_som()
	set_process(false)   # `_process` só cuida da emenda da música, depois que ela começa
	# Ponteiro do mouse em pixel art (os desenhos estão em cursor_pixel.gd). Ele é refeito
	# quando a janela muda de tamanho, para os pixels dele acompanharem os da interface.
	if DisplayServer.get_name() != "headless":
		get_window().size_changed.connect(_ajustar_ponteiro)
		_ajustar_ponteiro()


## Escolhe o tamanho do ponteiro: um pixel dele = um pixel da tela 640x360 na janela atual
## (2 na janela de 1280x720, 3 em tela cheia de 1920x1080).
func _ajustar_ponteiro() -> void:
	var janela := Vector2(get_window().size)
	var escala := roundi(minf(janela.x / 640.0, janela.y / 360.0))
	escala = clampi(escala, CursorPixel.ESCALA_MIN, CursorPixel.ESCALA_MAX)
	if escala != _escala_do_ponteiro:
		_escala_do_ponteiro = escala
		CursorPixel.aplicar(escala)


# ---------- tradução ----------

## Texto no idioma escolhido. `texto` é o original em inglês (a chave da tabela).
func t(texto: String) -> String:
	if idioma == "en":
		return texto
	if Traducoes.TEXTOS.has(texto):
		return Traducoes.TEXTOS[texto][Traducoes.COLUNA[idioma]]
	return _por_modelo(texto)


## Traduz uma frase dos dados que só muda nos números (tabela MODELOS de traducoes.gd):
## acha o modelo em inglês que casa com a frase, pega os números dela e os coloca na frase
## traduzida. Sem modelo que sirva, devolve a frase como veio (em inglês).
func _por_modelo(texto: String) -> String:
	var chave := idioma + "|" + texto
	if _ja_traduzidos.has(chave):
		return _ja_traduzidos[chave]
	if _modelos.is_empty():
		for linha in Traducoes.MODELOS:
			_modelos.append(RegEx.create_from_string(_expressao_do_modelo(linha[0])))
	var resultado := texto
	for i in _modelos.size():
		var achado: RegExMatch = _modelos[i].search(texto)
		if achado == null:
			continue
		resultado = Traducoes.MODELOS[i][1 + Traducoes.COLUNA[idioma]]
		for k in range(1, achado.get_group_count() + 1):
			resultado = resultado.replace("{%d}" % k, achado.get_string(k))
		break
	_ja_traduzidos[chave] = resultado
	return resultado


## Transforma um modelo ("... more than {n}° above ...") numa expressão regular que casa com
## a frase inteira: {n} vira "um número" e {s} vira "um trecho de texto".
func _expressao_do_modelo(modelo: String) -> String:
	var especiais := "\\.^$|?*+()[]{}"
	var expressao := "^"
	var i := 0
	while i < modelo.length():
		if modelo.substr(i, 3) == "{n}":
			expressao += "(-?[0-9]+(?:\\.[0-9]+)?)"
			i += 3
		elif modelo.substr(i, 3) == "{s}":
			expressao += "(.+?)"
			i += 3
		else:
			var c := modelo[i]
			expressao += ("\\" + c) if especiais.contains(c) else c
			i += 1
	return expressao + "$"


## Texto comprido, pelo nome (tabela LONGOS).
func longo(nome: String) -> String:
	var linha: Array = Traducoes.LONGOS[nome]
	return linha[IDIOMAS.find(idioma)]


## "7 DAYS", "7 DIAS", "7 DÍAS" (e "1 DAY", "1 DIA", "1 DÍA").
func dias(n: int) -> String:
	return t("%d DAY" if n == 1 else "%d DAYS") % n


## Letra de um ponto cardeal no idioma: `cardeal("W")` é "W" em inglês e "O" em português.
func cardeal(letra: String) -> String:
	return Traducoes.CARDEAIS[idioma][letra]


func meses() -> Array:
	return Traducoes.MESES[idioma]


func dias_da_semana() -> Array:
	return Traducoes.DIAS_DA_SEMANA[idioma]


## Nome traduzido de um local, se houver; senão devolve `padrao` (o nome dos dados).
func nome_do_local(id: String, padrao: String) -> String:
	if idioma != "en" and Traducoes.NOMES_DOS_LOCAIS.has(id):
		return Traducoes.NOMES_DOS_LOCAIS[id][Traducoes.COLUNA[idioma]]
	return padrao


## Caminho da imagem de um botão no idioma escolhido. Os botões com texto têm uma versão
## por idioma (Assets/Sprites/botoes/pt_BR e /es); os sem texto (help, close, play-icon,
## delay-icon) e os em inglês ficam na pasta principal.
func caminho_do_botao(nome: String) -> String:
	var pasta := "res://Assets/Sprites/botoes/"
	if idioma != "en":
		var traduzido := "%s%s/%s.png" % [pasta, idioma, nome]
		if ResourceLoader.exists(traduzido):
			return traduzido
	return pasta + nome + ".png"


func definir_idioma(novo: String) -> void:
	if novo in IDIOMAS and novo != idioma:
		idioma = novo
		_salvar()
		idioma_mudou.emit()


# ---------- volumes ----------

func definir_volume_musica(valor: float) -> void:
	volume_musica = clampf(valor, 0.0, 1.0)
	_aplicar_volumes()
	_salvar()


func definir_volume_sfx(valor: float) -> void:
	volume_sfx = clampf(valor, 0.0, 1.0)
	_aplicar_volumes()
	_salvar()


func _criar_canal(nome: String, envio := "Master") -> void:
	if AudioServer.get_bus_index(nome) == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, nome)
		AudioServer.set_bus_send(i, envio)


## Muda o volume de um canal pelo nome (usado nos fades da música).
func _volume_do_canal(db: float, nome: String) -> void:
	var i := AudioServer.get_bus_index(nome)
	if i != -1:
		AudioServer.set_bus_volume_db(i, db)


func _aplicar_volumes() -> void:
	for par in [[CANAL_MUSICA, volume_musica], [CANAL_SFX, volume_sfx]]:
		var i := AudioServer.get_bus_index(par[0])
		if i == -1:
			continue
		AudioServer.set_bus_mute(i, par[1] <= 0.0)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(par[1], 0.0001)))


# ---------- música e efeitos ----------

func _montar_som() -> void:
	for nome in SONS:
		var efeito := _carregar_som(SONS[nome])
		if efeito != null:
			_efeitos[nome] = efeito
	for i in 6:   # seis efeitos podem tocar ao mesmo tempo
		var tocador := AudioStreamPlayer.new()
		tocador.bus = CANAL_SFX
		add_child(tocador)
		_tocadores_de_sfx.append(tocador)
	var musica := _carregar_som(MUSICA)
	if musica == null:
		return
	if "loop" in musica:
		musica.set("loop", false)   # quem emenda o fim com o começo é o `_process` daqui
	for i in 2:
		# Cada cópia da música tem um canal só dela, que desemboca no canal da música. Os fades
		# mexem no volume desse canal e não no do tocador: no navegador, mudar o volume de um
		# tocador que já está tocando não funciona direito (a música ficava quase muda).
		var canal: String = CANAIS_DAS_COPIAS[i]
		_criar_canal(canal, CANAL_MUSICA)
		_volume_do_canal(SILENCIO_DB, canal)
		var tocador := AudioStreamPlayer.new()
		tocador.stream = musica
		tocador.volume_db = AJUSTE_DB.get(MUSICA, 0.0)
		tocador.bus = canal
		add_child(tocador)
		_tocadores_de_musica.append(tocador)
	# No navegador o Godot, por padrão, entrega cada som pronto ao navegador ("amostra"). Com os
	# canais criados aqui em código isso saía mudo, e preparar a música inteira travava o
	# EXPLORE. Então, lá, todo som é misturado pelo próprio Godot, como no computador.
	if OS.has_feature("web"):
		for tocador: AudioStreamPlayer in _tocadores_de_sfx + _tocadores_de_musica:
			tocador.playback_type = AudioServer.PLAYBACK_TYPE_STREAM


## Carrega um som de Assets/Audio pelo nome, com qualquer das extensões que o Godot aceita.
## Arquivo que não existe não é erro: o programa só fica sem aquele som.
func _carregar_som(nome: String) -> AudioStream:
	for extensao in [".ogg", ".mp3", ".wav"]:
		var caminho: String = PASTA_DE_AUDIO + nome + extensao
		if ResourceLoader.exists(caminho):
			return load(caminho) as AudioStream
	return null


## Toca um efeito sonoro pelo nome (as chaves de SONS): `Config.som("passar")`.
func som(nome: String) -> void:
	if not _efeitos.has(nome):
		return
	if nome == "passar":   # varrer o mouse por vários botões não vira uma metralhadora
		var agora := Time.get_ticks_msec()
		if agora - _ultimo_passar < INTERVALO_DO_PASSAR_MS:
			return
		_ultimo_passar = agora
	var livre: AudioStreamPlayer = _tocadores_de_sfx[0]
	for tocador in _tocadores_de_sfx:
		if not tocador.playing:
			livre = tocador
			break
	livre.stream = _efeitos[nome]
	livre.volume_db = AJUSTE_DB.get(SONS[nome], 0.0)   # todos os sons no mesmo volume médio
	livre.play()


## Começa a música de fundo, com fade-in. É chamada no clique do EXPLORE; ela toca no mapa e
## na tela do horizonte, e para (com fade-out) na volta ao menu: ver `parar_musica`.
func iniciar_musica() -> void:
	if _musica_atual >= 0 or _tocadores_de_musica.is_empty():
		return
	_musica_atual = _proxima_copia
	_entrar(_tocadores_de_musica[_musica_atual], TEMPO_DE_ENTRADA)
	set_process(true)


## Para a música com fade-out. É chamada na volta ao menu; o próximo EXPLORE recomeça a
## música do início, na outra cópia (esta pode ainda estar terminando de sumir).
func parar_musica(tempo := TEMPO_DE_SAIDA) -> void:
	if _musica_atual < 0:
		return
	_proxima_copia = 1 - _musica_atual
	for tocador in _tocadores_de_musica:
		if tocador.playing:
			_sair(tocador, tempo)
	_musica_atual = -1
	set_process(false)


func _entrar(tocador: AudioStreamPlayer, tempo: float) -> void:
	var canal := String(tocador.bus)
	_volume_do_canal(SILENCIO_DB, canal)
	tocador.play(0.0)
	_novo_fade(canal).tween_method(_volume_do_canal.bind(canal), SILENCIO_DB, 0.0, tempo) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _sair(tocador: AudioStreamPlayer, tempo: float) -> void:
	var canal := String(tocador.bus)
	var de_onde := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(canal))   # pode estar no meio de outro fade
	var some := _novo_fade(canal)
	some.tween_method(_volume_do_canal.bind(canal), de_onde, SILENCIO_DB, tempo) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	some.tween_callback(tocador.stop)


## Um fade novo para o canal; se havia outro em andamento nele, é cancelado (senão os dois
## brigariam pelo mesmo volume).
func _novo_fade(canal: String) -> Tween:
	var antigo: Tween = _fades.get(canal)
	if antigo != null and antigo.is_valid():
		antigo.kill()
	var novo := create_tween()
	_fades[canal] = novo
	return novo


## Ao fechar o programa, para todos os sons: um tocador ainda tocando na hora de sair faz o
## Godot reclamar de recurso em uso.
func _exit_tree() -> void:
	for tocador in _tocadores_de_musica + _tocadores_de_sfx:
		tocador.stop()
		tocador.stream = null


## A emenda da música: perto do fim, a outra cópia entra do começo enquanto esta some.
func _process(_delta: float) -> void:
	if _musica_atual < 0:
		return
	var tocando := _tocadores_de_musica[_musica_atual]
	var duracao := tocando.stream.get_length()
	if not tocando.playing:   # acabou sem emendar (faixa curta demais, por exemplo): recomeça
		_entrar(tocando, 1.0)
		return
	var emenda := minf(TEMPO_DE_EMENDA, duracao * 0.25)
	if duracao > 0.0 and tocando.get_playback_position() >= duracao - emenda:
		var proximo := 1 - _musica_atual
		_sair(tocando, emenda)
		_entrar(_tocadores_de_musica[proximo], emenda)
		_musica_atual = proximo


# ---------- gravar e ler ----------

func _salvar() -> void:
	var arquivo := ConfigFile.new()
	arquivo.set_value("jogo", "idioma", idioma)
	arquivo.set_value("audio", "musica", volume_musica)
	arquivo.set_value("audio", "sfx", volume_sfx)
	arquivo.save(ARQUIVO)


func _carregar() -> void:
	var arquivo := ConfigFile.new()
	if arquivo.load(ARQUIVO) != OK:
		return
	var lido: String = arquivo.get_value("jogo", "idioma", "en")
	if lido in IDIOMAS:
		idioma = lido
	volume_musica = clampf(float(arquivo.get_value("audio", "musica", VOLUME_INICIAL_DA_MUSICA)), 0.0, 1.0)
	volume_sfx = clampf(float(arquivo.get_value("audio", "sfx", VOLUME_INICIAL_DOS_EFEITOS)), 0.0, 1.0)
