const prisma = require('../lib/prisma');

class ServiceRepository {
  /**
   * Retrieves all services from the database ordered by name.
   */
  async findAll() {
    return prisma.service.findMany({
      orderBy: { name: 'asc' }
    });
  }

  /**
   * Retrieves all active services from the database ordered by name.
   */
  async findActive() {
    return prisma.service.findMany({
      where: { isActive: true },
      orderBy: { name: 'asc' }
    });
  }

  /**
   * Retrieves a single service by ID
   */
  async getServiceById(id) {
    return prisma.service.findUnique({
      where: { id }
    });
  }

  async create(data) {
    return prisma.service.create({
      data
    });
  }

  async update(id, data) {
    return prisma.service.update({
      where: { id },
      data
    });
  }

  async setStatus(id, isActive) {
    return prisma.service.update({
      where: { id },
      data: { isActive }
    });
  }
}

module.exports = new ServiceRepository();
