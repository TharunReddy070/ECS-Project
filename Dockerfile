# Stage 1: Build
FROM node:20-alpine AS builder
WORKDIR /app

# Install build tools needed for some node packages
RUN apk add --no-cache python3 make g++

COPY package*.json ./
RUN npm ci

COPY . .

# Stage 2: Production
FROM node:20-alpine
WORKDIR /app

# Force update all packages to fix known OS vulnerabilities
RUN apk update && apk upgrade --no-cache

ENV NODE_ENV=production

COPY --from=builder /app/package*.json ./
RUN npm ci --only=production && npm cache clean --force

COPY --from=builder /app/src ./src
# Only include .sequelizerc if it actually exists in your project
# COPY --from=builder /app/.sequelizerc ./

EXPOSE 5000

CMD ["npm", "start"]
