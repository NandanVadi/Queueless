const request = require('supertest');
const app = require('../src/app');
const prisma = require('../src/lib/prisma');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

describe('Admin Service Endpoints', () => {
  let adminToken, userToken, operatorToken, testAdmin, testUser, testOperator, testService;
  const JWT_SECRET = process.env.JWT_SECRET || 'queueless_secret_dev';

  beforeAll(async () => {
    // Clear data
    await prisma.queueToken.deleteMany({});
    await prisma.appointment.deleteMany({});
    await prisma.user.deleteMany({});
    await prisma.service.deleteMany({});

    const passwordHash = await bcrypt.hash('password123', 10);
    
    // Create Admin
    testAdmin = await prisma.user.create({
      data: { name: 'Admin', email: 'admin@test.com', passwordHash, role: 'admin' }
    });
    adminToken = jwt.sign({ userId: testAdmin.id }, JWT_SECRET);

    // Create Operator
    testOperator = await prisma.user.create({
      data: { name: 'Op', email: 'op@test.com', passwordHash, role: 'operator' }
    });
    operatorToken = jwt.sign({ userId: testOperator.id }, JWT_SECRET);

    // Create User
    testUser = await prisma.user.create({
      data: { name: 'User', email: 'user@test.com', passwordHash, role: 'user' }
    });
    userToken = jwt.sign({ userId: testUser.id }, JWT_SECRET);
  });

  afterAll(async () => {
    await prisma.queueToken.deleteMany({});
    await prisma.appointment.deleteMany({});
    await prisma.user.deleteMany({});
    await prisma.service.deleteMany({});
    await prisma.$disconnect();
  });

  describe('Authorization Tests', () => {
    it('unauthenticated user -> admin endpoint -> 401', async () => {
      const res = await request(app).get('/api/admin/services');
      expect(res.statusCode).toBe(401);
    });

    it('normal user -> admin endpoint -> 403', async () => {
      const res = await request(app)
        .get('/api/admin/services')
        .set('Authorization', `Bearer ${userToken}`);
      expect(res.statusCode).toBe(403);
    });

    it('operator -> admin endpoint -> 403', async () => {
      const res = await request(app)
        .get('/api/admin/services')
        .set('Authorization', `Bearer ${operatorToken}`);
      expect(res.statusCode).toBe(403);
    });

    it('normal user cannot create service', async () => {
      const res = await request(app)
        .post('/api/admin/services')
        .set('Authorization', `Bearer ${userToken}`)
        .send({ name: 'Test', description: 'Test', icon: 'test' });
      expect(res.statusCode).toBe(403);
    });

    it('operator cannot create service', async () => {
      const res = await request(app)
        .post('/api/admin/services')
        .set('Authorization', `Bearer ${operatorToken}`)
        .send({ name: 'Test', description: 'Test', icon: 'test' });
      expect(res.statusCode).toBe(403);
    });
  });

  describe('Service Business Rule Tests', () => {
    it('admin can create active service', async () => {
      const res = await request(app)
        .post('/api/admin/services')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ name: 'Medical', description: 'Doctor appt', icon: 'medical' });
      expect(res.statusCode).toBe(201);
      expect(res.body.service.name).toBe('Medical');
      expect(res.body.service.isActive).toBe(true);
      testService = res.body.service;
    });

    it('admin can edit service', async () => {
      const res = await request(app)
        .patch(`/api/admin/services/${testService.id}`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ description: 'Updated doctor appt' });
      expect(res.statusCode).toBe(200);
      expect(res.body.service.description).toBe('Updated doctor appt');
    });

    it('customer GET /api/services sees the active service', async () => {
      const res = await request(app).get('/api/services');
      expect(res.statusCode).toBe(200);
      const s = res.body.services.find(x => x.id === testService.id);
      expect(s).toBeDefined();
    });

    it('admin can deactivate service', async () => {
      const res = await request(app)
        .patch(`/api/admin/services/${testService.id}/status`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ isActive: false });
      expect(res.statusCode).toBe(200);
      expect(res.body.service.isActive).toBe(false);
    });

    it('inactive service does not appear in GET /api/services', async () => {
      const res = await request(app).get('/api/services');
      const s = res.body.services.find(x => x.id === testService.id);
      expect(s).toBeUndefined();
    });

    it('inactive service cannot create queue token', async () => {
      const res = await request(app)
        .post('/api/queue')
        .set('Authorization', `Bearer ${userToken}`)
        .send({ serviceId: testService.id });
      expect(res.statusCode).toBe(409);
    });

    it('inactive service cannot create appointment', async () => {
      const res = await request(app)
        .post('/api/appointments')
        .set('Authorization', `Bearer ${userToken}`)
        .send({ 
          serviceId: testService.id, 
          customerName: 'Test User',
          appointmentDate: '2027-01-01',
          appointmentTime: '10:00'
        });
      expect(res.statusCode).toBe(409);
    });

    it('admin can reactivate service', async () => {
      const res = await request(app)
        .patch(`/api/admin/services/${testService.id}/status`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ isActive: true });
      expect(res.statusCode).toBe(200);
      expect(res.body.service.isActive).toBe(true);
    });

    it('reactivated service can receive new queue token', async () => {
      const res = await request(app)
        .post('/api/queue')
        .set('Authorization', `Bearer ${userToken}`)
        .send({ serviceId: testService.id });
      expect(res.statusCode).toBe(201);
    });

    it('reactivated service can receive new appointment', async () => {
      const res = await request(app)
        .post('/api/appointments')
        .set('Authorization', `Bearer ${userToken}`)
        .send({ 
          serviceId: testService.id, 
          customerName: 'Test User',
          appointmentDate: '2027-01-02',
          appointmentTime: '11:00'
        });
      expect(res.statusCode).toBe(201);
    });
  });
});
