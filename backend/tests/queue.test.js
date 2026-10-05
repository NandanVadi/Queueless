const request = require('supertest');

// Mock auth middleware before app is required
jest.mock('../src/middleware/auth.middleware', () => {
  return (req, res, next) => {
    req.userId = 1;
    next();
  };
});

const app = require('../src/app');
const { mockDeep } = require('jest-mock-extended');

// Mock the prisma client
jest.mock('../src/lib/prisma', () => {
  const { mockDeep } = require('jest-mock-extended');
  return mockDeep();
});
const prismaMock = require('../src/lib/prisma');

describe('Queue API Endpoints', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('POST /api/queue', () => {
    it('should create a queue token when service exists', async () => {
      // Mock the service check
      prismaMock.service.findUnique.mockResolvedValue({
        id: 1,
        name: 'Test Service',
        isActive: true
      });

      // Mock the transaction
      prismaMock.$transaction.mockImplementation(async (callback) => {
        // mock tx object
        const tx = {
          queueToken: {
            findFirst: jest.fn().mockResolvedValue({ tokenNumber: 4 }),
            count: jest.fn().mockResolvedValue(2),
            create: jest.fn().mockImplementation(({ data }) => Promise.resolve({
              id: 1,
              ...data,
              createdAt: new Date().toISOString()
            }))
          }
        };
        return callback(tx);
      });

      const response = await request(app)
        .post('/api/queue')
        .send({ serviceId: 1 });
      
      expect(response.statusCode).toBe(201);
      expect(response.body).toHaveProperty('queueToken');
      expect(response.body.queueToken.tokenNumber).toBe(5);
      expect(response.body.queueToken.peopleAhead).toBe(2);
      expect(response.body.queueToken.currentTokenNumber).toBe(4);
      expect(response.body.queueToken.status).toBe('waiting');
      expect(prismaMock.$transaction).toHaveBeenCalled();
    });

    it('should return 400 if serviceId is missing', async () => {
      const response = await request(app).post('/api/queue').send({});
      expect(response.statusCode).toBe(400);
    });

    it('should return 404 if service does not exist', async () => {
      prismaMock.service.findUnique.mockResolvedValue(null);
      const response = await request(app).post('/api/queue').send({ serviceId: 999 });
      expect(response.statusCode).toBe(404);
    });
  });

  describe('GET /api/queue/active', () => {
    it('should return active tokens', async () => {
      prismaMock.queueToken.findMany.mockResolvedValue([
        { id: 1, serviceId: 1, tokenNumber: 5, isActive: true, status: 'waiting' }
      ]);
      prismaMock.queueToken.count.mockResolvedValue(4);
      prismaMock.queueToken.findFirst.mockResolvedValue({ tokenNumber: 1 });
      
      const response = await request(app).get('/api/queue/active');
      expect(response.statusCode).toBe(200);
      expect(response.body.queueTokens.length).toBe(1);
      expect(response.body.queueTokens[0].peopleAhead).toBe(4);
      expect(response.body.queueTokens[0].currentTokenNumber).toBe(1);
      expect(response.body.queueTokens[0].estimatedWaitTime).toBe(40);
    });
  });

  describe('GET /api/queue/:id', () => {
    it('should return token by id', async () => {
      prismaMock.queueToken.findUnique.mockResolvedValue({ 
        id: 1, serviceId: 1, tokenNumber: 5, status: 'waiting', isActive: true, userId: 1 
      });
      prismaMock.queueToken.count.mockResolvedValue(4);
      prismaMock.queueToken.findFirst.mockResolvedValue({ tokenNumber: 1 });

      const response = await request(app).get('/api/queue/1');
      expect(response.statusCode).toBe(200);
      expect(response.body.queueToken.id).toBe(1);
      expect(response.body.queueToken.peopleAhead).toBe(4);
      expect(response.body.queueToken.currentTokenNumber).toBe(1);
    });

    it('should return 404 if token not found', async () => {
      prismaMock.queueToken.findUnique.mockResolvedValue(null);
      const response = await request(app).get('/api/queue/999');
      expect(response.statusCode).toBe(404);
    });
  });

  describe('PATCH /api/queue/:id/cancel', () => {
    it('should cancel active token', async () => {
      prismaMock.queueToken.findUnique.mockResolvedValue({ id: 1, isActive: true, status: 'waiting', userId: 1 });
      prismaMock.queueToken.update.mockResolvedValue({ id: 1, isActive: false, status: 'cancelled', userId: 1 });

      const response = await request(app).patch('/api/queue/1/cancel');
      expect(response.statusCode).toBe(200);
      expect(response.body.queueToken.status).toBe('cancelled');
    });

    it('should handle already cancelled token gracefully', async () => {
      prismaMock.queueToken.findUnique.mockResolvedValue({ id: 1, isActive: false, status: 'cancelled', userId: 1 });
      const response = await request(app).patch('/api/queue/1/cancel');
      expect(response.statusCode).toBe(200);
      // Ensure update was not called
      expect(prismaMock.queueToken.update).not.toHaveBeenCalled();
    });
  });
});
