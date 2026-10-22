'use strict';

const request = require('supertest');
const { app } = require('../src/app');
const { prisma } = require('../src/repositories/task.repository');

let counter = 0;

/** Registers a fresh user and returns its email, password and token pair. */
async function registerUser() {
  counter += 1;
  const email = `test-${Date.now()}-${counter}@example.test`;
  const password = 'a-long-test-password';
  const response = await request(app).post('/api/v1/auth/register').send({ email, password });
  expect(response.status).toBe(201);
  return { email, password, ...response.body };
}

/** Removes every user created by the test suite (cascades to tasks and tokens). */
async function cleanup() {
  await prisma.user.deleteMany({ where: { email: { endsWith: '@example.test' } } });
  await prisma.$disconnect();
}

module.exports = { app, request, registerUser, cleanup };
