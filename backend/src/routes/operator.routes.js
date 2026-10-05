const express = require('express');
const router = express.Router();
const controller = require('../controllers/queue.controller');
const authenticate = require('../middleware/auth.middleware');
const requireOperator = require('../middleware/operator.middleware');

router.use(authenticate);
router.use(requireOperator);

router.get('/queue/:serviceId', controller.getServiceQueue);
router.post('/queue/:serviceId/next', controller.callNextToken);
router.post('/queue/:id/complete', controller.completeToken);

module.exports = router;
