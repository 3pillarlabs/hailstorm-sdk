# Hailstorm Client Exchange

An exchange for messages shared by different services. This connects with Redis to publish incoming messages to a
configurable topic.

# Quick Start

Start Redis
```
➜  hailstorm-sdk$ docker-compose up -d hailstorm-mq
```

Run it from the command line.
```bash
➜  hailstorm-client-exchange$ ./gradlew bootRun
```

If Redis is running on a different host, pass ``redisHost`` as an argument.
```bash
➜  hailstorm-client-exchange$ ./gradlew bootRun --args=--redisHost=hailstorm-mq.somewhere
```

# Docker

Build a docker image.
```
➜  hailstorm-client-exchange$ make package
```
