'use strict';

/**
 * Wraps an async route handler and forwards failures to Express error handling.
 *
 * @param {Function} handler - Async Express route handler.
 * @returns {import('express').RequestHandler} Wrapped handler.
 */
const asyncRoute = (handler) => (req, res, next) =>
  Promise.resolve(handler(req, res, next)).catch(next);

module.exports = { asyncRoute };
