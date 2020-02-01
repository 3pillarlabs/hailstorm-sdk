FROM ruby:2.4.1-stretch

WORKDIR /usr/local/lib/hailstorm-site

RUN apt-get update && apt-get install -y mysql-client nodejs

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY . .

RUN RAILS_ENV=container rake db:setup && \
    RAILS_ENV=container rake db:migrate && \
    mkdir -p tmp/cache tmp/pids tmp/sessions tmp/sockets log

ENV RAILS_ENV container

EXPOSE 34451

CMD [ "rackup", "-o", "0.0.0.0", "-p", "34451", "-E", "container" ]
