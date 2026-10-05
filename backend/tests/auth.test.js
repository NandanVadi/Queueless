const request = require('supertest');
const app = require('../src/app');
const { mockDeep } = require('jest-mock-extended');

jest.mock('../src/lib/prisma', () => {
  const { mockDeep } = require('jest-mock-extended');
  return mockDeep();
});
const prismaMock = require('../src/lib/prisma');
const bcrypt = require('bcrypt');

describe('Auth API Endpoints', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('POST /api/auth/register', () => {
    it('should register a new user successfully', async () => {
      prismaMock.user.findUnique.mockResolvedValue(null);
      prismaMock.user.create.mockResolvedValue({
        id: 1,
        name: 'Test User',
        email: 'test@example.com',
        passwordHash: 'hashedpassword'
      });

      const response = await request(app)
        .post('/api/auth/register')
        .send({
          name: 'Test User',
          email: 'test@example.com',
          password: 'password123'
        });

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('token');
      expect(response.body.user).toHaveProperty('name', 'Test User');
      expect(response.body.user).not.toHaveProperty('passwordHash');
    });

    it('should fail if email is already taken', async () => {
      prismaMock.user.findUnique.mockResolvedValue({ id: 1 });

      const response = await request(app)
        .post('/api/auth/register')
        .send({
          name: 'Test',
          email: 'test@example.com',
          password: 'password123'
        });

      expect(response.status).toBe(409);
    });
  });
});
