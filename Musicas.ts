// Integração de links musicais: Spotify, Apple Music, Deezer e YouTube Music.
// Sem navegador; pesquisa e download do áudio são feitos pelo yt-dlp.
export {};
const args=Deno.args;
function arg(n:string,d=""){const i=args.indexOf(n);return i<0?d:(args[i+1]??d);}
const url=arg("--url"),ytdlp=arg("--ytdlp"),ffmpeg=arg("--ffmpeg"),outputRoot=arg("--output"),tempRoot=arg("--temp");
const ua="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
type Track={title:string;artist:string;album:string;duration:number;number:number;year?:string;sourceUrl?:string;coverUrl?:string};
const sleep=(ms:number)=>new Promise(r=>setTimeout(r,ms));
function clean(s:string){return s.replace(/[<>:"/\\|?*\x00-\x1F]/g," ").replace(/[. ]+$/g,"").trim().slice(0,100)||"Playlist";}
function spotifyId(s:string){const m=s.match(/(?:https?:\/\/)?(?:open\.)?spotify\.com\/(?:intl-[a-z]{2}\/)?(track|album|playlist)\/([A-Za-z0-9]+)/i);return m?{kind:m[1].toLowerCase(),id:m[2]}:null;}
function appleUrl(s:string){try{const u=new URL(s);if(u.hostname.toLowerCase()!=="music.apple.com")return null;const p=u.pathname.split("/").filter(Boolean);const i=p.findIndex(x=>["playlist","album","song"].includes(x.toLowerCase()));if(i<1||!p[p.length-1])return null;const id=p[p.length-1];if(!/^[A-Za-z0-9.]+$/.test(id))return null;return{storefront:p[0].toLowerCase(),kind:p[i].toLowerCase(),id};}catch{return null;}}
async function getText(u:string,h:Record<string,string>={}){const r=await fetch(u,{headers:{"User-Agent":ua,...h},signal:AbortSignal.timeout(25000)});if(!r.ok)throw new Error("HTTP "+r.status+" ao consultar "+new URL(u).hostname);return await r.text();}
async function getJson(u:string,h:Record<string,string>={}){return JSON.parse(await getText(u,h));}
function spotifyEntity(p:any){const x=p?.props?.pageProps??{};return x?.state?.data?.entity??x?.entity??x?.data?.entity??null;}
function bestSpotifyImage(value:any):string{const sources=Array.isArray(value)?value:Array.isArray(value?.sources)?value.sources:[];const sorted=[...sources].filter((x:any)=>typeof x?.url==="string").sort((a:any,b:any)=>(Number(b.width||0)*Number(b.height||0))-(Number(a.width||0)*Number(a.height||0)));return String(sorted[0]?.url||"");}
function spotifyTrack(row:any,i:number,album="",albumCover=""):Track|null{const t=row?.track&&typeof row.track==="object"?{...row.track,subtitle:row.track.subtitle||row.subtitle}:row;const title=String(t?.name||t?.title||"").trim();if(!title)return null;let artists=Array.isArray(t?.artists)?t.artists.map((a:any)=>typeof a==="string"?a:String(a?.name||"")).filter(Boolean):[];if(!artists.length&&t?.subtitle)artists=[String(t.subtitle).trim()];const ms=Number(t?.duration??t?.duration_ms??0),albumData=t?.album??t?.albumOfTrack??{},cover=bestSpotifyImage(albumData?.images)||bestSpotifyImage(albumData?.coverArt)||bestSpotifyImage(t?.coverArt)||String(albumData?.images?.[0]?.url||albumData?.coverArt?.sources?.[0]?.url||t?.coverArt?.sources?.[0]?.url||albumCover);return{title,artist:artists.join(", "),album:String(albumData?.name||album),duration:ms>0?Math.round(ms/1000):0,number:Number(t?.trackNumber||t?.track_number||i+1),year:String(albumData?.release_date||albumData?.releaseDate||"").slice(0,4),coverUrl:cover};}
async function readSpotify(input:string){const ref=spotifyId(input);if(!ref)throw new Error("Link Spotify inválido.");const html=await getText("https://open.spotify.com/embed/"+ref.kind+"/"+ref.id,{"Accept-Language":"pt-BR,pt;q=0.9,en;q=0.8"});const m=html.match(/<script[^>]*id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/i);if(!m)throw new Error("Spotify não forneceu metadados públicos para este link.");const entity=spotifyEntity(JSON.parse(m[1]));if(!entity)throw new Error("Não foi possível interpretar os metadados do Spotify.");const name=String(entity.name||entity.title||"Spotify");let rows:any[]=Array.isArray(entity.trackList)?entity.trackList:[];if(!rows.length&&Array.isArray(entity.tracks?.items))rows=entity.tracks.items;if(ref.kind==="track")rows=[entity];const og=html.match(/<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)/i)||html.match(/<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i);const htmlCover=String(og?.[1]||"").replace(/&amp;/g,"&");const albumCover=bestSpotifyImage(entity?.coverArt)||bestSpotifyImage(entity?.images)||bestSpotifyImage(entity?.album?.images)||String(entity?.coverArt?.sources?.[0]?.url||entity?.images?.[0]?.url||htmlCover);const tracks=rows.map((x,i)=>spotifyTrack(x,i,ref.kind==="album"?name:"",albumCover)).filter((x):x is Track=>!!x);if(!tracks.length)throw new Error("Nenhuma faixa encontrada no conteúdo público do Spotify.");return{name,tracks};}
const APPLE_HEADER="eyJ0eXAiOiJKV1QiLCJhbGciOiJFUzI1NiIsImtpZCI6IldlYlBsYXlLaWQifQ";
async function appleToken(){const html=await getText("https://music.apple.com/us/browse");const b=html.match(/src="(\/assets\/index~[^"]+\.js)"/);if(!b)throw new Error("Pacote público do Apple Music não encontrado.");const js=await getText("https://music.apple.com"+b[1]);const t=js.match(new RegExp(APPLE_HEADER+"\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+"));if(!t)throw new Error("Token público do catálogo Apple Music não encontrado.");return t[0];}
function appleTrack(row:any,i:number):Track|null{const a=row?.attributes??{},title=String(a.name||"").trim();if(!title)return null;const ms=Number(a.durationInMillis||0);const artwork=String(a.artwork?.url||"").replaceAll("{w}","1000").replaceAll("{h}","1000").replaceAll("{f}","jpg");return{title,artist:String(a.artistName||""),album:String(a.albumName||""),duration:ms>0?Math.round(ms/1000):0,number:Number(a.trackNumber||i+1),year:String(a.releaseDate||"").slice(0,4),coverUrl:artwork};}
async function readApple(input:string){const ref=appleUrl(input);if(!ref)throw new Error("Link Apple Music inválido.");const token=await appleToken(),h={Authorization:"Bearer "+token,Origin:"https://music.apple.com",Referer:"https://music.apple.com/"};let endpoint="";if(ref.kind==="song")endpoint="https://amp-api.music.apple.com/v1/catalog/"+ref.storefront+"/songs/"+ref.id;else if(ref.kind==="album")endpoint="https://amp-api.music.apple.com/v1/catalog/"+ref.storefront+"/albums/"+ref.id+"/tracks?limit=100";else endpoint="https://amp-api.music.apple.com/v1/catalog/"+ref.storefront+"/playlists/"+ref.id+"/tracks?limit=100";let tracks:Track[]=[],name="Apple Music";if(ref.kind==="song"){const p=await getJson(endpoint,h),row=p?.data?.[0];name=String(row?.attributes?.albumName||row?.attributes?.name||name);const t=appleTrack(row,0);if(t)tracks.push(t);}else{let next:string|null=endpoint,page=0;while(next&&page++<100){const p=await getJson(next,h);for(const row of(Array.isArray(p?.data)?p.data:[])){const t=appleTrack(row,tracks.length);if(t)tracks.push(t);}const n=p?.next;next=typeof n==="string"?(n.startsWith("http")?n:"https://amp-api.music.apple.com"+n):null;}try{const p=await getJson("https://amp-api.music.apple.com/v1/catalog/"+ref.storefront+"/"+(ref.kind==="album"?"albums":"playlists")+"/"+ref.id,h);name=String(p?.data?.[0]?.attributes?.name||name);}catch{}if(ref.kind==="album")for(const t of tracks)if(!t.album)t.album=name;}if(!tracks.length)throw new Error("Nenhuma faixa encontrada no catálogo público do Apple Music.");return{name,tracks};}

function deezerUrl(s:string){try{const u=new URL(s);if(!/(^|\.)deezer\.com$/i.test(u.hostname))return null;const m=u.pathname.match(/\/(track|album|playlist)\/(\d+)/i);return m?{kind:m[1].toLowerCase(),id:m[2]}:null;}catch{return null;}}
function deezerTrack(row:any,i:number):Track|null{const title=String(row?.title||"").trim();if(!title)return null;return{title,artist:String(row?.artist?.name||""),album:String(row?.album?.title||""),duration:Number(row?.duration||0),number:Number(row?.track_position||i+1),year:String(row?.album?.release_date||row?.release_date||"").slice(0,4),coverUrl:String(row?.album?.cover_xl||row?.album?.cover_big||"")};}
async function readDeezer(input:string){const ref=deezerUrl(input);if(!ref)throw new Error("Link Deezer inválido.");let endpoint="https://api.deezer.com/"+(ref.kind==="track"?"track":ref.kind==="album"?"album":"playlist")+"/"+ref.id;const p=await getJson(endpoint);let name=String(p?.title||p?.album?.title||"Deezer"),rows:any[]=[];if(ref.kind==="track")rows=[p];else{let next=String(p?.tracks?.next||""),page=0;rows=Array.isArray(p?.tracks?.data)?p.tracks.data:[];if(!rows.length)next=endpoint+"/tracks?limit=100";while(next&&page++<100){const q=await getJson(next);rows.push(...(Array.isArray(q?.data)?q.data:[]));next=String(q?.next||"");}}const tracks=rows.map((x,i)=>deezerTrack(x,i)).filter((x):x is Track=>!!x);if(!tracks.length)throw new Error("Nenhuma faixa encontrada no Deezer.");return{name,tracks};}
function youtubeMusicUrl(s:string){try{const u=new URL(s);const host=u.hostname.toLowerCase();if(host!=="music.youtube.com")return null;const list=u.searchParams.get("list");const video=u.searchParams.get("v");const isPlaylist=/\/playlist/i.test(u.pathname)||(!video&&!!list);if(!isPlaylist&&!video)return null;return{kind:isPlaylist?"playlist":"track",url:s};}catch{return null;}}
async function readYoutubeMusic(input:string){const ref=youtubeMusicUrl(input);if(!ref)throw new Error("Link do YouTube Music inválido.");const cmd=ref.kind==="playlist"?["--dump-single-json","--flat-playlist","--no-warnings","--skip-download",input]:["--dump-single-json","--no-warnings","--skip-download",input];const result=await runYt(cmd,true);if(result.code!==0)throw new Error("Não foi possível ler o conteúdo do YouTube Music: "+result.out.slice(-500));let p:any;try{p=JSON.parse(result.out);}catch{throw new Error("O yt-dlp retornou metadados inválidos do YouTube Music.");}const rows=ref.kind==="playlist"?(Array.isArray(p?.entries)?p.entries:[]):[p];const tracks=rows.map((x:any,i:number)=>{const id=String(x?.id||"");const source=String(x?.webpage_url||(id?"https://www.youtube.com/watch?v="+id:"")||x?.url||"");const title=String(x?.title||"").trim();if(!title||!source)return null;return{title,artist:String(x?.artist||x?.uploader||x?.channel||""),album:String(x?.album||p?.title||""),duration:Number(x?.duration||0),number:Number(x?.playlist_index||i+1),sourceUrl:source} as Track;}).filter((x:Track|null):x is Track=>!!x);if(!tracks.length)throw new Error("Nenhuma faixa encontrada no link do YouTube Music.");return{name:String(p?.title||p?.playlist_title||"YouTube Music"),tracks};}
function norm(s:string){return s.normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLowerCase().replace(/[^a-z0-9]+/g," ").trim();}
function score(e:any,t:Track){const title=norm(String(e?.title||"")),artist=norm(String(e?.uploader||e?.channel||e?.artist||"")),wanted=norm(t.title),artistNames=t.artist.split(/,|&| feat\.? | ft\.? /i).map(norm).filter(x=>x.length>2);let n=title===wanted?10:(title.includes(wanted)||wanted.includes(title)?6:0);const matched=artistNames.filter(a=>artist.includes(a)||a.includes(artist));n+=artistNames.length?Math.min(6,matched.length*3):0;const d=Number(e?.duration||0);if(t.duration>0&&d>0){const delta=Math.abs(d-t.duration);n+=delta<=5?5:delta<=12?3:delta<=25?1:-8;}if(/\b(lyrics|lyric video|karaoke|nightcore|sped up|slowed|8d audio)\b/i.test(String(e?.title||"")))n-=3;return n;}
async function runYt(a:string[],capture=false){const command=new Deno.Command(ytdlp,{args:a,stdout:capture?"piped":"inherit",stderr:capture?"piped":"inherit"});if(capture){const r=await command.output();const out=new TextDecoder().decode(r.stdout);if(r.stderr.length)console.error(new TextDecoder().decode(r.stderr).trim());return{code:r.code,out};}const child=command.spawn();const status=await child.status;return{code:status.code,out:""};}
function localDownloadDate(){return new Intl.DateTimeFormat("pt-BR",{timeZone:"America/Sao_Paulo",day:"2-digit",month:"2-digit",year:"numeric"}).format(new Date()).replaceAll("/","-");}
function filePart(value:string){return value.replace(/[<>:"/\\|?*\x00-\x1F]/g," ").replace(/[. ]+$/g,"").trim().slice(0,90)||"Desconhecido";}
function lyricsScore(row:any,t:Track){const title=norm(String(row?.trackName||row?.name||"")),artist=norm(String(row?.artistName||"")),wantedTitle=norm(t.title),wantedArtists=t.artist.split(/,|&/).map(norm).filter(x=>x.length>2);if(!title||!artist||title!==wantedTitle)return-100;let score=10;if(artist===norm(t.artist)||wantedArtists.includes(artist))score+=10;else if(wantedArtists.some(a=>artist.includes(a)||a.includes(artist)))score+=6;else return-100;if(t.album&&row?.albumName){const a=norm(t.album),b=norm(String(row.albumName));score+=a===b?4:(a.includes(b)||b.includes(a)?2:-2);}const d=Number(row?.duration||0);if(t.duration>0&&d>0){const delta=Math.abs(d-t.duration);if(delta<=2)score+=5;else if(delta<=5)score+=2;else return-100;}return score;}
async function findLyrics(t:Track){if(!t.artist)return null;const base="https://lrclib.net/api/";const headers={"User-Agent":"YT-DLP Downloader/1.0 (https://github.com/LuizOlivrz/YT_DLP)"};const exact=new URLSearchParams({track_name:t.title,artist_name:t.artist});if(t.album)exact.set("album_name",t.album);if(t.duration>0&&t.duration<=3600)exact.set("duration",String(t.duration));try{const r=await fetch(base+"get?"+exact,{headers,signal:AbortSignal.timeout(20000)});if(r.ok){const row=await r.json();if(lyricsScore(row,t)>=16)return row;}else if(r.status!==404)console.log("  [AVISO] LRCLIB respondeu HTTP "+r.status+".");}catch(e){console.log("  [AVISO] Consulta exata ao LRCLIB falhou: "+String(e));}
  try{await sleep(300);const query=new URLSearchParams({track_name:t.title,artist_name:t.artist});if(t.album)query.set("album_name",t.album);const r=await fetch(base+"search?"+query,{headers,signal:AbortSignal.timeout(20000)});if(!r.ok){console.log("  [AVISO] Pesquisa LRCLIB respondeu HTTP "+r.status+".");return null;}const rows=await r.json();if(!Array.isArray(rows))return null;rows.sort((a:any,b:any)=>lyricsScore(b,t)-lyricsScore(a,t));const best=rows[0];return best&&lyricsScore(best,t)>=16?best:null;}catch(e){console.log("  [AVISO] Não foi possível consultar letras no LRCLIB: "+String(e));return null;}}
function lyricsText(row:any){const plain=String(row?.plainLyrics||"").trim();if(plain)return plain;const synced=String(row?.syncedLyrics||"").trim();return synced.replace(/^\s*\[(?:\d{2}:){1,2}\d{2}(?:[.:]\d{2,3})?\]\s*/gm,"").trim();}
async function prepareCover(url:string,path:string){
  if(!url)return null;
  try{
    const u=new URL(url);if(u.protocol!=="https:"&&u.protocol!=="http:")return null;
    const response=await fetch(u,{headers:{"User-Agent":ua},signal:AbortSignal.timeout(20000)});
    if(!response.ok)throw new Error("HTTP "+response.status);
    const source=path+".source";await Deno.writeFile(source,new Uint8Array(await response.arrayBuffer()));
    const exe=ffmpeg.replace(/[\\/]+$/,"")+"\\ffmpeg.exe";
    const result=await new Deno.Command(exe,{args:["-y","-i",source,"-vf","scale=600:600:force_original_aspect_ratio=increase,crop=600:600","-frames:v","1","-q:v","2",path],stdout:"null",stderr:"piped"}).output();
    try{await Deno.remove(source);}catch{}
    if(result.code!==0)throw new Error(new TextDecoder().decode(result.stderr).slice(-300));
    return path;
  }catch(e){console.log("  [AVISO] Não foi possível obter a capa do álbum: "+String(e));return null;}
}
async function tagMp3(path:string,t:Track,lyrics:string,coverPath:string|null=null){
  const exe=ffmpeg.replace(/[\\/]+$/,"")+"\\ffmpeg.exe",tmp=path+".tagged.mp3";
  const metadata=coverPath
    ?["-y","-i",path,"-i",coverPath,"-map","0:a:0","-map","1:v:0","-c:a","copy","-c:v","mjpeg","-disposition:v:0","attached_pic"]
    :["-y","-i",path,"-map","0","-c","copy"];
  metadata.push("-id3v2_version","3","-metadata","title="+t.title,"-metadata","artist="+t.artist,"-metadata","album="+t.album,"-metadata","album_artist="+t.artist,"-metadata","date="+(t.year||""),"-metadata","track="+String(t.number),"-metadata","lyrics="+lyrics,tmp);
  const command=new Deno.Command(exe,{args:metadata,stdout:"null",stderr:"piped"});const result=await command.output();
  if(result.code!==0){try{await Deno.remove(tmp);}catch{}throw new Error("FFmpeg não conseguiu incorporar as tags e a letra: "+new TextDecoder().decode(result.stderr).slice(-700));}
  await Deno.remove(path);await Deno.rename(tmp,path);
}
async function download(name:string,tracks:Track[]){
  const folder=outputRoot;await Deno.mkdir(folder,{recursive:true});await Deno.mkdir(tempRoot,{recursive:true});const failed:string[]=[];
  console.log("\nLista: "+name+"\nFaixas: "+tracks.length+"\nDestino: "+folder+"\n");
  for(let i=0;i<tracks.length;i++){
    const t=tracks[i],label=(t.artist?t.artist+" - ":"")+t.title;console.log("\n["+(i+1)+"/"+tracks.length+"] "+label);
    let video=String(t.sourceUrl||"");
    if(!video){
      const artistParts=t.artist.split(/,|&| feat\.? | ft\.? /i).map(x=>x.trim()).filter(Boolean);
      const queries=[(t.artist+" "+t.title).trim(),(t.title+" "+t.artist).trim(),...(artistParts.slice(0,3).map(a=>(a+" "+t.title).trim())),t.title].filter((q,i,a)=>q&&a.indexOf(q)===i);
      const found=new Map<string,any>();
      for(const query of queries){
        const musicSearch=new URL("https://music.youtube.com/search");
        musicSearch.searchParams.set("q",query);
        musicSearch.searchParams.set("sp","EgWKAQIIAWoKEAoQAxAEEAkQBQ==");
        let search;try{search=await runYt(["--dump-single-json","--flat-playlist","--no-warnings","--skip-download",musicSearch.toString()],true);}catch(e){console.log("  [AVISO] Pesquisa no YouTube Music falhou: "+String(e));continue;}
        if(search.code===0)try{const p=JSON.parse(search.out);for(const entry of(Array.isArray(p?.entries)?p.entries:[])){if(!entry)continue;const key=String(entry.id||entry.webpage_url||entry.url||"");if(key&&!found.has(key))found.set(key,entry);}}catch{}
        if([...found.values()].some((entry:any)=>score(entry,t)>=15))break;
      }
      const wanted=norm(t.title);const hasMusicMatch=[...found.values()].some((entry:any)=>{const title=norm(String(entry?.title||""));return score(entry,t)>=8&&(title===wanted||title.includes(wanted));});
      if(!hasMusicMatch){
        for(const query of queries){
          let search;try{search=await runYt(["--dump-single-json","--no-warnings","--skip-download","ytsearch20:"+query],true);}catch(e){console.log("  [AVISO] Pesquisa alternativa falhou: "+String(e));continue;}
          if(search.code!==0)continue;
          try{const p=JSON.parse(search.out);for(const entry of(Array.isArray(p?.entries)?p.entries:[])){if(!entry)continue;const key=String(entry.id||entry.webpage_url||entry.url||"");if(key&&!found.has(key))found.set(key,entry);}}catch{}
          if([...found.values()].some((entry:any)=>score(entry,t)>=15))break;
        }
      }
      const entries=[...found.values()];
      if(!entries.length){failed.push(label+": não encontrada");console.log("  [NÃO ENCONTRADA]");continue;}
      entries.sort((a:any,b:any)=>score(b,t)-score(a,t));const best=entries[0],s=score(best,t),bestTitle=norm(String(best?.title||"")),wantedTitle=norm(t.title),titleMatch=bestTitle===wantedTitle||bestTitle.includes(wantedTitle);
      video=String(best?.webpage_url||best?.url||(best?.id?"https://www.youtube.com/watch?v="+best.id:""));
      if(s<8||!titleMatch||!video){failed.push(label+": nenhum resultado confiável (melhor: "+String(best?.title||"sem título")+")");console.log("  [IGNORADA] Resultado não confiável.");continue;}
    }
    const date=localDownloadDate(),filename=filePart(t.title)+"-"+filePart(t.artist||"Artista desconhecido")+"_"+date,outputPath=folder+"\\"+filename+".mp3",template=filename+".%(ext)s";
    const downloadArgs=["--no-playlist","--ffmpeg-location",ffmpeg,"-f","bestaudio/best","--extract-audio","--audio-format","mp3","--audio-quality","0","--embed-metadata","--windows-filenames","--no-overwrites","--paths","home:"+folder,"--paths","temp:"+tempRoot];
    if(t.sourceUrl)downloadArgs.push("--embed-thumbnail","--convert-thumbnails","jpg");
    downloadArgs.push("-o",template,"--",video);
    let result;try{result=await runYt(downloadArgs,false);}catch(e){failed.push(label+": "+String(e));continue;}
    if(result.code!==0){failed.push(label+": erro no download (código "+result.code+")");continue;}
    try{
      const stat=await Deno.stat(outputPath);if(!stat.isFile)throw new Error("arquivo MP3 não encontrado no destino esperado.");
      console.log("  [OK] Áudio baixado na melhor qualidade disponível.");
      console.log("  Consultando letra no LRCLIB...");
      const lyricRecord=await findLyrics(t),lyric=lyricRecord?lyricsText(lyricRecord):"";
      const coverPath=t.sourceUrl?null:await prepareCover(t.coverUrl,tempRoot+"\\"+filePart(t.title)+".cover.jpg");
      if(lyric){await tagMp3(outputPath,t,lyric,coverPath);console.log("  [OK] Tags ID3 e letra incorporadas.");}
      else{await tagMp3(outputPath,t,"",coverPath);console.log("  [AVISO] Letra não encontrada com correspondência confiável; tags ID3 atualizadas.");}
      if(coverPath){try{await Deno.remove(coverPath);}catch{}console.log("  [OK] Capa quadrada do álbum incorporada.");}
      else if(t.sourceUrl)console.log("  [OK] Capa original do YouTube Music mantida no MP3.");
      else console.log("  [AVISO] Nenhuma capa de álbum disponível no serviço de origem.");
    }catch(e){failed.push(label+": pós-processamento: "+String(e));console.log("  [ERRO] "+String(e));}
    await sleep(350);
  }
  const report=["Relatório de download: "+name,"Total de faixas: "+tracks.length,"Falhas/não encontradas: "+failed.length,"",...failed.map(x=>"- "+x)].join("\r\n");
  await Deno.writeTextFile(folder+"\\relatorio-download.txt",report);console.log("\nRelatório salvo em: "+folder+"\\relatorio-download.txt");console.log("Concluído: "+(tracks.length-failed.length)+"/"+tracks.length+" faixas.");
}
async function main(){if(!url||!ytdlp||!outputRoot||!tempRoot)throw new Error("Parâmetros obrigatórios ausentes.");let data:{name:string;tracks:Track[]}|null=null;if(spotifyId(url)){data=await readSpotify(url);}else if(appleUrl(url)){data=await readApple(url);}else if(deezerUrl(url)){data=await readDeezer(url);}else if(youtubeMusicUrl(url)){data=await readYoutubeMusic(url);}else if(/(?:youtube\.com|youtu\.be)/i.test(new URL(url).hostname)){throw new Error("Links comuns do YouTube continuam sendo processados pelo fluxo principal do BAT.");}if(!data)throw new Error("Serviço não reconhecido. Suportados: Spotify, Apple Music, Deezer e YouTube Music.");await download(data.name,data.tracks);}
try{await main();}catch(e){console.error("\n[ERRO] "+(e instanceof Error?e.message:String(e)));Deno.exit(1);}
