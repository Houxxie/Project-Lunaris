class_name CursorPixel
extends RefCounted
## Ponteiro do mouse em pixel art, para combinar com o resto da interface.
##
## Os desenhos ficam aqui mesmo, em texto (um caractere = um pixel), e viram imagem quando o
## programa abre. Assim não há arquivo de imagem para importar e é fácil retocar um pixel.
##
## São os quatro ponteiros que o programa usa:
## - seta (normal);
## - mão (em cima de botões, marcadores e linhas da lista);
## - seta dupla (barras de arrastar: duração, linha do tempo e volumes);
## - "I" (em cima de texto que dá para selecionar, nas janelas).
##
## O ponteiro é desenhado pelo sistema, não pela tela do programa, então ele não cresce junto
## com a janela. Por isso `aplicar` recebe a escala: quem chama (o autoload `Config`) passa o
## tamanho de um pixel da tela 640x360 na janela atual, e o ponteiro fica com pixels do mesmo
## tamanho dos da interface.
##
## Uso de IA: escrito e desenhado com assistência do Claude (Anthropic).

const ESCALA_MIN := 2   ## menor que isso o ponteiro fica pequeno demais para usar
const ESCALA_MAX := 6   ## o maior desenho tem 17 pixels: 17 x 6 = 102, abaixo do limite de 128 da web

## Caractere -> cor. O ponto é transparente.
const CORES := {
	"#": Color("#070b22"),   # contorno (o azul-marinho dos painéis)
	"o": Color("#e6f1ff"),   # preenchimento (o branco dos textos)
	"c": Color("#4fe3ff"),   # sombra (o ciano das bordas)
}

## Para cada ponteiro: o desenho e a "ponta" (o pixel do desenho que marca onde o mouse está).
const DESENHOS := {
	Input.CURSOR_ARROW: {"ponta": Vector2i(0, 0), "linhas": [
		"#........",
		"##.......",
		"#o#......",
		"#oc#.....",
		"#ooc#....",
		"#oooc#...",
		"#ooooc#..",
		"#oooooc#.",
		"#ooooooc#",
		"#oooo####",
		"#oo#oc#..",
		"#o#.#oc#.",
		"##..#oc#.",
		".....##..",
	]},
	Input.CURSOR_POINTING_HAND: {"ponta": Vector2i(4, 0), "linhas": [
		"....##.......",
		"...#oo#......",
		"...#oo#......",
		"...#oo#......",
		"...#oo###....",
		"...#oo#oo###.",
		".###oo#oo#oo#",
		"#oo#oooooooc#",
		"#ooooooooooc#",
		".#oooooooooc#",
		"..#ooooooooc#",
		"..#oooooooc#.",
		"...#ooooooc#.",
		"...#ccccccc#.",
		"...#########.",
	]},
	Input.CURSOR_HSIZE: {"ponta": Vector2i(8, 4), "linhas": [
		"....#.......#....",
		"...##.......##...",
		"..#o#.......#o#..",
		".#oo#########oo#.",
		"#ooooooooooooooo#",
		".#cc#########cc#.",
		"..#c#.......#c#..",
		"...##.......##...",
		"....#.......#....",
	]},
	Input.CURSOR_IBEAM: {"ponta": Vector2i(3, 7), "linhas": [
		".##.##.",
		"#oo#oo#",
		".##o##.",
		"..#o#..",
		"..#o#..",
		"..#o#..",
		"..#o#..",
		"..#o#..",
		"..#o#..",
		"..#o#..",
		"..#o#..",
		"..#o#..",
		".##o##.",
		"#oo#oo#",
		".##.##.",
	]},
}


## Imagem de um ponteiro, com cada pixel do desenho virando um quadrado de `escala` pixels.
static func imagem(forma: int, escala: int) -> Image:
	var linhas: Array = DESENHOS[forma]["linhas"]
	var largura := 0
	for linha in linhas:
		largura = maxi(largura, String(linha).length())
	var img := Image.create(largura, linhas.size(), false, Image.FORMAT_RGBA8)
	for y in linhas.size():
		var linha: String = linhas[y]
		for x in linha.length():
			if CORES.has(linha[x]):
				img.set_pixel(x, y, CORES[linha[x]])
	img.resize(largura * escala, linhas.size() * escala, Image.INTERPOLATE_NEAREST)
	return img


## Troca os ponteiros do sistema pelos de pixel art, no tamanho pedido.
static func aplicar(escala: int) -> void:
	escala = clampi(escala, ESCALA_MIN, ESCALA_MAX)
	for forma in DESENHOS:
		var ponta: Vector2i = DESENHOS[forma]["ponta"]
		# a ponta fica no meio do "pixelzão", não no canto dele
		var ponto := Vector2(ponta * escala) + Vector2.ONE * floorf(escala / 2.0)
		if ponta == Vector2i.ZERO:
			ponto = Vector2.ZERO   # a seta aponta com o canto de cima, à esquerda
		# Passa a imagem pura (Image), não uma textura: uma textura ficaria guardada até depois
		# de o programa fechar a parte gráfica, e o Godot reclamaria de textura não liberada.
		Input.set_custom_mouse_cursor(imagem(forma, escala), forma, ponto)
