const express = require('express');
const router = express.Router();
const controller = require('../controllers/services.controller');

router.get('/', controller.getServices);
router.get('/:id', controller.getServiceById);

module.exports = router;
