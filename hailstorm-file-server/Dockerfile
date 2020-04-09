FROM openjdk:8-jdk-alpine

VOLUME /tmp /hailstorm

ARG JAR_FILE

COPY ${JAR_FILE} app.jar

EXPOSE 8080

CMD ["java", "-jar", "/app.jar"]
