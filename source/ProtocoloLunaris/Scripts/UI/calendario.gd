class_name Calendario
extends Control
## Calendário para escolher a data do pouso (sempre em UTC).
##
## Abrir:  Calendario.abrir(self, ponto, data_atual, minimo, maximo, func(dia): ...)
## - `ponto`: canto inferior esquerdo onde o calendário aparece (ele abre para cima).
## - Dias antes de `minimo` ou depois de `maximo` ficam apagados e não podem ser escolhidos.
## Fechar: escolher um dia, tecla Esc ou clique fora.
##
## Uso de IA: escrito com assistência do Claude (Anthropic).

const CELULA := Vector2(18, 12)
const DIA := 86400.0

var _selecionado := 0.0
var _minimo := 0.0
var _maximo := 0.0
var _ao_escolher: Callable
var _animado := false
var _fechando := false
var _ano := 2026
var _mes := 11

var _painel: PanelContainer
var _titulo: Label
var _anterior: Button
var _proximo: Button
var _grade: GridContainer
var _ponto := Vector2.ZERO


static func abrir(de: Node, ponto: Vector2, selecionado: float, minimo: float, maximo: float,
		ao_escolher: Callable) -> Calendario:
	var c := Calendario.new()
	c._selecionado = selecionado
	c._minimo = minimo
	c._maximo = maximo
	c._ao_escolher = ao_escolher
	c._ponto = ponto
	Estilo.tela_de(de).add_child(c)
	return c


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 40
	gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			fechar())

	_painel = PanelContainer.new()
	_painel.add_theme_stylebox_override("panel", Estilo.caixa(Estilo.MARINHO, Estilo.CIANO, 6.0))
	add_child(_painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 3)
	_painel.add_child(coluna)

	# Cabeçalho: mês anterior, nome do mês, próximo mês.
	var topo := HBoxContainer.new()
	coluna.add_child(topo)
	_anterior = Estilo.botao_texto("<", Config.t("Previous month"))
	_anterior.custom_minimum_size = Vector2(14, 12)
	_anterior.pressed.connect(func(): _mudar_mes(-1))
	topo.add_child(_anterior)
	_titulo = Estilo.rotulo("", 8, Estilo.CIANO)
	Estilo.em_negrito(_titulo)
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(_titulo)
	_proximo = Estilo.botao_texto(">", Config.t("Next month"))
	_proximo.custom_minimum_size = Vector2(14, 12)
	_proximo.pressed.connect(func(): _mudar_mes(1))
	topo.add_child(_proximo)

	_grade = GridContainer.new()
	_grade.columns = 7
	_grade.add_theme_constant_override("h_separation", 1)
	_grade.add_theme_constant_override("v_separation", 1)
	coluna.add_child(_grade)

	coluna.add_child(Estilo.rotulo(Config.t("DATES IN UTC"), 8, Estilo.TEXTO_FRACO))

	var d := Time.get_datetime_dict_from_unix_time(int(clampf(_selecionado, _minimo, _maximo)))
	_ano = d["year"]
	_mes = d["month"]
	_montar_mes()
	_posicionar.call_deferred()


## Põe o painel logo acima do ponto pedido, sem sair da tela.
func _posicionar() -> void:
	var tam := _painel.get_combined_minimum_size()
	_painel.size = tam
	_painel.position = Vector2(
			clampf(_ponto.x, 4.0, size.x - tam.x - 4.0),
			clampf(_ponto.y - tam.y, 4.0, size.y - tam.y - 4.0)).round()
	if not _animado:
		_animado = true
		# Nasce do canto inferior direito: o calendário abre para cima, a partir da barra.
		Estilo.animar_abertura(_painel, -1.0, true)


func _unix(ano: int, mes: int, dia: int) -> float:
	return float(Time.get_unix_time_from_datetime_dict({"year": ano, "month": mes, "day": dia, "hour": 0, "minute": 0, "second": 0}))


func _mudar_mes(passo: int) -> void:
	_mes += passo
	if _mes > 12:
		_mes = 1
		_ano += 1
	elif _mes < 1:
		_mes = 12
		_ano -= 1
	_montar_mes()


func _montar_mes() -> void:
	for filho in _grade.get_children():
		_grade.remove_child(filho)
		filho.queue_free()
	_titulo.text = "%s %d" % [Config.meses()[_mes - 1], _ano]

	var primeiro := _unix(_ano, _mes, 1)
	var prox_ano := _ano + 1 if _mes == 12 else _ano
	var prox_mes := 1 if _mes == 12 else _mes + 1
	var seguinte := _unix(prox_ano, prox_mes, 1)
	var dias_no_mes := int(round((seguinte - primeiro) / DIA))
	var dia_da_semana: int = Time.get_datetime_dict_from_unix_time(int(primeiro))["weekday"]  # 0 = domingo

	# Só deixa navegar por meses que têm algum dia permitido.
	_anterior.disabled = primeiro <= _minimo
	_proximo.disabled = seguinte > _maximo

	for nome in Config.dias_da_semana():
		var r := Estilo.rotulo(nome, 8, Estilo.TEXTO_FRACO)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.custom_minimum_size = Vector2(CELULA.x, 9)
		_grade.add_child(r)
	for i in dia_da_semana:
		var vazio := Control.new()
		vazio.custom_minimum_size = CELULA
		_grade.add_child(vazio)
	for dia in range(1, dias_no_mes + 1):
		var t := primeiro + (dia - 1) * DIA
		var b := Estilo.botao_texto(str(dia))
		b.custom_minimum_size = CELULA
		b.disabled = t < _minimo or t > _maximo
		if b.disabled:
			b.mouse_default_cursor_shape = Control.CURSOR_ARROW
		if absf(t - _selecionado) < 1.0:
			b.add_theme_stylebox_override("normal", Estilo.caixa(Estilo.CIANO, Estilo.CIANO, 2.0))
			b.add_theme_stylebox_override("disabled", Estilo.caixa(Color(Estilo.CIANO, 0.5), Estilo.CIANO, 2.0))
			b.add_theme_color_override("font_color", Estilo.MARINHO)
			b.add_theme_color_override("font_disabled_color", Estilo.MARINHO)
			Estilo.em_negrito(b)
		b.pressed.connect(func(): _escolher(t))
		_grade.add_child(b)
	# Completa até 6 semanas, para o calendário não mudar de altura de um mês para o outro.
	for i in 42 - dia_da_semana - dias_no_mes:
		var vazio := Control.new()
		vazio.custom_minimum_size = CELULA
		_grade.add_child(vazio)
	_posicionar.call_deferred()


func _escolher(t: float) -> void:
	if _fechando:
		return
	if _ao_escolher.is_valid():
		_ao_escolher.call(t)
	fechar()


## Fecha recolhendo o calendário para o canto de onde ele abriu.
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
