const appointmentService = require('../services/appointment.service');

const createAppointment = async (req, res) => {
  try {
    const appointment = await appointmentService.createAppointment(req.body, req.userId);
    res.status(201).json({ appointment });
  } catch (error) {
    console.error('Error creating appointment:', error);
    const statusCode = error.statusCode || 500;
    res.status(statusCode).json({ error: error.message || 'Internal Server Error' });
  }
};

const getAppointments = async (req, res) => {
  try {
    const appointments = await appointmentService.getAppointments(req.userId);
    res.status(200).json({ appointments });
  } catch (error) {
    console.error('Error fetching appointments:', error);
    const statusCode = error.statusCode || 500;
    res.status(statusCode).json({ error: error.message || 'Internal Server Error' });
  }
};

const getAppointmentById = async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (isNaN(id)) {
      return res.status(400).json({ error: 'Invalid appointment ID' });
    }
    const appointment = await appointmentService.getAppointmentById(id, req.userId);
    res.status(200).json({ appointment });
  } catch (error) {
    console.error(`Error fetching appointment ${req.params.id}:`, error);
    const statusCode = error.statusCode || 500;
    res.status(statusCode).json({ error: error.message || 'Internal Server Error' });
  }
};

const cancelAppointment = async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (isNaN(id)) {
      return res.status(400).json({ error: 'Invalid appointment ID' });
    }
    const appointment = await appointmentService.cancelAppointment(id, req.userId);
    res.status(200).json({ appointment });
  } catch (error) {
    console.error(`Error cancelling appointment ${req.params.id}:`, error);
    const statusCode = error.statusCode || 500;
    res.status(statusCode).json({ error: error.message || 'Internal Server Error' });
  }
};

module.exports = {
  createAppointment,
  getAppointments,
  getAppointmentById,
  cancelAppointment
};
