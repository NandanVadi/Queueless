const { PrismaClient } = require('@prisma/client');
const request = require('supertest');
const app = require('./src/app');
const bcrypt = require('bcrypt');

const prisma = new PrismaClient();

async function runOperatorTest() {
  console.log('--- STARTING OPERATOR INTEGRATION TEST ---');
  
  // 1. Clear the DB
  await prisma.queueToken.deleteMany({});
  await prisma.appointment.deleteMany({});
  await prisma.user.deleteMany({});
  await prisma.service.deleteMany({});

  // 2. Create a service
  const service = await prisma.service.create({
    data: { name: 'Op Service', description: 'Testing ops', icon: 'test', isActive: true }
  });
  console.log('Service created:', service.id);

  // 3. Create 3 users
  const pwdHash = await bcrypt.hash('password123', 10);
  const operator = await prisma.user.create({ data: { name: 'Operator', email: 'op@test.com', passwordHash: pwdHash, role: 'operator' }});
  const user1 = await prisma.user.create({ data: { name: 'User 1', email: 'u1@test.com', passwordHash: pwdHash, role: 'user' }});
  const user2 = await prisma.user.create({ data: { name: 'User 2', email: 'u2@test.com', passwordHash: pwdHash, role: 'user' }});

  // Login all 3 to get JWTs
  const loginOp = await request(app).post('/api/auth/login').send({ email: 'op@test.com', password: 'password123' });
  const opToken = loginOp.body.token;

  const loginU1 = await request(app).post('/api/auth/login').send({ email: 'u1@test.com', password: 'password123' });
  const u1Token = loginU1.body.token;

  const loginU2 = await request(app).post('/api/auth/login').send({ email: 'u2@test.com', password: 'password123' });
  const u2Token = loginU2.body.token;

  // 4. Normal user 1 gets a token
  let r = await request(app).post('/api/queue').set('Authorization', `Bearer ${u1Token}`).send({ serviceId: service.id });
  const token1 = r.body.queueToken;
  console.log('User 1 Token:', token1.tokenNumber, token1.status, 'PeopleAhead:', token1.peopleAhead);

  // 5. Normal user 2 gets a token
  r = await request(app).post('/api/queue').set('Authorization', `Bearer ${u2Token}`).send({ serviceId: service.id });
  const token2 = r.body.queueToken;
  console.log('User 2 Token:', token2.tokenNumber, token2.status, 'PeopleAhead:', token2.peopleAhead);

  if (token2.peopleAhead !== 1) throw new Error('User 2 peopleAhead should be 1');

  // 7. Operator calls callNextToken
  console.log('\\n[Operator] Calling next token...');
  r = await request(app).post(`/api/operator/queue/${service.id}/next`).set('Authorization', `Bearer ${opToken}`);
  console.log('Operator next token response:', r.body);

  if (r.body.queueToken.tokenNumber !== token1.tokenNumber) throw new Error('Operator should have called token 1');
  if (r.body.queueToken.status !== 'serving') throw new Error('Token 1 should be serving');

  // 8. Verify A2 is waiting with peopleAhead = 0
  r = await request(app).get(`/api/queue/${token2.id}`).set('Authorization', `Bearer ${u2Token}`);
  console.log('User 2 updated token state:', r.body.queueToken.status, 'PeopleAhead:', r.body.queueToken.peopleAhead, 'CurrentTokenNumber:', r.body.queueToken.currentTokenNumber);
  if (r.body.queueToken.peopleAhead !== 0) throw new Error('User 2 peopleAhead should be 0 because T1 is serving');
  if (r.body.queueToken.currentTokenNumber !== 1) throw new Error('Current serving token number should be 1');

  // 9. Operator calls callNextToken again (should fail)
  console.log('\\n[Operator] Calling next token AGAIN (should fail)...');
  r = await request(app).post(`/api/operator/queue/${service.id}/next`).set('Authorization', `Bearer ${opToken}`);
  console.log('Operator next token response (expect 409):', r.status, r.body);
  if (r.status !== 409) throw new Error('Expected 409 Conflict when a token is already serving');

  // 10. Operator completes token A1
  console.log('\\n[Operator] Completing token 1...');
  r = await request(app).post(`/api/operator/queue/${token1.id}/complete`).set('Authorization', `Bearer ${opToken}`);
  console.log('Operator complete token response:', r.body);
  if (r.body.queueToken.status !== 'completed') throw new Error('Token 1 should be completed');

  // 11. Verify A2 is still waiting
  r = await request(app).get(`/api/queue/${token2.id}`).set('Authorization', `Bearer ${u2Token}`);
  console.log('User 2 updated token state:', r.body.queueToken.status, 'PeopleAhead:', r.body.queueToken.peopleAhead, 'CurrentTokenNumber:', r.body.queueToken.currentTokenNumber);
  if (r.body.queueToken.currentTokenNumber !== null) throw new Error('Current serving token number should be null since no one is serving');

  // 12. Operator calls callNextToken again
  console.log('\\n[Operator] Calling next token again...');
  r = await request(app).post(`/api/operator/queue/${service.id}/next`).set('Authorization', `Bearer ${opToken}`);
  console.log('Operator next token response:', r.body);
  if (r.body.queueToken.tokenNumber !== token2.tokenNumber) throw new Error('Operator should have called token 2');

  console.log('\\n--- INTEGRATION TEST PASSED SUCCESSFULLY ---');
  process.exit(0);
}

runOperatorTest().catch(e => {
  console.error('TEST FAILED:', e);
  process.exit(1);
});
