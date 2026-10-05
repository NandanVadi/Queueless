const prisma = require('../lib/prisma');

class AuthRepository {
  async createUser(data) {
    return prisma.user.create({
      data
    });
  }

  async findByEmail(email) {
    return prisma.user.findUnique({
      where: { email }
    });
  }

  async findById(id) {
    return prisma.user.findUnique({
      where: { id }
    });
  }

  async updateUser(id, data) {
    return prisma.user.update({
      where: { id },
      data
    });
  }
}

module.exports = new AuthRepository();
