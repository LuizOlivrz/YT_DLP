# YT_DLP

Downloader para Windows baseado em **yt-dlp** e **FFmpeg**, com instalação local das ferramentas e execução por arquivo BAT.

## Recursos

- Download de vídeos e playlists do YouTube.
- Extração de áudio em MP3.
- Incorporação de metadados e miniaturas.
- Suporte a cookies de navegador ou arquivo.
- Processamento de links públicos do Spotify, Apple Music, Deezer e YouTube Music.
- Pesquisa individual das faixas no YouTube, com comparação de título, artista e duração.
- Relatório de faixas não encontradas ou que falharam no download.

## Links musicais

Cole no prompt inicial um link de faixa, álbum ou playlist do:

- Spotify: `open.spotify.com/track`, `/album` ou `/playlist`.
- Apple Music: `music.apple.com/.../song`, `/album` ou `/playlist`.
- Deezer: `deezer.com/track`, `/album` ou `/playlist`.
- YouTube Music: `music.youtube.com/watch` ou `music.youtube.com/playlist`.

O programa lê os metadados públicos do link, cria uma pasta com o nome do álbum ou playlist e pesquisa no YouTube as faixas do Spotify, Apple Music e Deezer. Para links do YouTube Music, obtém a lista pelo yt-dlp e baixa diretamente os vídeos/áudios correspondentes. O áudio é convertido para MP3 e salvo em ordem numerada.

A identificação do serviço também aparece colorida no terminal: Spotify em verde, YouTube e YouTube Music em vermelho, Deezer em roxo e Apple Music em vermelho/rosa.

As faixas sem correspondência confiável não são baixadas automaticamente. Ao final, o programa cria `relatorio-download.txt` na pasta da coleção com as faixas não encontradas ou que apresentaram erro.

### Dependências

O BAT instala/usa yt-dlp, FFmpeg e Deno localmente em `tools\`. O módulo `Musicas.ts` é executado pelo Deno e não abre navegador para consultar os links musicais. Os cookies configurados no fluxo atual podem ser usados nas pesquisas e downloads do YouTube.

### Limitações atuais

- A leitura de metadados contempla Spotify, Apple Music, Deezer e YouTube Music; os serviços podem alterar seus endpoints e formatos.
- A leitura depende das páginas e endpoints públicos dos serviços, que podem mudar sem aviso ou aplicar limites temporários de acesso.
- O Spotify pode limitar a quantidade de faixas expostas pelo conteúdo incorporado.
- O áudio é pesquisado no YouTube; a versão encontrada pode diferir da gravação original. O programa aplica uma pontuação de correspondência por título, artista e duração e ignora resultados com pontuação baixa.
- Outros serviços ainda não possuem adaptador nesta versão.

## Execução

Execute `YT-DLP.bat` e cole o link quando solicitado. Os arquivos são salvos na pasta de saída configurada pelo próprio programa.
