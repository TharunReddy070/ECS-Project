import Url from '../db/models/url.model.js';

async function shorten(req, reply) {
  try {
    const { destination } = req.body;

    if (!destination || typeof destination !== 'string') {
      return reply.code(400).send({ error: 'Invalid URL' });
    }

    const normalizedUrl = destination.trim();

    const existing = await Url.findOne({ where: { destination: normalizedUrl } });

    if (existing) {
      req.log.info(`Existing URL: ${normalizedUrl} → ${existing.shortID}`);
      return reply.send({
        shortID: existing.shortID,
        destination: existing.destination,
      });
    }

    const url = await Url.create({ destination: normalizedUrl });

    req.log.info(`Shortened: ${normalizedUrl} → ${url.shortID}`);

    return reply.send({
      shortID: url.shortID,
      destination: url.destination,
    });

  } catch (error) {
    req.log.error('SHORTEN ERROR', error);
    return reply.code(500).send({ error: 'Failed to shorten URL' });
  }
}

async function redirect(req, reply) {
  try {
    const { shortID } = req.params;

    if (!shortID) {
      return reply.code(400).send({ error: 'Invalid short ID' });
    }

    const url = await Url.findOne({ where: { shortID } });

    if (!url) {
      req.log.warn(`Short URL not found: ${shortID}`);
      return reply.code(404).send({ error: 'Short URL not found' });
    }

    const destination = url.destination;

    if (!destination) {
      req.log.error(`Missing destination for ${shortID}`);
      return reply.code(500).send({ error: 'Invalid stored URL' });
    }

    req.log.info(`Redirect: ${shortID} → ${destination}`);

    return reply.redirect(destination);

  } catch (error) {
    req.log.error('REDIRECT ERROR', error);
    return reply.code(500).send({ error: 'Redirect failed' });
  }
}

export default { shorten, redirect };
