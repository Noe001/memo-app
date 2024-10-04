#!/bin/bash
set -e

# Remove a potentially pre-existing server.pid for Rails.
rm -f /myapp/tmp/pids/server.pid

# Install dependencies
bundle check || bundle install

# Precompile assets
bundle exec rake assets:precompile
bundle exec rake assets:clean

# Migrate the database
bundle exec rake db:migrate

# Execute the container's main process (what's set as CMD in the Dockerfile).
exec "$@"
