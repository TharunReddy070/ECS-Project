import path from 'node:path';
import * as url from 'node:url';
import envSchema from 'env-schema';

const schema = {
  type: 'object',
  required: [
    'PORT',
    'LOG_LEVEL',
    'NODE_ENV',
    'POSTGRES_HOST',
    'POSTGRES_USER',
    'POSTGRES_PASSWORD',
    'POSTGRES_DB',
  ],
  properties: {
    PORT: {
      type: 'number',
      default: 3000,
    },
    LOG_LEVEL: {
      type: 'string',
      default: 'info',
    },
    NODE_ENV: {
      type: 'string',
      default: 'development',
      enum: ['development', 'testing', 'production', 'staging'],
    },
    POSTGRES_HOST: {
      type: 'string',
      default: 'localhost',
    },
    POSTGRES_DB: {
      type: 'string',
    },
    POSTGRES_USER: {
      type: 'string',
    },
    POSTGRES_PASSWORD: {
      type: 'string',
    },
  },
};

const config = envSchema({
  schema: schema,
  dotenv: {
    path: path.join(import.meta.dirname, '../../.env'),
  },
});

export default {
  port: config.PORT,
  logLevel: config.LOG_LEVEL,
  node_env: config.NODE_ENV,
  postgres: {
    user: config.POSTGRES_USER,
    password: config.POSTGRES_PASSWORD,
    db: config.POSTGRES_DB,
    host: config.POSTGRES_HOST,
  },
};
