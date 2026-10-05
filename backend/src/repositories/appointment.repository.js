const prisma = require('../lib/prisma');

class AppointmentRepository {
  /**
   * Creates a new appointment
   */
  async createAppointment(data) {
    return prisma.appointment.create({
      data,
      include: {
        service: true
      }
    });
  }

  /**
   * Finds an active appointment for the given service, date, and time
   */
  async findConflictingAppointment(serviceId, appointmentDate, appointmentTime) {
    return prisma.appointment.findFirst({
      where: {
        serviceId,
        appointmentDate,
        appointmentTime,
        status: {
          not: 'cancelled'
        }
      }
    });
  }

  /**
   * Retrieves all appointments, ordered by date and time
   */
  async getAppointments(userId) {
    return prisma.appointment.findMany({
      where: { userId },
      orderBy: [
        { appointmentDate: 'asc' },
        { appointmentTime: 'asc' }
      ],
      include: {
        service: true
      }
    });
  }

  /**
   * Retrieves a single appointment by ID
   */
  async getAppointmentById(id) {
    return prisma.appointment.findUnique({
      where: { id },
      include: {
        service: true
      }
    });
  }

  /**
   * Updates an appointment (used for cancellation)
   */
  async updateAppointment(id, data) {
    return prisma.appointment.update({
      where: { id },
      data,
      include: {
        service: true
      }
    });
  }
}

module.exports = new AppointmentRepository();
