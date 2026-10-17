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
REM - Tenta usar Brave Portable
REM - Fallback automatico sem cookies
REM - Detecta playlist pelo parametro "list="
REM - Permite playlist inteira ou video individual
REM - Detecta categoria
REM - Baixa musica como MP3
REM - Baixa videos como MKV
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

REM Brave Portable
set "BRAVE_ROOT=E:\Universal (Z)\Programas\brave-portable\app"
set "BRAVE_PROFILE=%BRAVE_ROOT%\data\Default"

REM Navegador local (Chrome / Edge / Chromium)
set "LOCAL_BROWSER="
if exist "%LOCALAPPDATA%\Google\Chrome\User Data\Default" set "LOCAL_BROWSER=chrome"
if not defined LOCAL_BROWSER if exist "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default" set "LOCAL_BROWSER=edge"
if not defined LOCAL_BROWSER if exist "%LOCALAPPDATA%\Chromium\User Data\Default" set "LOCAL_BROWSER=chromium"

REM Cookies alternativos
set "COOKIE_DIR=%BASE%cookies"
set "COOKIE_FILE=%COOKIE_DIR%\youtube.txt"

REM Documentos
set "DOCS=%USERPROFILE%\Documents"

REM Temporarios
set "TEMP_YTDLP=%DOCS%\yt-dlp-temp"

REM Saidas
REM Salva ao lado do script por padrao.
set "OUTPUT_ROOT=%BASE%"
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
                set "OUTPUT_ROOT=!ALT_DRIVE!\YT-DLP"
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

set /p "URL=Cole o link do YouTube: "

if not defined URL (
    echo.
    echo Nenhum link informado.
    echo.
    pause
    exit /b 1
)


REM ============================================================
REM CONFIGURA COOKIES
REM ============================================================

echo.
echo ============================================================
echo                    CONFIGURANDO COOKIES
echo ============================================================
echo.

set "COOKIE_MODE=NONE"

if exist "%COOKIE_FILE%" (

    echo [OK] Arquivo de cookies encontrado.
    echo.
    echo "%COOKIE_FILE%"
    echo.
    set "COOKIE_MODE=FILE"

) else if exist "%BRAVE_PROFILE%" (

    echo [OK] Brave Portable encontrado.
    echo.
    echo Perfil:
    echo "%BRAVE_PROFILE%"
    echo.
    echo O Brave sera usado para obter os cookies.
    echo.
    set "COOKIE_MODE=BRAVE"

) else (

    echo [AVISO] Nenhuma fonte de cookies encontrada.
    echo.
    echo O download continuara sem cookies.
    echo.

)


REM ============================================================
REM DETECTA PLAYLIST PELO LINK
REM ============================================================

echo ============================================================
echo                    ANALISANDO LINK
echo ============================================================
echo.

set "HAS_PLAYLIST=0"

echo !URL! | findstr /I /C:"list=" >nul

if not errorlevel 1 (
    set "HAS_PLAYLIST=1"
)

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
        "%URL%" >"%TEMP_YTDLP%\category.txt" 2>"%TEMP_YTDLP%\category_error.txt"

) else if /I "!COOKIE_MODE!"=="BRAVE" (

    "%YTDLP%" ^
        --cookies-from-browser "brave:%BRAVE_PROFILE%" ^
        --no-playlist ^
        --skip-download ^
        --no-warnings ^
        --print "%%(categories.0|)s" ^
        "%URL%" >"%TEMP_YTDLP%\category.txt" 2>"%TEMP_YTDLP%\category_error.txt"

) else if /I "!COOKIE_MODE!"=="LOCAL" (

    "%YTDLP%" ^
        --cookies-from-browser "!LOCAL_BROWSER!" ^
        --no-playlist ^
        --skip-download ^
        --no-warnings ^
        --print "%%(categories.0|)s" ^
        "%URL%" >"%TEMP_YTDLP%\category.txt" 2>"%TEMP_YTDLP%\category_error.txt"

) else (

    "%YTDLP%" ^
        --no-playlist ^
        --skip-download ^
        --no-warnings ^
        --print "%%(categories.0|)s" ^
        "%URL%" >"%TEMP_YTDLP%\category.txt" 2>"%TEMP_YTDLP%\category_error.txt"

)


REM ============================================================
REM VERIFICA ERRO DE COOKIES
REM ============================================================

if /I "!COOKIE_MODE!"=="BRAVE" (

    findstr /I /C:"Failed to decrypt with DPAPI" "%TEMP_YTDLP%\category_error.txt" >nul

    if not errorlevel 1 (

        echo.
        echo [AVISO] O Brave foi encontrado, mas o yt-dlp nao conseguiu
        echo descriptografar os cookies usando o DPAPI do Windows.
        echo.

        if defined LOCAL_BROWSER (
            echo [INFO] Tentando agora com o navegador local: !LOCAL_BROWSER!
            echo.
            set "COOKIE_MODE=LOCAL"

            "%YTDLP%" ^
                --cookies-from-browser "!LOCAL_BROWSER!" ^
                --no-playlist ^
                --skip-download ^
                --no-warnings ^
                --print "%%(categories.0|)s" ^
                "%URL%" >"%TEMP_YTDLP%\category.txt" 2>"%TEMP_YTDLP%\category_error.txt"
        ) else (
            echo O download continuara SEM cookies.
            echo.
            set "COOKIE_MODE=NONE"

            "%YTDLP%" ^
                --no-playlist ^
                --skip-download ^
                --no-warnings ^
                --print "%%(categories.0|)s" ^
                "%URL%" >"%TEMP_YTDLP%\category.txt" 2>"%TEMP_YTDLP%\category_error.txt"
        )
    )
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
    set "VIDEO_SUBTITLE_ARGS=--write-subs --write-auto-subs --sub-langs ""pt-BR,pt"" --sub-format ""srt/vtt/best"" --embed-subs"
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
    set "VIDEO_FORMAT=-f ""bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best"""
) else (
    set "VIDEO_FORMAT=-f ""bestvideo[ext=mp4][height<=!VIDEO_QUALITY!]+bestaudio[ext=m4a]/bestvideo[ext=mp4][height<=!VIDEO_QUALITY!]/bestvideo+bestaudio/best"""
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
            "%URL%"

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
            "%URL%"

    )

    set "RESULT=!ERRORLEVEL!"

    goto FINISH
)


REM ------------------------------------------------------------
REM COM COOKIES DO BRAVE
REM ------------------------------------------------------------

if /I "!COOKIE_MODE!"=="BRAVE" (

    if /I "!VIDEO_FINAL_FORMAT!"=="mp3" (

        "%YTDLP%" ^
            --cookies-from-browser "brave:%BRAVE_PROFILE%" ^
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
            "%URL%"

    ) else (

        "%YTDLP%" ^
            --cookies-from-browser "brave:%BRAVE_PROFILE%" ^
            %PLAYLIST% ^
            --ffmpeg-location "%FFMPEG_BIN%" ^
            !VIDEO_FORMAT! ^
            !VIDEO_SUBTITLE_ARGS! ^
            --merge-output-format !VIDEO_FINAL_FORMAT! ^
            --windows-filenames ^
            --paths "home:%OUTPUT_VIDEO%" ^
            --paths "temp:%TEMP_YTDLP%" ^
            -o "!VIDEO_OUTPUT!" ^
            "%URL%"

    )

    set "RESULT=!ERRORLEVEL!"

    goto CHECK_BRAVE_DOWNLOAD_ERROR
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
            "%URL%"

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
            "%URL%"

    )

    set "RESULT=!ERRORLEVEL!"

    goto CHECK_BRAVE_DOWNLOAD_ERROR
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
        "%URL%"

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
        "%URL%"

)

set "RESULT=!ERRORLEVEL!"

goto FINISH


REM ============================================================
REM VERIFICA ERRO DO BRAVE NO DOWNLOAD
REM ============================================================

:CHECK_BRAVE_DOWNLOAD_ERROR

if "!RESULT!"=="0" goto FINISH

if /I "!COOKIE_MODE!"=="BRAVE" (

    findstr /I /C:"Failed to decrypt with DPAPI" "%TEMP_YTDLP%\category_error.txt" >nul

    if not errorlevel 1 (

        echo.
        echo [AVISO] Falha de descriptografia DPAPI detectada.
        echo.

        if defined LOCAL_BROWSER (
            echo [INFO] Tentando novamente com o navegador local: !LOCAL_BROWSER!
            echo.
            set "COOKIE_MODE=LOCAL"

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
                    "%URL%"

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
                    "%URL%"

            )

            set "RESULT=!ERRORLEVEL!"
        ) else (
            echo Tentando novamente sem cookies...
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
                    "%URL%"

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
                    "%URL%"

            )

            set "RESULT=!ERRORLEVEL!"
        )
    )
)

if /I "!COOKIE_MODE!"=="LOCAL" if "!RESULT!"=="1" (
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
            "%URL%"

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
            "%URL%"

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
        "%URL%"

    set "RESULT=!ERRORLEVEL!"

    goto FINISH
)


REM ------------------------------------------------------------
REM COOKIES DO BRAVE
REM ------------------------------------------------------------

if /I "!COOKIE_MODE!"=="BRAVE" (

    "%YTDLP%" ^
        --cookies-from-browser "brave:%BRAVE_PROFILE%" ^
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
        "%URL%"

    set "RESULT=!ERRORLEVEL!"

    goto CHECK_BRAVE_MUSIC_ERROR
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
        "%URL%"

    set "RESULT=!ERRORLEVEL!"

    goto CHECK_BRAVE_MUSIC_ERROR
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
    "%URL%"

set "RESULT=!ERRORLEVEL!"

goto FINISH


REM ============================================================
REM VERIFICA ERRO DO BRAVE / LOCAL NO DOWNLOAD DE MUSICA
REM ============================================================

:CHECK_BRAVE_MUSIC_ERROR

if "!RESULT!"=="0" goto FINISH

if /I "!COOKIE_MODE!"=="BRAVE" (

    if defined LOCAL_BROWSER (
        echo.
        echo [AVISO] O Brave falhou ao usar cookies.
        echo [INFO] Tentando novamente com o navegador local: !LOCAL_BROWSER!
        echo.
        set "COOKIE_MODE=LOCAL"

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
            "%URL%"

        set "RESULT=!ERRORLEVEL!"
    ) else (
        echo.
        echo [AVISO] O Brave falhou. Tentando sem cookies...
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
            "%URL%"

        set "RESULT=!ERRORLEVEL!"
    )
)

if /I "!COOKIE_MODE!"=="LOCAL" if "!RESULT!"=="1" (
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
        "%URL%"

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

echo.
echo ============================================================

if "%RESULT%"=="0" (

    echo DOWNLOAD CONCLUIDO COM SUCESSO!

) else if "%RESULT%"=="2" (

    echo OPERACAO CANCELADA.

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