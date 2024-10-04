#!/bin/bash
set -e
rm -f /myapp/tmp/pids/server.pid
bundle install
bundle exec rake assets:precompile
bundle exec rake assets:clean
bundle exec rake db:create
bundle exec rake db:migrate
bundle exec rake db:reset
exec "$@"
