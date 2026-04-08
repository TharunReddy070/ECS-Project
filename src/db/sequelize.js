import { Sequelize } from 'sequelize';
import logger from '../config/logger.js';

//use DATABASE_URL directly
const sequelize = new Sequelize(process.env.DATABASE_URL, {
  dialect: 'postgres',
  logging: (msg) => logger.debug(msg),
});

export default sequelize;
