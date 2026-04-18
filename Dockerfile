# Stage 1: Build
FROM node:20-alpine AS builder
WORKDIR /app
RUN apk add --no-cache python3 make g++
COPY package*.json ./
RUN npm ci
COPY . .

# Stage 2: Production
FROM node:20-alpine
WORKDIR /app
RUN apk update && apk upgrade --no-cache
ENV NODE_ENV=production
COPY --from=builder /app/package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY --from=builder /app/src ./src
COPY --from=builder /app/.sequelizerc ./
EXPOSE 3000
CMD ["npm", "start"]
