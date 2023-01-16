# To proxy from nginx to localhost: 
#     docker run --network=host <image>:latest

FROM node:18.13.0-buster-slim as builder

WORKDIR .
COPY . .
RUN npm install && npm run build

FROM nginx

COPY --from=builder ./dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
