const WebSocket = require("ws");

const server = require("http").createServer();
const wss = new WebSocket.Server({ server });

const clients = new Set();

wss.on("connection", (ws) => {
  clients.add(ws);

  ws.on("message", (data) => {
    for (const client of clients) {
      if (client.readyState === WebSocket.OPEN) {
        client.send(data);
      }
    }
  });

  ws.on("close", () => {
    clients.delete(ws);
  });

  ws.on("error", () => {
    clients.delete(ws);
  });
});

server.listen(8080);
