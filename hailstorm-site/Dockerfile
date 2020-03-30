FROM ruby:2.4

WORKDIR /usr/local/lib/hailstorm-site

RUN apt-get update && apt-get install -y default-mysql-client nodejs

RUN gem install bundler -v 2.1.4

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY . .

RUN mkdir -p tmp/cache tmp/pids tmp/sessions tmp/sockets log

ENV RAILS_ENV container

EXPOSE 80

CMD bundle exec rake db:setup && \
    bundle exec rake db:migrate && \
    bundle exec rackup -o 0.0.0.0 -p 80 -E container
