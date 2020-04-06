FROM jruby:9.1.17.0-jre

WORKDIR /usr/local/lib/hailstorm-api

RUN groupadd rack && \
    useradd -g rack -mr rack && \
    chown -R rack:rack /usr/local/lib/hailstorm-api

RUN apt-get update && apt-get install -y default-mysql-client git wget && rm -rf /var/lib/apt/lists/*

ENV DOCKERIZE_VERSION v0.6.1

RUN wget -q https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz

ENV GEM_PATH /usr/local/bundle/gems

RUN gem install bundler -v 2.0.1

RUN mkdir pkg

COPY pkg/hailstorm-*.gem ./pkg/

RUN gem install pkg/hailstorm-*.gem

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY . .

RUN chown -R rack:rack /usr/local/lib/hailstorm-api

EXPOSE 8080

USER rack:rack

CMD [ "rackup", "-o", "0.0.0.0", "-p", "8080" ]
