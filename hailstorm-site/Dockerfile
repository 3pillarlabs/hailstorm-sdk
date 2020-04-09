FROM ruby:2.4

ENV DOCKERIZE_VERSION v0.6.1

RUN wget -q https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz

WORKDIR /usr/local/lib/hailstorm-site

RUN apt-get update && apt-get install -y default-mysql-client nodejs

RUN gem install bundler -v 2.1.4

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY . .

RUN mkdir -p tmp/cache tmp/pids tmp/sessions tmp/sockets log

ENV RAILS_ENV container

EXPOSE 80

CMD [ "/usr/local/lib/hailstorm-site/startup.sh" ]
