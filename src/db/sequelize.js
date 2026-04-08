import { Sequelize } from 'sequelize';
import logger from '../config/logger.js';

const sequelize = new Sequelize(process.env.DATABASE_URL, {
  dialect: 'postgres',
  dialectOptions: {
    ssl: {
      require: true,
      rejectUnauthorized: false, // important for RDS
    },
  },
  logging: (msg) => logger.debug(msg),
});

export default sequelize;
