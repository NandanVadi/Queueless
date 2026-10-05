const express = require('express');
const router = express.Router();
const controller = require('../controllers/queue.controller');

router.post('/', controller.createQueueToken);
router.get('/active', controller.getActiveQueueTokens);
router.get('/:id', controller.getQueueTokenById);
router.patch('/:id/cancel', controller.cancelQueueToken);

module.exports = router;
