const http = require('http');
const Client = require('socket.io-client');

const request = (options, bodyData) => {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ statusCode: res.statusCode, body: data ? JSON.parse(data) : {} }));
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
  
  // Register & Login User A
  let res = await request({ hostname: 'localhost', port: 3000, path: '/api/auth/register', method: 'POST', headers: { 'Content-Type': 'application/json' }}, { name: "User A", email: emailA, password: "password123" });
  res = await request({ hostname: 'localhost', port: 3000, path: '/api/auth/login', method: 'POST', headers: { 'Content-Type': 'application/json' }}, { email: emailA, password: "password123" });
  const tokenA = res.body.token;

  // Register & Login User B
  await request({ hostname: 'localhost', port: 3000, path: '/api/auth/register', method: 'POST', headers: { 'Content-Type': 'application/json' }}, { name: "User B", email: emailB, password: "password123" });
  res = await request({ hostname: 'localhost', port: 3000, path: '/api/auth/login', method: 'POST', headers: { 'Content-Type': 'application/json' }}, { email: emailB, password: "password123" });
  const tokenB = res.body.token;

  console.log("Registered both users.");

  // Connect both sockets
  const socketA = new Client(`http://localhost:3000`, { auth: { token: tokenA }, transports: ['websocket'] });
  const socketB = new Client(`http://localhost:3000`, { auth: { token: tokenB }, transports: ['websocket'] });

  socketA.on('connect', () => socketA.emit('join_service', 1));
  socketB.on('connect', () => socketB.emit('join_service', 1));

  await new Promise(r => setTimeout(r, 500));

  let aUpdates = 0;
  let bUpdates = 0;

  socketA.on('queue:updated', () => aUpdates++);
  socketB.on('queue:updated', () => bUpdates++);

  // 1. User A creates a token
  res = await request({ hostname: 'localhost', port: 3000, path: '/api/queue', method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${tokenA}` }}, { serviceId: 1 });
  const tokenAId = res.body.queueToken.id;
  console.log("User A token created:", res.body.queueToken.tokenNumber, "| People ahead:", res.body.queueToken.peopleAhead, "| Wait:", res.body.queueToken.estimatedWaitTime);

  await new Promise(r => setTimeout(r, 500));
  
  // Verify User A fetching their active queue
  res = await request({ hostname: 'localhost', port: 3000, path: '/api/queue/active', method: 'GET', headers: { 'Authorization': `Bearer ${tokenA}` }});
  let activeA = res.body.queueTokens[0];
  console.log("User A Active Queue -> People ahead:", activeA.peopleAhead, "Wait:", activeA.estimatedWaitTime);

  // 2. User B creates a token
  res = await request({ hostname: 'localhost', port: 3000, path: '/api/queue', method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${tokenB}` }}, { serviceId: 1 });
  const tokenBId = res.body.queueToken.id;
  console.log("User B token created:", res.body.queueToken.tokenNumber, "| People ahead:", res.body.queueToken.peopleAhead, "| Wait:", res.body.queueToken.estimatedWaitTime);

  await new Promise(r => setTimeout(r, 500));

  // User B cannot access User A's token
  res = await request({ hostname: 'localhost', port: 3000, path: `/api/queue/${tokenAId}`, method: 'GET', headers: { 'Authorization': `Bearer ${tokenB}` }});
  console.log("User B trying to access User A's token. Status:", res.statusCode); // Expect 403

  // 3. User A checks queue again
  res = await request({ hostname: 'localhost', port: 3000, path: '/api/queue/active', method: 'GET', headers: { 'Authorization': `Bearer ${tokenA}` }});
  activeA = res.body.queueTokens[0];
  console.log("User A Active Queue AFTER B -> People ahead:", activeA.peopleAhead, "Wait:", activeA.estimatedWaitTime);

  // 4. User A cancels token
  res = await request({ hostname: 'localhost', port: 3000, path: `/api/queue/${tokenAId}/cancel`, method: 'PATCH', headers: { 'Authorization': `Bearer ${tokenA}` }});
  console.log("User A cancels token. Status:", res.statusCode);

  await new Promise(r => setTimeout(r, 500));

  // 5. User B checks queue again
  res = await request({ hostname: 'localhost', port: 3000, path: '/api/queue/active', method: 'GET', headers: { 'Authorization': `Bearer ${tokenB}` }});
  let activeB = res.body.queueTokens[0];
  console.log("User B Active Queue AFTER A CANCELS -> People ahead:", activeB.peopleAhead, "Wait:", activeB.estimatedWaitTime);

  console.log("Socket A updates:", aUpdates, "Socket B updates:", bUpdates);

  socketA.disconnect();
  socketB.disconnect();
}
run();
