FROM jruby:9.2.11.1-jre8

# throw errors if Gemfile has been modified since Gemfile.lock
RUN gem update bundler \
    && bundle config --global frozen 1

WORKDIR /usr/local/lib/hailstorm-cli

RUN groupadd hailstorm \
    && useradd -g hailstorm -m -s /bin/bash hailstorm \
    && apt-get update \
    && apt-get install -y default-mysql-client git vim \
    && rm -rf /var/lib/apt/lists/*

ENV DOCKERIZE_VERSION v0.6.1

RUN wget -q https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz

COPY . .

RUN bundle install

ENV HAILSTORM_ENV production

CMD [ "/bin/bash" ]
