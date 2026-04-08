import Url from '../db/models/url.model.js';

async function shorten(req, reply) {
  const [url] = await Url.findOrCreate({
    where: { destination: req.body.destination },
  });

  const {
    dataValues: { shortID, destination },
  } = url;

  req.log.debug(`${destination} shortened to ${shortID}`);

  reply.send({ shortID, destination });
}

async function redirect(req, reply) {
  const { shortID } = req.params;

  const { destination } = await Url.findOne({ where: { shortID } });

  req.log.debug(`redirecting /${shortID} to ${destination}`);

  reply.redirect(destination);
}

export default { shorten, redirect };
