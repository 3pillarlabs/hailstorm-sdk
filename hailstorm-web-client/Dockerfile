FROM sebp/lighttpd

RUN apk add --no-cache openssl

ENV DOCKERIZE_VERSION v0.6.1

RUN wget -q https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz

COPY BUILD_ID .

COPY build /var/www/localhost/htdocs

CMD [ "start.sh" ]
