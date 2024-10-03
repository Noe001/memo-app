FROM ruby:3.2.3

RUN apt-get update -qq && apt-get install -y postgresql-client vim

ENV APP_ROOT /rails_app
RUN mkdir -p $APP_ROOT
WORKDIR $APP_ROOT

COPY ./Gemfile $APP_ROOT/Gemfile
COPY ./Gemfile.lock $APP_ROOT/Gemfile.lock

RUN bundle install
COPY . $APP_ROOT

CMD ["rails", "server", "-b", "0.0.0.0"]
