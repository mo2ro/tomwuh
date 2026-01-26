const WS_URL = "wss://4d56834391b5.hbpkcjfv.workers.dev";
const HB_INT = 1000;
const OFFLINE_MS = 12000;

const PROTO = 1;
const PKT_HB = 1;
const PKT_OFFER = 2;
const PKT_ANSWER = 3;
const PKT_ICE = 4;

const XOR = new TextEncoder().encode("aESRE43efs"); // make this change later maybe

function xor(b) {
  const o = new Uint8Array(b.length);
  for (let i = 0; i < b.length; i++) o[i] = b[i] ^ XOR[i % XOR.length];
  return o;
}

async function deflate(b) {
  const cs = new CompressionStream("deflate");
  const w = cs.writable.getWriter();
  w.write(b);
  w.close();
  return new Uint8Array(await new Response(cs.readable).arrayBuffer());
}

async function inflate(b) {
  const ds = new DecompressionStream("deflate");
  const w = ds.writable.getWriter();
  w.write(b);
  w.close();
  return new Uint8Array(await new Response(ds.readable).arrayBuffer());
}

async function encStr(s) {
  return xor(await deflate(new TextEncoder().encode(s)));
}

async function decStr(b) {
  return new TextDecoder().decode(await inflate(xor(b)));
}

const now = () => Date.now();

function uidToBytes(u) {
  const h = u.replace(/-/g, "");
  return Uint8Array.from(h.match(/.{2}/g).map(x => parseInt(x, 16)));
}

function bytesToUid(b) {
  const h = [...b].map(x => x.toString(16).padStart(2, "0")).join("");
  return `${h.slice(0,8)}-${h.slice(8,12)}-${h.slice(12,16)}-${h.slice(16,20)}-${h.slice(20)}`;
}
let selfUID; 
let selfUIDBytes; 
const peers = new Map();
let ws;

function Net(uid){
  selfUID = uid || crypto.randomUUID();
  selfUIDBytes = uidToBytes(selfUID);
  ws = new WebSocket(WS_URL);
  ws.binaryType = "arraybuffer";
  
  
  ws.onopen = () => {
    sendHB();
    setInterval(sendHB, HB_INT);
    setInterval(checkOffline, 1000);
  };
  ws.onerror = ()=>{ws.error = true};
  
  ws.onmessage = async ev => {
    const buf = ev.data instanceof ArrayBuffer
      ? ev.data
      : await ev.data.arrayBuffer();
  
    const v = new DataView(buf);
    if (v.getUint8(0) !== PROTO) return;
  
    const t = v.getUint8(1);
  
    if (t === PKT_HB) {
      const uid = bytesToUid(new Uint8Array(buf.slice(2, 18)));
      if (uid === selfUID) return;
  
      const ts = now();
      let p = peers.get(uid);
      if (!p) {
        p = {
          uid,
          last: ts,
          state: "online",
          stateAt: ts,
          rtc: "idle",
          iceQ: []
        };
        peers.set(uid, p);
      } else {
        p.last = ts;
        if (p.state === "offline") {
          p.state = "online";
          p.stateAt = ts;
        }
      }
      return;
    }
  
    const from = bytesToUid(new Uint8Array(buf.slice(2, 18)));
    const to = bytesToUid(new Uint8Array(buf.slice(18, 34)));
    if (to !== selfUID) return;
  
    sigIn(t, from, new Uint8Array(buf.slice(34)));
  };
}
  function sendHB() {
    const b = new ArrayBuffer(18);
    const v = new DataView(b);
    v.setUint8(0, PROTO);
    v.setUint8(1, PKT_HB);
    new Uint8Array(b, 2).set(selfUIDBytes);
    ws.send(b);
    peers.forEach(p=>{if(p.pc ? p.pc.iceConnectionState=="failed" : false){p.pc.close();peers.delete(p.uid)}});
  }


 function mkPC(p) {
  const pc = new RTCPeerConnection({
   iceServers: [
     { urls: "stun:stun.l.google.com:19302" },
     { urls: "stun:stun1.l.google.com:19302" },
   ]
  });

  pc.onicecandidate = e => e.candidate && sendIce(p.uid, e.candidate);

  pc.onconnectionstatechange = () => {
    if (pc.connectionState === "connected") p.rtc = "connected";
    if (pc.connectionState === "disconnected" || pc.connectionState === "closed")
      p.rtc = "disconnected";
  };

  p.chan = pc.createDataChannel("demo");
  p.pc = pc;
  try { attachIceRecovery(p) } catch(e){;}
 }

async function makeOffer(p) {
  if (p.pc) return;

  p.wait = true;
  p.rtc = "offering";
  mkPC(p);

  const o = await p.pc.createOffer();
  await p.pc.setLocalDescription(o);

  sendSig(PKT_OFFER, p.uid, await encStr(o.sdp));
}

async function takeOffer(p, data) {
  if (p.pc) return;

  p.rtc = "answering";
  p.pc = new RTCPeerConnection({
   iceServers: [
     { urls: "stun:stun.l.google.com:19302" },
     { urls: "stun:stun1.l.google.com:19302" },
   ]
 });
  p.pc.ondatachannel = e => {p.chan = e.channel; p.rtc = "connected"}
  p.pc.onicecandidate = e => e.candidate && sendIce(p.uid, e.candidate);

  const sdp = await decStr(data);
  await p.pc.setRemoteDescription({ type: "offer", sdp });

  for (const c of p.iceQ) p.pc.addIceCandidate(c).catch(() => {});
  p.iceQ.length = 0;

  const a = await p.pc.createAnswer();
  await p.pc.setLocalDescription(a);

  sendSig(PKT_ANSWER, p.uid, await encStr(a.sdp));
}

async function sigIn(t, from, data) {
  const p = peers.get(from);
  if (!p) return;

  if (t === PKT_OFFER) {
    if (p.wait || p.rtc === "connected") return;
    p.offer = data;
  }

  if (t === PKT_ANSWER && p.pc) {
    const sdp = await decStr(data);
    await p.pc.setRemoteDescription({ type: "answer", sdp });
    p.wait = false;
    p.rtc = "connected";
  }

  if (t === PKT_ICE && p.pc) {
    const c = JSON.parse(await decStr(data));
    if (!p.pc.remoteDescription) p.iceQ.push(c);
    else p.pc.addIceCandidate(c).catch(() => {});
  }
}

function dropPeer(p) {
  p.pc?.close();
  p.pc = null;
  p.chan = null;
  p.offer = null;
  p.wait = false;
  p.rtc = "disconnected";
}

function sendSig(t, to, payload) {
  const b = new ArrayBuffer(34 + payload.length);
  const v = new DataView(b);

  v.setUint8(0, PROTO);
  v.setUint8(1, t);
  new Uint8Array(b, 2, 16).set(selfUIDBytes);
  new Uint8Array(b, 18, 16).set(uidToBytes(to));
  new Uint8Array(b, 34).set(payload);

  ws.send(b);
}

async function sendIce(to, c) {
  sendSig(PKT_ICE, to, await encStr(JSON.stringify(c)));
}

function checkOffline() {
  const t = now();
  for (const p of peers.values()) {
    if (p.state === "online" && t - p.last > OFFLINE_MS) {
      p.state = "offline";
      p.stateAt = t;
    }
  }
}
// export
// Object.assign({dropPeer, sigIn, takeOffer, makeOffer, mkPC, sendHB, ws, peers, selfUID, selfUIDBytes, bytesToUid, uidToBytes, now, decStr, encStr, PKT_ANSWER, PKT_HB, PKT_ICE, PKT_OFFER, PROTO, WS_URL, OFFLINE_MS, HB_INT}, globalThis)