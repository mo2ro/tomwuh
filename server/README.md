# Relay Servers

There are two (tested) options for creating peer discovery relays for tomwuh:
 - Cloudflare (via workers)
 - Node.js

### Cloudflare workers:
if you aren't familar with the process of deploying a worker, a guide can be found [here](https://developers.cloudflare.com/workers/get-started/guide/). otherwise, continue as normal after cloning the repo or downloading the `server` folder:

```bash
cd ./server/cf
wrangler login # if not authenticated
wrangler deploy
```
**Notice:** when listing the websocket server in `net.js`, *there is no port number* after the URL; that seems to be the nature of serverless workers. Make sure to configure what exactly you want the deployment to be called/any other settings you would want to change in `wrangler.toml` before deploying.

### Node.js Websocket server:

The only dependency required by the server is `ws`.

(assuming in the repo directory):
```bash
cd ./server
npm init -y
npm i ws
node server.js [PORT]
```

The server will start by default on port 9121, but others can be specified.
