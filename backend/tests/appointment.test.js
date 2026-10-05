const request = require('supertest');

// Mock auth middleware before app is required
jest.mock('../src/middleware/auth.middleware', () => {
  return (req, res, next) => {
    req.userId = 1;
    next();
  };
});

const app = require('../src/app');

// Mock the prisma client
jest.mock('../src/lib/prisma', () => {
  const { mockDeep } = require('jest-mock-extended');
  return mockDeep();
});
const prismaMock = require('../src/lib/prisma');

describe('Appointment API Endpoints', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  const mockService = {
    id: 1,
    name: 'Banking Services',
    isActive: true,
  };

  const mockAppointment = {
    id: 1,
    serviceId: 1,
    customerName: 'John Doe',
    appointmentDate: '2026-10-15',
    appointmentTime: '10:30',
    status: 'scheduled',
    createdAt: new Date('2026-09-22T10:30:00Z'),
    userId: 1,
    service: mockService,
  };

  describe('POST /api/appointments', () => {
    it('should create a new appointment on success', async () => {
      prismaMock.service.findUnique.mockResolvedValue(mockService);
      prismaMock.appointment.findFirst.mockResolvedValue(null);
      prismaMock.appointment.create.mockResolvedValue(mockAppointment);

      const response = await request(app)
        .post('/api/appointments')
        .send({
          serviceId: 1,
          customerName: 'John Doe',
          appointmentDate: '2026-10-15',
          appointmentTime: '10:30'
        });

      expect(response.status).toBe(201);
      expect(response.body.appointment).toBeDefined();
      expect(response.body.appointment.customerName).toBe('John Doe');
      expect(prismaMock.appointment.create).toHaveBeenCalled();
    });

    it('should return 400 if serviceId is missing', async () => {
      const response = await request(app)
        .post('/api/appointments')
        .send({
          customerName: 'John Doe',
          appointmentDate: '2026-10-15',
          appointmentTime: '10:30'
        });
      expect(response.status).toBe(400);
      expect(response.body.error).toBe('serviceId is required');
    });

    it('should return 404 if service does not exist', async () => {
      prismaMock.service.findUnique.mockResolvedValue(null);

      const response = await request(app)
        .post('/api/appointments')
        .send({
          serviceId: 99,
          customerName: 'John Doe',
          appointmentDate: '2026-10-15',
          appointmentTime: '10:30'
        });
      
      expect(response.status).toBe(404);
      expect(response.body.error).toBe('Service not found');
    });

    it('should return 400 if service is inactive', async () => {
      prismaMock.service.findUnique.mockResolvedValue({ ...mockService, isActive: false });

      const response = await request(app)
        .post('/api/appointments')
        .send({
          serviceId: 1,
          customerName: 'John Doe',
          appointmentDate: '2026-10-15',
          appointmentTime: '10:30'
        });

      expect(response.status).toBe(409);
    });

    it('should return 400 for invalid date format', async () => {
      const response = await request(app)
        .post('/api/appointments')
        .send({
          serviceId: 1,
          customerName: 'John Doe',
          appointmentDate: '10/15/2026',
          appointmentTime: '10:30'
        });
      expect(response.status).toBe(400);
    });

    it('should return 400 for past date', async () => {
      const response = await request(app)
        .post('/api/appointments')
        .send({
          serviceId: 1,
          customerName: 'John Doe',
          appointmentDate: '2000-01-01',
          appointmentTime: '10:30'
        });
      expect(response.status).toBe(400);
    });

    it('should return 400 for invalid time format', async () => {
      const response = await request(app)
        .post('/api/appointments')
        .send({
          serviceId: 1,
          customerName: 'John Doe',
          appointmentDate: '2026-10-15',
          appointmentTime: '25:99'
        });
      expect(response.status).toBe(400);
    });

    it('should return 409 if time slot is conflicting', async () => {
      prismaMock.service.findUnique.mockResolvedValue(mockService);
      prismaMock.appointment.findFirst.mockResolvedValue(mockAppointment); // conflict exists

      const response = await request(app)
        .post('/api/appointments')
        .send({
          serviceId: 1,
          customerName: 'Jane Doe',
          appointmentDate: '2026-10-15',
          appointmentTime: '10:30'
        });

      expect(response.status).toBe(409);
      expect(response.body.error).toContain('already booked');
    });
  });

  describe('GET /api/appointments', () => {
    it('should return list of appointments', async () => {
      prismaMock.appointment.findMany.mockResolvedValue([mockAppointment]);

      const response = await request(app).get('/api/appointments');
      expect(response.status).toBe(200);
      expect(Array.isArray(response.body.appointments)).toBe(true);
      expect(response.body.appointments.length).toBe(1);
    });
  });

  describe('GET /api/appointments/:id', () => {
    it('should return appointment by id', async () => {
      prismaMock.appointment.findUnique.mockResolvedValue(mockAppointment);

      const response = await request(app).get('/api/appointments/1');
      expect(response.status).toBe(200);
      expect(response.body.appointment.id).toBe(1);
    });

    it('should return 404 if not found', async () => {
      prismaMock.appointment.findUnique.mockResolvedValue(null);

      const response = await request(app).get('/api/appointments/999');
      expect(response.status).toBe(404);
    });
  });

  describe('PATCH /api/appointments/:id/cancel', () => {
    it('should cancel the appointment', async () => {
      prismaMock.appointment.findUnique.mockResolvedValue(mockAppointment);
      prismaMock.appointment.update.mockResolvedValue({ ...mockAppointment, status: 'cancelled' });

      const response = await request(app).patch('/api/appointments/1/cancel');
      expect(response.status).toBe(200);
      expect(response.body.appointment.status).toBe('cancelled');
    });

    it('should return 200 gracefully if already cancelled', async () => {
      prismaMock.appointment.findUnique.mockResolvedValue({ ...mockAppointment, status: 'cancelled' });

      const response = await request(app).patch('/api/appointments/1/cancel');
      expect(response.status).toBe(200);
      expect(response.body.appointment.status).toBe('cancelled');
      // Should not call update
      expect(prismaMock.appointment.update).not.toHaveBeenCalled();
    });
  });
});
