# syntax=docker/dockerfile:1

# ---- build: dependências completas, Prisma Client e compilação ----
FROM node:22-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends openssl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY prisma ./prisma
RUN npx prisma generate
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# ---- runtime: apenas dependências de produção + CLI do Prisma para migrações ----
FROM node:22-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends openssl && rm -rf /var/lib/apt/lists/*
ENV NODE_ENV=production
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm install --no-save prisma@6 && npm cache clean --force
COPY prisma ./prisma
RUN npx prisma generate
COPY --from=build /app/dist ./dist
# Diretório de mídia gravável pelo usuário sem privilégios (o volume herda o dono na criação)
RUN mkdir -p /app/storage/media && chown -R node:node /app/storage
USER node
EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=5 \
  CMD node -e "fetch('http://127.0.0.1:3000/api/auth/me').then(r=>process.exit(r.status===401?0:1)).catch(()=>process.exit(1))"
# Aplica migrações pendentes e sobe a API
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/main.js"]
