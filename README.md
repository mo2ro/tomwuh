# tomwuh!!!
"instant" messaging thing
### what is ts
tomwuh (unregistered trademark) is a project for facilitating communication under more restricted using WebRTC and somewhat oversimplified relay servers. the [server software](/server) is used primarily for peer discovery and ICE, all communication between peers beyond that point is done end-to-end encrypted with AES over WebRTC.

### features
- send chats and files encrypted peer to peer
- decentralized user account registry builder
- message trust model[*](#s)
- typing indicator
- message replies
- mike 🤤
- [distributable](/build/bundle.html) as a single HTML file
- lightweight server software (for now...)
- automatic error recovery
- still being maintained idk

##
### I wanna use it!!
awesome sauce!! you'll need:
- something to run bash (once, for bootstrapper)
- a dedicated server (or just a cloudflare account)

once you have those, its pretty simple!!

first, you need to get a server up an running. you have two options: cloudflare workers or your own server. if your just using this for funsies, its best to just use a cloudflare worker: they're free, have pretty good uptime, and if the websocket servers exposed any important data (they don't...) it would still be secure. there are options to host your own server as well, which you need Node.js for. For this specifically, you don't need the latest version (tested on Nodejs 18+), but theres no harm in having it. unless there is. then don't get it.

for server installations, check that [readme](/server)

then, you need to build a copy of tomwuh with your server config.

```bash
git clone https://github.com/mo2ro/tomwuh
cd ./tomwuh
```
at this point, you just need to configure two things: 
- `RELAY_URL`: address your server is at in `ws(s)://[host]:[port]`
- `WS_KEY`: messages sent on the WebSocket server by the client (tomwuh) are encoded with this XOR key. as of version 0.0.2, it can not be left blank.

your `config.json` will look like
```JSON
{
  "RELAY_URL": "wss://xxxxxx.xxxxx.workers.dev", // alternatively your machine's IP
  "WS_KEY": "XXXXXXXXX"
}
```

after editing the config, you're ready to build!! just run `bash build.sh` and search for `bundle.html` in the `build` folder!

**As of version 0.0.2, you MUST use `bash`, *NOT* `sh`, to compile!!!**

### Ok i have it now!!!
tubular!!! you can start using it!!

here are some things you should keep in mind/known failures:
- sometimes buttons don't respond when you press them, make sure to wait at least 3 seconds between clicks if you choose to press it again. yes, even if it doesn't change color, it recieved the click. the buttons (erronous ones) are bound directly to `async` functions. this will be fixed in future versions
- firefox and edge ABSOLUTELY HATE tomwuh. This hatred is caused by the different WebRTC implementations that exist per browser, not *entirely* my fault. an interesting pattern emerges:

| Peer A  | Peer B  | Result |
| ------- | ------- | ------ |
| Firefox | Firefox | ~10% sucess rate, sucesses tend to be back to back|
| Chrome/Chrome-based | Firefox | ~50ish% sucess rate, also back to back|
| Chrome/Chrome-based| Chrome/Chrome-based| >90% success rate, only because I don't wanna say 99%|

Chrome <---> Chrome or Brave <---> Brave (and even Chrome <---> Brave) work very well/quickly during my tests, obviously results may differ. The initial WebRTC connection stage has several error handling features in place (specifically for firefox my beloved) to make sure failures aren't fatal.

- double click a message to reply to it, and press escape to cancel a reply
- typing indicators use static timers and can fail miserably if you spend a long time writing a message.
- <p id="s">users appear as a truncated version of their UID in the registry; this is to prevent the websocket relay from ever seeing usernames, even encoded, and prevents anyone but people you message from seeing them in the client. this is intentional and (probably) will not change in the future</p>
