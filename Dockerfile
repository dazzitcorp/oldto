FROM node:9.8.0 as builder

WORKDIR frontend
COPY frontend .
RUN npm install && npm run build

FROM nginx

COPY --from=builder frontend/dist /usr/share/nginx/html
COPY nginx.config /etc/nginx/conf.d/default.conf

EXPOSE 80
