'use strict';

const { app, request, registerUser, cleanup } = require('./helpers');

afterAll(cleanup);

describe('registration and login', () => {
  test('registers a user and returns a token pair', async () => {
    const user = await registerUser();
    expect(typeof user.accessToken).toBe('string');
    expect(typeof user.refreshToken).toBe('string');
    expect(user.expiresIn).toBe(600);
    expect(user).not.toHaveProperty('passwordHash');
  });

  test('rejects a duplicate email with 409', async () => {
    const user = await registerUser();
    const response = await request(app).post('/api/v1/auth/register')
      .send({ email: user.email, password: user.password });
    expect(response.status).toBe(409);
    expect(response.body.error.code).toBe('CONFLICT');
  });

  test('rejects short passwords and invalid emails', async () => {
    const response = await request(app).post('/api/v1/auth/register')
      .send({ email: 'not-an-email', password: 'short' });
    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });

  test('logs in with valid credentials', async () => {
    const user = await registerUser();
    const response = await request(app).post('/api/v1/auth/login')
      .send({ email: user.email, password: user.password });
    expect(response.status).toBe(200);
    expect(typeof response.body.accessToken).toBe('string');
  });

  test('uses the same generic message for a wrong password and an unknown email', async () => {
    const user = await registerUser();
    const wrongPassword = await request(app).post('/api/v1/auth/login')
      .send({ email: user.email, password: 'wrong-password-123' });
    const unknownEmail = await request(app).post('/api/v1/auth/login')
      .send({ email: 'nobody@example.test', password: 'wrong-password-123' });
    expect(wrongPassword.status).toBe(401);
    expect(unknownEmail.status).toBe(401);
    expect(wrongPassword.body).toEqual(unknownEmail.body);
  });

  test('rejects malformed JSON without leaking parser details', async () => {
    const response = await request(app).post('/api/v1/auth/login')
      .set('Content-Type', 'application/json')
      .send('{"email":');
    expect(response.status).toBe(400);
    expect(JSON.stringify(response.body)).not.toMatch(/SyntaxError|stack/i);
  });
});

describe('refresh-token lifecycle', () => {
  test('rotation returns a different refresh token', async () => {
    const initial = await registerUser();
    const response = await request(app).post('/api/v1/auth/refresh')
      .send({ refreshToken: initial.refreshToken });
    expect(response.status).toBe(200);
    expect(response.body.refreshToken).not.toBe(initial.refreshToken);
  });

  test('reuse of an old token revokes the newer token family token', async () => {
    const initial = await registerUser();
    const rotated = await request(app).post('/api/v1/auth/refresh')
      .send({ refreshToken: initial.refreshToken });
    expect(rotated.status).toBe(200);

    const reuse = await request(app).post('/api/v1/auth/refresh')
      .send({ refreshToken: initial.refreshToken });
    expect(reuse.status).toBe(401);

    const newer = await request(app).post('/api/v1/auth/refresh')
      .send({ refreshToken: rotated.body.refreshToken });
    expect(newer.status).toBe(401);
  });

  test('logout makes the refresh token unusable', async () => {
    const tokens = await registerUser();
    const logout = await request(app).post('/api/v1/auth/logout')
      .send({ refreshToken: tokens.refreshToken });
    expect(logout.status).toBe(204);

    const refresh = await request(app).post('/api/v1/auth/refresh')
      .send({ refreshToken: tokens.refreshToken });
    expect(refresh.status).toBe(401);
  });

  test('logout-all revokes every session of the user', async () => {
    const user = await registerUser();
    const second = await request(app).post('/api/v1/auth/login')
      .send({ email: user.email, password: user.password });

    const logoutAll = await request(app).post('/api/v1/auth/logout-all')
      .set('Authorization', `Bearer ${user.accessToken}`);
    expect(logoutAll.status).toBe(204);

    for (const token of [user.refreshToken, second.body.refreshToken]) {
      const refresh = await request(app).post('/api/v1/auth/refresh').send({ refreshToken: token });
      expect(refresh.status).toBe(401);
    }
  });

  test('logout-all requires an access token', async () => {
    const response = await request(app).post('/api/v1/auth/logout-all');
    expect(response.status).toBe(401);
  });

  test('an unknown refresh token is rejected', async () => {
    const response = await request(app).post('/api/v1/auth/refresh')
      .send({ refreshToken: 'x'.repeat(64) });
    expect(response.status).toBe(401);
  });
});
