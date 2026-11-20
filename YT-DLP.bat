@echo off
setlocal EnableExtensions EnableDelayedExpansion

title YT-DLP Downloader

REM ============================================================
REM                    YT-DLP DOWNLOADER
REM ============================================================
REM
REM Recursos:
REM
REM - Instala yt-dlp automaticamente
REM - Instala FFmpeg automaticamente
REM - Mantem yt-dlp local
REM - Mantem FFmpeg local
REM - Atualiza yt-dlp automaticamente
REM - Verifica atualizacao do FFmpeg
REM - Suporta cookies.txt
REM - Permite selecionar o navegador para obter cookies
REM - Fallback automatico sem cookies
REM - Aceita links musicais do Spotify, Apple Music, Deezer e YouTube Music
REM - Pesquisa faixas no YouTube e baixa com yt-dlp
REM - Gera relatorio de faixas nao encontradas
REM - Detecta playlist pelo parametro "list="
REM - Permite playlist inteira ou video individual
REM - Detecta categoria
REM - Baixa musica como MP3
REM - Baixa videos em H.264/AVC + AAC para ampla compatibilidade
REM - Legendas PT-BR/PT
REM - Thumbnail e metadados em musicas
REM
REM ============================================================


REM ============================================================
REM CONFIGURACAO PRINCIPAL
REM ============================================================

REM Pasta onde este BAT esta localizado
set "BASE=%~dp0"

REM Ferramentas locais
set "TOOLS=%BASE%tools"
set "YTDLP=%TOOLS%\yt-dlp.exe"

set "FFMPEG_DIR=%TOOLS%\ffmpeg"
set "FFMPEG_BIN=%FFMPEG_DIR%\bin"
set "FFMPEG=%FFMPEG_BIN%\ffmpeg.exe"
set "FFPROBE=%FFMPEG_BIN%\ffprobe.exe"

REM Arquivo usado para controlar verificacao do FFmpeg
set "FFMPEG_CHECK=%TOOLS%\ffmpeg_update_check.txt"

REM Perfis dos navegadores suportados
set "EDGE_PROFILE=%LOCALAPPDATA%\Microsoft\Edge\User Data"
set "CHROME_PROFILE=%LOCALAPPDATA%\Google\Chrome\User Data"
set "CHROMIUM_PROFILE=%LOCALAPPDATA%\Chromium\User Data"

REM Edge e o navegador preferencial; a escolha pode ser alterada no menu.
set "LOCAL_BROWSER=edge"
set "BROWSER_PROFILE=%EDGE_PROFILE%\Default"

REM Cookies alternativos
set "COOKIE_DIR=%BASE%cookies"
set "COOKIE_FILE=%COOKIE_DIR%\youtube.txt"

REM Documentos
set "DOCS=%USERPROFILE%\Documents"

REM Temporarios
set "TEMP_YTDLP=%DOCS%\yt-dlp-temp"

REM Saidas
REM Todos os downloads ficam juntos na pasta Downloads.
set "OUTPUT_ROOT=%BASE%Downloads"
set "OUTPUT_VIDEO=%OUTPUT_ROOT%"
set "OUTPUT_MUSIC=%OUTPUT_ROOT%"


REM ============================================================
REM CABECALHO
REM ============================================================

echo.
echo ============================================================
echo                    YT-DLP DOWNLOADER
echo ============================================================
echo.
echo Pasta do programa:
echo "%BASE%"
echo.


REM ============================================================
REM CRIA PASTA DE FERRAMENTAS
REM ============================================================

if not exist "%TOOLS%" mkdir "%TOOLS%" >nul 2>&1

if not exist "%TOOLS%" (
    echo [ERRO] Nao foi possivel criar:
    echo "%TOOLS%"
    echo.
    pause
    exit /b 1
)


REM ============================================================
REM VERIFICA ESPACO EM DISCO
REM ============================================================

set "SCRIPT_DRIVE=%BASE:~0,2%"

for /f %%A in ('powershell -NoProfile -Command "$d=(Get-Item '%BASE%').PSDrive.Root; $d=$d.TrimEnd('\\'); $d=$d.TrimEnd(':'); $f=(Get-Volume -DriveLetter $d -ErrorAction Stop).SizeRemaining; [math]::Round($f/1MB,0)"') do (
    set "FREE_MB=%%A"
)

if not defined FREE_MB set "FREE_MB=0"

if !FREE_MB! LSS 300 (
    echo.
    echo [AVISO] Espaco livre no disco do script: !FREE_MB! MB
    echo O limite minimo e 300 MB.
    echo.
    choice /C SN /N /M "Deseja salvar em outra unidade? [S/N]: "

    if errorlevel 2 (
        echo [OK] Usando a pasta do script.
    ) else (
        set "ALT_DRIVE="
        set /p "ALT_DRIVE=Informe a unidade (ex.: D:): "

        if defined ALT_DRIVE (
            set "ALT_DRIVE=!ALT_DRIVE:~0,2!"
            if exist "!ALT_DRIVE!\" (
                set "OUTPUT_ROOT=!ALT_DRIVE!\YT-DLP\Downloads"
                set "OUTPUT_VIDEO=!OUTPUT_ROOT!"
                set "OUTPUT_MUSIC=!OUTPUT_ROOT!"
                if not exist "!OUTPUT_ROOT!" mkdir "!OUTPUT_ROOT!" >nul 2>&1
                echo.
                echo [OK] Destino alternativo definido:
                echo "!OUTPUT_ROOT!"
            ) else (
                echo.
                echo [AVISO] Unidade invalida. Usando a pasta do script.
            )
        ) else (
            echo.
            echo [AVISO] Nenhuma unidade informada. Usando a pasta do script.
        )
    )
)


REM Cria o destino unico para todos os downloads.
if not exist "%OUTPUT_ROOT%" mkdir "%OUTPUT_ROOT%" >nul 2>&1

if not exist "%OUTPUT_ROOT%" (
    echo [ERRO] Nao foi possivel criar a pasta de downloads:
    echo "%OUTPUT_ROOT%"
    pause
    exit /b 1
)


REM ============================================================
REM VERIFICA / INSTALA YT-DLP
REM ============================================================

echo ============================================================
echo                 VERIFICANDO YT-DLP
echo ============================================================
echo.

if exist "%YTDLP%" (

    echo [OK] yt-dlp encontrado localmente.
    echo.

) else (

    echo [AVISO] yt-dlp nao foi encontrado.
    echo.
    echo Baixando a versao oficial...
    echo.

    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$ProgressPreference='SilentlyContinue'; try { Invoke-WebRequest -Uri 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe' -OutFile '%YTDLP%'; exit 0 } catch { exit 1 }"

    if errorlevel 1 (
        echo.
        echo [ERRO] Nao foi possivel baixar o yt-dlp.
        echo.
        echo Verifique sua conexao com a internet.
        echo.
        pause
        exit /b 1
    )

    if not exist "%YTDLP%" (
        echo.
        echo [ERRO] O yt-dlp nao foi encontrado apos o download.
        echo.
        pause
        exit /b 1
    )

    echo.
    echo [OK] yt-dlp instalado.
    echo.
)


REM ============================================================
REM MOSTRA VERSAO DO YT-DLP
REM ============================================================

echo Versao instalada:

"%YTDLP%" --version

if errorlevel 1 (
    echo.
    echo [ERRO] O yt-dlp nao conseguiu iniciar.
    echo.
    pause
    exit /b 1
)

echo.


REM ============================================================
REM ATUALIZA YT-DLP
REM ============================================================

echo ============================================================
echo                 ATUALIZANDO YT-DLP
echo ============================================================
echo.

"%YTDLP%" -U

echo.


REM ============================================================
REM VERIFICA / INSTALA DENO (RUNTIME JAVASCRIPT)
REM ============================================================

set "DENO_DIR=%TOOLS%\deno"
set "DENO=%DENO_DIR%\deno.exe"

if exist "%DENO%" goto DENO_READY

echo ============================================================
echo             VERIFICANDO RUNTIME JAVASCRIPT
echo ============================================================
echo.
echo Deno nao encontrado. Baixando versao portatil...
echo.

if not exist "%DENO_DIR%" mkdir "%DENO_DIR%" >nul 2>&1

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; $arch=$env:PROCESSOR_ARCHITECTURE; if ($arch -eq 'ARM64') { $asset='deno-aarch64-pc-windows-msvc.zip' } elseif ($arch -eq 'AMD64') { $asset='deno-x86_64-pc-windows-msvc.zip' } else { throw 'Arquitetura Windows nao suportada pelo pacote portatil do Deno.' }; $zip=Join-Path '%TOOLS%' 'deno.zip'; $tmp=Join-Path '%TOOLS%' 'deno_extract'; try { Invoke-WebRequest -Uri ('https://github.com/denoland/deno/releases/latest/download/' + $asset) -OutFile $zip; if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }; Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force; Move-Item -LiteralPath (Join-Path $tmp 'deno.exe') -Destination '%DENO%' -Force; exit 0 } catch { Write-Error $_; exit 1 } finally { if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }; if (Test-Path $zip) { Remove-Item $zip -Force -ErrorAction SilentlyContinue } }"

if errorlevel 1 (
    echo.
    echo [AVISO] Nao foi possivel instalar o Deno portatil.
    echo A extracao do YouTube pode falhar ou apresentar formatos limitados.
    echo.
    goto DENO_CONTINUE
)

:DENO_READY

if exist "%DENO%" (
    echo [OK] Deno encontrado:
    "%DENO%" --version
    set "PATH=%DENO_DIR%;%PATH%"
) else (
    echo.
    echo [AVISO] Deno indisponivel. O yt-dlp tentara continuar sem runtime JavaScript.
    echo.
)

:DENO_CONTINUE

echo.


REM ============================================================
REM VERIFICA FFMPEG
REM ============================================================

echo ============================================================
echo                 VERIFICANDO FFMPEG
echo ============================================================
echo.

if exist "%FFMPEG%" if exist "%FFPROBE%" goto FFMPEG_FOUND

echo [AVISO] FFmpeg nao foi encontrado.
echo.
echo O FFmpeg sera instalado automaticamente.
echo.

goto INSTALL_FFMPEG


REM ============================================================
REM FFMPEG ENCONTRADO
REM ============================================================

:FFMPEG_FOUND

echo [OK] FFmpeg encontrado localmente.
echo.

goto CHECK_FFMPEG_UPDATE


REM ============================================================
REM INSTALA FFMPEG
REM ============================================================

:INSTALL_FFMPEG

echo ============================================================
echo                  INSTALANDO FFMPEG
echo ============================================================
echo.

set "FFMPEG_ZIP=%TOOLS%\ffmpeg.zip"

if exist "%FFMPEG_ZIP%" (
    del /f /q "%FFMPEG_ZIP%" >nul 2>&1
)

if exist "%TOOLS%\ffmpeg_extract" (
    rmdir /S /Q "%TOOLS%\ffmpeg_extract" >nul 2>&1
)

echo Baixando FFmpeg...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ProgressPreference='SilentlyContinue'; try { Invoke-WebRequest -Uri 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -OutFile '%FFMPEG_ZIP%'; exit 0 } catch { exit 1 }"

if errorlevel 1 (
    echo.
    echo [ERRO] Nao foi possivel baixar o FFmpeg.
    echo.
    echo Verifique sua conexao com a internet.
    echo.
    pause
    exit /b 1
)

if not exist "%FFMPEG_ZIP%" (
    echo.
    echo [ERRO] O arquivo ZIP do FFmpeg nao foi encontrado.
    echo.
    pause
    exit /b 1
)

echo.
echo [OK] Download concluido.
echo.
echo Extraindo FFmpeg...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { Expand-Archive -LiteralPath '%FFMPEG_ZIP%' -DestinationPath '%TOOLS%\ffmpeg_extract' -Force; exit 0 } catch { exit 1 }"

if errorlevel 1 (
    echo.
    echo [ERRO] Falha ao extrair o FFmpeg.
    echo.
    pause
    exit /b 1
)

if not exist "%TOOLS%\ffmpeg_extract" (
    echo.
    echo [ERRO] A pasta de extracao do FFmpeg nao foi criada.
    echo.
    pause
    exit /b 1
)


REM ============================================================
REM ENCONTRA A PASTA BIN DENTRO DO ZIP
REM ============================================================

set "FOUND_FFMPEG_BIN="

for /d %%D in ("%TOOLS%\ffmpeg_extract\*") do (
    if exist "%%D\bin\ffmpeg.exe" (
        set "FOUND_FFMPEG_BIN=%%D\bin"
    )
)

if not defined FOUND_FFMPEG_BIN (
    echo.
    echo [ERRO] ffmpeg.exe nao foi encontrado dentro do pacote.
    echo.
    rmdir /S /Q "%TOOLS%\ffmpeg_extract" >nul 2>&1
    del /f /q "%FFMPEG_ZIP%" >nul 2>&1
    pause
    exit /b 1
)


REM ============================================================
REM COPIA BINARIOS
REM ============================================================

if exist "%FFMPEG_DIR%" (
    rmdir /S /Q "%FFMPEG_DIR%" >nul 2>&1
)

mkdir "%FFMPEG_BIN%" >nul 2>&1

xcopy "%FOUND_FFMPEG_BIN%\*" "%FFMPEG_BIN%\" /E /I /Y /Q >nul

if not exist "%FFMPEG%" (
    echo.
    echo [ERRO] FFmpeg nao foi instalado corretamente.
    echo.
    rmdir /S /Q "%TOOLS%\ffmpeg_extract" >nul 2>&1
    del /f /q "%FFMPEG_ZIP%" >nul 2>&1
    pause
    exit /b 1
)

if not exist "%FFPROBE%" (
    echo.
    echo [ERRO] FFprobe nao foi instalado corretamente.
    echo.
    rmdir /S /Q "%TOOLS%\ffmpeg_extract" >nul 2>&1
    del /f /q "%FFMPEG_ZIP%" >nul 2>&1
    pause
    exit /b 1
)


REM ============================================================
REM LIMPA INSTALACAO
REM ============================================================

rmdir /S /Q "%TOOLS%\ffmpeg_extract" >nul 2>&1
del /f /q "%FFMPEG_ZIP%" >nul 2>&1

echo.
echo [OK] FFmpeg instalado localmente.
echo.

goto SAVE_FFMPEG_DATE


REM ============================================================
REM VERIFICA ATUALIZACAO DO FFMPEG
REM ============================================================

:CHECK_FFMPEG_UPDATE

REM
REM Para nao baixar o pacote do FFmpeg toda vez que o programa abre,
REM a verificacao e realizada no maximo uma vez por dia.
REM

set "NEED_FFMPEG_CHECK=1"

if exist "%FFMPEG_CHECK%" (

    set "LAST_FFMPEG_CHECK="

    set /p "LAST_FFMPEG_CHECK="<"%FFMPEG_CHECK%"

    for /f %%T in ('powershell -NoProfile -Command "(Get-Date).ToString('yyyy-MM-dd')"') do (
        set "TODAY=%%T"
    )

    if "!LAST_FFMPEG_CHECK!"=="!TODAY!" (
        set "NEED_FFMPEG_CHECK=0"
    )
)

if "!NEED_FFMPEG_CHECK!"=="0" (
    echo [OK] FFmpeg ja foi verificado hoje.
    goto FFMPEG_READY
)

echo.
echo Verificando atualizacao do FFmpeg...
echo.

set "FFMPEG_UPDATE_ZIP=%TOOLS%\ffmpeg_update.zip"

if exist "%FFMPEG_UPDATE_ZIP%" (
    del /f /q "%FFMPEG_UPDATE_ZIP%" >nul 2>&1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ProgressPreference='SilentlyContinue'; try { Invoke-WebRequest -Uri 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -OutFile '%FFMPEG_UPDATE_ZIP%'; exit 0 } catch { exit 1 }"

if errorlevel 1 (
    echo.
    echo [AVISO] Nao foi possivel verificar o FFmpeg.
    echo O FFmpeg atual continuara sendo usado.
    echo.
    goto SAVE_FFMPEG_DATE
)

if not exist "%FFMPEG_UPDATE_ZIP%" (
    echo.
    echo [AVISO] O pacote de atualizacao nao foi encontrado.
    echo O FFmpeg atual continuara sendo usado.
    echo.
    goto SAVE_FFMPEG_DATE
)

echo.
echo [OK] Pacote FFmpeg recebido.
echo.
echo Verificando arquivos...

if exist "%TOOLS%\ffmpeg_update_extract" (
    rmdir /S /Q "%TOOLS%\ffmpeg_update_extract" >nul 2>&1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { Expand-Archive -LiteralPath '%FFMPEG_UPDATE_ZIP%' -DestinationPath '%TOOLS%\ffmpeg_update_extract' -Force; exit 0 } catch { exit 1 }"

if errorlevel 1 (
    echo.
    echo [AVISO] Nao foi possivel extrair a atualizacao.
    echo O FFmpeg atual continuara sendo usado.
    echo.
    del /f /q "%FFMPEG_UPDATE_ZIP%" >nul 2>&1
    goto SAVE_FFMPEG_DATE
)

set "NEW_FFMPEG_BIN="

for /d %%D in ("%TOOLS%\ffmpeg_update_extract\*") do (
    if exist "%%D\bin\ffmpeg.exe" (
        set "NEW_FFMPEG_BIN=%%D\bin"
    )
)

if not defined NEW_FFMPEG_BIN (

    echo.
    echo [AVISO] Nao foi encontrada uma pasta bin valida.
    echo O FFmpeg atual continuara sendo usado.
    echo.

    rmdir /S /Q "%TOOLS%\ffmpeg_update_extract" >nul 2>&1
    del /f /q "%FFMPEG_UPDATE_ZIP%" >nul 2>&1

    goto SAVE_FFMPEG_DATE
)


REM ============================================================
REM COMPARA VERSAO DO FFMPEG
REM ============================================================

set "CURRENT_FFMPEG_VERSION="
set "NEW_FFMPEG_VERSION="

for /f "tokens=3" %%V in ('"%FFMPEG%" -version 2^>nul ^| findstr /B /C:"ffmpeg version"') do (
    set "CURRENT_FFMPEG_VERSION=%%V"
)

for /f "tokens=3" %%V in ('"!NEW_FFMPEG_BIN!\ffmpeg.exe" -version 2^>nul ^| findstr /B /C:"ffmpeg version"') do (
    set "NEW_FFMPEG_VERSION=%%V"
)

echo.
echo Versao atual:
echo !CURRENT_FFMPEG_VERSION!
echo.
echo Versao encontrada:
echo !NEW_FFMPEG_VERSION!
echo.

if "!CURRENT_FFMPEG_VERSION!"=="!NEW_FFMPEG_VERSION!" (

    echo [OK] FFmpeg ja esta na versao mais recente.

) else (

    echo Nova versao do FFmpeg detectada.
    echo Atualizando instalacao local...
    echo.

    if exist "%FFMPEG_BIN%" (
        rmdir /S /Q "%FFMPEG_BIN%" >nul 2>&1
    )

    mkdir "%FFMPEG_BIN%" >nul 2>&1

    xcopy "!NEW_FFMPEG_BIN!\*" "%FFMPEG_BIN%\" /E /I /Y /Q >nul

    if exist "%FFMPEG%" if exist "%FFPROBE%" (
        echo [OK] FFmpeg atualizado.
    ) else (
        echo [AVISO] Falha ao copiar a nova versao.
        echo O FFmpeg pode estar indisponivel.
    )
)

rmdir /S /Q "%TOOLS%\ffmpeg_update_extract" >nul 2>&1
del /f /q "%FFMPEG_UPDATE_ZIP%" >nul 2>&1


REM ============================================================
REM SALVA DATA DA VERIFICACAO
REM ============================================================

:SAVE_FFMPEG_DATE

for /f %%T in ('powershell -NoProfile -Command "(Get-Date).ToString('yyyy-MM-dd')"') do (
    echo %%T>"%FFMPEG_CHECK%"
)


REM ============================================================
REM FFMPEG PRONTO
REM ============================================================

:FFMPEG_READY

if not exist "%FFMPEG%" (
    echo.
    echo [ERRO] ffmpeg.exe nao esta disponivel.
    echo.
    pause
    exit /b 1
)

if not exist "%FFPROBE%" (
    echo.
    echo [ERRO] ffprobe.exe nao esta disponivel.
    echo.
    pause
    exit /b 1
)

echo.
echo [OK] FFmpeg pronto.
echo.

echo Versao do FFmpeg:
"%FFMPEG%" -version 2>nul | findstr /B /C:"ffmpeg version"

echo.


REM ============================================================
REM CRIA PASTAS
REM ============================================================

if not exist "%TEMP_YTDLP%" mkdir "%TEMP_YTDLP%" >nul 2>&1
if not exist "%OUTPUT_ROOT%" mkdir "%OUTPUT_ROOT%" >nul 2>&1

if not exist "%TEMP_YTDLP%" (
    echo.
    echo [ERRO] Nao foi possivel criar a pasta temporaria:
    echo "%TEMP_YTDLP%"
    echo.
    pause
    exit /b 1
)


REM ============================================================
REM PEDE URL
REM ============================================================

echo ============================================================
echo                       NOVO DOWNLOAD
echo ============================================================
echo.

set "URL="

set /p "URL=Cole o link do YouTube, YouTube Music, Spotify, Apple Music ou Deezer: "

if not defined URL (
    echo.
    echo Nenhum link informado.
    echo.
    pause
    exit /b 1
)


REM Links musicais nao precisam de cookies nem de leitura do navegador.
if /I not "!URL:spotify.com=!"=="!URL!" goto MUSICAL_LINKS
if /I not "!URL:music.apple.com=!"=="!URL!" goto MUSICAL_LINKS
if /I not "!URL:deezer.com=!"=="!URL!" goto MUSICAL_LINKS
if /I not "!URL:music.youtube.com=!"=="!URL!" goto MUSICAL_LINKS


REM ============================================================
REM CONFIGURA COOKIES
REM ============================================================

echo.
echo ============================================================
echo                    CONFIGURANDO COOKIES
echo ============================================================
echo.

set "COOKIE_MODE=NONE"
set "LOCAL_BROWSER=edge"
set "BROWSER_PROFILE=%EDGE_PROFILE%\Default"

echo Selecione a fonte de cookies:
echo.
echo [1] Microsoft Edge (padrao)
echo [2] Google Chrome
echo [3] Chromium
echo [4] Arquivo cookies\youtube.txt
echo [5] Nao usar cookies
echo.
set "BROWSER_CHOICE=1"
set /p "BROWSER_CHOICE=Opcao [1-5] (Enter = Edge): "

if "!BROWSER_CHOICE!"=="1" (
    set "LOCAL_BROWSER=edge"
    set "BROWSER_PROFILE=%EDGE_PROFILE%\Default"
) else if "!BROWSER_CHOICE!"=="2" (
    set "LOCAL_BROWSER=chrome"
    set "BROWSER_PROFILE=%CHROME_PROFILE%\Default"
) else if "!BROWSER_CHOICE!"=="3" (
    set "LOCAL_BROWSER=chromium"
    set "BROWSER_PROFILE=%CHROMIUM_PROFILE%\Default"
) else if "!BROWSER_CHOICE!"=="4" (
    set "BROWSER_PROFILE="
    if exist "%COOKIE_FILE%" (
        set "COOKIE_MODE=FILE"
        echo.
        echo [OK] Usando arquivo de cookies.
    ) else (
        echo.
        echo [AVISO] Arquivo cookies\youtube.txt nao encontrado.
        echo O download seguira sem cookies.
    )
) else if "!BROWSER_CHOICE!"=="5" (
    set "COOKIE_MODE=NONE"
) else (
    echo.
    echo [AVISO] Opcao invalida. Usando Microsoft Edge.
    set "LOCAL_BROWSER=edge"
    set "BROWSER_PROFILE=%EDGE_PROFILE%\Default"
)

if "!BROWSER_CHOICE!"=="1" if not exist "%EDGE_PROFILE%\Default" (
    echo.
    echo [AVISO] Perfil do Edge nao encontrado. Tentando sem cookies.
    set "COOKIE_MODE=NONE"
)
if "!BROWSER_CHOICE!"=="2" if not exist "%CHROME_PROFILE%\Default" (
    echo.
    echo [AVISO] Perfil do Chrome nao encontrado. Tentando sem cookies.
    set "COOKIE_MODE=NONE"
)
if "!BROWSER_CHOICE!"=="3" if not exist "%CHROMIUM_PROFILE%\Default" (
    echo.
    echo [AVISO] Perfil do Chromium nao encontrado. Tentando sem cookies.
    set "COOKIE_MODE=NONE"
)


if "!COOKIE_MODE!"=="NONE" if not "!BROWSER_CHOICE!"=="5" if exist "!BROWSER_PROFILE!" (
    set "COOKIE_MODE=LOCAL"
    echo.
    echo [OK] Navegador selecionado: !LOCAL_BROWSER!
    echo Perfil: "!BROWSER_PROFILE!"
)


goto AFTER_MUSICAL_COOKIE_BYPASS

:MUSICAL_LINKS
set "COOKIE_MODE=NONE"
set "LOCAL_BROWSER=edge"

:AFTER_MUSICAL_COOKIE_BYPASS
REM ============================================================
REM LINKS DE SERVICOS MUSICAIS (SPOTIFY / APPLE MUSIC / DEEZER / YOUTUBE MUSIC)
REM ============================================================

if /I not "!URL:spotify.com=!"=="!URL!" goto EXTERNAL_MUSIC
if /I not "!URL:music.apple.com=!"=="!URL!" goto EXTERNAL_MUSIC
if /I not "!URL:music.youtube.com=!"=="!URL!" goto EXTERNAL_MUSIC
if /I not "!URL:deezer.com=!"=="!URL!" goto EXTERNAL_MUSIC

goto CHECK_YOUTUBE_PLAYLIST

:EXTERNAL_MUSIC

if /I not "!URL:spotify.com=!"=="!URL!" (
    powershell -NoProfile -Command "Write-Host 'Spotify' -ForegroundColor Green"
) else if /I not "!URL:music.apple.com=!"=="!URL!" (
    powershell -NoProfile -Command "Write-Host 'Apple ' -ForegroundColor Red -NoNewline; Write-Host 'Music' -ForegroundColor Magenta"
) else if /I not "!URL:deezer.com=!"=="!URL!" (
    powershell -NoProfile -Command "Write-Host 'Deezer' -ForegroundColor Magenta"
) else (
    powershell -NoProfile -Command "Write-Host 'YouTube Music' -ForegroundColor Red"
)

echo.
echo ============================================================
echo               SERVICO MUSICAL DETECTADO
echo ============================================================
echo.
echo O programa vai ler as faixas do servico e pesquisar cada uma no YouTube.
echo O audio sera baixado pelo yt-dlp e convertido para MP3.
echo.

set "OUTPUT_MODE=PLAYLIST"
set "CATEGORY=Music"

if not exist "%DENO%" (
    echo [ERRO] Deno nao esta disponivel. Nao e possivel processar links musicais.
    set "RESULT=1"
    goto FINISH
)

"%DENO%" run --allow-net=spotify.com,open.spotify.com,music.apple.com,amp-api.music.apple.com,api.deezer.com,music.youtube.com,youtube.com,www.youtube.com,lrclib.net --allow-run --allow-read --allow-write "%BASE%Musicas.ts" ^
    --url "!URL!" ^
    --ytdlp "%YTDLP%" ^
    --ffmpeg "%FFMPEG_BIN%" ^
    --output "%OUTPUT_ROOT%" ^
    --temp "%TEMP_YTDLP%"

set "RESULT=!ERRORLEVEL!"

goto FINISH


:CHECK_YOUTUBE_PLAYLIST

REM ============================================================
REM IDENTIFICA YOUTUBE (VERMELHO)
REM ============================================================

powershell -NoProfile -Command "Write-Host '● YouTube' -ForegroundColor Red"

REM ============================================================
REM DETECTA PLAYLIST PELO LINK
REM ============================================================

echo ============================================================
echo                    ANALISANDO LINK
echo ============================================================
echo.

set "HAS_PLAYLIST=0"

REM Verifica o parametro list= sem enviar a URL ao interpretador do CMD.
REM A substituicao interna evita que o caractere & seja executado como separador.
if not "!URL:list=!"=="!URL!" set "HAS_PLAYLIST=1"

if "!HAS_PLAYLIST!"=="1" goto PLAYLIST_DETECTED

echo [OK] Nenhum parametro de playlist detectado.
echo.
goto SINGLE_VIDEO


REM ============================================================
REM PLAYLIST DETECTADA
REM ============================================================

:PLAYLIST_DETECTED

echo.
echo ============================================================
echo                    PLAYLIST DETECTADA
echo ============================================================
echo.

echo O link contem uma playlist.
echo.

echo [1] Baixar playlist inteira
echo [2] Baixar somente este video
echo [3] Cancelar
echo.

choice /C 123 /N /M "Escolha uma opcao [1/2/3]: "

if errorlevel 3 goto CANCEL
if errorlevel 2 goto SINGLE_VIDEO

set "PLAYLIST=--yes-playlist"
set "OUTPUT_MODE=PLAYLIST"

echo.
echo [OK] Playlist inteira selecionada.
echo.

goto CHECK_CATEGORY


REM ============================================================
REM VIDEO INDIVIDUAL
REM ============================================================

:SINGLE_VIDEO

set "PLAYLIST=--no-playlist"
set "OUTPUT_MODE=VIDEO"

echo.
echo [OK] Video individual selecionado.
echo.

goto CHECK_CATEGORY


REM ============================================================
REM ANALISA CATEGORIA
REM ============================================================

:CHECK_CATEGORY

echo ============================================================
echo                  ANALISANDO CONTEUDO
echo ============================================================
echo.

set "CATEGORY="

echo Consultando categoria...
echo.


REM ------------------------------------------------------------
REM TENTA ANALISAR COM A FONTE DE COOKIES SELECIONADA
REM ------------------------------------------------------------

if /I "!COOKIE_MODE!"=="FILE" (

    "%YTDLP%" ^
        --cookies "%COOKIE_FILE%" ^
        --no-playlist ^
        --skip-download ^
        --no-warnings ^
        --print "%%(categories.0|)s" ^
        -- "!URL!" >"%TEMP_YTDLP%\category.txt" 2>"%TEMP_YTDLP%\category_error.txt"


) else if /I "!COOKIE_MODE!"=="LOCAL" (

    "%YTDLP%" ^
        --cookies-from-browser "!LOCAL_BROWSER!" ^
        --no-playlist ^
        --skip-download ^
        --no-warnings ^
        --print "%%(categories.0|)s" ^
        -- "!URL!" >"%TEMP_YTDLP%\category.txt" 2>"%TEMP_YTDLP%\category_error.txt"

) else (

    "%YTDLP%" ^
        --no-playlist ^
        --skip-download ^
        --no-warnings ^
        --print "%%(categories.0|)s" ^
        -- "!URL!" >"%TEMP_YTDLP%\category.txt" 2>"%TEMP_YTDLP%\category_error.txt"

)


REM ============================================================
REM LE CATEGORIA
REM ============================================================

if exist "%TEMP_YTDLP%\category.txt" (

    for /f "usebackq delims=" %%C in ("%TEMP_YTDLP%\category.txt") do (

        if not defined CATEGORY (
            if not "%%C"=="" (
                if not "%%C"=="NA" (
                    set "CATEGORY=%%C"
                )
            )
        )

    )

)

if not defined CATEGORY (
    set "CATEGORY=Desconhecida"
)

echo.
echo Categoria: !CATEGORY!
echo.


REM ============================================================
REM DETECTA MUSICA
REM ============================================================

echo !CATEGORY! | findstr /I /C:"Music" /C:"Musica" /C:"Música" >nul

if not errorlevel 1 goto MUSIC

goto VIDEO


REM ============================================================
REM VIDEO
REM ============================================================

:VIDEO

echo.
echo ============================================================
echo                     VIDEO DETECTADO
echo ============================================================
echo.

echo Escolha a configuracao antes do download:
echo.

echo [1] Melhor qualidade disponivel

echo [2] 1080p maximo

echo [3] 720p maximo

echo [4] 480p maximo

echo [5] 360p maximo

echo.

set "VIDEO_QUALITY=best"

choice /C 12345 /N /M "Qualidade do video [1/2/3/4/5]: "

if errorlevel 5 (
    set "VIDEO_QUALITY=360"
) else if errorlevel 4 (
    set "VIDEO_QUALITY=480"
) else if errorlevel 3 (
    set "VIDEO_QUALITY=720"
) else if errorlevel 2 (
    set "VIDEO_QUALITY=1080"
) else (
    set "VIDEO_QUALITY=best"
)

echo.
choice /C SN /N /M "Deseja baixar legendas PT-BR/PT? [S/N]: "

if errorlevel 2 (
    set "VIDEO_SUBTITLES=0"
) else (
    set "VIDEO_SUBTITLES=1"
)

echo.
if /I "!VIDEO_SUBTITLES!"=="1" (
    echo [OK] Legendas PT-BR/PT serao baixadas.
    set "VIDEO_SUBTITLE_ARGS=--write-subs --write-auto-subs --sub-langs pt-BR,pt --sub-format srt/vtt/best --embed-subs"
) else (
    echo [OK] Legendas nao serao baixadas.
    set "VIDEO_SUBTITLE_ARGS="
)

echo.
echo [1] MP4

echo [2] MKV

echo [3] MP3 (audio extraido)

echo.

set "VIDEO_FINAL_FORMAT=mp4"

choice /C 123 /N /M "Formato final do download [1/2/3]: "

if errorlevel 3 (
    set "VIDEO_FINAL_FORMAT=mp3"
) else if errorlevel 2 (
    set "VIDEO_FINAL_FORMAT=mkv"
) else (
    set "VIDEO_FINAL_FORMAT=mp4"
)

echo.
if /I "!VIDEO_FINAL_FORMAT!"=="mp3" (
    echo [OK] Formato final selecionado: MP3.
) else (
    echo [OK] Formato final selecionado: !VIDEO_FINAL_FORMAT!.
)

echo.
echo Audio em PT-BR/PT quando disponivel.
echo Audio sempre no maximo disponivel.
echo.

if /I "!OUTPUT_MODE!"=="PLAYLIST" (

    set "VIDEO_OUTPUT=%%(playlist_index|0)03d - %%(title)s.%%(ext)s"
    set "MUSIC_OUTPUT=%%(playlist_index|0)03d - %%(title)s.%%(ext)s"

) else (

    set "VIDEO_OUTPUT=%%(title)s.%%(ext)s"
    set "MUSIC_OUTPUT=%%(title)s.%%(ext)s"

)

if /I "!VIDEO_QUALITY!"=="best" (
    set "VIDEO_FORMAT=-f bv*[vcodec^^=avc1]+ba[ext=m4a]/bv*[vcodec^^=avc1]+ba/b[vcodec^^=avc1]"
) else (
    set "VIDEO_FORMAT=-f bv*[vcodec^^=avc1][height^<=!VIDEO_QUALITY!]+ba[ext=m4a]/bv*[vcodec^^=avc1][height^<=!VIDEO_QUALITY!]+ba/b[vcodec^^=avc1][height^<=!VIDEO_QUALITY!]
)


REM ============================================================
REM DOWNLOAD VIDEO
REM ============================================================

echo Iniciando download...
echo.


REM ------------------------------------------------------------
REM COM COOKIES DE ARQUIVO
REM ------------------------------------------------------------

if /I "!COOKIE_MODE!"=="FILE" (

    if /I "!VIDEO_FINAL_FORMAT!"=="mp3" (

        "%YTDLP%" ^
            --cookies "%COOKIE_FILE%" ^
            %PLAYLIST% ^
            --ffmpeg-location "%FFMPEG_BIN%" ^
            -f "ba/b" ^
            --extract-audio ^
            --audio-format mp3 ^
            --audio-quality 0 ^
            --embed-metadata ^
            --embed-thumbnail ^
            --convert-thumbnails jpg ^
            --windows-filenames ^
            --paths "home:%OUTPUT_MUSIC%" ^
            --paths "temp:%TEMP_YTDLP%" ^
            -o "!MUSIC_OUTPUT!" ^
            -- "!URL!" 2>"%TEMP_YTDLP%\download_error.txt"

    ) else (

        "%YTDLP%" ^
            --cookies "%COOKIE_FILE%" ^
            %PLAYLIST% ^
            --ffmpeg-location "%FFMPEG_BIN%" ^
            !VIDEO_FORMAT! ^
            !VIDEO_SUBTITLE_ARGS! ^
            --merge-output-format !VIDEO_FINAL_FORMAT! ^
            --windows-filenames ^
            --paths "home:%OUTPUT_VIDEO%" ^
            --paths "temp:%TEMP_YTDLP%" ^
            -o "!VIDEO_OUTPUT!" ^
            -- "!URL!" 2>"%TEMP_YTDLP%\download_error.txt"

    )

    set "RESULT=!ERRORLEVEL!"

    goto FINISH
)


REM ------------------------------------------------------------
REM COM COOKIES DO NAVEGADOR LOCAL
REM ------------------------------------------------------------

if /I "!COOKIE_MODE!"=="LOCAL" (

    if /I "!VIDEO_FINAL_FORMAT!"=="mp3" (

        "%YTDLP%" ^
            --cookies-from-browser "!LOCAL_BROWSER!" ^
            %PLAYLIST% ^
            --ffmpeg-location "%FFMPEG_BIN%" ^
            -f "ba/b" ^
            --extract-audio ^
            --audio-format mp3 ^
            --audio-quality 0 ^
            --embed-metadata ^
            --embed-thumbnail ^
            --convert-thumbnails jpg ^
            --windows-filenames ^
            --paths "home:%OUTPUT_MUSIC%" ^
            --paths "temp:%TEMP_YTDLP%" ^
            -o "!MUSIC_OUTPUT!" ^
            -- "!URL!" 2>"%TEMP_YTDLP%\download_error.txt"

    ) else (

        "%YTDLP%" ^
            --cookies-from-browser "!LOCAL_BROWSER!" ^
            %PLAYLIST% ^
            --ffmpeg-location "%FFMPEG_BIN%" ^
            !VIDEO_FORMAT! ^
            !VIDEO_SUBTITLE_ARGS! ^
            --merge-output-format !VIDEO_FINAL_FORMAT! ^
            --windows-filenames ^
            --paths "home:%OUTPUT_VIDEO%" ^
            --paths "temp:%TEMP_YTDLP%" ^
            -o "!VIDEO_OUTPUT!" ^
            -- "!URL!" 2>"%TEMP_YTDLP%\download_error.txt"

    )

    set "RESULT=!ERRORLEVEL!"

    goto CHECK_LOCAL_DOWNLOAD_ERROR
)


REM ------------------------------------------------------------
REM SEM COOKIES
REM ------------------------------------------------------------

if /I "!VIDEO_FINAL_FORMAT!"=="mp3" (

    "%YTDLP%" ^
        %PLAYLIST% ^
        --ffmpeg-location "%FFMPEG_BIN%" ^
        -f "ba/b" ^
        --extract-audio ^
        --audio-format mp3 ^
        --audio-quality 0 ^
        --embed-metadata ^
        --embed-thumbnail ^
        --convert-thumbnails jpg ^
        --windows-filenames ^
        --paths "home:%OUTPUT_MUSIC%" ^
        --paths "temp:%TEMP_YTDLP%" ^
        -o "!MUSIC_OUTPUT!" ^
        -- "!URL!" 2>"%TEMP_YTDLP%\download_error.txt"

) else (

    "%YTDLP%" ^
        %PLAYLIST% ^
        --ffmpeg-location "%FFMPEG_BIN%" ^
        !VIDEO_FORMAT! ^
        !VIDEO_SUBTITLE_ARGS! ^
        --merge-output-format !VIDEO_FINAL_FORMAT! ^
        --windows-filenames ^
        --paths "home:%OUTPUT_VIDEO%" ^
        --paths "temp:%TEMP_YTDLP%" ^
        -o "!VIDEO_OUTPUT!" ^
        -- "!URL!" 2>"%TEMP_YTDLP%\download_error.txt"

)

set "RESULT=!ERRORLEVEL!"

goto FINISH


:CHECK_LOCAL_DOWNLOAD_ERROR

set "COOKIE_COPY_ERROR=0"
if exist "%TEMP_YTDLP%\download_error.txt" (
    findstr /I /C:"Could not copy Chrome cookie database" "%TEMP_YTDLP%\download_error.txt" >nul
    if not errorlevel 1 set "COOKIE_COPY_ERROR=1"
)

if /I "!COOKIE_MODE!"=="LOCAL" if "!RESULT!"=="1" if "!COOKIE_COPY_ERROR!"=="1" (
    echo.
    echo [AVISO] O navegador local falhou. Tentando sem cookies...
    echo.
    set "COOKIE_MODE=NONE"

    if /I "!VIDEO_FINAL_FORMAT!"=="mp3" (

        "%YTDLP%" ^
            %PLAYLIST% ^
            --ffmpeg-location "%FFMPEG_BIN%" ^
            -f "ba/b" ^
            --extract-audio ^
            --audio-format mp3 ^
            --audio-quality 0 ^
            --embed-metadata ^
            --embed-thumbnail ^
            --convert-thumbnails jpg ^
            --windows-filenames ^
            --paths "home:%OUTPUT_MUSIC%" ^
            --paths "temp:%TEMP_YTDLP%" ^
            -o "!MUSIC_OUTPUT!" ^
            -- "!URL!" 2>"%TEMP_YTDLP%\download_error.txt"

    ) else (

        "%YTDLP%" ^
            %PLAYLIST% ^
            --ffmpeg-location "%FFMPEG_BIN%" ^
            !VIDEO_FORMAT! ^
            !VIDEO_SUBTITLE_ARGS! ^
            --merge-output-format !VIDEO_FINAL_FORMAT! ^
            --windows-filenames ^
            --paths "home:%OUTPUT_VIDEO%" ^
            --paths "temp:%TEMP_YTDLP%" ^
            -o "!VIDEO_OUTPUT!" ^
            -- "!URL!" 2>"%TEMP_YTDLP%\download_error.txt"

    )

    set "RESULT=!ERRORLEVEL!"
)

goto FINISH


REM ============================================================
REM MUSICA
REM ============================================================

:MUSIC

echo.
echo ============================================================
echo                     MUSICA DETECTADA
echo ============================================================
echo.

echo Audio original sera convertido para MP3.
echo Metadados serao incorporados.
echo Thumbnail sera incorporada.
echo.

if /I "!OUTPUT_MODE!"=="PLAYLIST" (

    set "MUSIC_OUTPUT=%%(playlist_index|0)03d - %%(title)s.%%(ext)s"

) else (

    set "MUSIC_OUTPUT=%%(title)s.%%(ext)s"

)


REM ============================================================
REM DOWNLOAD MUSICA
REM ============================================================

echo Iniciando download...
echo.


REM ------------------------------------------------------------
REM COOKIES DE ARQUIVO
REM ------------------------------------------------------------

if /I "!COOKIE_MODE!"=="FILE" (

    "%YTDLP%" ^
        --cookies "%COOKIE_FILE%" ^
        %PLAYLIST% ^
        --ffmpeg-location "%FFMPEG_BIN%" ^
        -f "ba/b" ^
        --extract-audio ^
        --audio-format mp3 ^
        --audio-quality 0 ^
        --embed-metadata ^
        --embed-thumbnail ^
        --convert-thumbnails jpg ^
        --windows-filenames ^
        --paths "home:%OUTPUT_MUSIC%" ^
        --paths "temp:%TEMP_YTDLP%" ^
        -o "!MUSIC_OUTPUT!" ^
        -- "!URL!" 2>"%TEMP_YTDLP%\download_error.txt"

    set "RESULT=!ERRORLEVEL!"

    goto FINISH
)


REM ------------------------------------------------------------
REM COM COOKIES DO NAVEGADOR LOCAL
REM ------------------------------------------------------------

if /I "!COOKIE_MODE!"=="LOCAL" (

    "%YTDLP%" ^
        --cookies-from-browser "!LOCAL_BROWSER!" ^
        %PLAYLIST% ^
        --ffmpeg-location "%FFMPEG_BIN%" ^
        -f "ba/b" ^
        --extract-audio ^
        --audio-format mp3 ^
        --audio-quality 0 ^
        --embed-metadata ^
        --embed-thumbnail ^
        --convert-thumbnails jpg ^
        --windows-filenames ^
        --paths "home:%OUTPUT_MUSIC%" ^
        --paths "temp:%TEMP_YTDLP%" ^
        -o "!MUSIC_OUTPUT!" ^
        -- "!URL!" 2>"%TEMP_YTDLP%\download_error.txt"

    set "RESULT=!ERRORLEVEL!"

    goto CHECK_LOCAL_MUSIC_ERROR
)


REM ------------------------------------------------------------
REM SEM COOKIES
REM ------------------------------------------------------------

"%YTDLP%" ^
    %PLAYLIST% ^
    --ffmpeg-location "%FFMPEG_BIN%" ^
    -f "ba/b" ^
    --extract-audio ^
    --audio-format mp3 ^
    --audio-quality 0 ^
    --embed-metadata ^
    --embed-thumbnail ^
    --convert-thumbnails jpg ^
    --windows-filenames ^
    --paths "home:%OUTPUT_MUSIC%" ^
    --paths "temp:%TEMP_YTDLP%" ^
    -o "!MUSIC_OUTPUT!" ^
    -- "!URL!" 2>"%TEMP_YTDLP%\download_error.txt"

set "RESULT=!ERRORLEVEL!"

goto FINISH


:CHECK_LOCAL_MUSIC_ERROR

set "COOKIE_COPY_ERROR=0"
if exist "%TEMP_YTDLP%\download_error.txt" (
    findstr /I /C:"Could not copy Chrome cookie database" "%TEMP_YTDLP%\download_error.txt" >nul
    if not errorlevel 1 set "COOKIE_COPY_ERROR=1"
)

if /I "!COOKIE_MODE!"=="LOCAL" if "!RESULT!"=="1" if "!COOKIE_COPY_ERROR!"=="1" (
    echo.
    echo [AVISO] O navegador local falhou. Tentando sem cookies...
    echo.
    set "COOKIE_MODE=NONE"

    "%YTDLP%" ^
        %PLAYLIST% ^
        --ffmpeg-location "%FFMPEG_BIN%" ^
        -f "ba/b" ^
        --extract-audio ^
        --audio-format mp3 ^
        --audio-quality 0 ^
        --embed-metadata ^
        --embed-thumbnail ^
        --convert-thumbnails jpg ^
        --windows-filenames ^
        --paths "home:%OUTPUT_MUSIC%" ^
        --paths "temp:%TEMP_YTDLP%" ^
        -o "!MUSIC_OUTPUT!" ^
        -- "!URL!" 2>"%TEMP_YTDLP%\download_error.txt"

    set "RESULT=!ERRORLEVEL!"
)

goto FINISH


REM ============================================================
REM CANCELAR
REM ============================================================

:CANCEL

echo.
echo Operacao cancelada.
echo.

set "RESULT=2"

goto FINISH


REM ============================================================
REM FINALIZACAO
REM ============================================================

:FINISH

if exist "%TEMP_YTDLP%\download_error.txt" (
    type "%TEMP_YTDLP%\download_error.txt"
)

echo.
REM ============================================================
REM DIAGNOSTICO SOMENTE PARA INDISPONIBILIDADE DE FORMATO
REM ============================================================

if not "%RESULT%"=="0" if not "%RESULT%"=="2" if defined VIDEO_FORMAT (
    if exist "%TEMP_YTDLP%\download_error.txt" (
        findstr /I /C:"Requested format is not available" "%TEMP_YTDLP%\download_error.txt" >nul
        if not errorlevel 1 (
            echo.
            echo [DIAGNOSTICO] A falha indica indisponibilidade de formato.
            echo Consultando os formatos disponibilizados pelo YouTube...
            echo.
            "%YTDLP%" %PLAYLIST% --list-formats -- "!URL!" >"%TEMP_YTDLP%\available_formats.txt" 2>&1
            if exist "%TEMP_YTDLP%\available_formats.txt" type "%TEMP_YTDLP%\available_formats.txt"
            echo.
            echo [DIAGNOSTICO] Fim da lista de formatos.
            echo.
        )
    )
)

echo.
echo ============================================================

if "%RESULT%"=="0" (

    echo DOWNLOAD CONCLUIDO COM SUCESSO!

) else if "%RESULT%"=="2" (

    echo OPERACAO CANCELADA.

) else if /I "!OUTPUT_MODE!"=="PLAYLIST" (

    echo A PLAYLIST TERMINOU COM FALHAS EM UM OU MAIS ITENS.
    echo Os itens concluidos permanecem salvos na pasta de destino.
    echo Codigo: %RESULT%

) else (

    echo O DOWNLOAD TERMINOU COM ERRO.
    echo Codigo: %RESULT%

)

echo ============================================================
echo.


REM ============================================================
REM MOSTRA LOCAL DOS ARQUIVOS
REM ============================================================

echo Arquivos salvos em:

if /I "!OUTPUT_MODE!"=="PLAYLIST" (

    echo "%OUTPUT_ROOT%"

) else if /I "!CATEGORY!"=="Music" (

    echo "%OUTPUT_MUSIC%"

) else if /I "!CATEGORY!"=="Musica" (

    echo "%OUTPUT_MUSIC%"

) else if /I "!CATEGORY!"=="Música" (

    echo "%OUTPUT_MUSIC%"

) else (

    echo "%OUTPUT_VIDEO%"

)

echo.


REM ============================================================
REM LIMPA TEMPORARIOS
REM ============================================================

echo Removendo temporarios...

if exist "%TEMP_YTDLP%" (
    rmdir /S /Q "%TEMP_YTDLP%" >nul 2>&1
)

if exist "%TEMP_YTDLP%" (

    echo [AVISO] Alguns temporarios nao puderam ser removidos.

) else (

    echo [OK] Temporarios removidos.

)

echo.
echo ============================================================
echo.
pause

exit /b %RESULT%