FROM jruby:9.1.17.0-jre

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

RUN gem install cucumber -v 2.99.0 && mkdir pkg

COPY pkg/hailstorm-*.gem ./pkg/

RUN gem install pkg/hailstorm-*.gem

ARG HAILSTORM_VERSION

RUN echo "#!/bin/sh" > /usr/local/bin/create_hailstorm_app && \
    echo -n \
    exec "hailstorm -g /usr/local/bundle/gems/hailstorm-$HAILSTORM_VERSION-java" >> \
    /usr/local/bin/create_hailstorm_app && \
    echo ' $*' >> /usr/local/bin/create_hailstorm_app && \
    chmod +x /usr/local/bin/create_hailstorm_app

COPY . .

ENV GEM_PATH /usr/local/bundle/gems

RUN gem install bundler -v 2.0.1 && bundle install

CMD [ "/bin/bash" ]
