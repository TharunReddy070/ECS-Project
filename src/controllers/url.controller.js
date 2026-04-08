import Url from '../db/models/url.model.js';

// ✅ SHORTEN URL (improved + safe)
async function shorten(req, reply) {
  try {
    const { destination } = req.body;

    // Check if already exists (avoid duplicates)
    const existing = await Url.findOne({ where: { destination } });

    if (existing) {
      req.log.debug(`Existing URL found: ${destination} → ${existing.shortID}`);
      return reply.send({
        shortID: existing.shortID,
        destination: existing.destination,
      });
    }

    // Create new short URL
    const url = await Url.create({ destination });

    req.log.debug(`${destination} shortened to ${url.shortID}`);

    return reply.send({
      shortID: url.shortID,
      destination: url.destination,
    });
  } catch (error) {
    req.log.error(error);
    return reply.code(500).send({ error: 'Failed to shorten URL' });
  }
}


// ✅ REDIRECT (FIXED — NO MORE TIMEOUTS)
async function redirect(req, reply) {
  try {
    const { shortID } = req.params;

    const url = await Url.findOne({ where: { shortID } });

    // 🔥 IMPORTANT FIX
    if (!url) {
      req.log.warn(`Short URL not found: ${shortID}`);
      return reply.code(404).send({ error: 'Short URL not found' });
    }

    const { destination } = url;

    req.log.debug(`redirecting /${shortID} → ${destination}`);

    return reply.redirect(destination);
  } catch (error) {
    req.log.error(error);
    return reply.code(500).send({ error: 'Redirect failed' });
  }
}

export default { shorten, redirect };
