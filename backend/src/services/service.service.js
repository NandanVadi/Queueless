const repository = require('../repositories/service.repository');

class ServiceService {
  /**
   * Retrieves all services.
   */
  async getActiveServices() {
    return repository.findActive();
  }

  async getAllServices() {
    return repository.findAll();
  }

  async getServiceById(id) {
    const service = await repository.getServiceById(id);
    if (!service) {
      const error = new Error('Service not found');
      error.statusCode = 404;
      throw error;
    }
    return service;
  }

  async createService(data) {
    if (!data.name || !data.name.trim()) throw Object.assign(new Error('name is required'), { statusCode: 400 });
    if (!data.description || !data.description.trim()) throw Object.assign(new Error('description is required'), { statusCode: 400 });
    if (!data.icon || !data.icon.trim()) throw Object.assign(new Error('icon is required'), { statusCode: 400 });

    return repository.create({
      name: data.name.trim(),
      description: data.description.trim(),
      icon: data.icon.trim(),
      isActive: true
    });
  }

  async updateService(id, data) {
    const service = await repository.getServiceById(id);
    if (!service) {
      throw Object.assign(new Error('Service not found'), { statusCode: 404 });
    }

    const updateData = {};
    if (data.name && data.name.trim()) updateData.name = data.name.trim();
    if (data.description && data.description.trim()) updateData.description = data.description.trim();
    if (data.icon && data.icon.trim()) updateData.icon = data.icon.trim();

    return repository.update(id, updateData);
  }

  async setServiceActive(id, isActive) {
    if (typeof isActive !== 'boolean') {
      throw Object.assign(new Error('isActive must be a boolean'), { statusCode: 400 });
    }
    const service = await repository.getServiceById(id);
    if (!service) {
      throw Object.assign(new Error('Service not found'), { statusCode: 404 });
    }
    return repository.setStatus(id, isActive);
  }
}

module.exports = new ServiceService();
