const request = require('supertest');
const app = require('../src/app');
const prisma = require('../src/lib/prisma');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

describe('Operator Queue Endpoints', () => {
  let operatorToken, userToken, testService, testUser, testOperator;
  const JWT_SECRET = process.env.JWT_SECRET || 'queueless_secret_dev';

  beforeAll(async () => {
    // Clear data
    await prisma.queueToken.deleteMany({});
    await prisma.appointment.deleteMany({});
    await prisma.user.deleteMany({});
    await prisma.service.deleteMany({});

    // Create service
    testService = await prisma.service.create({
      data: { name: 'Op Service', description: 'Op test', icon: 'test', isActive: true }
    });

    const passwordHash = await bcrypt.hash('password123', 10);
    
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

  afterEach(async () => {
    await prisma.queueToken.deleteMany({});
  });

  it('should reject unauthenticated request', async () => {
    const res = await request(app).post(`/api/operator/queue/${testService.id}/next`);
    expect(res.statusCode).toBe(401);
  });

  it('should reject non-operator request', async () => {
    const res = await request(app)
      .post(`/api/operator/queue/${testService.id}/next`)
      .set('Authorization', `Bearer ${userToken}`);
    expect(res.statusCode).toBe(403);
  });

  it('should return 404 when calling next on an empty queue', async () => {
    const res = await request(app)
      .post(`/api/operator/queue/${testService.id}/next`)
      .set('Authorization', `Bearer ${operatorToken}`);
    expect(res.statusCode).toBe(404);
  });

  it('should correctly select the earliest waiting token and mark it serving', async () => {
    await prisma.queueToken.create({ data: { serviceId: testService.id, tokenNumber: 1, status: 'waiting', userId: testUser.id }});
    await prisma.queueToken.create({ data: { serviceId: testService.id, tokenNumber: 2, status: 'waiting', userId: testUser.id }});

    const res = await request(app)
      .post(`/api/operator/queue/${testService.id}/next`)
      .set('Authorization', `Bearer ${operatorToken}`);
    
    expect(res.statusCode).toBe(200);
    expect(res.body.queueToken.tokenNumber).toBe(1);
    expect(res.body.queueToken.status).toBe('serving');
    expect(res.body.queueToken.peopleAhead).toBe(0);
    expect(res.body.queueToken.currentTokenNumber).toBe(1);
  });

  it('should return 409 if trying to call next when there is already a serving token', async () => {
    await prisma.queueToken.create({ data: { serviceId: testService.id, tokenNumber: 1, status: 'serving', userId: testUser.id }});
    await prisma.queueToken.create({ data: { serviceId: testService.id, tokenNumber: 2, status: 'waiting', userId: testUser.id }});

    const res = await request(app)
      .post(`/api/operator/queue/${testService.id}/next`)
      .set('Authorization', `Bearer ${operatorToken}`);
    
    expect(res.statusCode).toBe(409);
    expect(res.body.error).toContain('A token is already currently being served');
  });

  it('should correctly complete a serving token', async () => {
    const token = await prisma.queueToken.create({ data: { serviceId: testService.id, tokenNumber: 1, status: 'serving', userId: testUser.id }});

    const res = await request(app)
      .post(`/api/operator/queue/${token.id}/complete`)
      .set('Authorization', `Bearer ${operatorToken}`);
    
    expect(res.statusCode).toBe(200);
    expect(res.body.queueToken.status).toBe('completed');
    expect(res.body.queueToken.isActive).toBe(false);
  });

  it('should reject completing a waiting token', async () => {
    const token = await prisma.queueToken.create({ data: { serviceId: testService.id, tokenNumber: 1, status: 'waiting', userId: testUser.id }});

    const res = await request(app)
      .post(`/api/operator/queue/${token.id}/complete`)
      .set('Authorization', `Bearer ${operatorToken}`);
    
    expect(res.statusCode).toBe(409); // 409 conflict
  });

  it('should reflect currentTokenNumber representing the actual serving token', async () => {
    await prisma.queueToken.create({ data: { serviceId: testService.id, tokenNumber: 1, status: 'serving', userId: testUser.id }});
    const waitingToken = await prisma.queueToken.create({ data: { serviceId: testService.id, tokenNumber: 2, status: 'waiting', userId: testUser.id }});

    const res = await request(app)
      .get(`/api/queue/${waitingToken.id}`)
      .set('Authorization', `Bearer ${userToken}`);
    
    expect(res.statusCode).toBe(200);
    expect(res.body.queueToken.currentTokenNumber).toBe(1);
    expect(res.body.queueToken.peopleAhead).toBe(0); // Serving token doesn't count
  });
});
