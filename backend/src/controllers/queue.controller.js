const queueService = require('../services/queue.service');
const { notifyQueueUpdated } = require('../socket');

const createQueueToken = async (req, res) => {
  try {
    const { serviceId } = req.body;
    const token = await queueService.createQueueToken(serviceId, req.userId);
    notifyQueueUpdated(serviceId);
    res.status(201).json({ queueToken: token });
  } catch (error) {
    console.error('Error creating queue token:', error);
    const statusCode = error.statusCode || 500;
    res.status(statusCode).json({ error: error.message || 'Internal Server Error' });
  }
};

const getActiveQueueTokens = async (req, res) => {
  try {
    const tokens = await queueService.getActiveQueueTokens(req.userId);
    res.status(200).json({ queueTokens: tokens });
  } catch (error) {
    console.error('Error fetching active queue tokens:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
};

const getServiceQueue = async (req, res) => {
  try {
    const serviceId = parseInt(req.params.serviceId, 10);
    if (isNaN(serviceId)) {
      return res.status(400).json({ error: 'Invalid Service ID' });
    }
    const tokens = await queueService.getServiceQueue(serviceId);
    res.status(200).json({ queueTokens: tokens });
  } catch (error) {
    console.error(`Error fetching queue for service ${req.params.serviceId}:`, error);
    const statusCode = error.statusCode || 500;
    res.status(statusCode).json({ error: error.message || 'Internal Server Error' });
  }
};

const getQueueTokenById = async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (isNaN(id)) {
      return res.status(400).json({ error: 'Invalid ID' });
    }
    const token = await queueService.getQueueTokenById(id, req.userId);
    res.status(200).json({ queueToken: token });
  } catch (error) {
    console.error(`Error fetching queue token ${req.params.id}:`, error);
    const statusCode = error.statusCode || 500;
    res.status(statusCode).json({ error: error.message || 'Internal Server Error' });
  }
};

const cancelQueueToken = async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (isNaN(id)) {
      return res.status(400).json({ error: 'Invalid ID' });
    }
    const token = await queueService.cancelQueueToken(id, req.userId);
    notifyQueueUpdated(token.serviceId);
    res.status(200).json({ queueToken: token });
  } catch (error) {
    console.error(`Error cancelling queue token ${req.params.id}:`, error);
    const statusCode = error.statusCode || 500;
    res.status(statusCode).json({ error: error.message || 'Internal Server Error' });
  }
};

const callNextToken = async (req, res) => {
  try {
    const serviceId = parseInt(req.params.serviceId, 10);
    if (isNaN(serviceId)) {
      return res.status(400).json({ error: 'Invalid Service ID' });
    }
    const token = await queueService.callNextToken(serviceId);
    notifyQueueUpdated(serviceId);
    res.status(200).json({ queueToken: token });
  } catch (error) {
    console.error(`Error calling next token for service ${req.params.serviceId}:`, error);
    const statusCode = error.statusCode || 500;
    res.status(statusCode).json({ error: error.message || 'Internal Server Error' });
  }
};

const completeToken = async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (isNaN(id)) {
      return res.status(400).json({ error: 'Invalid Token ID' });
    }
    const token = await queueService.completeToken(id);
    notifyQueueUpdated(token.serviceId);
    res.status(200).json({ queueToken: token });
  } catch (error) {
    console.error(`Error completing token ${req.params.id}:`, error);
    const statusCode = error.statusCode || 500;
    res.status(statusCode).json({ error: error.message || 'Internal Server Error' });
  }
};

module.exports = {
  createQueueToken,
  getActiveQueueTokens,
  getServiceQueue,
  getQueueTokenById,
  cancelQueueToken,
  callNextToken,
  completeToken
};
