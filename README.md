# YT_DLP

Downloader para Windows baseado em **yt-dlp** e **FFmpeg**, com instalação local das ferramentas e execução por arquivo BAT.

## Recursos

- Download de vídeos e playlists do YouTube.
- Extração de áudio em MP3.
- Incorporação de metadados e miniaturas.
- Suporte a cookies de navegador ou arquivo.
- Processamento de links públicos do Spotify e Apple Music.
- Pesquisa individual das faixas no YouTube, com comparação de título, artista e duração.
- Relatório de faixas não encontradas ou que falharam no download.

## Links musicais

Cole no prompt inicial um link de faixa, álbum ou playlist do:

- Spotify: `open.spotify.com/track`, `/album` ou `/playlist`.
- Apple Music: `music.apple.com/.../song`, `/album` ou `/playlist`.

O programa lê os metadados públicos do link, cria uma pasta com o nome do álbum ou playlist e pesquisa cada faixa no YouTube. O áudio é obtido pelo **yt-dlp**, convertido para MP3 e salvo em ordem numerada.

As faixas sem correspondência confiável não são baixadas automaticamente. Ao final, o programa cria `relatorio-download.txt` na pasta da coleção com as faixas não encontradas ou que apresentaram erro.

### Dependências

O BAT instala/usa yt-dlp, FFmpeg e Deno localmente em `tools\\`. O módulo `Musicas.ts` é executado pelo Deno e não abre navegador para consultar os links musicais. Os cookies configurados no fluxo atual podem ser usados nas pesquisas e downloads do YouTube.

### Limitações atuais

- A integração de metadados contempla Spotify e Apple Music nesta versão.
- A leitura depende das páginas e endpoints públicos dos serviços, que podem mudar sem aviso.
- O Spotify pode limitar a quantidade de faixas expostas pelo conteúdo incorporado.
- O áudio é pesquisado no YouTube; a versão encontrada pode diferir da gravação original. O programa aplica uma pontuação de correspondência por título, artista e duração e ignora resultados com pontuação baixa.
- Deezer e outros serviços ainda não possuem adaptador nesta versão.

## Execução

Execute `YT-DLP.bat` e cole o link quando solicitado. Os arquivos são salvos na pasta de saída configurada pelo próprio programa.
