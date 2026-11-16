class_name MapaLunar
extends Control
## Desenha um mapa pixel art da Lua com os contornos das regiões candidatas e os marcadores
## dos locais, nas posições prontas de `maps.json` (em pixels do mapa, multiplicadas pela escala).
##
## - Passar o mouse num marcador emite `local_apontado(id)`; clicar emite `local_escolhido(id)`.
## - No mapa da Lua inteira só os 3 locais sem relevo são clicáveis; os do polo aparecem como
##   pontinhos apagados (eles abrem no mapa do polo sul).
## - O mapa pode ser ampliado por um valor quebrado (ex.: x1,16) sem os pixels ficarem
##   desiguais: um shader mantém cada pixel do mapa nítido e só suaviza a borda entre eles.
##
## Uso de IA: escrito com assistência do Claude (Anthropic).

signal local_apontado(id: String)
signal local_escolhido(id: String)

const RAIO_CLIQUE := 8.0
const TINTA := Color(0.80, 0.90, 1.0)   # leve tom azulado sobre o mapa em tons de cinza
const SHADER_PIXEL := "
shader_type canvas_item;
uniform vec4 tinta : source_color = vec4(1.0);
void fragment() {
	vec2 tam = vec2(textureSize(TEXTURE, 0));
	vec2 px = UV * tam;
	vec2 emenda = floor(px + 0.5);
	px = emenda + clamp((px - emenda) / fwidth(px), -0.5, 0.5);
	COLOR = texture(TEXTURE, px / tam) * tinta;
}
"

## id -> "met" | "not_met" | "insufficient_data" (cor do marcador). Vazio = marcadores neutros.
var status_por_id: Dictionary = {}
var destacado := "":
	set(v):
		if destacado != v:
			destacado = v
			queue_redraw()

var mapa_id := ""
var escala := 1.0
var _imagem: TextureRect
var _posicoes: Dictionary = {}     # id -> Vector2 (já na escala da tela)
var _regioes: Array = []
var _clicaveis: Array = []


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	mouse_exited.connect(func(): _apontar(""))
	# A imagem do mapa fica num filho, atrás dos desenhos deste nó (marcadores e contornos).
	_imagem = TextureRect.new()
	_imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagem.stretch_mode = TextureRect.STRETCH_SCALE
	_imagem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_imagem.show_behind_parent = true
	_imagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER_PIXEL
	var material_pixel := ShaderMaterial.new()
	material_pixel.shader = shader
	material_pixel.set_shader_parameter("tinta", TINTA)
	_imagem.material = material_pixel
	add_child(_imagem)


## Troca o mapa mostrado ("south_pole_px" ou "global_px") e o tamanho na tela.
func mostrar(id_do_mapa: String, nova_escala := 1.0) -> void:
	mapa_id = id_do_mapa
	escala = nova_escala
	var m := Dados.mapa(mapa_id)
	_imagem.texture = Dados.textura_do_mapa(mapa_id)
	_posicoes.clear()
	for id in m.get("sites", {}):
		var p: Array = m["sites"][id]
		_posicoes[id] = Vector2(p[0], p[1]) * escala
	_regioes = m.get("regions", [])
	var polar := String(m.get("projection", "")).begins_with("south_polar")
	_clicaveis = _posicoes.keys() if polar else Dados.ids_sem_terreno()
	custom_minimum_size = (Vector2(m.get("width", 256), m.get("height", 256)) * escala).round()
	size = custom_minimum_size
	_imagem.position = Vector2.ZERO
	_imagem.size = size
	destacado = ""
	queue_redraw()


func tem_local(id: String) -> bool:
	return id in _clicaveis


## Onde o local está desenhado neste mapa (coordenadas globais da tela); null se ele não
## aparece neste mapa. Vale também para os pontinhos apagados da Lua inteira.
func posicao_global(id: String) -> Variant:
	if not _posicoes.has(id):
		return null
	return global_position + (_posicoes[id] as Vector2).floor() + Vector2(0.5, 0.5)


## Quantos marcadores ficam dentro de um retângulo da tela (coordenadas globais).
## A ficha do local usa isto para abrir do lado menos poluído.
func marcadores_em(retangulo_global: Rect2) -> int:
	var n := 0
	for id in _clicaveis:
		if retangulo_global.grow(4.0).has_point(global_position + _posicoes[id]):
			n += 1
	return n


func _apontar(id: String) -> void:
	if id != destacado:
		destacado = id
		local_apontado.emit(id)
		if id != "":
			Config.som("passar")   # o mouse chegou num marcador clicável


func _mais_perto(ponto: Vector2) -> String:
	var melhor := ""
	var menor := RAIO_CLIQUE
	for id in _clicaveis:
		var d: float = ponto.distance_to(_posicoes[id])
		if d < menor:
			menor = d
			melhor = id
	return melhor


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion:
		_apontar(_mais_perto(evento.position))
	elif evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		var id := _mais_perto(evento.position)
		if id != "":
			local_escolhido.emit(id)


func _draw() -> void:
	if _imagem.texture == null:
		return
	# Contornos das regiões candidatas.
	for regiao in _regioes:
		var pontos := PackedVector2Array()
		for p in regiao["polygon_px"]:
			pontos.append((Vector2(p[0], p[1]) * escala).round() + Vector2(0.5, 0.5))
		pontos.append(pontos[0])
		draw_polyline(pontos, Color(Estilo.CIANO, 0.45), 1.0)

	# Pontinhos apagados: locais que existem neste mapa mas abrem em outro.
	for id in _posicoes:
		if not id in _clicaveis:
			draw_rect(Rect2(_posicoes[id].floor() - Vector2(1, 1), Vector2(2, 2)), Color(Estilo.TEXTO_FRACO, 0.7))

	# Marcadores (o destacado por último, para ficar por cima).
	var ordem: Array = _clicaveis.duplicate()
	if destacado in ordem:
		ordem.erase(destacado)
		ordem.append(destacado)
	for id in ordem:
		_desenhar_marcador(id)
	_desenhar_rotulos()

	draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), Estilo.INDIGO, false, 1.0)


func _desenhar_marcador(id: String) -> void:
	var c: Vector2 = _posicoes[id].floor()
	var cor := Estilo.TEXTO   # neutro: ainda sem análise
	if status_por_id.has(id):
		cor = Estilo.cor_status(status_por_id[id])
	# fundo escuro em losango, igual para todos
	draw_rect(Rect2(c + Vector2(-1, -3), Vector2(3, 7)), Estilo.MARINHO)
	draw_rect(Rect2(c + Vector2(-3, -1), Vector2(7, 3)), Estilo.MARINHO)
	draw_rect(Rect2(c + Vector2(-2, -2), Vector2(5, 5)), Estilo.MARINHO)
	# A forma muda com o status, para não depender só da cor: losango cheio = atende (ou ainda
	# sem análise); X = não atende; cruz fina = dados insuficientes.
	match String(status_por_id.get(id, "")):
		"not_met":
			for i in 5:
				draw_rect(Rect2(c + Vector2(i - 2, i - 2), Vector2.ONE), cor)
				draw_rect(Rect2(c + Vector2(2 - i, i - 2), Vector2.ONE), cor)
		"insufficient_data":
			draw_rect(Rect2(c + Vector2(0, -2), Vector2(1, 5)), cor)
			draw_rect(Rect2(c + Vector2(-2, 0), Vector2(5, 1)), cor)
		_:
			draw_rect(Rect2(c + Vector2(0, -2), Vector2(1, 5)), cor)
			draw_rect(Rect2(c + Vector2(-2, 0), Vector2(5, 1)), cor)
			draw_rect(Rect2(c + Vector2(-1, -1), Vector2(3, 3)), cor)


## Escreve a sigla ao lado de cada marcador, sem deixar um rótulo cair em cima de outro.
## Rótulo que não couber some; ele aparece quando o mouse passa no marcador.
func _desenhar_rotulos() -> void:
	var fonte := Estilo.fonte()
	var tam := 8
	var ocupados: Array[Rect2] = []
	for id in _clicaveis:
		ocupados.append(Rect2(_posicoes[id].floor() - Vector2(4, 4), Vector2(9, 9)))
	var ordem: Array = _clicaveis.duplicate()
	for prioridade in ["CR1", "IM2", destacado]:  # o último da lista é escrito primeiro
		if prioridade in ordem:
			ordem.erase(prioridade)
			ordem.push_front(prioridade)
	for id in ordem:
		var ativo: bool = id == destacado
		var largura := fonte.get_string_size(id, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x + 3.0
		var r := _lugar_do_rotulo(_posicoes[id].floor(), Vector2(largura, 10), ocupados, ativo)
		if r.size.x <= 0.0:
			continue
		# O local destacado muda só a cor das letras da sigla (sem moldura em volta).
		draw_rect(r, Color(Estilo.MARINHO, 0.8))
		draw_string(fonte, r.position + Vector2(2, 9), id, HORIZONTAL_ALIGNMENT_LEFT, -1, tam,
				Estilo.CIANO if ativo else Estilo.TEXTO)
		ocupados.append(r)


## Primeiro lugar livre em volta do marcador `c`. Sem lugar livre: Rect2() vazio, ou, se
## `forcar`, o primeiro lugar que cabe no mapa (o rótulo do marcador destacado sempre aparece).
func _lugar_do_rotulo(c: Vector2, tamanho: Vector2, ocupados: Array[Rect2], forcar: bool) -> Rect2:
	var tentativas := [
		c + Vector2(6, -5), c + Vector2(-5 - tamanho.x, -5),
		c + Vector2(-tamanho.x / 2.0, -16), c + Vector2(-tamanho.x / 2.0, 6),
		c + Vector2(6, -14), c + Vector2(6, 5), c + Vector2(-5 - tamanho.x, -14), c + Vector2(-5 - tamanho.x, 5),
	]
	var reserva := Rect2()
	for origem in tentativas:
		var r := Rect2(origem.floor(), tamanho)
		if r.position.x < 1 or r.position.y < 1 or r.end.x > size.x - 1 or r.end.y > size.y - 1:
			continue
		if reserva.size.x <= 0.0:
			reserva = r
		var livre := true
		for o in ocupados:
			if o.intersects(r):
				livre = false
				break
		if livre:
			return r
	return reserva if forcar else Rect2()
