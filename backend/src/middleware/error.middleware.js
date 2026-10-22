'use strict';

/**
 * Sends a consistent safe error response.
 *
 * @param {Error} error - Error forwarded by an earlier middleware.
 * @param {import('express').Request} req - Express request.
 * @param {import('express').Response} res - Express response.
 * @param {import('express').NextFunction} _next - Express continuation.
 * @returns {void}
 */
function errorHandler(error, req, res, _next) {
  req.log?.error({ err: error }, 'Request failed');

  if (res.headersSent) return;

  // body-parser errors (malformed JSON, payload too large) carry a safe status.
  const rawStatus = error.status ?? error.statusCode;
  const status = Number.isInteger(rawStatus) ? rawStatus : 500;
  const safeStatus = status >= 400 && status < 500 ? status : 500;
  const isParserError = typeof error.type === 'string';

  res.status(safeStatus).json({
    error: {
      code: safeStatus === 500 ? 'INTERNAL_ERROR' : (error.code || 'REQUEST_ERROR'),
      message: safeStatus === 500
        ? 'An unexpected error occurred.'
        : (isParserError ? 'The request body is invalid.' : error.message),
    },
  });
}

module.exports = { errorHandler };
