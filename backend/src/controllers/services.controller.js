const serviceService = require('../services/service.service');

const getServices = async (req, res) => {
  try {
    const services = await serviceService.getActiveServices();
    res.status(200).json({ services });
  } catch (error) {
    console.error('Error fetching services:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
};

const getServiceById = async (req, res) => {
  try {
    const service = await serviceService.getServiceById(parseInt(req.params.id, 10));
    res.status(200).json({ service });
  } catch (error) {
    console.error(`Error fetching service ${req.params.id}:`, error);
    const statusCode = error.statusCode || 500;
    res.status(statusCode).json({ error: error.message || 'Internal Server Error' });
  }
};

const getAllServicesForAdmin = async (req, res) => {
  try {
    const services = await serviceService.getAllServices();
    res.status(200).json({ services });
  } catch (error) {
    console.error('Error fetching admin services:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
};

const createService = async (req, res) => {
  try {
    const service = await serviceService.createService(req.body);
    res.status(201).json({ service });
  } catch (error) {
    console.error('Error creating service:', error);
    const statusCode = error.statusCode || 500;
    res.status(statusCode).json({ error: error.message || 'Internal Server Error' });
  }
};

const updateService = async (req, res) => {
  try {
    const service = await serviceService.updateService(parseInt(req.params.id, 10), req.body);
    res.status(200).json({ service });
  } catch (error) {
    console.error(`Error updating service ${req.params.id}:`, error);
    const statusCode = error.statusCode || 500;
    res.status(statusCode).json({ error: error.message || 'Internal Server Error' });
  }
};

const setServiceActive = async (req, res) => {
  try {
    const service = await serviceService.setServiceActive(parseInt(req.params.id, 10), req.body.isActive);
    res.status(200).json({ service });
  } catch (error) {
    console.error(`Error updating service status ${req.params.id}:`, error);
    const statusCode = error.statusCode || 500;
    res.status(statusCode).json({ error: error.message || 'Internal Server Error' });
  }
};

module.exports = {
  getServices,
  getServiceById,
  getAllServicesForAdmin,
  createService,
  updateService,
  setServiceActive
};
