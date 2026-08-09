@echo off
setlocal EnableExtensions EnableDelayedExpansion

title yt-dlp Downloader

echo.
echo ==================================================
echo                 YT-DLP DOWNLOADER
echo ==================================================
echo.

set /p "URL=Cole o link do YouTube: "

if not defined URL (
    echo.
    echo Nenhum link informado.
    pause
    exit /b 1
)

REM ==================================================
REM CONFIGURACOES
REM ==================================================

set "BRAVE=brave:D:\Apps\brave-portable\data\Default"
set "DOCS=%USERPROFILE%\Documents"
set "TEMP_YTDLP=%DOCS%\yt-dlp-temp"

REM ==================================================
REM CRIA PASTA TEMPORARIA
REM ==================================================

if not exist "%TEMP_YTDLP%" mkdir "%TEMP_YTDLP%" >nul 2>&1

if not exist "%TEMP_YTDLP%" (
    echo.
    echo ERRO: nao foi possivel criar:
    echo %TEMP_YTDLP%
    echo.
    pause
    exit /b 1
)

REM ==================================================
REM DETECTA SE E PLAYLIST
REM ==================================================

echo.
echo Verificando o link...
echo.

set "PLAYLIST_ID="

for /f "delims=" %%P in ('yt-dlp ^
    --cookies-from-browser "%BRAVE%" ^
    --yes-playlist ^
    --flat-playlist ^
    --skip-download ^
    --no-warnings ^
    --print "%%(playlist_id)s" ^
    "%URL%" 2^>nul') do (

    if not defined PLAYLIST_ID set "PLAYLIST_ID=%%P"
)

REM ==================================================
REM SE FOR PLAYLIST, PERGUNTA O QUE FAZER
REM ==================================================

if defined PLAYLIST_ID goto IS_PLAYLIST

REM ==================================================
REM VIDEO NORMAL
REM NAO PERGUNTA NADA
REM ==================================================

echo.
echo [OK] Video individual detectado.
echo [OK] Continuando automaticamente...
echo.

set "PLAYLIST=--no-playlist"
goto CHECK_CATEGORY


REM ==================================================
REM PLAYLIST DETECTADA
REM ==================================================

:IS_PLAYLIST

echo.
echo ==================================================
echo              PLAYLIST DETECTADA
echo ==================================================
echo.
echo ID da playlist: !PLAYLIST_ID!
echo.
echo [1] Baixar a playlist inteira
echo [2] Baixar somente este video
echo.

choice /C 12 /N /M "Escolha uma opcao [1/2]: "

if errorlevel 2 (
    set "PLAYLIST=--no-playlist"
    echo.
    echo [OK] Baixando somente este video.
) else (
    set "PLAYLIST=--yes-playlist"
    echo.
    echo [OK] Baixando a playlist inteira.
)

REM ==================================================
REM DETECTA CATEGORIA
REM ==================================================

:CHECK_CATEGORY

echo.
echo Verificando novamente...
echo.

set "CATEGORY="

for /f "delims=" %%C in ('yt-dlp ^
    --cookies-from-browser "%BRAVE%" ^
    --no-playlist ^
    --skip-download ^
    --no-warnings ^
    --print "%%(categories)s" ^
    "%URL%" 2^>nul') do (
    set "CATEGORY=%%C"
)

echo Categoria: !CATEGORY!
echo.

REM ==================================================
REM DETECTA MUSICA
REM ==================================================

echo !CATEGORY! | findstr /I /C:"Music" >nul

if not errorlevel 1 goto MUSIC

REM ==================================================
REM VIDEO
REM ==================================================

:VIDEO

echo.
echo ==================================================
echo                  VIDEO DETECTADO
echo ==================================================
echo.
echo Melhor qualidade de video.
echo Melhor audio em PT-BR/PT quando disponivel.
echo Legendas PT-BR/PT quando disponiveis.
echo.

yt-dlp ^
    --cookies-from-browser "%BRAVE%" ^
    %PLAYLIST% ^
    -f "bv*+ba[language^=pt-BR]/bv*+ba[language=pt]/bv*+ba" ^
    --write-subs ^
    --write-auto-subs ^
    --sub-langs "pt-BR,pt" ^
    --sub-format "srt/vtt/best" ^
    --embed-subs ^
    --merge-output-format mkv ^
    --windows-filenames ^
    --paths "home:%DOCS%" ^
    --paths "temp:%TEMP_YTDLP%" ^
    -o "%%(playlist)s/%%(playlist_index)03d - %%(title)s.%%(ext)s" ^
    "%URL%"

set "RESULT=%ERRORLEVEL%"
goto FINISH


REM ==================================================
REM MUSICA
REM ==================================================

:MUSIC

echo.
echo ==================================================
echo                  MUSICA DETECTADA
echo ==================================================
echo.
echo Baixando somente MP3...
echo Melhor qualidade disponivel.
echo.

yt-dlp ^
    --cookies-from-browser "%BRAVE%" ^
    %PLAYLIST% ^
    -f "ba/b" ^
    --extract-audio ^
    --audio-format mp3 ^
    --audio-quality 0 ^
    --embed-metadata ^
    --embed-thumbnail ^
    --windows-filenames ^
    --paths "home:%DOCS%" ^
    --paths "temp:%TEMP_YTDLP%" ^
    -o "%%(playlist)s/%%(playlist_index)03d - %%(title)s.%%(ext)s" ^
    "%URL%"

set "RESULT=%ERRORLEVEL%"
goto FINISH


REM ==================================================
REM FINALIZA E APAGA TEMPORARIOS
REM ==================================================

:FINISH

echo.
echo ==================================================

if "%RESULT%"=="0" (
    echo DOWNLOAD CONCLUIDO COM SUCESSO!
) else (
    echo O DOWNLOAD TERMINOU COM ERRO.
    echo Codigo: %RESULT%
)

echo ==================================================
echo.
echo Arquivos salvos em:
echo %DOCS%
echo.
echo Removendo pasta temporaria...
echo.

if exist "%TEMP_YTDLP%" (
    rmdir /S /Q "%TEMP_YTDLP%" >nul 2>&1
)

if exist "%TEMP_YTDLP%" (
    echo AVISO: nao foi possivel remover completamente:
    echo %TEMP_YTDLP%
) else (
    echo Pasta temporaria removida com sucesso.
)

echo.
echo ==================================================
echo.
pause