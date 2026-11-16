class_name Traducoes
extends RefCounted
## Tabela de traduções da interface: inglês (o original), português do Brasil e espanhol.
##
## Como funciona:
## - No código os textos ficam em inglês: `Config.t("ANALYZE")`. Se o idioma for outro, o
##   texto é procurado em TEXTOS e trocado. Texto que não está na tabela aparece em inglês.
## - Os textos compridos (guia do HELP) ficam em LONGOS, com um nome curto como chave.
## - As frases dos arquivos de dados (janelas SOURCES e ABOUT) também passam por aqui: as
##   fixas estão em TEXTOS, com a frase inteira em inglês como chave, e as que mudam só nos
##   números estão em MODELOS. Se uma frase dos dados mudar e não casar mais com nada aqui,
##   ela aparece em inglês (nunca some nem mostra número errado).
## - Para corrigir uma tradução, mude só aqui. Ordem das colunas: [português, espanhol].
## - Os números ficam com ponto decimal nos três idiomas, como no resto da tela.
##
## Uso de IA: traduções escritas com assistência do Claude (Anthropic); revisar antes do envio.

const COLUNA := {"pt_BR": 0, "es": 1}

const TEXTOS := {
	# ---------- tela do mapa ----------
	"LUNAR SOUTH POLE": ["POLO SUL LUNAR", "POLO SUR LUNAR"],
	"WHOLE MOON": ["LUA INTEIRA", "LUNA COMPLETA"],
	"LANDING": ["POUSO", "ALUNIZAJE"],
	"DURATION": ["DURAÇÃO", "DURACIÓN"],
	"ANALYZE": ["ANALISAR", "ANALIZAR"],
	"%d DAY": ["%d DIA", "%d DÍA"],
	"%d DAYS": ["%d DIAS", "%d DÍAS"],
	"%d OF %d MEET THE\nREQUIREMENTS": ["%d DE %d ATENDEM\nAOS REQUISITOS", "%d DE %d CUMPLEN\nLOS REQUISITOS"],
	"BEFORE DELAY: %d OF %d": ["ANTES DE ADIAR: %d DE %d", "SIN APLAZAR: %d DE %d"],
	"OTHER SITES": ["OUTROS LOCAIS", "OTROS SITIOS"],
	"%d OF %d": ["%d DE %d", "%d DE %d"],
	"Choose the landing date (UTC)": ["Escolher a data do pouso (UTC)", "Elegir la fecha de alunizaje (UTC)"],
	"See the best landing dates and durations in the data": [
		"Ver as melhores datas e durações de pouso nos dados",
		"Ver las mejores fechas y duraciones de alunizaje en los datos"],
	"Check every site against the requirements for this mission": [
		"Verificar todos os locais com os requisitos desta missão",
		"Comprobar todos los sitios con los requisitos de esta misión"],
	"DATES IN UTC": ["DATAS EM UTC", "FECHAS EN UTC"],
	"Previous month": ["Mês anterior", "Mes anterior"],
	"Next month": ["Próximo mês", "Mes siguiente"],
	"BEST DATES": ["MELHORES DATAS", "MEJORES FECHAS"],
	"HARDEST DATE": ["DATA MAIS DIFÍCIL", "FECHA MÁS DIFÍCIL"],
	"UNDO DELAY": ["DESFAZER ADIAMENTO", "DESHACER APLAZAMIENTO"],
	"Go back to the landing date before the delay": [
		"Voltar à data de pouso de antes do adiamento",
		"Volver a la fecha de alunizaje anterior al aplazamiento"],
	"WHEN THE MOST SOUTH POLE SITES\nMEET THE REQUIREMENTS": [
		"QUANDO MAIS LOCAIS DO POLO SUL\nATENDEM AOS REQUISITOS",
		"CUANDO MÁS SITIOS DEL POLO SUR\nCUMPLEN LOS REQUISITOS"],
	"NO SUCH DATES LEFT\nIN THE DATA": [
		"NÃO HÁ MAIS DATAS ASSIM\nNOS DADOS", "NO QUEDAN FECHAS ASÍ\nEN LOS DATOS"],

	# ---------- ficha do local (descrições de até 10 palavras) ----------
	"One of the most illuminated spots near the south pole.": [
		"Um dos pontos mais iluminados perto do polo sul.",
		"Uno de los puntos más iluminados cerca del polo sur."],
	"NASA CLPS delivery by Intuitive Machines, landed 6 March 2025.": [
		"Entrega CLPS da NASA (Intuitive Machines), pousou em 6/3/2025.",
		"Entrega CLPS de la NASA (Intuitive Machines), alunizó el 6/3/2025."],
	"India's lander, 2023, about 600 km from the south pole.": [
		"Módulo indiano, 2023, a uns 600 km do polo sul.",
		"Módulo indio, 2023, a unos 600 km del polo sur."],
	"First landing on the lunar far side, 3 January 2019.": [
		"Primeiro pouso no lado oculto da Lua, em 3/1/2019.",
		"Primer alunizaje en la cara oculta de la Luna, 3/1/2019."],
	"Equatorial near-side site, 20 July 1969. Two-week days and nights.": [
		"Equador, lado visível, 20/7/1969. Dias e noites de duas semanas.",
		"Ecuador, cara visible, 20/7/1969. Días y noches de dos semanas."],
	"Sample point: Sun visible %s of the year, Earth %s.": [
		"Ponto de amostra: Sol visível %s do ano, Terra %s.",
		"Punto de muestra: Sol visible %s del año, Tierra %s."],

	# ---------- tela do horizonte ----------
	"Sun": ["Sol", "Sol"],
	"Earth": ["Terra", "Tierra"],
	"Both": ["Ambos", "Ambos"],
	"Sun (hidden)": ["Sol (oculto)", "Sol (oculto)"],
	"Earth (hidden)": ["Terra (oculta)", "Tierra (oculta)"],
	"Sun (below this view)": ["Sol (abaixo desta vista)", "Sol (debajo de esta vista)"],
	"Earth (below this view)": ["Terra (abaixo desta vista)", "Tierra (debajo de esta vista)"],
	"Sun (above this view)": ["Sol (acima desta vista)", "Sol (encima de esta vista)"],
	"Earth (above this view)": ["Terra (acima desta vista)", "Tierra (encima de esta vista)"],
	"VISIBLE": ["VISÍVEL", "VISIBLE"],
	"LONGEST GAP": ["MAIOR INTERVALO", "MAYOR INTERVALO"],
	"LIMIT": ["LIMITE", "LÍMITE"],
	"max %s": ["máx. %s", "máx. %s"],
	"min %s": ["mín. %s", "mín. %s"],
	"+%dd from %s": ["+%dd desde %s", "+%dd desde %s"],
	"UNDO": ["DESFAZER", "DESHACER"],

	# ---------- tela do horizonte: leitura no cursor ----------
	"At cursor: %s, day %d": ["No cursor: %s, dia %d", "En el cursor: %s, día %d"],
	"visible": ["visível", "visible"],
	"hidden": ["não visível", "no visible"],
	"sets in ~%d h": ["se põe em ~%d h", "se pone en ~%d h"],
	"rises in ~%d h": ["nasce em ~%d h", "sale en ~%d h"],
	"%s (after the mission)": ["%s (depois da missão)", "%s (después de la misión)"],
	"does not set in the data period": ["não se põe no período dos dados", "no se pone en el periodo de los datos"],
	"does not rise in the data period": ["não nasce no período dos dados", "no sale en el periodo de los datos"],
	"%s above the terrain": ["%s acima do relevo", "%s sobre el relieve"],
	"%s below the terrain": ["%s abaixo do relevo", "%s bajo el relieve"],
	"%s above the horizon": ["%s acima do horizonte", "%s sobre el horizonte"],
	"%s below the horizon": ["%s abaixo do horizonte", "%s bajo el horizonte"],

	# ---------- tela do horizonte: quadro de requisitos ----------
	"Meets the requirements": ["Atende aos requisitos", "Cumple los requisitos"],
	"Does not meet the requirements": ["Não atende aos requisitos", "No cumple los requisitos"],
	"before delay: %s": ["antes do adiamento: %s", "antes del aplazamiento: %s"],
	"Why it does not meet the requirements": ["Por que não atende aos requisitos", "Por qué no cumple los requisitos"],
	"REQUIREMENTS NOT MET": ["REQUISITOS NÃO ATENDIDOS", "REQUISITOS NO CUMPLIDOS"],
	"NOT MET": ["NÃO ATENDIDOS", "NO CUMPLIDOS"],
	"MET": ["ATENDIDOS", "CUMPLIDOS"],
	"met": ["atendia", "cumplía"],
	"not met": ["não atendia", "no cumplía"],
	"insufficient data": ["dados insuficientes", "datos insuficientes"],
	# rótulo do horizonte em uso (texts_en.json -> model_labels)
	"0° reference horizon, no terrain": ["Horizonte plano de 0°, sem relevo", "Horizonte de 0°, sin relieve"],
	"at least": ["pelo menos", "al menos"],
	"Insufficient data": ["Dados insuficientes", "Datos insuficientes"],
	"Play / pause the mission (Space)": ["Reproduzir / pausar a missão (Espaço)", "Reproducir / pausar la misión (Espacio)"],
	"Delay the landing by 7 days": ["Adiar o pouso em 7 dias", "Aplazar el alunizaje 7 días"],
	"Context and facts about this site": ["Contexto e fatos sobre este local", "Contexto y datos sobre este sitio"],

	# ---------- janelas ----------
	"Close (Esc)": ["Fechar (Esc)", "Cerrar (Esc)"],
	"QUICK GUIDE": ["GUIA RÁPIDO", "GUÍA RÁPIDA"],
	"%s - about this site": ["%s - sobre este local", "%s - acerca de este sitio"],
	"FACTS FROM THE DATA": ["FATOS TIRADOS DOS DADOS", "DATOS DESTACADOS"],
	"HOW THE MOON IS DIFFERENT": ["COMO A LUA É DIFERENTE", "CÓMO ES DIFERENTE LA LUNA"],
	"Coordinates source: %s": ["Fonte das coordenadas: %s", "Fuente de las coordenadas: %s"],
	"Sources & assumptions": ["Fontes e premissas", "Fuentes y supuestos"],
	"SOURCES": ["FONTES", "FUENTES"],
	"ASSUMPTIONS AND SIMPLIFICATIONS": ["PREMISSAS E SIMPLIFICAÇÕES", "SUPUESTOS Y SIMPLIFICACIONES"],
	"Interface code": ["Código da interface", "Código de la interfaz"],
	"The Godot interface code was written with an AI coding assistant (Claude by Anthropic) following the team's specification. Every number on screen is read from the data files above and checked against reference values.": [
		"O código da interface no Godot foi escrito com um assistente de programação por IA (Claude, da Anthropic), seguindo a especificação da equipe. Todo número na tela é lido dos arquivos de dados acima e conferido com valores de referência.",
		"El código de la interfaz en Godot se escribió con un asistente de programación con IA (Claude, de Anthropic), siguiendo la especificación del equipo. Cada número en pantalla se lee de los archivos de datos de arriba y se comprueba con valores de referencia."],

	# ---------- configurações ----------
	"SETTINGS": ["CONFIGURAÇÕES", "AJUSTES"],
	"LANGUAGE": ["IDIOMA", "IDIOMA"],
	"MUSIC": ["MÚSICA", "MÚSICA"],
	"SOUND EFFECTS": ["EFEITOS SONOROS", "EFECTOS DE SONIDO"],

	# ---------- guia do HELP: títulos e palavras ----------
	"WHAT THIS SCREEN DOES": ["O QUE ESTA TELA FAZ", "QUÉ HACE ESTA PANTALLA"],
	"HOW TO USE IT": ["COMO USAR", "CÓMO USARLA"],
	"HOW TO READ THE LIST": ["COMO LER A LISTA", "CÓMO LEER LA LISTA"],
	"THE REQUIREMENTS": ["OS REQUISITOS", "LOS REQUISITOS"],
	"WHY LONG MISSIONS TURN RED": ["POR QUE MISSÕES LONGAS FICAM VERMELHAS", "POR QUÉ LAS MISIONES LARGAS SE PONEN ROJAS"],
	"at most": ["no máximo", "como máximo"],
	"less than": ["menos de", "menos de"],
	"more than": ["mais de", "más de"],

	# ---------- textos que vêm dos arquivos de dados e aparecem no guia ----------
	"Longest period without the Sun": ["Maior período sem o Sol", "Período más largo sin el Sol"],
	"Longest period without Earth": ["Maior período sem a Terra", "Período más largo sin la Tierra"],
	"Share of the mission with Sun and Earth both visible": [
		"Parte da missão com Sol e Terra visíveis juntos",
		"Parte de la misión con el Sol y la Tierra visibles a la vez"],
	"Team demonstration assumptions - not NASA criteria": [
		"Premissas de demonstração da equipe - não são critérios da NASA",
		"Supuestos de demostración del equipo - no son criterios de la NASA"],
	"Data: NASA/JPL Horizons (DE441) and NASA LRO LOLA topography. Times in UTC. Educational decision-support tool; it does not certify landing sites.": [
		"Dados: NASA/JPL Horizons (DE441) e topografia NASA LRO LOLA. Horários em UTC. Ferramenta educativa de apoio à decisão; não certifica locais de pouso.",
		"Datos: NASA/JPL Horizons (DE441) y topografía NASA LRO LOLA. Horas en UTC. Herramienta educativa de apoyo a la decisión; no certifica sitios de alunizaje."],

	# ---------- janela SOURCES: textos de texts_en.json e requirements_default.json ----------
	"Sun and Earth positions": ["Posições do Sol e da Terra", "Posiciones del Sol y la Tierra"],
	"NASA/JPL Horizons System, DE441 ephemeris, observer on the Moon (MOON_ME frame, 1737.4 km sphere). Apparent azimuth and elevation with no atmospheric refraction (APPARENT=AIRLESS), one sample per hour. Lunar libration is included in the Horizons geometry.": [
		"Sistema NASA/JPL Horizons, efeméride DE441, observador na Lua (referencial MOON_ME, esfera de 1737.4 km). Azimute e elevação aparentes sem refração atmosférica (APPARENT=AIRLESS), uma amostra por hora. A libração lunar está incluída na geometria do Horizons.",
		"Sistema NASA/JPL Horizons, efemérides DE441, observador en la Luna (sistema MOON_ME, esfera de 1737.4 km). Acimut y elevación aparentes sin refracción atmosférica (APPARENT=AIRLESS), una muestra por hora. La libración lunar está incluida en la geometría de Horizons."],
	"Terrain (all south pole sites)": ["Relevo (todos os locais do polo sul)", "Relieve (todos los sitios del polo sur)"],
	"LRO LOLA elevation models. Connecting Ridge: 5 m/pixel Site01 map (Barker et al. 2021, NASA/GSFC PGDA product 78) plus the PDS LDEM_875S_20M and LDEM_80S_80M polar maps. Other south pole sites: PDS LDEM_85S_20M (20 m/pixel) plus LDEM_80S_80M. The horizon is the highest terrain angle in each direction, including the Moon's curvature. Sites far from the pole use a flat 0° horizon.": [
		"Modelos de elevação LRO LOLA. Connecting Ridge: mapa Site01 de 5 m/pixel (Barker et al. 2021, produto 78 do NASA/GSFC PGDA) mais os mapas polares PDS LDEM_875S_20M e LDEM_80S_80M. Outros locais do polo sul: PDS LDEM_85S_20M (20 m/pixel) mais LDEM_80S_80M. O horizonte é o maior ângulo do terreno em cada direção, incluindo a curvatura da Lua. Locais longe do polo usam um horizonte plano de 0°.",
		"Modelos de elevación LRO LOLA. Connecting Ridge: mapa Site01 de 5 m/píxel (Barker et al. 2021, producto 78 de NASA/GSFC PGDA) más los mapas polares PDS LDEM_875S_20M y LDEM_80S_80M. Otros sitios del polo sur: PDS LDEM_85S_20M (20 m/píxel) más LDEM_80S_80M. El horizonte es el mayor ángulo del terreno en cada dirección, incluida la curvatura de la Luna. Los sitios lejos del polo usan un horizonte plano de 0°."],
	"Candidate landing regions": ["Regiões candidatas de pouso", "Regiones candidatas de alunizaje"],
	"Outlines of the nine regions NASA selected in October 2024 for the first crewed south pole landing (then planned as Artemis III; NASA now plans it as Artemis IV, in 2028), from the USGS data release by M. T. McClernan (2024), doi:10.5066/P1MEQ6UK, based on LROC QuickMap. In each region the app uses one sample point: the most illuminated pixel in NASA's LOLA average illumination map. It is a team choice for comparison, not a landing site.": [
		"Contornos das nove regiões que a NASA selecionou em outubro de 2024 para o primeiro pouso tripulado no polo sul (na época planejado como Artemis III; hoje a NASA o planeja como Artemis IV, em 2028), da publicação de dados do USGS por M. T. McClernan (2024), doi:10.5066/P1MEQ6UK, baseada no LROC QuickMap. Em cada região o app usa um ponto de amostra: o pixel mais iluminado no mapa de iluminação média LOLA da NASA. É uma escolha da equipe para comparação, não um local de pouso.",
		"Contornos de las nueve regiones que la NASA seleccionó en octubre de 2024 para el primer alunizaje tripulado en el polo sur (entonces previsto como Artemis III; la NASA ahora lo prevé como Artemis IV, en 2028), de la publicación de datos del USGS de M. T. McClernan (2024), doi:10.5066/P1MEQ6UK, basada en LROC QuickMap. En cada región la app usa un punto de muestra: el píxel más iluminado en el mapa de iluminación media LOLA de la NASA. Es una elección del equipo para comparar, no un sitio de alunizaje."],
	"Validation of the terrain horizon": ["Validação do horizonte com relevo", "Validación del horizonte con relieve"],
	"Compared with published illumination studies of the lunar south pole: Glaser et al. 2018 (Planetary and Space Science 162) for the Connecting Ridge, and the LOLA average illumination and Earth visibility maps of Mazarico et al. 2011 (Icarus 211) for every south pole site. Periods and resolutions differ, so the agreement shows consistency, not equality.": [
		"Comparado com estudos publicados de iluminação do polo sul lunar: Glaser et al. 2018 (Planetary and Space Science 162) para a Connecting Ridge, e os mapas LOLA de iluminação média e de visibilidade da Terra de Mazarico et al. 2011 (Icarus 211) para todos os locais do polo sul. Os períodos e as resoluções são diferentes, então a concordância mostra consistência, não igualdade.",
		"Comparado con estudios publicados de iluminación del polo sur lunar: Glaser et al. 2018 (Planetary and Space Science 162) para la Connecting Ridge, y los mapas LOLA de iluminación media y de visibilidad de la Tierra de Mazarico et al. 2011 (Icarus 211) para todos los sitios del polo sur. Los periodos y las resoluciones son distintos, así que la concordancia muestra coherencia, no igualdad."],
	"Maps and site context": ["Mapas e contexto dos locais", "Mapas y contexto de los sitios"],
	"Global map: LRO Wide Angle Camera global mosaic served by NASA Moon Trek (NASA/GSFC/Arizona State University). South pole maps: shaded relief from the LOLA polar elevation maps. Site coordinates from LROC image releases, Glaser et al. 2018 and the NASA NSSDC Apollo site list (each site lists its own source).": [
		"Mapa global: mosaico global da Wide Angle Camera do LRO, fornecido pelo NASA Moon Trek (NASA/GSFC/Arizona State University). Mapas do polo sul: relevo sombreado a partir dos mapas polares de elevação LOLA. Coordenadas dos locais: publicações de imagens do LROC, Glaser et al. 2018 e a lista de locais Apollo do NASA NSSDC (cada local indica a própria fonte).",
		"Mapa global: mosaico global de la Wide Angle Camera del LRO, servido por NASA Moon Trek (NASA/GSFC/Arizona State University). Mapas del polo sur: relieve sombreado a partir de los mapas polares de elevación LOLA. Coordenadas de los sitios: publicaciones de imágenes de LROC, Glaser et al. 2018 y la lista de sitios Apollo del NASA NSSDC (cada sitio indica su propia fuente)."],
	"Space agency partner context": ["Contexto das agências espaciais parceiras", "Contexto de las agencias espaciales asociadas"],
	"Canadian Space Agency (CSA) Moon Exploration portal, for the educational context on lunar missions. The Chandrayaan-3 site comes from the Indian Space Research Organisation (ISRO) mission.": [
		"Portal de exploração da Lua da Agência Espacial Canadense (CSA), para o contexto educativo sobre missões lunares. O local do Chandrayaan-3 vem da missão da Organização Indiana de Pesquisa Espacial (ISRO).",
		"Portal de exploración de la Luna de la Agencia Espacial Canadiense (CSA), para el contexto educativo sobre misiones lunares. El sitio de Chandrayaan-3 viene de la misión de la Organización India de Investigación Espacial (ISRO)."],
	"Use of AI tools": ["Uso de ferramentas de IA", "Uso de herramientas de IA"],
	"Parts of the data-processing code were written with AI coding assistants (Claude by Anthropic; Codex by OpenAI) following the team's specification, and reviewed by the team. Results come from fixed rules, not from generative AI.": [
		"Partes do código de processamento dos dados foram escritas com assistentes de programação por IA (Claude, da Anthropic; Codex, da OpenAI), seguindo a especificação da equipe, e revisadas pela equipe. Os resultados vêm de regras fixas, não de IA generativa.",
		"Partes del código de procesamiento de datos se escribieron con asistentes de programación con IA (Claude, de Anthropic; Codex, de OpenAI), siguiendo la especificación del equipo, y fueron revisadas por el equipo. Los resultados vienen de reglas fijas, no de IA generativa."],
	"Visible means the center of the body is above the horizon.": [
		"Visível quer dizer que o centro do corpo está acima do horizonte.",
		"Visible significa que el centro del cuerpo está sobre el horizonte."],
	"Hourly samples with linear interpolation: event times are rounded to the hour.": [
		"Amostras de hora em hora com interpolação linear: os horários dos eventos são arredondados para a hora.",
		"Muestras cada hora con interpolación lineal: las horas de los eventos se redondean a la hora."],
	"Without terrain data, the horizon is a flat 0° line from a smooth sphere.": [
		"Sem dados de relevo, o horizonte é uma linha plana de 0° de uma esfera lisa.",
		"Sin datos de relieve, el horizonte es una línea plana de 0° de una esfera lisa."],
	"No solar panel, battery, antenna or radio link model.": [
		"Não há modelo de painel solar, bateria, antena ou enlace de rádio.",
		"No hay modelo de panel solar, batería, antena ni enlace de radio."],
	"Requirements are team demonstration assumptions, not NASA criteria.": [
		"Os requisitos são premissas de demonstração da equipe, não critérios da NASA.",
		"Los requisitos son supuestos de demostración del equipo, no criterios de la NASA."],
	"Periods outside the data coverage show 'Insufficient data'; values are never extrapolated.": [
		"Períodos fora da cobertura dos dados mostram 'Dados insuficientes'; os valores nunca são extrapolados.",
		"Los periodos fuera de la cobertura de los datos muestran 'Datos insuficientes'; los valores nunca se extrapolan."],
	# Descrição dos requisitos, já sem a frase "Every value can be changed in the interface."
	# (ver Dados.descricao_dos_requisitos).
	"Example mission requirements used to classify a scenario. They are not requirements from NASA or any mission.": [
		"Requisitos de missão de exemplo, usados para classificar um cenário. Não são requisitos da NASA nem de nenhuma missão.",
		"Requisitos de misión de ejemplo, usados para clasificar un escenario. No son requisitos de la NASA ni de ninguna misión."],

	# ---------- janela ABOUT: contexto dos locais com coordenada publicada ----------
	"One of the most illuminated spots near the lunar south pole. 'Connecting Ridge' was one of the 13 candidate regions NASA announced in August 2022 for the first crewed landing (then planned as Artemis III), but it is not in NASA's updated list of nine (October 2024). NASA now plans that first landing as Artemis IV, in 2028.": [
		"Um dos pontos mais iluminados perto do polo sul lunar. A 'Connecting Ridge' foi uma das 13 regiões candidatas que a NASA anunciou em agosto de 2022 para o primeiro pouso tripulado (na época planejado como Artemis III), mas não está na lista atualizada de nove regiões da NASA (outubro de 2024). Hoje a NASA planeja esse primeiro pouso como Artemis IV, em 2028.",
		"Uno de los puntos más iluminados cerca del polo sur lunar. 'Connecting Ridge' fue una de las 13 regiones candidatas que la NASA anunció en agosto de 2022 para el primer alunizaje tripulado (entonces previsto como Artemis III), pero no está en la lista actualizada de nueve regiones de la NASA (octubre de 2024). La NASA ahora prevé ese primer alunizaje como Artemis IV, en 2028."],
	"NASA CLPS delivery by Intuitive Machines, landed 6 March 2025. LROC notes the intended site lies in the central portion of a potential landing region for the first crewed landing; Mons Mouton is one of the nine candidate regions NASA selected in October 2024 for that landing, then planned as Artemis III. NASA now plans it as Artemis IV, in 2028.": [
		"Entrega CLPS da NASA pela Intuitive Machines, que pousou em 6 de março de 2025. O LROC observa que o local pretendido fica na parte central de uma possível região de pouso para o primeiro pouso tripulado; Mons Mouton é uma das nove regiões candidatas que a NASA selecionou em outubro de 2024 para esse pouso, na época planejado como Artemis III. Hoje a NASA o planeja como Artemis IV, em 2028.",
		"Entrega CLPS de la NASA por Intuitive Machines, que alunizó el 6 de marzo de 2025. LROC señala que el sitio previsto está en la parte central de una posible región de alunizaje para el primer alunizaje tripulado; Mons Mouton es una de las nueve regiones candidatas que la NASA seleccionó en octubre de 2024 para ese alunizaje, entonces previsto como Artemis III. La NASA ahora lo prevé como Artemis IV, en 2028."],
	"India's lander, 23 August 2023, about 600 km from the south pole.": [
		"Módulo de pouso da Índia, 23 de agosto de 2023, a cerca de 600 km do polo sul.",
		"Módulo de alunizaje de la India, 23 de agosto de 2023, a unos 600 km del polo sur."],
	"First landing on the lunar far side, 3 January 2019. Earth is never above the horizon here; communication goes through a relay satellite.": [
		"Primeiro pouso no lado oculto da Lua, em 3 de janeiro de 2019. Aqui a Terra nunca fica acima do horizonte; a comunicação passa por um satélite de retransmissão.",
		"Primer alunizaje en la cara oculta de la Luna, el 3 de enero de 2019. Aquí la Tierra nunca está sobre el horizonte; la comunicación pasa por un satélite repetidor."],
	"Equatorial near-side site, 20 July 1969: about 14 days of light and 14 of night, Earth almost fixed in the sky.": [
		"Local equatorial no lado visível, 20 de julho de 1969: cerca de 14 dias de luz e 14 de noite, com a Terra quase parada no céu.",
		"Sitio ecuatorial en la cara visible, 20 de julio de 1969: unos 14 días de luz y 14 de noche, con la Tierra casi fija en el cielo."],

	# ---------- janela ABOUT: fatos sem números ----------
	"Earth never rises here: this is the far side of the Moon. Talking to Earth needs a relay satellite.": [
		"Aqui a Terra nunca nasce: este é o lado oculto da Lua. Falar com a Terra exige um satélite de retransmissão.",
		"Aquí la Tierra nunca sale: esta es la cara oculta de la Luna. Hablar con la Tierra requiere un satélite repetidor."],
	"The Moon has no atmosphere: no refraction lifts the Sun near the horizon, so the horizon is set only by terrain and the Moon's curvature.": [
		"A Lua não tem atmosfera: nenhuma refração levanta o Sol perto do horizonte, então o horizonte é definido só pelo relevo e pela curvatura da Lua.",
		"La Luna no tiene atmósfera: ninguna refracción eleva el Sol cerca del horizonte, así que el horizonte lo definen solo el relieve y la curvatura de la Luna."],
}

## Frases dos arquivos de dados que mudam só nos números (ou no nome da região).
## [inglês, português, espanhol]. No inglês, {n} marca um número e {s} um nome; nas traduções,
## {1}, {2}... são os valores encontrados, na ordem em que aparecem no inglês. Assim os números
## continuam vindo dos dados: se o Ricardo gerar os arquivos de novo, a tradução acompanha.
const MODELOS := [
	["Sample point in the best-lit part of the '{s}' region, one of the nine candidate regions NASA selected in October 2024 for the first crewed south pole landing (then planned as Artemis III; NASA now plans that landing as Artemis IV, in 2028). Chosen by the team with a fixed rule: the best-lit {n} m block in NASA's LOLA average illumination map, then the highest ground inside it. A sample point, not a landing site.",
		"Ponto de amostra na parte mais iluminada da região '{1}', uma das nove regiões candidatas que a NASA selecionou em outubro de 2024 para o primeiro pouso tripulado no polo sul (na época planejado como Artemis III; hoje a NASA planeja esse pouso como Artemis IV, em 2028). Escolhido pela equipe com uma regra fixa: o bloco de {2} m mais iluminado no mapa de iluminação média LOLA da NASA e, dentro dele, o terreno mais alto. É um ponto de amostra, não um local de pouso.",
		"Punto de muestra en la parte más iluminada de la región '{1}', una de las nueve regiones candidatas que la NASA seleccionó en octubre de 2024 para el primer alunizaje tripulado en el polo sur (entonces previsto como Artemis III; la NASA ahora prevé ese alunizaje como Artemis IV, en 2028). Elegido por el equipo con una regla fija: el bloque de {2} m más iluminado en el mapa de iluminación media LOLA de la NASA y, dentro de él, el terreno más alto. Es un punto de muestra, no un sitio de alunizaje."],
	# Fonte das coordenadas dos 9 pontos de amostra (campo `source` dos dados). Os títulos das
	# publicações e os nomes dos produtos ficam em inglês, como numa referência bibliográfica.
	["Region outline: USGS, McClernan, M. T. (2024), Down Selected Artemis III Candidate Landing Site Navigational Grids, doi:10.5066/P1MEQ6UK (region outlines sourced from LROC QuickMap). Point: highest node of {s} (NASA LRO LOLA) inside the 3x3-pixel block with the highest mean of {s} (Mazarico et al. 2011) in the region; block center pixel row {n}, column {n}.",
		"Contorno da região: USGS, McClernan, M. T. (2024), Down Selected Artemis III Candidate Landing Site Navigational Grids, doi:10.5066/P1MEQ6UK (contornos das regiões obtidos do LROC QuickMap). Ponto: nó mais alto do {1} (NASA LRO LOLA) dentro do bloco de 3x3 pixels com a maior média do {2} (Mazarico et al. 2011) na região; pixel central do bloco na linha {3}, coluna {4}.",
		"Contorno de la región: USGS, McClernan, M. T. (2024), Down Selected Artemis III Candidate Landing Site Navigational Grids, doi:10.5066/P1MEQ6UK (contornos de las regiones obtenidos de LROC QuickMap). Punto: nodo más alto de {1} (NASA LRO LOLA) dentro del bloque de 3x3 píxeles con la media más alta de {2} (Mazarico et al. 2011) en la región; píxel central del bloque en la fila {3}, columna {4}."],
	["Here the Sun never climbs more than {n}° above a flat horizon. Any terrain rising more than {n}° in its direction would hide it all year.",
		"Aqui o Sol nunca sobe mais de {1}° acima de um horizonte plano. Qualquer relevo que suba mais de {2}° na direção dele o esconderia o ano todo.",
		"Aquí el Sol nunca sube más de {1}° sobre un horizonte plano. Cualquier relieve que se eleve más de {2}° en su dirección lo ocultaría todo el año."],
	["Earth rises and sets here because of libration: it is above the horizon {n}% of the year, and the longest wait without it is {n} days.",
		"Aqui a Terra nasce e se põe por causa da libração: ela fica acima do horizonte {1}% do ano, e a maior espera sem ela é de {2} dias.",
		"Aquí la Tierra sale y se pone por la libración: está sobre el horizonte el {1}% del año, y la espera más larga sin ella es de {2} días."],
	["With a flat 0° horizon the Sun would be hidden for {n} days in a row. The real terrain seen from 2 m above the ground cuts that to {n} days: the Sun is visible {n}% of the year instead of {n}%.",
		"Com um horizonte plano de 0°, o Sol ficaria escondido por {1} dias seguidos. O relevo real, visto a 2 m do solo, reduz isso para {2} dias: o Sol fica visível {3}% do ano em vez de {4}%.",
		"Con un horizonte plano de 0°, el Sol quedaría oculto durante {1} días seguidos. El relieve real, visto a 2 m del suelo, lo reduce a {2} días: el Sol es visible el {3}% del año en vez del {4}%."],
	["Real terrain takes sunlight away here: nearby high ground rises up to {n}° above a flat horizon, so the Sun is visible {n}% of the year instead of the {n}% a flat 0° horizon would give.",
		"Aqui o relevo real tira luz solar: o terreno alto próximo sobe até {1}° acima de um horizonte plano, então o Sol fica visível {2}% do ano em vez dos {3}% que um horizonte plano de 0° daria.",
		"Aquí el relieve real quita luz solar: el terreno alto cercano se eleva hasta {1}° sobre un horizonte plano, así que el Sol es visible el {2}% del año en vez del {3}% que daría un horizonte plano de 0°."],
	["Real terrain gives more sunlight here: seen from 2 m above the ground, the Sun is visible {n}% of the year instead of the {n}% a flat 0° horizon would give. The longest stretch without it is still {n} days.",
		"Aqui o relevo real dá mais luz solar: visto a 2 m do solo, o Sol fica visível {1}% do ano em vez dos {2}% que um horizonte plano de 0° daria. O maior trecho sem ele ainda é de {3} dias.",
		"Aquí el relieve real da más luz solar: visto a 2 m del suelo, el Sol es visible el {1}% del año en vez del {2}% que daría un horizonte plano de 0°. El tramo más largo sin él sigue siendo de {3} días."],
	["This site is {n} m above the reference sphere. On a perfectly smooth Moon its horizon would sit at {n}°; the real one is between {n}° and {n}°, depending on the direction.",
		"Este local está {1} m acima da esfera de referência. Numa Lua perfeitamente lisa, o horizonte dele ficaria em {2}°; o real fica entre {3}° e {4}°, dependendo da direção.",
		"Este sitio está {1} m por encima de la esfera de referencia. En una Luna perfectamente lisa, su horizonte estaría en {2}°; el real está entre {3}° y {4}°, según la dirección."],
	["Here the Sun climbs as high as {n}°, and night lasts about two weeks: the longest stretch without the Sun in the year is {n} days.",
		"Aqui o Sol sobe até {1}°, e a noite dura cerca de duas semanas: o maior trecho sem o Sol no ano é de {2} dias.",
		"Aquí el Sol sube hasta {1}°, y la noche dura unas dos semanas: el tramo más largo sin el Sol en el año es de {2} días."],
	["Earth never sets here. It only wobbles in the sky (libration): its elevation stays between {n}° and {n}° all year.",
		"Aqui a Terra nunca se põe. Ela só balança no céu (libração): a elevação dela fica entre {1}° e {2}° o ano todo.",
		"Aquí la Tierra nunca se pone. Solo oscila en el cielo (libración): su elevación se mantiene entre {1}° y {2}° todo el año."],
	["A full day on the Moon (sunrise to sunrise) lasts about {n} hours, or {n} Earth days.",
		"Um dia completo na Lua (de um nascer do Sol ao outro) dura cerca de {1} horas, ou {2} dias da Terra.",
		"Un día completo en la Luna (de un amanecer al siguiente) dura unas {1} horas, o {2} días terrestres."],
	["The Moon's axis is tilted only about {n}°, so near the poles the Sun skims the horizon all year and small terrain changes decide between light and darkness.",
		"O eixo da Lua é inclinado só cerca de {1}°, então perto dos polos o Sol passa rente ao horizonte o ano todo e pequenas mudanças no relevo decidem entre luz e escuridão.",
		"El eje de la Luna está inclinado solo unos {1}°, así que cerca de los polos el Sol roza el horizonte todo el año y pequeños cambios del relieve deciden entre luz y oscuridad."],
]

## Textos compridos, por nome: [inglês, português, espanhol].
const LONGOS := {
	"guia_tela_polo": [
		"This map shows the lunar south pole. Each marker is a point the app can analyze. The boxes are the nine candidate regions NASA chose in October 2024 for the first crewed landing; in each one the app uses one sample point, not a landing site.",
		"Este mapa mostra o polo sul da Lua. Cada marcador é um ponto que o app consegue analisar. Os quadrados são as nove regiões candidatas que a NASA escolheu em outubro de 2024 para o primeiro pouso tripulado; em cada uma o app usa um ponto de amostra, não um local de pouso.",
		"Este mapa muestra el polo sur de la Luna. Cada marcador es un punto que la app puede analizar. Los recuadros son las nueve regiones candidatas que la NASA eligió en octubre de 2024 para el primer alunizaje tripulado; en cada una la app usa un punto de muestra, no un sitio de alunizaje."],
	"guia_tela_lua": [
		"This map shows the whole Moon and three sites far from the south pole: Apollo 11 (A11), Chandrayaan-3 (CH3) and Chang'e-4 (CE4). The south pole points are the small dots at the bottom; open SOUTH POLE to see them.\nFor these three sites the app has no terrain data, so it uses a flat 0° horizon. That does not mean their horizon is clear.",
		"Este mapa mostra a Lua inteira e três locais longe do polo sul: Apollo 11 (A11), Chandrayaan-3 (CH3) e Chang'e-4 (CE4). Os pontos do polo sul são os pontinhos lá embaixo; abra POLO SUL para vê-los.\nPara esses três locais o app não tem dados de relevo, então usa um horizonte plano de 0°. Isso não quer dizer que o horizonte deles esteja livre.",
		"Este mapa muestra la Luna completa y tres sitios lejos del polo sur: Apolo 11 (A11), Chandrayaan-3 (CH3) y Chang'e-4 (CE4). Los puntos del polo sur son los puntitos de abajo; abre POLO SUR para verlos.\nPara estos tres sitios la app no tiene datos de relieve, así que usa un horizonte plano de 0°. Eso no significa que su horizonte esté despejado."],
	"guia_tela_escolha": [
		"You choose when the mission lands and how long it lasts. The app then checks, point by point, how long the Sun and Earth stay above the horizon during that mission.",
		"Você escolhe quando a missão pousa e quanto tempo ela dura. O app então confere, ponto a ponto, quanto tempo o Sol e a Terra ficam acima do horizonte durante essa missão.",
		"Tú eliges cuándo aluniza la misión y cuánto dura. La app comprueba entonces, punto por punto, cuánto tiempo el Sol y la Tierra quedan sobre el horizonte durante esa misión."],
	"guia_uso_1": [
		"1. LANDING: click the calendar and pick a date (UTC). Or click BEST DATES to choose from a short list of the best dates and durations in the data.",
		"1. POUSO: clique no calendário e escolha uma data (UTC). Ou clique em MELHORES DATAS para escolher numa lista curta das melhores datas e durações nos dados.",
		"1. ALUNIZAJE: haz clic en el calendario y elige una fecha (UTC). O haz clic en MEJORES FECHAS para elegir de una lista corta de las mejores fechas y duraciones en los datos."],
	"guia_uso_2": [
		"2. DURATION: drag the bar, from %d to %d days.",
		"2. DURAÇÃO: arraste a barra, de %d a %d dias.",
		"2. DURACIÓN: arrastra la barra, de %d a %d días."],
	"guia_uso_3": [
		"3. Press ANALYZE. The list opens and the markers take the color of their result. After that, the list updates by itself when you change the date or the duration.",
		"3. Aperte ANALISAR. A lista abre e os marcadores ganham a cor do resultado. Depois disso, a lista se atualiza sozinha quando você muda a data ou a duração.",
		"3. Pulsa ANALIZAR. La lista se abre y los marcadores toman el color de su resultado. Después, la lista se actualiza sola cuando cambias la fecha o la duración."],
	"guia_uso_4": [
		"4. Click a point, on the map or in the list, to open its horizon screen. Rest the mouse on a list row to see that point's details on the map.",
		"4. Clique num ponto, no mapa ou na lista, para abrir a tela do horizonte dele. Deixe o mouse parado numa linha da lista para ver os detalhes desse ponto no mapa.",
		"4. Haz clic en un punto, en el mapa o en la lista, para abrir su pantalla del horizonte. Deja el ratón quieto sobre una fila de la lista para ver los detalles de ese punto en el mapa."],
	"guia_uso_5": [
		"5. +7d: delays the landing by 7 days and keeps the duration, to see which points still meet the requirements. An arrow marks the points whose result changed from the original date. UNDO DELAY goes back to that date.",
		"5. +7d: adia o pouso em 7 dias e mantém a duração, para ver quais pontos ainda atendem aos requisitos. Uma seta marca os pontos cujo resultado mudou em relação à data original. DESFAZER ADIAMENTO volta para essa data.",
		"5. +7d: aplaza el alunizaje 7 días y mantiene la duración, para ver qué puntos siguen cumpliendo los requisitos. Una flecha marca los puntos cuyo resultado cambió respecto a la fecha original. DESHACER APLAZAMIENTO vuelve a esa fecha."],
	"guia_lista_cores": [
		"[color=#%s]Green square[/color]: the point meets all the requirements below for this mission. [color=#%s]Red X[/color]: at least one requirement is not met.",
		"[color=#%s]Quadrado verde[/color]: o ponto atende a todos os requisitos abaixo nesta missão. [color=#%s]X vermelho[/color]: pelo menos um requisito não é atendido.",
		"[color=#%s]Cuadrado verde[/color]: el punto cumple todos los requisitos de abajo en esta misión. [color=#%s]X roja[/color]: al menos un requisito no se cumple."],
	"guia_lista_horas": [
		"The hours next to each point are the hours of the mission with the Sun and Earth both above the horizon. More hours is better. Green points come first; inside each color, the list is sorted by those hours.",
		"As horas ao lado de cada ponto são as horas da missão com o Sol e a Terra acima do horizonte ao mesmo tempo. Quanto mais horas, melhor. Os pontos verdes vêm primeiro; dentro de cada cor, a lista é ordenada por essas horas.",
		"Las horas junto a cada punto son las horas de la misión con el Sol y la Tierra sobre el horizonte a la vez. Cuantas más horas, mejor. Los puntos verdes van primero; dentro de cada color, la lista se ordena por esas horas."],
	"guia_lista_significado": [
		"Sun above the horizon means sunlight is available (it is not generated power). Earth above the horizon means a direct line of sight to Earth (it does not guarantee a radio link).",
		"Sol acima do horizonte quer dizer que há luz solar disponível (não é energia gerada). Terra acima do horizonte quer dizer linha de visada direta para a Terra (não garante um enlace de rádio).",
		"El Sol sobre el horizonte significa que hay luz solar disponible (no es energía generada). La Tierra sobre el horizonte significa línea de visión directa con la Tierra (no garantiza un enlace de radio)."],
	"guia_requisitos_fim": [
		"One requirement not met is enough to turn a point red: a good number never makes up for a bad one.",
		"Basta um requisito não atendido para o ponto ficar vermelho: um número bom nunca compensa um ruim.",
		"Basta un requisito no cumplido para que el punto se ponga rojo: un número bueno nunca compensa uno malo."],
	"guia_missoes_longas": [
		"Near the pole the Sun circles low around the horizon once every 29.5 days, and hills hide it for days at a time. Earth also drops below the horizon for days every month. The longer the mission, the more likely it includes one of those stretches. In this data, no south pole point meets the requirements for a mission of 30 days or more, on any date. That is why the duration bar stops at %d days.",
		"Perto do polo o Sol dá uma volta rente ao horizonte a cada 29.5 dias, e os morros o escondem por dias seguidos. A Terra também desce abaixo do horizonte por dias, todo mês. Quanto mais longa a missão, maior a chance de pegar um desses trechos. Nestes dados, nenhum ponto do polo sul atende aos requisitos numa missão de 30 dias ou mais, em nenhuma data. Por isso a barra de duração para em %d dias.",
		"Cerca del polo el Sol da una vuelta a ras del horizonte cada 29.5 días, y las colinas lo ocultan durante días seguidos. La Tierra también baja del horizonte durante días, cada mes. Cuanto más larga la misión, más probable es que incluya uno de esos tramos. En estos datos, ningún punto del polo sur cumple los requisitos en una misión de 30 días o más, en ninguna fecha. Por eso la barra de duración se detiene en %d días."],
	"guia_recomendados": [
		"For missions of 7, 14 and 21 days, the landing dates (from today on) when the most south pole points meet the requirements. It is a fixed rule applied to the data, not a NASA recommendation. HARDEST DATE shows the opposite case: the 14-day mission for which the fewest points meet them.",
		"Para missões de 7, 14 e 21 dias, as datas de pouso (de hoje em diante) em que mais pontos do polo sul atendem aos requisitos. É uma regra fixa aplicada aos dados, não uma recomendação da NASA. DATA MAIS DIFÍCIL mostra o caso oposto: a missão de 14 dias em que menos pontos os atendem.",
		"Para misiones de 7, 14 y 21 días, las fechas de alunizaje (de hoy en adelante) en que más puntos del polo sur cumplen los requisitos. Es una regla fija aplicada a los datos, no una recomendación de la NASA. FECHA MÁS DIFÍCIL muestra el caso opuesto: la misión de 14 días en la que menos puntos los cumplen."],
}

const MESES := {
	"en": ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"],
	"pt_BR": ["JANEIRO", "FEVEREIRO", "MARÇO", "ABRIL", "MAIO", "JUNHO", "JULHO", "AGOSTO", "SETEMBRO", "OUTUBRO", "NOVEMBRO", "DEZEMBRO"],
	"es": ["ENERO", "FEBRERO", "MARZO", "ABRIL", "MAYO", "JUNIO", "JULIO", "AGOSTO", "SEPTIEMBRE", "OCTUBRE", "NOVIEMBRE", "DICIEMBRE"],
}

## Iniciais dos dias da semana, de domingo a sábado.
const DIAS_DA_SEMANA := {
	"en": ["S", "M", "T", "W", "T", "F", "S"],
	"pt_BR": ["D", "S", "T", "Q", "Q", "S", "S"],
	"es": ["D", "L", "M", "X", "J", "V", "S"],
}

## Letras dos pontos cardeais: norte, sul, leste, oeste.
const CARDEAIS := {
	"en": {"N": "N", "S": "S", "E": "E", "W": "W"},
	"pt_BR": {"N": "N", "S": "S", "E": "L", "W": "O"},
	"es": {"N": "N", "S": "S", "E": "E", "W": "O"},
}

## Nomes dos locais que têm palavras comuns em inglês. Os nomes das regiões (Nobile Rim 2,
## Haworth...) são nomes próprios e ficam como estão.
const NOMES_DOS_LOCAIS := {
	"CR1": ["Crista de ligação Shackleton-de Gerlache", "Cresta de conexión Shackleton-de Gerlache"],
	"IM2": ["Local de pouso do IM-2 Athena, Mons Mouton", "Sitio de alunizaje del IM-2 Athena, Mons Mouton"],
	"CH3": ["Local de pouso do Chandrayaan-3 Vikram", "Sitio de alunizaje del Chandrayaan-3 Vikram"],
	"CE4": ["Local de pouso da Chang'e-4, cratera Von Karman", "Sitio de alunizaje de la Chang'e-4, cráter Von Karman"],
	"A11": ["Apollo 11, Base da Tranquilidade", "Apolo 11, Base de la Tranquilidad"],
}
