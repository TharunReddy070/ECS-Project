import app from './app.js';
import sequelize from './db/sequelize.js';
import env from './config/env.js';
import logger from './config/logger.js';

function exit() {
  if (app.server) {
    app.server.close(() => {
      logger.info('Server closed');
      process.exit(1);
    });
  } else {
    process.exit(1);
  }
}

function handleError(error) {
  logger.fatal(error);
  exit();
}

try {
  //DEBUG LOGS (VERY IMPORTANT)
  console.log("==== ENV DEBUG START ====");
  console.log("DATABASE_URL:", process.env.DATABASE_URL);
  console.log("POSTGRES_HOST:", process.env.POSTGRES_HOST);
  console.log("POSTGRES_USER:", process.env.POSTGRES_USER);
  console.log("POSTGRES_DB:", process.env.POSTGRES_DB);
  console.log("NODE_ENV:", process.env.NODE_ENV);
  console.log("==== ENV DEBUG END ====");

  await sequelize.authenticate();
  logger.info('Database authentication successful');

  await sequelize.sync();
  logger.info('Database sync successful');

  const address = await app.listen({
  port: env.port,
  host: '0.0.0.0',   // 🔥 REQUIRED FOR ECS
  });
  
  logger.info(
  `URL Shortener running on port ${env.port} in ${env.node_env} mode`
  );

  process.on('SIGTERM', () => {
    logger.info('SIGTERM received. Executing shutdown sequence');
    exit();
  });

  process.on('uncaughtException', handleError);
  process.on('unhandledRejection', handleError);
} catch (err) {
  logger.fatal('Application failed to start');
  logger.fatal(err);
  exit();
}
