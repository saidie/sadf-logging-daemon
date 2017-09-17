FROM ruby:2.4.1

WORKDIR /app

COPY Gemfile Gemfile.lock /app/

RUN bundle install --without development test

COPY bin/sart /app/bin/

COPY lib/ /app/lib/

CMD bundle exec ruby bin/sart
