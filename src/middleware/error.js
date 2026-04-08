import logger from '../config/logger.js';

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, reply) {
  let statusCode = 500;
  let message = 'internal server error';

  if (err.code === 'FST_ERR_VALIDATION') {
    statusCode = 400;
    message = 'validation error';
    logger.info(err);
  } else {
    logger.error(err);
  }

  const response = {
    code: statusCode,
    message,
  };

  reply.code(statusCode).send(response);
}

export default errorHandler;
