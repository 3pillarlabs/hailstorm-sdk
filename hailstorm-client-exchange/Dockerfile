FROM openjdk:8-jdk-alpine

RUN apk add --no-cache openssl

ENV DOCKERIZE_VERSION v0.6.1

RUN wget -q https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz

VOLUME /tmp /hailstorm

ARG JAR_FILE

COPY ${JAR_FILE} app.jar

EXPOSE 8080

CMD ["java", "-jar", "/app.jar"]
