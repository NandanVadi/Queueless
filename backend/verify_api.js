const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const bcrypt = require('bcrypt');
// Using native fetch instead of axios

async function main() {
  try {
    const passwordHash = await bcrypt.hash('password123', 10);
    
    // Create users in DB
    const adminUser = await prisma.user.create({
      data: { name: 'Real Admin', email: `admin_${Date.now()}@test.com`, passwordHash, role: 'admin' }
    });
    const opUser = await prisma.user.create({
      data: { name: 'Real Op', email: `op_${Date.now()}@test.com`, passwordHash, role: 'operator' }
    });
    const normalUser = await prisma.user.create({
      data: { name: 'Real User', email: `user_${Date.now()}@test.com`, passwordHash, role: 'user' }
    });

    console.log('Users created');

    const login = async (email) => {
      const res = await fetch('http://localhost:3000/api/auth/login', { 
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password: 'password123' }) 
      });
      const data = await res.json();
      return data.token;
    };

    const adminToken = await login(adminUser.email);
    const opToken = await login(opUser.email);
    const userToken = await login(normalUser.email);

    // Verify 403s
    let res = await fetch('http://localhost:3000/api/admin/services', { headers: { Authorization: `Bearer ${userToken}` }});
    if (res.status !== 403) throw new Error('User should get 403');
    console.log('User got 403 on admin endpoint');

    res = await fetch('http://localhost:3000/api/admin/services', { headers: { Authorization: `Bearer ${opToken}` }});
    if (res.status !== 403) throw new Error('Operator should get 403');
    console.log('Operator got 403 on admin endpoint');

    // 1. Admin can create service
    res = await fetch('http://localhost:3000/api/admin/services', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${adminToken}` },
      body: JSON.stringify({ name: 'Live Testing Service', description: 'Testing', icon: 'hospital' })
    });
    let data = await res.json();
    let serviceId = data.service.id;
    console.log('1. Admin created service:', serviceId);

    // 2. Admin can edit service
    await fetch(`http://localhost:3000/api/admin/services/${serviceId}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${adminToken}` },
      body: JSON.stringify({ description: 'Updated testing' })
    });
    console.log('2. Admin edited service');

    // Customer creates a queue token while active to ensure history survives
    res = await fetch('http://localhost:3000/api/queue', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${userToken}` },
      body: JSON.stringify({ serviceId })
    });
    data = await res.json();
    let tokenId = data.queueToken.id;
    console.log('Created historical queue token:', tokenId);

    // 3. Admin can deactivate service
    await fetch(`http://localhost:3000/api/admin/services/${serviceId}/status`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${adminToken}` },
      body: JSON.stringify({ isActive: false })
    });
    console.log('3. Admin deactivated service');

    // 4. Customer GET /api/services no longer sees it
    res = await fetch('http://localhost:3000/api/services');
    data = await res.json();
    let found = data.services.find(s => s.id === serviceId);
    if (found) throw new Error('Customer saw inactive service');
    console.log('4. Customer GET /api/services no longer sees it');

    // 5. Customer cannot create queue token for inactive service
    res = await fetch('http://localhost:3000/api/queue', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${userToken}` },
      body: JSON.stringify({ serviceId })
    });
    if (res.status === 409) console.log('5. Customer cannot create queue token for inactive service (409)');
    else throw new Error(`Should not create queue for inactive, got ${res.status}`);

    // 6. Customer cannot create appointment for inactive service
    res = await fetch('http://localhost:3000/api/appointments', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${userToken}` },
      body: JSON.stringify({ serviceId, customerName: 'X', appointmentDate: '2027-01-01', appointmentTime: '10:00' })
    });
    if (res.status === 409) console.log('6. Customer cannot create appointment for inactive service (409)');
    else throw new Error(`Should not create appointment for inactive, got ${res.status}`);

    // 7. Admin reactivates service
    await fetch(`http://localhost:3000/api/admin/services/${serviceId}/status`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${adminToken}` },
      body: JSON.stringify({ isActive: true })
    });
    console.log('7. Admin reactivates service');

    // 8. Customer can then create queue token
    res = await fetch('http://localhost:3000/api/queue', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${userToken}` },
      body: JSON.stringify({ serviceId })
    });
    if (res.status === 201) console.log('8. Customer can then create queue token');
    else throw new Error('Failed to create queue token after reactivation');

    // 9. Existing historical records remain intact
    let historicalToken = await prisma.queueToken.findUnique({ where: { id: tokenId }});
    if (!historicalToken) throw new Error('Historical token was deleted!');
    console.log('9. Existing historical records remain intact');

    console.log('ALL REAL API VERIFICATIONS PASSED');

    // Milestone 20: Dashboard Analytics Verification
    console.log('\n--- MILESTONE 20 DASHBOARD VERIFICATION ---');
    
    // 1. Verify standard user receives 403
    const dashRes1 = await fetch('http://localhost:3000/api/admin/dashboard', {
      headers: { 'Authorization': `Bearer ${userToken}` }
    });
    if (dashRes1.status !== 403) throw new Error('Customer should get 403 on dashboard');
    console.log('Customer got 403 on dashboard');

    // 2. Verify operator receives 403
    const dashRes2 = await fetch('http://localhost:3000/api/admin/dashboard', {
      headers: { 'Authorization': `Bearer ${opToken}` }
    });
    if (dashRes2.status !== 403) throw new Error('Operator should get 403 on dashboard');
    console.log('Operator got 403 on dashboard');

    // 3. Verify admin receives 200
    const dashRes3 = await fetch('http://localhost:3000/api/admin/dashboard', {
      headers: { 'Authorization': `Bearer ${adminToken}` }
    });
    if (dashRes3.status !== 200) throw new Error('Admin should get 200 on dashboard, got ' + dashRes3.status);
    
    const dashboardData = await dashRes3.json();
    const dash = dashboardData.dashboard;
    console.log('Admin got 200 on dashboard');

    // 4. Verify against PostgreSQL
    const pgUsersTotal = await prisma.user.count();
    if (dash.users.total !== pgUsersTotal) throw new Error('Dashboard users.total mismatch');
    console.log('Dashboard users.total matches PostgreSQL:', dash.users.total);

    const pgQueueTotal = await prisma.queueToken.count();
    if (dash.queue.total !== pgQueueTotal) throw new Error('Dashboard queue.total mismatch');
    console.log('Dashboard queue.total matches PostgreSQL:', dash.queue.total);

    const pgApptTotal = await prisma.appointment.count();
    if (dash.appointments.total !== pgApptTotal) throw new Error('Dashboard appointments.total mismatch');
    console.log('Dashboard appointments.total matches PostgreSQL:', dash.appointments.total);

    console.log('ALL DASHBOARD VERIFICATIONS PASSED');
  } catch (err) {
    console.error('VERIFICATION FAILED:', err);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

main();
