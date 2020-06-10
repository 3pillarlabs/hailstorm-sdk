FROM jruby:9.2.11.1-jre8

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

WORKDIR /usr/local/lib/hailstorm-api

RUN groupadd rack && \
    useradd -g rack -mr rack && \
    chown -R rack:rack /usr/local/lib/hailstorm-api

RUN apt-get update && apt-get install -y default-mysql-client git wget && rm -rf /var/lib/apt/lists/*

ENV DOCKERIZE_VERSION v0.6.1

RUN wget -q https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz

COPY . .

RUN bundle install && chown -R rack:rack /usr/local/lib/hailstorm-api

EXPOSE 8080

USER rack:rack

CMD [ "rackup", "-o", "0.0.0.0", "-p", "8080" ]
