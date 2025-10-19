# Publicar na Steam — caminho enxuto

Este guia resume os passos mínimos para levar o protótipo a um lançamento "Acesso Antecipado" com seu filho.

## 1) Planejar escopo pequeno
- Objetivo: 1–2 horas de diversão com loop claro.
- Core: dirigir o trem por trilhos com ramificações, coletar recursos, evitar inimigos, comprar upgrades de vagões.

## 2) Progresso em 4 marcos
- M1 — Protótipo jogável (2–3 semanas): trem no trilho, ramificações, coleta simples, UI básica.
- M2 — Conteúdo e arte (2–4 semanas): 3 biomas, 6 inimigos, 10 upgrades, música/sfx simples.
- M3 — Polimento (2 semanas): salvar/carregar, opções de vídeo/áudio, controles.
- M4 — Build e página da Steam (1 semana): trailer curto, 6 screenshots, descrição.

## 3) Integração Steam (opcional no início)
- Não é obrigatório para o primeiro upload. Foque no jogo; 
- Depois, adicione conquistas e cloud save usando Steamworks. Para Godot, use o módulo/plug-in "GodotSteam" ou "GodotSteamworks" (instale só quando precisar).

## 4) Builds
- Godot: `Project -> Export` e crie perfis para Windows e Linux.
- Inclua `--rendering-driver opengl3` se quiser compatibilidade ampla.
- Teste em uma máquina sem o editor antes de enviar.

## 5) Página da Steam
- Crie a “App” no Steamworks, suba arte: capsule 616x353, header, ícone.
- Escreva descrição curta e clara (1–2 parágrafos) e uma lista de features.
- Trailer de 30–60s com gameplay direto.

## 6) Upload via SteamPipe (Depot)
- Use o `steamcmd` e um `app_build.vdf` com os arquivos exportados.
- Tenha um depot para Windows e outro para Linux.

## 7) Checklists de qualidade
- Performance estável a 60 FPS na resolução base.
- Opções: volume master, brilho, fullscreen/window, escala.
- Save/Load robusto (1 arquivo por usuário).
- Acessibilidade: remap de teclas, daltonismo opcional para efeitos.

> Dica: lance primeiro como "Demo" no próximo festival Steam para feedback.
