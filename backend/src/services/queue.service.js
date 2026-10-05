const queueRepository = require('../repositories/queue.repository');
const serviceRepository = require('../repositories/service.repository');

class QueueService {
  async createQueueToken(serviceId, userId) {
    if (!serviceId) {
      const error = new Error('serviceId is required');
      error.statusCode = 400;
      throw error;
    }

    // Since we don't have findById in service.repository.js yet, let's just 
    // rely on Prisma's foreign key constraint or add a quick check.
    // We can also fetch the service from prisma directly here, or add findById to serviceRepo.
    
    // For now, let's create the token. The repository transaction will fail if the serviceId doesn't exist,
    // but checking first is better for specific error messages.
    // The requirement says: "service must exist", "service must be active".
    // I'll implement those checks inside the queue service by importing the prisma client directly for the check,
    // or by adding a findById method to the service repository.
    
    const prisma = require('../lib/prisma');
    const service = await prisma.service.findUnique({ where: { id: serviceId } });
    
    if (!service) {
      const error = new Error('Service not found');
      error.statusCode = 404;
      throw error;
    }

    if (!service.isActive) {
      const error = new Error('Service is inactive');
      error.statusCode = 409;
      throw error;
    }

    return queueRepository.createToken(serviceId, userId);
  }

  async getActiveQueueTokens(userId) {
    return queueRepository.findActiveTokens(userId);
  }

  async getServiceQueue(serviceId) {
    if (!serviceId) {
      const error = new Error('serviceId is required');
      error.statusCode = 400;
      throw error;
    }
    return queueRepository.getServiceQueue(serviceId);
  }

  async getQueueTokenById(id, userId) {
    const token = await queueRepository.findById(id);
    if (!token) {
      const error = new Error('Queue token not found');
      error.statusCode = 404;
      throw error;
    }
    if (token.userId !== null && token.userId !== userId) {
      const error = new Error('Forbidden: You do not own this queue token');
      error.statusCode = 403;
      throw error;
    }
    return token;
  }

  async cancelQueueToken(id, userId) {
    const token = await queueRepository.findById(id);
    if (!token) {
      const error = new Error('Queue token not found');
      error.statusCode = 404;
      throw error;
    }

    if (token.userId !== null && token.userId !== userId) {
      const error = new Error('Forbidden: You do not own this queue token');
      error.statusCode = 403;
      throw error;
    }

    if (!token.isActive && token.status === 'cancelled') {
      // Gracefully handle already cancelled token
      return token;
    }

    return queueRepository.update(id, {
      status: 'cancelled',
      isActive: false
    });
  }

  async callNextToken(serviceId) {
    if (!serviceId) {
      const error = new Error('serviceId is required');
      error.statusCode = 400;
      throw error;
    }

    const prisma = require('../lib/prisma');
    const service = await prisma.service.findUnique({ where: { id: serviceId } });
    
    if (!service) {
      const error = new Error('Service not found');
      error.statusCode = 404;
      throw error;
    }

    return queueRepository.callNextToken(serviceId);
  }

  async completeToken(id) {
    return queueRepository.completeToken(id);
  }
}

module.exports = new QueueService();
