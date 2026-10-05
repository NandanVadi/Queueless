const request = require('supertest');
const app = require('../src/app');
const prisma = require('../src/lib/prisma');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

describe('Admin Dashboard Endpoints', () => {
  let adminToken, userToken, operatorToken, testAdmin, testUser, testOperator, testService;
  const JWT_SECRET = process.env.JWT_SECRET || 'queueless_secret_dev';

  beforeAll(async () => {
    // Clear data
    await prisma.queueToken.deleteMany({});
    await prisma.appointment.deleteMany({});
    await prisma.user.deleteMany({});
    await prisma.service.deleteMany({});

    const passwordHash = await bcrypt.hash('password123', 10);
    
    // Create Users
    testAdmin = await prisma.user.create({
      data: { name: 'Admin', email: 'admin_dash@test.com', passwordHash, role: 'admin' }
    });
    adminToken = jwt.sign({ userId: testAdmin.id }, JWT_SECRET);

    testOperator = await prisma.user.create({
      data: { name: 'Op', email: 'op_dash@test.com', passwordHash, role: 'operator' }
    });
    operatorToken = jwt.sign({ userId: testOperator.id }, JWT_SECRET);

    testUser = await prisma.user.create({
      data: { name: 'User', email: 'user_dash@test.com', passwordHash, role: 'user' }
    });
    userToken = jwt.sign({ userId: testUser.id }, JWT_SECRET);

    // Create Service
    testService = await prisma.service.create({
      data: { name: 'Test Service', description: 'Testing', icon: 'test', isActive: true }
    });
    
    // Create inactive service
    await prisma.service.create({
      data: { name: 'Inactive Service', description: 'Testing', icon: 'test', isActive: false }
    });

    // Create some data
    await prisma.queueToken.create({
      data: { serviceId: testService.id, tokenNumber: 1, status: 'waiting', isActive: true, userId: testUser.id }
    });
    await prisma.queueToken.create({
      data: { serviceId: testService.id, tokenNumber: 2, status: 'serving', isActive: true, userId: testUser.id }
    });
    await prisma.queueToken.create({
      data: { serviceId: testService.id, tokenNumber: 3, status: 'completed', isActive: false, userId: testUser.id }
    });
    await prisma.queueToken.create({
      data: { serviceId: testService.id, tokenNumber: 4, status: 'cancelled', isActive: false, userId: testUser.id }
    });

    await prisma.appointment.create({
      data: { serviceId: testService.id, customerName: 'X', appointmentDate: '2026-10-15', appointmentTime: '10:00', status: 'scheduled', userId: testUser.id }
    });
    await prisma.appointment.create({
      data: { serviceId: testService.id, customerName: 'Y', appointmentDate: '2026-10-15', appointmentTime: '11:00', status: 'completed', userId: testUser.id }
    });
  });

  afterAll(async () => {
    await prisma.queueToken.deleteMany({});
    await prisma.appointment.deleteMany({});
    await prisma.user.deleteMany({});
    await prisma.service.deleteMany({});
    await prisma.$disconnect();
  });

  describe('Authorization Tests', () => {
    it('unauthenticated request -> 401', async () => {
      const res = await request(app).get('/api/admin/dashboard');
      expect(res.statusCode).toBe(401);
    });

    it('standard user -> 403', async () => {
      const res = await request(app)
        .get('/api/admin/dashboard')
        .set('Authorization', `Bearer ${userToken}`);
      expect(res.statusCode).toBe(403);
    });

    it('operator -> 403', async () => {
      const res = await request(app)
        .get('/api/admin/dashboard')
        .set('Authorization', `Bearer ${operatorToken}`);
      expect(res.statusCode).toBe(403);
    });
  });

  describe('Dashboard Analytics', () => {
    it('admin -> success and valid structure', async () => {
      const res = await request(app)
        .get('/api/admin/dashboard')
        .set('Authorization', `Bearer ${adminToken}`);
      expect(res.statusCode).toBe(200);
      
      const dash = res.body.dashboard;
      expect(dash).toBeDefined();
      expect(dash.users).toBeDefined();
      expect(dash.queue).toBeDefined();
      expect(dash.appointments).toBeDefined();
      expect(dash.services).toBeDefined();

      // Users
      expect(dash.users.total).toBeGreaterThanOrEqual(3);
      expect(dash.users.operators).toBeGreaterThanOrEqual(1);
      expect(dash.users.admins).toBeGreaterThanOrEqual(1);

      // Queue
      expect(dash.queue.total).toBe(4);
      expect(dash.queue.today).toBe(4); // Created right now in beforeAll
      expect(dash.queue.waiting).toBe(1);
      expect(dash.queue.serving).toBe(1);
      expect(dash.queue.completed).toBe(1);
      expect(dash.queue.cancelled).toBe(1);

      // Appointments
      expect(dash.appointments.total).toBe(2);
      expect(dash.appointments.today).toBe(2);
      expect(dash.appointments.scheduled).toBe(1);
      expect(dash.appointments.completed).toBe(1);

      // Services
      expect(dash.services.length).toBe(2);
      const testServiceData = dash.services.find(s => s.id === testService.id);
      expect(testServiceData.currentServingToken).toBe(2);
      expect(testServiceData.peopleWaiting).toBe(1);
      expect(testServiceData.estimatedWaitTime).toBe(10);
      expect(testServiceData.queue.total).toBe(4);
      expect(testServiceData.appointments.total).toBe(2);
      
      const inactiveService = dash.services.find(s => s.name === 'Inactive Service');
      expect(inactiveService.isActive).toBe(false);
      expect(inactiveService.queue.total).toBe(0);
    });
  });
});
