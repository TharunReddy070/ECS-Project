import Url from '../db/models/url.model.js';

//  SHORTEN URL (FINAL VERSION)
async function shorten(req, reply) {
try {
const { destination } = req.body;

```
// Validate input
if (!destination || typeof destination !== 'string') {
  return reply.code(400).send({ error: 'Invalid URL' });
}

// Optional: normalize URL
const normalizedUrl = destination.trim();

//  Check if already exists (avoid duplicates)
const existing = await Url.findOne({ where: { destination: normalizedUrl } });

if (existing) {
  req.log.info(` Existing URL: ${normalizedUrl} → ${existing.shortID}`);
  return reply.send({
    shortID: existing.shortID,
    destination: existing.destination,
  });
}

// Create new short URL
const url = await Url.create({ destination: normalizedUrl });

req.log.info(` Shortened: ${normalizedUrl} → ${url.shortID}`);

return reply.send({
  shortID: url.shortID,
  destination: url.destination,
});
```

} catch (error) {
req.log.error(' SHORTEN ERROR', error);
return reply.code(500).send({ error: 'Failed to shorten URL' });
}
}

// REDIRECT (FINAL VERSION — SAFE)
async function redirect(req, reply) {
try {
const { shortID } = req.params;

```
//  Validate input
if (!shortID) {
  return reply.code(400).send({ error: 'Invalid short ID' });
}

const url = await Url.findOne({ where: { shortID } });

// Handle missing URL properly (no crash, no timeout)
if (!url) {
  req.log.warn(`Short URL not found: ${shortID}`);
  return reply.code(404).send({ error: 'Short URL not found' });
}

const destination = url.destination;

// Safety check
if (!destination) {
  req.log.error(`Missing destination for ${shortID}`);
  return reply.code(500).send({ error: 'Invalid stored URL' });
}

req.log.info(` Redirect: ${shortID} → ${destination}`);

return reply.redirect(destination);
```

} catch (error) {
req.log.error('REDIRECT ERROR', error);
return reply.code(500).send({ error: 'Redirect failed' });
}
}

export default { shorten, redirect };

