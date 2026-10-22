'use strict';

const jwt = require('jsonwebtoken');
const { app, request, registerUser, cleanup } = require('./helpers');

afterAll(cleanup);

const auth = (user) => ({ Authorization: `Bearer ${user.accessToken}` });

async function createTask(user, body = { title: 'Review API security' }) {
  const response = await request(app).post('/api/v1/tasks').set(auth(user)).send(body);
  expect(response.status).toBe(201);
  return response.body.item;
}

describe('authentication on task routes', () => {
  test('rejects requests without a token', async () => {
    const response = await request(app).get('/api/v1/tasks');
    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('UNAUTHENTICATED');
  });

  test('rejects a token signed with another secret', async () => {
    const forged = jwt.sign({ sub: 'someone', type: 'access' }, 'x'.repeat(40), {
      issuer: 'task-manager-api', audience: 'task-manager-client',
    });
    const response = await request(app).get('/api/v1/tasks').set('Authorization', `Bearer ${forged}`);
    expect(response.status).toBe(401);
  });

  test('rejects an unsigned (alg none) token', async () => {
    const unsigned = jwt.sign({ sub: 'someone', type: 'access' }, null, { algorithm: 'none' });
    const response = await request(app).get('/api/v1/tasks').set('Authorization', `Bearer ${unsigned}`);
    expect(response.status).toBe(401);
  });
});

describe('task CRUD', () => {
  test('creates, lists, updates and deletes a task', async () => {
    const user = await registerUser();
    const task = await createTask(user, { title: '  Write tests  ', description: 'Check ownership' });
    expect(task.title).toBe('Write tests');
    expect(task.completed).toBe(false);

    const list = await request(app).get('/api/v1/tasks').set(auth(user));
    expect(list.status).toBe(200);
    expect(list.body.items.map((t) => t.id)).toContain(task.id);

    const updated = await request(app).patch(`/api/v1/tasks/${task.id}`).set(auth(user))
      .send({ completed: true });
    expect(updated.status).toBe(200);
    expect(updated.body.item.completed).toBe(true);

    const removed = await request(app).delete(`/api/v1/tasks/${task.id}`).set(auth(user));
    expect(removed.status).toBe(204);

    const after = await request(app).get(`/api/v1/tasks/${task.id}`).set(auth(user));
    expect(after.status).toBe(404);
  });

  test('rejects a client-supplied ownerId', async () => {
    const owner = await registerUser();
    const victim = await registerUser();
    const response = await request(app).post('/api/v1/tasks').set(auth(owner))
      .send({ title: 'Sneaky', ownerId: 'victim-id' });
    expect(response.status).toBe(400);
    const victimList = await request(app).get('/api/v1/tasks').set(auth(victim));
    expect(victimList.body.items).toHaveLength(0);
  });

  test('validates task payloads', async () => {
    const user = await registerUser();
    const empty = await request(app).post('/api/v1/tasks').set(auth(user)).send({ title: '   ' });
    expect(empty.status).toBe(400);
    const tooLong = await request(app).post('/api/v1/tasks').set(auth(user)).send({ title: 'a'.repeat(121) });
    expect(tooLong.status).toBe(400);
    const task = await createTask(user);
    const noFields = await request(app).patch(`/api/v1/tasks/${task.id}`).set(auth(user)).send({});
    expect(noFields.status).toBe(400);
  });

  test('rejects malformed task ids with a safe 400', async () => {
    const user = await registerUser();
    const response = await request(app)
      .patch(`/api/v1/tasks/${encodeURIComponent("1' OR '1'='1")}`)
      .set(auth(user))
      .send({ completed: true });
    expect(response.status).toBe(400);
    expect(JSON.stringify(response.body)).not.toMatch(/prisma|sql|stack/i);
  });
});

describe('ownership (IDOR protection)', () => {
  test('user A cannot read, update or delete user B task', async () => {
    const userA = await registerUser();
    const userB = await registerUser();
    const taskB = await createTask(userB, { title: 'Private to B' });

    const read = await request(app).get(`/api/v1/tasks/${taskB.id}`).set(auth(userA));
    expect(read.status).toBe(404);

    const update = await request(app).patch(`/api/v1/tasks/${taskB.id}`).set(auth(userA))
      .send({ title: 'Hacked' });
    expect(update.status).toBe(404);

    const remove = await request(app).delete(`/api/v1/tasks/${taskB.id}`).set(auth(userA));
    expect(remove.status).toBe(404);

    const listA = await request(app).get('/api/v1/tasks').set(auth(userA));
    expect(listA.body.items).toHaveLength(0);

    const stillThere = await request(app).get(`/api/v1/tasks/${taskB.id}`).set(auth(userB));
    expect(stillThere.status).toBe(200);
    expect(stillThere.body.item.title).toBe('Private to B');
  });
});

describe('pagination bounds', () => {
  test('applies page and limit', async () => {
    const user = await registerUser();
    for (let i = 0; i < 3; i += 1) await createTask(user, { title: `Task ${i}` });
    const page1 = await request(app).get('/api/v1/tasks?page=1&limit=2').set(auth(user));
    const page2 = await request(app).get('/api/v1/tasks?page=2&limit=2').set(auth(user));
    expect(page1.body.items).toHaveLength(2);
    expect(page2.body.items).toHaveLength(1);
    expect(page1.body).toMatchObject({ page: 1, limit: 2 });
  });

  test('rejects out-of-range pagination values', async () => {
    const user = await registerUser();
    for (const query of ['limit=101', 'limit=0', 'page=0', 'page=abc']) {
      const response = await request(app).get(`/api/v1/tasks?${query}`).set(auth(user));
      expect(response.status).toBe(400);
    }
  });
});
