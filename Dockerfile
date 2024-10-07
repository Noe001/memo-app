FROM ruby:3.3.5

RUN apt-get update -qq && apt-get install -y postgresql-client vim curl

RUN curl -sL https://deb.nodesource.com/setup_16.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g yarn

ENV APP_ROOT /rails_app
ENV RUBY_YJIT_ENABLE=1

RUN mkdir -p $APP_ROOT
WORKDIR $APP_ROOT

COPY ./Gemfile $APP_ROOT/Gemfile
COPY ./Gemfile.lock $APP_ROOT/Gemfile.lock

RUN bundle install
COPY . $APP_ROOT

RUN yarn install
RUN yarn build

EXPOSE 3000

COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

CMD ["rails", "server", "-b", "0.0.0.0"]
