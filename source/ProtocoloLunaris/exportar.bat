@echo off
rem Gera de novo as duas versoes do programa (Windows e Web) na pasta build.
rem Uso: dois cliques neste arquivo, com o editor do Godot fechado ou aberto, tanto faz.
rem Se o Godot mudar de lugar, troque o caminho abaixo.
set GODOT="C:\Users\sayaj\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
cd /d "%~dp0"

echo === Windows: build\windows\ProtocoloLunaris.exe
%GODOT% --headless --path . --export-release "Windows Desktop" build/windows/ProtocoloLunaris.exe > build\exportar_windows.log 2>&1
if errorlevel 1 (echo FALHOU - veja build\exportar_windows.log) else (echo ok)

echo === Web: build\web\index.html
%GODOT% --headless --path . --export-release "Web" build/web/index.html > build\exportar_web.log 2>&1
if errorlevel 1 (echo FALHOU - veja build\exportar_web.log) else (echo ok)

echo === Zip da versao Web (para enviar a um site como o itch.io): build\ProtocoloLunaris_web.zip
powershell -NoProfile -Command "Compress-Archive -Path 'build\web\*' -DestinationPath 'build\ProtocoloLunaris_web.zip' -Force"
if errorlevel 1 (echo FALHOU) else (echo ok)

echo.
echo Pronto.
pause
