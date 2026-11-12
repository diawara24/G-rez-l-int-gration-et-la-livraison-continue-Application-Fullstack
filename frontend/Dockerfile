# Étape 1 : construire l'application Angular
FROM node:22-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build -- --configuration=production

# Étape 2 : servir l'application avec Nginx
FROM nginx:alpine AS runtime

COPY --from=builder /app/dist/olympic-games-starter/browser/ /usr/share/nginx/html/
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
