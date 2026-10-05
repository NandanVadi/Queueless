const express = require('express');
const router = express.Router();
const appointmentController = require('../controllers/appointment.controller');

// POST /api/appointments - Create a new appointment
router.post('/', appointmentController.createAppointment);

// GET /api/appointments - Get all appointments
router.get('/', appointmentController.getAppointments);

// GET /api/appointments/:id - Get appointment by ID
router.get('/:id', appointmentController.getAppointmentById);

// PATCH /api/appointments/:id/cancel - Cancel an appointment
router.patch('/:id/cancel', appointmentController.cancelAppointment);

module.exports = router;
