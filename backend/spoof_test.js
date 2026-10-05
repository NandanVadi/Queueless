async function test() {
  const baseURL = 'http://localhost:3000/api';
  const suffix = Date.now();
  
  // Register a user
  let res = await fetch(`${baseURL}/auth/register`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name: 'Normal User', email: `normal${suffix}@test.com`, password: 'password123' }) });
  let data = await res.json();
  const userToken = data.token;
  const userId = data.user.id;

  // Register another user
  res = await fetch(`${baseURL}/auth/register`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name: 'Other User', email: `other${suffix}@test.com`, password: 'password123' }) });
  data = await res.json();
  const otherId = data.user.id;
  
  console.log('--- GET /auth/me ---');
  res = await fetch(`${baseURL}/auth/me`, { headers: { Authorization: `Bearer ${userToken}` }});
  console.log(await res.json());

  console.log('\n--- PATCH /auth/me (Spoof Attempt) ---');
  res = await fetch(`${baseURL}/auth/me`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${userToken}` },
    body: JSON.stringify({
      userId: otherId,
      id: otherId,
      role: 'admin',
      name: 'Spoofed Name'
    })
  });
  console.log('Response Status:', res.status);
  console.log('Response Data:', await res.json());

  console.log('\n--- Verify Target User Was NOT Changed ---');
  res = await fetch(`${baseURL}/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: `other${suffix}@test.com`, password: 'password123' }) });
  data = await res.json();
  console.log('Other user name:', data.user.name);

  console.log('\n--- Password Change (Incorrect Current) ---');
  res = await fetch(`${baseURL}/auth/me/password`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${userToken}` },
    body: JSON.stringify({ currentPassword: 'wrong', newPassword: 'newpassword123' })
  });
  console.log('Status:', res.status);

  console.log('\n--- Password Change (Correct Current) ---');
  res = await fetch(`${baseURL}/auth/me/password`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${userToken}` },
    body: JSON.stringify({ currentPassword: 'password123', newPassword: 'newpassword123' })
  });
  console.log('Status:', res.status);
  console.log('Response:', await res.json());

  console.log('\n--- Login with Old Password ---');
  res = await fetch(`${baseURL}/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: `normal${suffix}@test.com`, password: 'password123' }) });
  console.log('Status:', res.status);

  console.log('\n--- Login with New Password ---');
  res = await fetch(`${baseURL}/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: `normal${suffix}@test.com`, password: 'newpassword123' }) });
  console.log('Status:', res.status);
}
test().catch(console.error);
