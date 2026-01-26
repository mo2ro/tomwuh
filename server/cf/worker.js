export class SignalingRoom {
  constructor(state) {
    this.state = state;
    this.sockets = new Set();
  }

  fetch(request) {
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("WebSocket only", { status: 400 });
    }

    const pair = new WebSocketPair();
    const client = pair[0];
    const server = pair[1];

    server.accept();
    this.sockets.add(server);

    server.addEventListener("message", evt => {
      for (const ws of this.sockets) {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(evt.data);
        }
      }
    });

    server.addEventListener("close", () => {
      this.sockets.delete(server);
    });

    server.addEventListener("error", () => {
      this.sockets.delete(server);
    });

    return new Response(null, {
      status: 101,
      webSocket: client
    });
  }
}

export default {
  fetch(request, env) {
    const id = env.ROOM.idFromName("default");
    const room = env.ROOM.get(id);
    return room.fetch(request);
  }
};
