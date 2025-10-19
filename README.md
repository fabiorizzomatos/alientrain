# AlienTrain (protótipo Godot 4)

Um ponto de partida simples para um jogo 2D de trem sobre trilhos com visual pixelado e pós-processo tipo CRT/bloom.

## Requisitos
- Godot 4.2+ (idealmente 4.3)

## Como rodar
1. Abra este diretório no Godot.
2. Rode a cena principal: `scenes/Main.tscn`.

## Controles (protótipo)
- Setas esquerda/direita: diminuir/aumentar a velocidade do trem.
- Mouse Esquerdo: enquanto em modo de edição, adiciona um ponto ao trilho.
- R: reseta os trilhos para um formato padrão.
- Enter: sai do modo de edição (o trem continua rodando).

## HUD e combustível
- HUD (canto superior esquerdo): `speed` e barra de `fuel`.
- Consumo padrão: `fuel_per_px = 0.01` (config em `scripts/TrainController.gd`).
  - 1 combustível -> 100 px de trilho.
  - 10 combustível -> 1.000 px.
  - 100 combustível -> 10.000 px.
  - Dica: ajuste `fuel_max` e `fuel_per_px` para calibrar a sessão.

## Estrutura
- `project.godot` — configuração do projeto (viewport 480×270 e filtros em "nearest").
- `scenes/Main.tscn` — cena principal com ambiente (bloom) e pós-processo `shaders/crt.gdshader`.
- `scenes/Track.tscn` — contém `Path2D` (curva), `Line2D` (desenho do trilho) e `PathFollow2D` para locomotiva e 3 vagões.
- `scripts/Track.gd` — edição simples da curva e atualização do desenho do trilho.
- `scripts/TrainController.gd` — movimenta locomotiva e mantém vagões espaçados ao longo da curva.
- `shaders/crt.gdshader` — shader de CRT/scanlines + vinheta e ruído.

## Próximas tarefas sugeridas
- Arte em pixel (16×16): trilhos, árvores, casa, vagões, fumaça.
- UI (velocidade, combustível, botão de inverter direção).
- Troca de trilho em junções (grafo de segmentos). 
- Obstáculos/inimigos simples e coleta de itens.
- Efeitos de partículas para fumaça e explosões.

## Notas de geração de trilhos
- Agora a geração alterna blocos: retas (1–2 segmentos) e curvas "meandro" (2–4). Isso dá ~40% retas e ~60% curvas.
- As curvas usam um ruído 1D suave (fBm – fractal Brownian motion, baseado em senos) aplicado ao ângulo do trilho, parecido com o visual de cursos de rio.
- Nomes comuns do método: "Perlin noise"/"Simplex noise" dirigindo o heading; também aparece como "flow field" ou "Perlin worms" em artigos de jogos.

### Helper para geração — `TrackGen`
- Arquivo: `scripts/TrackGen.gd` (`class_name TrackGen`).
- Configurável via `configure({ ... })` e `reset(seed)`.
- Principais opções: `segment_length`, `max_turn_deg`, `handle_factor`, `straight_block_min/max`, `curve_block_min/max`, `alternate_blocks`, `ratio_straight/ratio_curve`, `use_noise_curves`, `noise_frequency`, `noise_amplitude_deg`, `noise_octaves`, `noise_gain`, `noise_lacunarity`.
- `Track.gd` usa o helper em `_append_segment()` para obter `new_pos/new_angle/in_tan/out_tan`.

### Zoom da câmera
- Teclas: `-` e `+` (ou Numpad ±) diminuem/aumentam o zoom, `0` reseta.
- Implementado em `scripts/CameraController.gd` (anexado ao `Camera2D`). Valores: `min_zoom=0.4`, `max_zoom=2.0`, `zoom_step=0.1`.

### O que é "meandro"?
- É o padrão de curvas sinuosas naturais de um rio. Em termos de algoritmo, simulamos isso gerando um ângulo que varia suavemente ao longo do caminho com ruído (fBm/Perlin), e integrando esse ângulo para construir a trilha.

Veja `STEAM.md` para um caminho enxuto até publicar na Steam.
