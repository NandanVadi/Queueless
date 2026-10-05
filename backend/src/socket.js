const socketIo = require('socket.io');
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'queueless_secret_dev';

let io;

function initSocket(server) {
  io = socketIo(server, {
    cors: {
      origin: '*',
    },
  });

  // Authentication Middleware
  io.use((socket, next) => {
    try {
      const token = socket.handshake.auth?.token;
      if (!token) {
        return next(new Error('Authentication error: No token provided'));
      }
      
      const decoded = jwt.verify(token, JWT_SECRET);
      socket.userId = decoded.userId;
      next();
    } catch (err) {
      next(new Error('Authentication error: Invalid token'));
    }
  });

  io.on('connection', (socket) => {
    console.log(`Socket connected: ${socket.id} (User: ${socket.userId})`);

    // Client requests to join a service room
    socket.on('join_service', (serviceId) => {
      if (serviceId) {
        const roomName = `queue:service:${serviceId}`;
        socket.join(roomName);
        console.log(`User ${socket.userId} joined room ${roomName}`);
      }
    });

    // Client requests to leave a service room
    socket.on('leave_service', (serviceId) => {
      if (serviceId) {
        const roomName = `queue:service:${serviceId}`;
        socket.leave(roomName);
        console.log(`User ${socket.userId} left room ${roomName}`);
      }
    });

    socket.on('disconnect', () => {
      console.log(`Socket disconnected: ${socket.id}`);
    });
  });

  return io;
}

function getIo() {
  if (!io) {
    throw new Error('Socket.io is not initialized');
  }
  return io;
}

function notifyQueueUpdated(serviceId) {
  if (io && serviceId) {
    const roomName = `queue:service:${serviceId}`;
    io.to(roomName).emit('queue:updated', { serviceId });
  }
}

module.exports = {
  initSocket,
  getIo,
  notifyQueueUpdated,
};
