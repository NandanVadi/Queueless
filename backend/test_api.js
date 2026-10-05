const http = require('http');

const request = (options, bodyData) => {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ statusCode: res.statusCode, body: JSON.parse(data) }));
    });
    req.on('error', reject);
    if (bodyData) {
      req.write(JSON.stringify(bodyData));
    }
    req.end();
  });
};

async function run() {
  const emailA = `testA_${Date.now()}@example.com`;
  const emailB = `testB_${Date.now()}@example.com`;
  
  console.log("=== 3. REAL API AUTHENTICATION TEST ===");
  // Register User A
  let res = await request({
    hostname: 'localhost', port: 3000, path: '/api/auth/register', method: 'POST',
    headers: { 'Content-Type': 'application/json' }
  }, { name: "User A", email: emailA, password: "password123" });
  console.log("Register User A:", res.statusCode);
  
  // Login User A
  res = await request({
    hostname: 'localhost', port: 3000, path: '/api/auth/login', method: 'POST',
    headers: { 'Content-Type': 'application/json' }
  }, { email: emailA, password: "password123" });
  console.log("Login User A:", res.statusCode);
  const tokenA = res.body.token;
  
  // Me User A
  res = await request({
    hostname: 'localhost', port: 3000, path: '/api/auth/me', method: 'GET',
    headers: { 'Authorization': `Bearer ${tokenA}` }
  });
  console.log("Me User A:", res.statusCode, "PasswordHash absent:", !res.body.user.passwordHash);

  console.log("\n=== 4. REAL AUTHENTICATED QUEUE TEST ===");
  // Create Queue User A
  res = await request({
    hostname: 'localhost', port: 3000, path: '/api/queue', method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${tokenA}` }
  }, { serviceId: 1 });
  console.log("Create Queue Token:", res.statusCode);
  const queueTokenIdA = res.body.queueToken.id;
  console.log("Queue Token User ID exists:", !!res.body.queueToken.userId);

  // Cancel Queue User A
  res = await request({
    hostname: 'localhost', port: 3000, path: `/api/queue/${queueTokenIdA}/cancel`, method: 'PATCH',
    headers: { 'Authorization': `Bearer ${tokenA}` }
  });
  console.log("Cancel Queue Token:", res.statusCode);

  console.log("\n=== 5. REAL AUTHENTICATED APPOINTMENT TEST ===");
  // Create Appointment User A
  res = await request({
    hostname: 'localhost', port: 3000, path: '/api/appointments', method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${tokenA}` }
  }, { serviceId: 1, customerName: "User A", appointmentDate: "2026-12-31", appointmentTime: "10:00" });
  console.log("Create Appointment:", res.statusCode);
  const appointmentIdA = res.body.appointment.id;
  
  // Cancel Appointment User A
  res = await request({
    hostname: 'localhost', port: 3000, path: `/api/appointments/${appointmentIdA}/cancel`, method: 'PATCH',
    headers: { 'Authorization': `Bearer ${tokenA}` }
  });
  console.log("Cancel Appointment:", res.statusCode);

  console.log("\n=== 6. CROSS-USER AUTHORIZATION TEST ===");
  // Register & Login User B
  await request({
    hostname: 'localhost', port: 3000, path: '/api/auth/register', method: 'POST',
    headers: { 'Content-Type': 'application/json' }
  }, { name: "User B", email: emailB, password: "password123" });
  res = await request({
    hostname: 'localhost', port: 3000, path: '/api/auth/login', method: 'POST',
    headers: { 'Content-Type': 'application/json' }
  }, { email: emailB, password: "password123" });
  const tokenB = res.body.token;

  // Retrieve User A's queue token as User B
  res = await request({
    hostname: 'localhost', port: 3000, path: `/api/queue/${queueTokenIdA}`, method: 'GET',
    headers: { 'Authorization': `Bearer ${tokenB}` }
  });
  console.log("User B fetch User A's Queue Token:", res.statusCode);

  // Retrieve User A's appointment as User B
  res = await request({
    hostname: 'localhost', port: 3000, path: `/api/appointments/${appointmentIdA}`, method: 'GET',
    headers: { 'Authorization': `Bearer ${tokenB}` }
  });
  console.log("User B fetch User A's Appointment:", res.statusCode);

  console.log("\n=== 7. CLIENT userId SECURITY TEST ===");
  // Create Queue User A but supply User B ID
  res = await request({
    hostname: 'localhost', port: 3000, path: '/api/queue', method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${tokenA}` }
  }, { serviceId: 1, userId: 999999 });
  console.log("Spoof User ID Queue Token:", res.statusCode, "Assigned User ID:", res.body.queueToken.userId);
}
run();
