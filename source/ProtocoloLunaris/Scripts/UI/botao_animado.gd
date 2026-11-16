extends Button
## Botão com resposta visual.
##
## - Mouse em cima (ou foco pelo teclado): o botão cresce um pouco, clareia e o cursor vira a mãozinha.
## - Ao apertar: afunda e escurece.
## - Ao soltar: dá um "flash" e, só depois de um instante, emite o sinal `acionado`.
##
## Conecte as ações no sinal `acionado` (e não em `pressed`), para dar tempo de ver o clique
## antes de trocar de tela.

signal acionado

@export var escala_destaque: float = 1.06
@export var escala_apertado: float = 0.94
@export var brilho_destaque: float = 1.25
@export var brilho_apertado: float = 0.75
@export var brilho_flash: float = 1.5
## Duração das transições, em segundos.
@export var duracao: float = 0.08
## Espera entre o clique e o sinal `acionado`, em segundos.
@export var atraso_acao: float = 0.15
## Para botões só de imagem (flat): tira as margens internas, então a imagem ocupa o botão
## inteiro e a área clicável fica exatamente do tamanho dela. Use com uma imagem sem bordas
## transparentes (ou recortada com AtlasTexture), senão a borda invisível também é clicável.
@export var sem_margens: bool = false

var _tween: Tween
var _ocupado := false


func _ready() -> void:
	_ajustar_pivo()
	resized.connect(_ajustar_pivo)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())  # o destaque já mostra o foco
	if sem_margens:
		var vazio := StyleBoxEmpty.new()
		for estilo in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			add_theme_stylebox_override(estilo, vazio)
	mouse_entered.connect(_atualizar)
	mouse_entered.connect(func():
		if not disabled:
			Config.som("passar"))   # som de passar o mouse por algo clicável
	mouse_exited.connect(_ao_sair_mouse)
	focus_entered.connect(_atualizar)
	focus_exited.connect(_atualizar)
	button_down.connect(_ao_apertar)
	button_up.connect(_atualizar)
	pressed.connect(_ao_acionar)


func _ajustar_pivo() -> void:
	pivot_offset = size / 2.0  # cresce e encolhe a partir do centro


func _destacado() -> bool:
	return not disabled and (is_hovered() or has_focus())   # botão desabilitado não reage ao mouse


func _animar(escala: float, brilho: float, tempo: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * escala, tempo)
	_tween.tween_property(self, "modulate", Color(brilho, brilho, brilho, 1.0), tempo)


func _atualizar() -> void:
	if _ocupado:
		return
	if _destacado():
		_animar(escala_destaque, brilho_destaque, duracao)
	else:
		_animar(1.0, 1.0, duracao)


func _ao_sair_mouse() -> void:
	if has_focus():
		release_focus()  # o foco veio do clique; sem isto o botão ficaria destacado
	_atualizar()


func _ao_apertar() -> void:
	if not _ocupado:
		_animar(escala_apertado, brilho_apertado, duracao * 0.6)


func _ao_acionar() -> void:
	if _ocupado:
		return
	_ocupado = true
	_animar(escala_destaque, brilho_flash, duracao)
	await get_tree().create_timer(atraso_acao).timeout
	_ocupado = false
	_atualizar()
	acionado.emit()
