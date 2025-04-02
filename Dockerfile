FROM node:22.14.0 AS builder

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm install --legacy-peer-deps

COPY . .

# This is the only command that works with SvelteKit 2+
RUN npm run build

# Serve the static build
FROM node:22.14.0

WORKDIR /app

RUN npm install -g serve

COPY --from=builder /app/build ./build

EXPOSE 5173
CMD ["serve", "build", "--listen", "5173"]
