const prisma = require('../src/lib/prisma');

beforeAll(async () => {
  try {
    const result = await prisma.$queryRaw`SELECT current_database() as db_name;`;
    const dbName = result[0].db_name;
    
    if (dbName !== 'queueless_test') {
      console.error(`ERROR: Refusing to run destructive tests against non-test database: ${dbName}`);
      process.exit(1);
    }
  } catch (error) {
    console.error('Failed to verify test database:', error);
    process.exit(1);
  }
});
