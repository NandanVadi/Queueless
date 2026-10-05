const { PrismaClient } = require('@prisma/client');

// Prevent multiple instances of Prisma Client in development
// (especially useful if running with nodemon or in tests)
const prisma = global.prisma || new PrismaClient();

if (process.env.NODE_ENV !== 'production') {
  global.prisma = prisma;
}

module.exports = prisma;
