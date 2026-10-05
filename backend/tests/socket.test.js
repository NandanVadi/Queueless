const { createServer } = require('http');
const { Server } = require('socket.io');
const Client = require('socket.io-client');
const { initSocket, notifyQueueUpdated } = require('../src/socket');
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'queueless_secret_dev';

describe('Socket.IO Implementation', () => {
  let io, serverSocket, clientSocket;
  let port;

  beforeAll((done) => {
    const httpServer = createServer();
    io = initSocket(httpServer);
    httpServer.listen(() => {
      port = httpServer.address().port;
      done();
    });
  });

  afterAll(() => {
    io.close();
  });

  afterEach((done) => {
    if (clientSocket && clientSocket.connected) {
      clientSocket.disconnect();
    }
    done();
  });

  it('1. should connect with valid JWT', (done) => {
    const token = jwt.sign({ userId: 1 }, JWT_SECRET);
    clientSocket = new Client(`http://localhost:${port}`, {
      auth: { token },
      transports: ['websocket'],
    });

    clientSocket.on('connect', () => {
      expect(clientSocket.connected).toBe(true);
      done();
    });
  });

  it('2. should reject invalid JWT', (done) => {
    clientSocket = new Client(`http://localhost:${port}`, {
      auth: { token: 'invalid_token' },
      transports: ['websocket'],
    });

    clientSocket.on('connect_error', (err) => {
      expect(err.message).toBe('Authentication error: Invalid token');
      done();
    });
  });

  it('3. should reject unauthenticated socket', (done) => {
    clientSocket = new Client(`http://localhost:${port}`, {
      transports: ['websocket'],
    });

    clientSocket.on('connect_error', (err) => {
      expect(err.message).toBe('Authentication error: No token provided');
      done();
    });
  });

  it('4. & 8. authenticated socket receives queue update in service room', (done) => {
    const token = jwt.sign({ userId: 1 }, JWT_SECRET);
    clientSocket = new Client(`http://localhost:${port}`, {
      auth: { token },
      transports: ['websocket'],
    });

    clientSocket.on('connect', () => {
      // Join service room 1
      clientSocket.emit('join_service', 1);
      
      // Listen for queue update
      clientSocket.on('queue:updated', (data) => {
        expect(data.serviceId).toBe(1);
        done();
      });

      // Server emits update after a short delay to ensure client joined
      setTimeout(() => {
        notifyQueueUpdated(1);
      }, 50);
    });
  });

  it('9. no private user data leakage (event only sends serviceId)', (done) => {
    const token = jwt.sign({ userId: 2 }, JWT_SECRET);
    clientSocket = new Client(`http://localhost:${port}`, {
      auth: { token },
      transports: ['websocket'],
    });

    clientSocket.on('connect', () => {
      clientSocket.emit('join_service', 1);
      
      clientSocket.on('queue:updated', (data) => {
        expect(data).toHaveProperty('serviceId', 1);
        expect(data.tokenNumber).toBeUndefined(); // No private queue data
        expect(data.userId).toBeUndefined();
        done();
      });

      setTimeout(() => {
        notifyQueueUpdated(1);
      }, 50);
    });
  });
});
