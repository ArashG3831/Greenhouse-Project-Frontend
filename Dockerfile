FROM node:22.14.0 AS builder

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm install --legacy-peer-deps

COPY . .

# Optional: force clean build
RUN rm -rf .svelte-kit build

# Build the SvelteKit app
RUN npx svelte-kit build

# -----------------------------------------------------
# Serve the static build (from adapter-static output)
FROM node:22.14.0

WORKDIR /app

RUN npm install -g serve

COPY --from=builder /app/build ./build

EXPOSE 5173
CMD ["serve", "build", "--listen", "5173"]
