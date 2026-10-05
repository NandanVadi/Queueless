const request = require('supertest');
const app = require('../src/app');
const { mockDeep } = require('jest-mock-extended');

// Mock the prisma client
jest.mock('../src/lib/prisma', () => {
  const { mockDeep } = require('jest-mock-extended');
  return mockDeep();
});
const prismaMock = require('../src/lib/prisma');

describe('API Endpoints', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('GET /api/services should return 200 and a list of services', async () => {
    const mockServices = [
      {
        id: 1,
        name: "Test Postgres Service",
        description: "Postgres test description",
        icon: "postgres",
        isActive: true
      }
    ];

    prismaMock.service.findMany.mockResolvedValue(mockServices);

    const response = await request(app).get('/api/services');
    
    expect(response.statusCode).toBe(200);
    expect(response.body).toHaveProperty('services');
    expect(Array.isArray(response.body.services)).toBeTruthy();
    expect(response.body.services.length).toBe(1);
    
    const firstService = response.body.services[0];
    expect(firstService).toHaveProperty('id');
    expect(firstService).toHaveProperty('name');
    expect(firstService).toHaveProperty('description');
    expect(firstService).toHaveProperty('icon');
    expect(firstService).toHaveProperty('isActive');
    expect(firstService.name).toBe("Test Postgres Service");

    // Verify Prisma was called correctly
    expect(prismaMock.service.findMany).toHaveBeenCalledWith({
      where: { isActive: true },
      orderBy: { name: 'asc' }
    });
  });

  it('should return 500 when database query fails', async () => {
    // Simulate database failure
    prismaMock.service.findMany.mockRejectedValue(new Error("Database connection failed"));

    const response = await request(app).get('/api/services');
    
    expect(response.statusCode).toBe(500);
    expect(response.body).toHaveProperty('error', 'Internal Server Error');
  });

  it('should return 404 for unknown routes', async () => {
    const response = await request(app).get('/api/unknown');
    expect(response.statusCode).toBe(404);
  });
});
