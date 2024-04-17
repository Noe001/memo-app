FROM ruby:3.2.3

RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
RUN apt-get update -qq && apt-get install -y default-mysql-client && apt-get install -y nodejs

RUN npm install --global yarn

ENV APP_ROOT /rails_app
RUN mkdir $APP_ROOT
WORKDIR $APP_ROOT

COPY ./Gemfile $APP_ROOT/Gemfile
COPY ./Gemfile.lock $APP_ROOT/Gemfile.lock

RUN bundle install
COPY . $APP_ROOT

CMD ["rails", "server", "-b", "0.0.0.0"]