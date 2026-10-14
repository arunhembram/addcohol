const { WebSocketServer, WebSocket } = require('ws');

let wss = null;
const clients = new Set();

function initWebSocket(server) {
  wss = new WebSocketServer({ server });

  wss.on('connection', (ws, req) => {
    clients.add(ws);
    console.log(`[WS] Client connected. Total active clients: ${clients.size}`);

    ws.send(JSON.stringify({
      type: 'connected',
      message: 'Connected to AdProof Live Updates Hub',
      timestamp: new Date().toISOString()
    }));

    ws.on('close', () => {
      clients.delete(ws);
      console.log(`[WS] Client disconnected. Remaining: ${clients.size}`);
    });

    ws.on('error', (err) => {
      console.error('[WS] Client error:', err);
      clients.delete(ws);
    });
  });

  return wss;
}

/**
 * Broadcast an event to all connected clients (e.g. Owner Admin, Company Dashboard)
 */
function broadcast(eventType, payload) {
  if (!wss) return;
  const message = JSON.stringify({
    type: eventType,
    payload,
    timestamp: new Date().toISOString()
  });

  for (const client of clients) {
    if (client.readyState === WebSocket.OPEN) {
      try {
        client.send(message);
      } catch (err) {
        console.error('[WS] Send error:', err);
      }
    }
  }
}

module.exports = {
  initWebSocket,
  broadcast
};
