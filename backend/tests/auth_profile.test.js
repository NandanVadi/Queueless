const request = require('supertest');
const app = require('../src/app');
const { mockDeep } = require('jest-mock-extended');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

jest.mock('../src/lib/prisma', () => {
  const { mockDeep } = require('jest-mock-extended');
  return mockDeep();
});
const prismaMock = require('../src/lib/prisma');

describe('Auth Profile & Password API', () => {
  const JWT_SECRET = process.env.JWT_SECRET || 'queueless_secret_dev';
  let userToken;
  let adminToken;
  let otherUserToken;

  const mockUser = {
    id: 1,
    name: 'Test User',
    email: 'testuser@test.com',
    passwordHash: 'hashedpassword',
    role: 'user'
  };

  const mockAdmin = {
    id: 2,
    name: 'Admin User',
    email: 'adminuser@test.com',
    passwordHash: 'hashedadmin',
    role: 'admin'
  };

  beforeAll(() => {
    userToken = jwt.sign({ userId: mockUser.id }, JWT_SECRET, { expiresIn: '1h' });
    adminToken = jwt.sign({ userId: mockAdmin.id }, JWT_SECRET, { expiresIn: '1h' });
    otherUserToken = jwt.sign({ userId: 3 }, JWT_SECRET, { expiresIn: '1h' });
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('PROFILE: GET /api/auth/me', () => {
    it('1. unauthenticated GET /me -> 401', async () => {
      const res = await request(app).get('/api/auth/me');
      expect(res.statusCode).toBe(401);
    });

    it('2. authenticated GET /me -> 200', async () => {
      prismaMock.user.findUnique.mockResolvedValue(mockUser);
      const res = await request(app)
        .get('/api/auth/me')
        .set('Authorization', `Bearer ${userToken}`);
      expect(res.statusCode).toBe(200);
      expect(res.body.user).toBeDefined();
      expect(res.body.user.email).toBe('testuser@test.com');
    });

    it('3. passwordHash never appears', async () => {
      prismaMock.user.findUnique.mockResolvedValue(mockUser);
      const res = await request(app)
        .get('/api/auth/me')
        .set('Authorization', `Bearer ${userToken}`);
      expect(res.body.user.passwordHash).toBeUndefined();
    });
  });

  describe('PROFILE: PATCH /api/auth/me', () => {
    it('4. authenticated user can update own name', async () => {
      prismaMock.user.update.mockResolvedValue({ ...mockUser, name: 'Updated Name' });
      const res = await request(app)
        .patch('/api/auth/me')
        .set('Authorization', `Bearer ${userToken}`)
        .send({ name: 'Updated Name' });
      expect(res.statusCode).toBe(200);
      expect(res.body.user.name).toBe('Updated Name');
    });

    it('5. empty name rejected', async () => {
      const res = await request(app)
        .patch('/api/auth/me')
        .set('Authorization', `Bearer ${userToken}`)
        .send({ name: '' });
      expect(res.statusCode).toBe(400);
    });

    it('6. whitespace-only name rejected', async () => {
      const res = await request(app)
        .patch('/api/auth/me')
        .set('Authorization', `Bearer ${userToken}`)
        .send({ name: '    ' });
      expect(res.statusCode).toBe(400);
    });

    it('7. user ID cannot be changed & 8. role cannot be changed', async () => {
      prismaMock.user.update.mockResolvedValue(mockUser);
      const res = await request(app)
        .patch('/api/auth/me')
        .set('Authorization', `Bearer ${userToken}`)
        .send({ name: 'Try ID Change', id: 9999, userId: 9999, role: 'admin' });
      expect(res.statusCode).toBe(200);
      // Service only updates `name`
      expect(prismaMock.user.update).toHaveBeenCalledWith({
        where: { id: 1 },
        data: { name: 'Try ID Change' }
      });
    });
  });

  describe('PASSWORD: PATCH /api/auth/me/password', () => {
    it('12. incorrect current password fails', async () => {
      prismaMock.user.findUnique.mockResolvedValue(mockUser);
      jest.spyOn(bcrypt, 'compare').mockResolvedValue(false);

      const res = await request(app)
        .patch('/api/auth/me/password')
        .set('Authorization', `Bearer ${userToken}`)
        .send({ currentPassword: 'wrongpassword', newPassword: 'newpassword123' });
      expect(res.statusCode).toBe(401);
    });

    it('17. invalid new password rejected', async () => {
      const res = await request(app)
        .patch('/api/auth/me/password')
        .set('Authorization', `Bearer ${userToken}`)
        .send({ currentPassword: 'password123', newPassword: '123' });
      expect(res.statusCode).toBe(400);
    });

    it('11. correct current password succeeds & 13. new password is bcrypt hashed & 14. no password returned', async () => {
      prismaMock.user.findUnique.mockResolvedValue(mockUser);
      jest.spyOn(bcrypt, 'compare').mockResolvedValue(true);
      jest.spyOn(bcrypt, 'hash').mockResolvedValue('newhash');
      prismaMock.user.update.mockResolvedValue({ ...mockUser, passwordHash: 'newhash' });

      const res = await request(app)
        .patch('/api/auth/me/password')
        .set('Authorization', `Bearer ${userToken}`)
        .send({ currentPassword: 'password123', newPassword: 'newpassword123' });
      expect(res.statusCode).toBe(200);
      
      expect(bcrypt.hash).toHaveBeenCalledWith('newpassword123', 10);
      expect(prismaMock.user.update).toHaveBeenCalledWith({
        where: { id: 1 },
        data: { passwordHash: 'newhash' }
      });

      expect(res.body.password).toBeUndefined();
      expect(res.body.newPassword).toBeUndefined();
      expect(res.body.message).toBe('Password updated successfully');
    });
  });
});
