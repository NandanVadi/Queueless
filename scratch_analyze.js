const fs = require('fs');
const path = require('path');

function getFiles(dir, filesList = []) {
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const stat = fs.statSync(path.join(dir, file));
    if (stat.isDirectory()) {
      if (!['node_modules', 'build', '.dart_tool', '.git'].includes(file)) {
        getFiles(path.join(dir, file), filesList);
      }
    } else {
      filesList.push(path.join(dir, file));
    }
  }
  return filesList;
}

const libFiles = getFiles('lib');
const backendFiles = getFiles('backend/src');
const testFiles = getFiles('test');

function categorize(files) {
  const counts = { Auth: 0, Queue: 0, Appointments: 0, QR: 0, Services: 0, AdminOperator: 0, Core: 0 };
  for (const f of files) {
    if (f.includes('auth') || f.includes('login') || f.includes('register') || f.includes('profile') || f.includes('password') || f.includes('user')) counts.Auth++;
    else if (f.includes('queue') || f.includes('token')) counts.Queue++;
    else if (f.includes('appointment')) counts.Appointments++;
    else if (f.includes('qr')) counts.QR++;
    else if (f.includes('service')) counts.Services++;
    else if (f.includes('admin') || f.includes('operator') || f.includes('dashboard')) counts.AdminOperator++;
    else counts.Core++;
  }
  return counts;
}

console.log("Lib:", categorize(libFiles));
console.log("Backend:", categorize(backendFiles));
console.log("Test:", categorize(testFiles));
