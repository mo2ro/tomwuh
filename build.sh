#!/usr/bin/env bash
sh source/compile.sh
set -eu

die() { echo "[fatal] $1" >&2; exit 1; }
log() { echo "[build] $1"; }

CONFIG="config.json"
NET_TEMPLATE="source/net.js"
CHAT_JS="source/chat.js"
LOGIN_HTML="source/login.html"
UI_SECTION="ui.section"
FONTS_DIR="fonts"
OUT_HTML="build/bundle.html"

[[ -f "$CONFIG" ]] || die "config.json not found"
[[ -f "$NET_TEMPLATE" ]] || die "net.template.js not found"
[[ -f "$CHAT_JS" ]] || die "chat.js not found"
[[ -f "$LOGIN_HTML" ]] || die "login.html not found"
[[ -f "$UI_SECTION" ]] || die "ui.section not found"

command -v jq >/dev/null || die "jq is required"
command -v node >/dev/null || die "node is required"

if ! command -v npx >/dev/null; then
  log "npx not found, installing…"
  npm install -g npx
fi

log "extracting config.json parameters"
RELAY_URL=$(jq -r '.RELAY_URL' "$CONFIG")
WS_KEY=$(jq -r '.WS_KEY' "$CONFIG")

[[ "$RELAY_URL" != "null" ]] || die "RELAY_URL missing"
[[ "$WS_KEY"   != "null" ]] || die "WS_KEY missing"

log "patching net.js"

TMP_NET="$(mktemp)"

awk -v relay="$RELAY_URL" -v key="$WS_KEY" '
NR==1 {
  sub(/const WS_URL = "[^"]*"/, "const WS_URL = \"" relay "\"")
  print; next
}
NR==11 {
  sub(/const XOR = new TextEncoder\(\)\.encode\("[^"]*"\)/,
      "const XOR = new TextEncoder().encode(\"" key "\")")
  print; next
}
{
  print
}
' "$NET_TEMPLATE" > "$TMP_NET"

# sed -n '1p;11p' "$TMP_NET"
log "minifying net.js"
NJS=$(npx terser "$TMP_NET" -c -m | base64 -w 0)
rm "$TMP_NET"
log "minifying chat.js"
CJS=$(npx terser "$CHAT_JS" -c -m | base64 -w 0)
log "minifying login.html"
LTM=$(sed \
  -e 's/<!--.*-->//g' \
  -e ':a;N;$!ba;s/\n//g' \
  -e 's/  \+/ /g' \
  "$LOGIN_HTML" | base64 -w 0)

UIA=$(sed ':a;N;$!ba;s/\n/ /g' "$UI_SECTION")
rm ui.section
log "processing fonts"
DWF=""

if [[ -d "$FONTS_DIR" ]]; then
  for f in "$FONTS_DIR"/*.woff; do
    [[ -f "$f" ]] || continue
    b64="$f.b64"

    if [[ ! -f "$b64" ]]; then
      log "encoding $(basename "$f")"
      base64 -w 0 "$f" > "$b64"
    fi

    if [[ "$(basename "$f")" == "Daydream.woff" ]]; then
      DWF=$(cat "$b64")
    fi
  done
fi

[[ -n "$DWF" ]] || die "Daydream.woff not found or not encoded"

log "writing out -> $OUT_HTML"

cat > "$OUT_HTML" <<EOF
<!DOCTYPE html>
<html>
    <head>
        <script>
        
window.PA = 'init'
_assets = [
   {"Daydream.woff": "$DWF"},
   {"net.js": "$NJS"},
   {"chat.js":"$CJS"}
]

function _bin64(base64, mime) {
  const binary = atob(base64);
  const len = binary.length;
  const bytes = new Uint8Array(len);

  for (let i = 0; i < len; i++) {
    bytes[i] = binary.charCodeAt(i);
  }

  return new Blob([bytes], { type: mime });
}

assets = [];
_assets.forEach(script=>{
   let type = Object.keys(script)[0].split('.').at(-1)
   if(type == 'js'){
     assets[Object.keys(script)[0]] = URL.createObjectURL(new Blob([atob(Object.values(script)[0])]));
   } else if(type == 'woff'){
      assets[Object.keys(script)[0]] = URL.createObjectURL(_bin64(Object.values(script)[0], 'font/woff'));
   }
})

function render(){
   if (PA=='init'){
      document.head.appendChild(Object.assign(document.createElement('style'), {innerText: "@font-face {font-family: 'daydream';src: url('"+assets['Daydream.woff']+"') format('woff');font-weight: normal;font-style: normal;}@keyframes bg {0% {background-position: 0px 0px;}100% {background-position: 0px 100px;}}body {margin-top: 13.5rem;background:repeating-conic-gradient(#ebc201 0 25%,#0d0adc 0 50%) 0 0/100px 100px;animation: bg 0.9s infinite;animation-timing-function: linear;}"}));
      let status = document.createElement('center');
      status.style = "font-family:Daydream;font-size:40px;color:white;";
      status.innerText = 'Loading...';
      document.body.appendChild(status);
      let scripts = Object.values(assets).slice(1)
      let flags = [];
      scripts.forEach(uri=>{let flag='_'+uri.split('-').at(-1);flags.push(flag);document.head.appendChild(Object.assign(document.createElement('script'), {src:uri})); Array.from(document.scripts).at(-1).onload = ()=>{globalThis[flag] = true;}})
      const check = () => {
         let count = 0
         flags.forEach(f=>{
            if(eval('window.'+f)){
              count += 1;
            }
         })
         status.innerText = \`Loading...(\${count}/\${scripts.length})\`
      }
      let ints = setInterval(()=>{if(status.innerText.includes(\`\${scripts.length}/\${scripts.length}\`)){clearInterval(ints);PA='login';setTimeout(render,200)}else{check();}}, 20)
   } else if (PA == 'login'){
      document.head.querySelector('style').remove();
      document.head.appendChild(Object.assign(document.createElement('style'), {innerText:"@font-face {  font-family: 'daydream';  src: url('"+assets['Daydream.woff']+"') format('opentype');  font-weight: normal;  font-style: normal;}@keyframes bg {  0% {    background-position: 0px 0px;  }  100% {    background-position: 0px 100px;  }}@media (max-width: 850px) {  img, svg{    display:none;  }}body {  margin-top: 13.5rem;  background:repeating-conic-gradient(#ebc201 0 25%,#0d0adc 0 50%) 0 0/100px 100px;  animation: bg 0.9s infinite;  animation-timing-function: linear;  height: 100vh;  margin: 0;  display: flex;  align-items: center;}h1 {  animation: spinny 2.2s infinite;  will-change: transform;  font-family:Daydream;  top:50px;  position: absolute;  left: 0;  right: 0;  margin: auto;  width: max-content;  font-size:50px;  color:white;}@keyframes spinny {  0% {    transform: rotate(-20deg);  }  50% {    transform: rotate(20deg);  }  100% {    transform: rotate(-20deg);  }}.c {  margin: auto;  width: 50%;  padding: 10px;}input {  width: 350px;  height:40px;  font-family:Daydream;  font-size:18px;  background-color:#0e0e0e;  color:grey;  outline:2px solid grey;  border-radius:20px;  padding-left:10px;}button {  position: absolute;  margin:auto;  left:0px;  right:0px;  top:80%;  width:240px;  height:60px;  padding:10px;  font-family: Daydream;  color:grey;  border:none;  background:#000;  outline: 2px solid grey;  font-size:21px;  transition: 0.07s;}button:hover{  transform: rotate(12deg) scale(1.12);  color:white;  outline: 2px solid white;}"}));  
      document.body.innerHTML = atob("$LTM");

 let sp = [
 "uhh",
 "ok",
 "actually nvm",
 "that's sooo gay dude",
 "they're here...",
 "you're gay arencha",
 "is it ME?",
 "yeah idk",
 ];
 document.querySelector("#svg_13").innerHTML = sp.at(
 Math.round(Math.random() * sp.length)
 );

   } else if(PA == 'app'){
       $UIA
   }
}
setTimeout(render, 200)
        </script>
    </head>
    <body></body>
</html>
EOF

log "operation complete"
