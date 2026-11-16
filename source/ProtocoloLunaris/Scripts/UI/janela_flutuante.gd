class_name JanelaFlutuante
extends Control
## Janelinha que abre por cima da tela, colada num ponto (ex.: logo acima de um botão).
## Usada pela lista de missões recomendadas.
##
## Abrir:  JanelaFlutuante.abrir(self, ponto, conteudo)
## - `ponto`: canto inferior esquerdo da janela (ela abre para cima), em coordenadas da tela.
## - `conteudo`: qualquer Control (uma coluna de botões, por exemplo).
## Fechar: `fechar()`, tecla Esc ou clique fora.
##
## Uso de IA: escrito com assistência do Claude (Anthropic).

var _painel: PanelContainer
var _ponto := Vector2.ZERO
var _fechando := false


static func abrir(de: Node, ponto: Vector2, conteudo: Control) -> JanelaFlutuante:
	var j := JanelaFlutuante.new()
	j._ponto = ponto
	j.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	j.mouse_filter = Control.MOUSE_FILTER_STOP
	j.z_index = 40
	j.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			j.fechar())
	j._painel = PanelContainer.new()
	j._painel.add_theme_stylebox_override("panel", Estilo.caixa(Estilo.MARINHO, Estilo.CIANO, 6.0))
	j.add_child(j._painel)
	j._painel.add_child(conteudo)
	Estilo.tela_de(de).add_child(j)
	j._posicionar.call_deferred()
	return j


## Põe o painel logo acima do ponto pedido, sem sair da tela, e toca a animação de abertura.
func _posicionar() -> void:
	var tam := _painel.get_combined_minimum_size()
	_painel.size = tam
	_painel.position = Vector2(
			clampf(_ponto.x, 4.0, size.x - tam.x - 4.0),
			clampf(_ponto.y - tam.y, 4.0, size.y - tam.y - 4.0)).round()
	Estilo.animar_abertura(_painel)


## Fecha recolhendo a janela para o canto de onde ela abriu.
func fechar() -> void:
	if _fechando:
		return
	_fechando = true
	Config.som("fechar_tela")
	await Estilo.animar_fechamento(_painel).finished
	queue_free()


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		fechar()
