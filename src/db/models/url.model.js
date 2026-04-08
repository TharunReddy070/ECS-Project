import { DataTypes } from 'sequelize';
import sequelize from '../sequelize.js';
import { nanoid } from 'nanoid';

const Url = sequelize.define(
  'Url',
  {
    destination: {
      type: DataTypes.STRING,
      allowNull: false,
      validate: {
        isUrl: true,
      },
    },
    shortID: {
      type: DataTypes.STRING,
      unique: true,
      trim: true,
      allowNull: false,
      len: {
        args: [7, 7],
        msg: 'String length is not equal to 7',
      },
    },
  },
  {
    tableName: 'urls',
    hooks: {
      beforeValidate: function (url, options) {
        url.shortID = nanoid(7);
      },
    },
  }
);

export default Url;
