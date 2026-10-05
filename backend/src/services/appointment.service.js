const appointmentRepository = require('../repositories/appointment.repository');
const serviceRepository = require('../repositories/service.repository');

class AppointmentService {
  async createAppointment(data, userId) {
    const { serviceId, customerName, appointmentDate, appointmentTime } = data;

    // Validate required fields
    if (!serviceId) throw Object.assign(new Error('serviceId is required'), { statusCode: 400 });
    if (!customerName || !customerName.trim()) throw Object.assign(new Error('customerName is required'), { statusCode: 400 });
    if (!appointmentDate) throw Object.assign(new Error('appointmentDate is required'), { statusCode: 400 });
    if (!appointmentTime) throw Object.assign(new Error('appointmentTime is required'), { statusCode: 400 });

    // Validate Date format (YYYY-MM-DD)
    const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
    if (!dateRegex.test(appointmentDate)) {
      throw Object.assign(new Error('Invalid appointmentDate format. Expected YYYY-MM-DD'), { statusCode: 400 });
    }

    // Validate not in the past (ignoring time for simplicity, checking only date)
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const apptDate = new Date(appointmentDate);
    if (apptDate < today) {
      throw Object.assign(new Error('appointmentDate cannot be in the past'), { statusCode: 400 });
    }

    // Validate Time format (HH:MM)
    const timeRegex = /^([01]\d|2[0-3]):([0-5]\d)$/;
    if (!timeRegex.test(appointmentTime)) {
      throw Object.assign(new Error('Invalid appointmentTime format. Expected HH:MM'), { statusCode: 400 });
    }

    // Validate Service
    const service = await serviceRepository.getServiceById(serviceId);
    if (!service) {
      throw Object.assign(new Error('Service not found'), { statusCode: 404 });
    }
    if (!service.isActive) {
      throw Object.assign(new Error('Service is inactive'), { statusCode: 409 });
    }

    // Check for conflicts
    const conflict = await appointmentRepository.findConflictingAppointment(serviceId, appointmentDate, appointmentTime);
    if (conflict) {
      throw Object.assign(new Error('This time slot is already booked for the selected service'), { statusCode: 409 });
    }

    // Create the appointment
    const appointmentData = {
      serviceId,
      customerName: customerName.trim(),
      appointmentDate,
      appointmentTime,
      status: 'scheduled',
      userId
      // createdAt is handled by Prisma default(now())
    };

    return await appointmentRepository.createAppointment(appointmentData);
  }

  async getAppointments(userId) {
    return await appointmentRepository.getAppointments(userId);
  }

  async getAppointmentById(id, userId) {
    const appointment = await appointmentRepository.getAppointmentById(id);
    if (!appointment) {
      throw Object.assign(new Error('Appointment not found'), { statusCode: 404 });
    }
    if (appointment.userId !== null && appointment.userId !== userId) {
      throw Object.assign(new Error('Forbidden: You do not own this appointment'), { statusCode: 403 });
    }
    return appointment;
  }

  async cancelAppointment(id, userId) {
    const appointment = await appointmentRepository.getAppointmentById(id);
    if (!appointment) {
      throw Object.assign(new Error('Appointment not found'), { statusCode: 404 });
    }
    if (appointment.userId !== null && appointment.userId !== userId) {
      throw Object.assign(new Error('Forbidden: You do not own this appointment'), { statusCode: 403 });
    }

    // If already cancelled, just return it gracefully
    if (appointment.status === 'cancelled') {
      return appointment;
    }

    return await appointmentRepository.updateAppointment(id, { status: 'cancelled' });
  }
}

module.exports = new AppointmentService();
