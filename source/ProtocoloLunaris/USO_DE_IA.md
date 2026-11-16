# Uso de IA no projeto Godot (para a descrição do envio)

As regras do Space Apps pedem que o uso de IA seja declarado. Este arquivo lista o que foi
feito com assistência de IA na parte do Godot. Atualize se algo mudar.

## Código escrito com assistência do Claude (Anthropic)

| Arquivo | O que faz |
|---|---|
| `Scripts/Dados/calculo_lunar.gd` | As contas (tradução do `lunar_calc.py` do Ricardo) |
| `Scripts/Dados/dados.gd` | Autoload `Dados`: lê os JSON e guarda a missão escolhida |
| `Scripts/UI/estilo.gd` | Cores, tema e pecinhas de interface |
| `Scripts/UI/dialogo_texto.gd` | Janelas de texto: guia rápido (HELP), ABOUT e "Sources & assumptions" |
| `Scripts/UI/calendario.gd` | Calendário da data do pouso (tela do mapa) |
| `Scripts/UI/janela_flutuante.gd` | Janelinha da lista de missões recomendadas |
| `Scripts/UI/janela_config.gd` | Janela de configurações (idioma, volume da música e dos efeitos) |
| `Scripts/Dados/config.gd` | Autoload `Config`: guarda idioma e volumes, traduz os textos e cuida do som (música de fundo, que começa no EXPLORE com fade-in e emenda o fim com o começo, e os efeitos sonoros) |
| `Scripts/Dados/traducoes.gd` | Tabela de traduções para português e espanhol, escritas com IA: **revisar antes do envio** |
| `Testes/gerar_fonte.gd` | Script que gera a fonte pixelada (rodar de novo se mudar algum desenho de letra) |
| `Assets/Fonts/lunaris_pixel*.fnt/.png` | Fonte pixelada 5x7 (normal e negrito), gerada por script a partir do conjunto clássico de caracteres 5x7 de matriz de pontos |
| `Scripts/UI/botao_animado.gd` | Animação dos botões |
| `Scripts/UI/salto_espacial.gd` | Transição do EXPLORE para o mapa (botões somem, estrelas viram riscos, logo vem na câmera, clarão, mapa chega do centro) e a volta ao menu, que é a mesma animação ao contrário |
| `Scripts/UI/cursor_pixel.gd` | Ponteiro do mouse em pixel art (seta, mão, seta dupla e "I"), desenhado em texto dentro do código com IA |
| `Scripts/Mapa/mapa_lunar.gd`, `Scripts/Mapa/tela_mapa.gd` | Tela do mapa |
| `Scripts/Mapa/nave.gd` | A navezinha da tela do mapa (surge acoplada, passeia, viaja até o local escolhido e pousa), desenhada em texto dentro do código com IA |
| `Scripts/Mapa/ficha_local.gd` | Ficha do local ao parar o mouse na lista; inclui as descrições curtas (até 10 palavras), resumidas do campo `context` dos dados |
| `Scripts/Local/tela_local.gd`, `vista_horizonte.gd`, `linha_tempo.gd` | Tela do local. O `vista_horizonte.gd` também desenha a iluminação do terreno pelo Sol (efeito visual, não é medida: os números continuam vindo só dos dados) |
| `Scripts/Local/faixa_missao.gd` | Faixa de cima da tela do local: pouso, duração, adiamento (com o botão de desfazer) e o horizonte em uso |
| `Scripts/Local/leitura_cursor.gd` | Leitura no cursor: data, se o Sol e a Terra estão visíveis, folga sobre o horizonte, elevação, azimute e próximo pôr ou nascer |
| `Scripts/Local/quadro_requisitos.gd` | Faixa de status do local e o botão de atenção, que abre a janela com o motivo (cada requisito com valor, limite e o antes do adiamento) |
| `Scripts/Fundo/fundo_espacial.gd`, `Scripts/Menus/logo_flutuante.gd` | Fundo animado e logo |
| `exportar.bat` | Gera de novo as versões de Windows e de Web na pasta `build` |
| `Testes/teste_referencia.gd` | Confere as contas contra `reference_1y.json` |
| `Testes/teste_traducoes.gd` | Confere se todo texto dos dados tem tradução e se os números batem com o inglês |
| `Testes/revisar_textos.gd` | Revisão automática de todos os textos nos 3 idiomas: chaves, marcadores, letras da fonte, larguras |

Os números mostrados no programa não são gerados por IA: vêm dos arquivos em `Data/` e são
conferidos automaticamente (503 conferências) contra `Testes/reference_1y.json`.

O diálogo "Sources & assumptions" do programa já traz uma frase em inglês declarando isso
(está em `Scripts/UI/dialogo_texto.gd`, função `abrir_fontes`).

## Imagens

Segundo a equipe, as imagens e os ícones (logo, botões, Lua, ícones e o ícone do programa)
foram feitos por um artista contratado. A equipe usou IA apenas para melhorar a resolução
de algumas delas (os ícones de configurações e de atenção, entre outras); o desenho é do artista.

Os desenhos feitos em texto dentro do código (ponteiro do mouse, navezinha, fonte) foram
escritos com assistência de IA e estão listados na tabela acima.

## Sons

- **Música de fundo** (`Assets/Audio/Musica Ambiente 1.mp3`): gerada pela equipe com IA, na
  plataforma Suno.
- **Efeitos sonoros** (`Assets/Audio/SFX*.mp3`): não foram gerados por IA. Foram recortados
  pela equipe destes vídeos do YouTube:
  - https://youtu.be/0uJ-6DWwudY
  - https://youtu.be/1TTSWWobIQE
  - https://youtu.be/weU9yqkyFy4

  Segundo a equipe, os três vídeos são declarados pelos autores como "copyright free" e
  "free to use".
