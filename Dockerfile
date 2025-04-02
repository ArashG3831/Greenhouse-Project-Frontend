FROM node:22.14.0 AS builder

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm install --legacy-peer-deps

COPY . .
RUN npm run build

# ---

FROM node:22.14.0

WORKDIR /app

COPY --from=builder /app ./

RUN npm install --omit=dev --legacy-peer-deps

EXPOSE 3000

CMD ["node", "build"]
