FROM node:22.14.0 AS builder

WORKDIR /app

COPY package*.json ./
RUN npm install --legacy-peer-deps

COPY . .
RUN npm run build

<<<<<<< HEAD
# ---

=======
>>>>>>> ea5f4e7 (new ssr)
FROM node:22.14.0

WORKDIR /app

<<<<<<< HEAD
COPY --from=builder /app ./

RUN npm install --omit=dev --legacy-peer-deps

EXPOSE 3000

CMD ["node", "build"]
=======
RUN npm install -g serve
COPY --from=builder /app/build ./build

CMD ["serve", "-s", "build", "-l", "3000"]
>>>>>>> ea5f4e7 (new ssr)
