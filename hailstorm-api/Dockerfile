FROM jruby:9.1.17.0-jre

WORKDIR /usr/local/lib/hailstorm-api

RUN apt-get update && apt-get install -y default-mysql-client git

RUN groupadd toys && \
    useradd -g toys -mr zoe && \
    chown -R zoe:toys /usr/local/lib/hailstorm-api

ENV GEM_PATH /usr/local/bundle/gems

RUN gem install bundler -v 2.0.1

RUN mkdir pkg

COPY pkg/hailstorm-*.gem ./pkg/

RUN gem install pkg/hailstorm-*.gem

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY . .

RUN chown -R zoe:toys /usr/local/lib/hailstorm-api

EXPOSE 8080

USER zoe:toys

ENTRYPOINT ["rackup", "-o", "0.0.0.0", "-p", "8080"]
