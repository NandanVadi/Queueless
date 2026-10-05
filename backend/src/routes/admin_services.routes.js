const express = require('express');
const router = express.Router();
const controller = require('../controllers/services.controller');

router.get('/', controller.getAllServicesForAdmin);
router.post('/', controller.createService);
router.patch('/:id', controller.updateService);
router.patch('/:id/status', controller.setServiceActive);

module.exports = router;
