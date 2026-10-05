const fs = require('fs');
const path = require('path');

const envTestPath = path.resolve(__dirname, '.env.test');
if (fs.existsSync(envTestPath)) {
  const content = fs.readFileSync(envTestPath, 'utf-8');
  const match = content.match(/TEST_DATABASE_URL="([^"]+)"/);
  if (match && match[1]) {
    process.env.DATABASE_URL = match[1];
  }
}

module.exports = {
  setupFilesAfterEnv: ['<rootDir>/tests/setup.js']
};
