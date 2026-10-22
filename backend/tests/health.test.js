'use strict';

const request = require('supertest');
const { app } = require('../src/app');
const { prisma } = require('../src/repositories/task.repository');

afterAll(() => prisma.$disconnect());

describe('health endpoint', () => {
  test('returns a healthy status', async () => {
    const response = await request(app).get('/health');
    expect(response.status).toBe(200);
    expect(response.body.status).toBe('ok');
  });

  test('sets security headers and hides the framework', async () => {
    const response = await request(app).get('/health');
    expect(response.headers['x-powered-by']).toBeUndefined();
    expect(response.headers['x-content-type-options']).toBe('nosniff');
  });

  test('unknown routes return a safe 404', async () => {
    const response = await request(app).get('/api/v1/nope');
    expect(response.status).toBe(404);
    expect(response.body.error.code).toBe('NOT_FOUND');
  });
});
