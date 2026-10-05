const prisma = require('../lib/prisma');

class QueueRepository {
  /**
   * Creates a new queue token for a given service.
   * Uses a transaction to ensure token numbering is deterministic and 
   * prevents race conditions if multiple users request a token concurrently.
   */
  async createToken(serviceId, userId) {
    return prisma.$transaction(async (tx) => {
      // 1. Find the highest existing token number for this service
      const maxToken = await tx.queueToken.findFirst({
        where: { serviceId },
        orderBy: { tokenNumber: 'desc' }
      });
      const nextTokenNumber = maxToken ? maxToken.tokenNumber + 1 : 1;

      // 2. Calculate wait time: active waiters currently in queue
      const activeWaiters = await tx.queueToken.count({
        where: {
          serviceId,
          isActive: true,
          status: 'waiting'
        }
      });
      const estimatedWaitTime = activeWaiters * 10;

      // 3. Create and return the new token
      const token = await tx.queueToken.create({
        data: {
          serviceId,
          tokenNumber: nextTokenNumber,
          status: 'waiting',
          isActive: true,
          estimatedWaitTime,
          userId
        },
        include: { service: true }
      });

      // 4. Determine current serving token
      const currentToken = await tx.queueToken.findFirst({
        where: { serviceId, isActive: true, status: 'serving' }
      });

      token.peopleAhead = activeWaiters;
      token.currentTokenNumber = currentToken ? currentToken.tokenNumber : null;
      return token;
    });
  }

  /**
   * Helper to attach dynamic queue intelligence to a token
   */
  async _attachQueueIntelligence(token) {
    const currentToken = await prisma.queueToken.findFirst({
      where: {
        serviceId: token.serviceId,
        isActive: true,
        status: 'serving'
      }
    });
    
    token.currentTokenNumber = currentToken ? currentToken.tokenNumber : null;

    if (!token || !token.isActive || (token.status !== 'waiting' && token.status !== 'serving')) {
      token.peopleAhead = 0;
      token.estimatedWaitTime = 0;
      return token;
    }

    if (token.status === 'serving') {
      token.peopleAhead = 0;
      token.estimatedWaitTime = 0;
      return token;
    }

    const peopleAhead = await prisma.queueToken.count({
      where: {
        serviceId: token.serviceId,
        isActive: true,
        status: 'waiting',
        tokenNumber: { lt: token.tokenNumber }
      }
    });

    token.peopleAhead = peopleAhead;
    token.estimatedWaitTime = peopleAhead * 10; // Dynamic wait time based on current people ahead

    return token;
  }

  async callNextToken(serviceId) {
    return prisma.$transaction(async (tx) => {
      // 1. Check if there is already a serving token for this service
      const existingServing = await tx.queueToken.findFirst({
        where: { serviceId, status: 'serving', isActive: true }
      });
      if (existingServing) {
        const error = new Error('A token is already currently being served for this service');
        error.statusCode = 409;
        throw error;
      }

      // 2. Find the earliest waiting token
      const nextToken = await tx.queueToken.findFirst({
        where: { serviceId, status: 'waiting', isActive: true },
        orderBy: { tokenNumber: 'asc' }
      });

      if (!nextToken) {
        const error = new Error('No waiting tokens in the queue');
        error.statusCode = 404;
        throw error;
      }

      // 3. Atomically update it to 'serving'
      const updated = await tx.queueToken.updateMany({
        where: { id: nextToken.id, status: 'waiting' },
        data: { status: 'serving' }
      });

      if (updated.count === 0) {
        const error = new Error('Token was already picked up or cancelled. Please try again.');
        error.statusCode = 409;
        throw error;
      }

      const finalToken = await tx.queueToken.findUnique({
        where: { id: nextToken.id },
        include: { service: true }
      });
      
      finalToken.peopleAhead = 0;
      finalToken.estimatedWaitTime = 0;
      finalToken.currentTokenNumber = finalToken.tokenNumber;
      return finalToken;
    });
  }

  async completeToken(id) {
    return prisma.$transaction(async (tx) => {
      const token = await tx.queueToken.findUnique({
        where: { id }
      });

      if (!token) {
        const error = new Error('Queue token not found');
        error.statusCode = 404;
        throw error;
      }

      if (token.status !== 'serving') {
        const error = new Error('Only serving tokens can be completed');
        error.statusCode = 409;
        throw error;
      }

      const updated = await tx.queueToken.update({
        where: { id },
        data: { status: 'completed', isActive: false },
        include: { service: true }
      });

      updated.peopleAhead = 0;
      updated.estimatedWaitTime = 0;
      updated.currentTokenNumber = null;
      return updated;
    });
  }

  /**
   * Retrieves all active queue tokens.
   */
  async findActiveTokens(userId) {
    const tokens = await prisma.queueToken.findMany({
      where: { isActive: true, userId },
      include: { 
        // Included so Flutter can display service info without N+1 queries
        service: true 
      },
      orderBy: { createdAt: 'asc' }
    });

    for (const token of tokens) {
      await this._attachQueueIntelligence(token);
    }

    return tokens;
  }

  /**
   * Retrieves all active queue tokens for a service (Operator view).
   */
  async getServiceQueue(serviceId) {
    return prisma.queueToken.findMany({
      where: { serviceId, isActive: true },
      orderBy: { tokenNumber: 'asc' },
      include: { service: true }
    });
  }

  /**
   * Retrieves a single queue token by ID.
   */
  async findById(id) {
    const token = await prisma.queueToken.findUnique({
      where: { id },
      include: { service: true }
    });
    
    if (token) {
      await this._attachQueueIntelligence(token);
    }
    
    return token;
  }

  /**
   * Updates an existing queue token.
   */
  async update(id, data) {
    const token = await prisma.queueToken.update({
      where: { id },
      data,
      include: { service: true }
    });
    
    if (token) {
      await this._attachQueueIntelligence(token);
    }
    
    return token;
  }
}

module.exports = new QueueRepository();
