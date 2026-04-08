# Stage 1: Build/Dependencies
FROM node:20-slim AS builder
WORKDIR /app

# Copy package manifests first for better layer caching
COPY package*.json ./
# Install ALL dependencies (including devDependencies)
RUN npm ci

# Copy the rest of the source code
COPY . .

# Stage 2: Final Production Image
FROM node:20-slim
WORKDIR /app

# Set production environment
ENV NODE_ENV=production

# Copy only production dependencies from builder
COPY --from=builder /app/package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy application source code from builder
COPY --from=builder /app/src ./src
COPY --from=builder /app/.sequelizerc ./

# Fastify requires listening on 0.0.0.0 to be reachable inside a container
# Ensure your app uses: await fastify.listen({ port: 5000, host: '0.0.0.0' })
EXPOSE 5000

# Start the application
CMD ["npm", "start"]
